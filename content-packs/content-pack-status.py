#!/usr/bin/env python3

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
VALIDATOR = ROOT / "validate-manifest.py"


def format_bytes(value):
    if value == 0:
        return "0 bytes"

    units = ("bytes", "KiB", "MiB", "GiB", "TiB")
    size = float(value)

    for unit in units:
        if size < 1024 or unit == units[-1]:
            if unit == "bytes":
                return f"{int(size)} bytes"
            return f"{size:.1f} {unit}"
        size /= 1024

    return f"{value} bytes"


def validate_manifest(path):
    result = subprocess.run(
        [str(VALIDATOR), str(path)],
        capture_output=True,
        text=True,
        check=False,
    )

    if result.returncode == 0:
        return True

    message = (result.stdout + result.stderr).strip()
    print(message, file=sys.stderr)
    return False


def show_status(path):
    manifest = json.loads(path.read_text(encoding="utf-8"))
    items = manifest["items"]

    installed_count = 0
    required_missing = 0
    metadata_incomplete = 0

    print(f"Pack: {manifest['name']}")
    print(f"Pack ID: {manifest['pack_id']}")
    print(f"Version: {manifest['version']}")
    print(f"Status: {manifest['status']}")
    print(
        "Estimated download: "
        f"{format_bytes(manifest['estimated_download_bytes'])}"
    )
    print(
        "Estimated installed size: "
        f"{format_bytes(manifest['estimated_installed_bytes'])}"
    )
    print()

    for number, item in enumerate(items, start=1):
        destination = Path(item["destination"])
        installed = destination.is_file()
        expected_size = item["size_bytes"]
        checksum_recorded = bool(item["sha256"])

        if installed:
            installed_count += 1

        if item["required"] and not installed:
            required_missing += 1

        if expected_size == 0 or not checksum_recorded:
            metadata_incomplete += 1

        print(f"[{number}] {item['title']}")
        print(f"    Item ID: {item['item_id']}")
        print(f"    Required: {'yes' if item['required'] else 'no'}")
        print(f"    Status: {'INSTALLED' if installed else 'MISSING'}")
        print(f"    Destination: {destination}")

        if expected_size:
            print(
                "    Manifest size: "
                f"{format_bytes(expected_size)}"
            )
        else:
            print("    Manifest size: not recorded")

        print(
            "    SHA-256: "
            f"{'recorded' if checksum_recorded else 'not recorded'}"
        )

        if installed:
            actual_size = destination.stat().st_size
            print(
                "    Actual size: "
                f"{format_bytes(actual_size)}"
            )

            if expected_size:
                match = actual_size == expected_size
                print(
                    "    Size verification: "
                    f"{'PASS' if match else 'FAIL'}"
                )

        print()


    print("Summary")
    print(f"    Installed items: {installed_count}/{len(items)}")
    print(f"    Required items missing: {required_missing}")
    print(f"    Items with incomplete metadata: {metadata_incomplete}")

    ready = required_missing == 0 and metadata_incomplete == 0
    print(f"    Pack readiness: {'READY' if ready else 'NOT READY'}")


def main():
    parser = argparse.ArgumentParser(
        description="Display Offgrid Pi content-pack status."
    )
    parser.add_argument(
        "manifest",
        type=Path,
        help="Path to a content-pack manifest.",
    )
    args = parser.parse_args()

    if not args.manifest.is_file():
        print(
            f"FAIL: Manifest not found: {args.manifest}",
            file=sys.stderr,
        )
        return 2

    if not validate_manifest(args.manifest):
        return 1

    show_status(args.manifest)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
