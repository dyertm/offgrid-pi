#!/usr/bin/env python3

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent
VALIDATOR = ROOT / "validate-manifest.py"
CONTENT_ROOT = Path("/srv/offgridpi/content")


def format_bytes(value):
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

    print(
        (result.stdout + result.stderr).strip(),
        file=sys.stderr,
    )
    return False


def plan_manifest(path):
    manifest = json.loads(path.read_text(encoding="utf-8"))

    incomplete_metadata = 0
    required_missing = 0
    destination_conflicts = 0
    insecure_sources = 0
    known_missing_bytes = 0

    print(f"Pack: {manifest['name']}")
    print(f"Pack ID: {manifest['pack_id']}")
    print(f"Version: {manifest['version']}")
    print("Mode: READ-ONLY")
    print()

    for number, item in enumerate(manifest["items"], start=1):
        destination = Path(item["destination"])
        installed = destination.is_file()
        metadata_complete = (
            item["size_bytes"] > 0 and bool(item["sha256"])
        )
        source_scheme = urlparse(item["source_url"]).scheme.lower()
        secure_source = source_scheme == "https"

        if not metadata_complete:
            incomplete_metadata += 1

        if item["required"] and not installed:
            required_missing += 1

        if not installed and item["size_bytes"] > 0:
            known_missing_bytes += item["size_bytes"]

        conflict = destination.exists() and not destination.is_file()
        if conflict:
            destination_conflicts += 1

        if not secure_source:
            insecure_sources += 1

        print(f"[{number}] {item['title']}")
        print(f"    Item ID: {item['item_id']}")
        print(f"    Required: {'yes' if item['required'] else 'no'}")
        print(f"    Installed: {'yes' if installed else 'no'}")
        print(
            "    Metadata: "
            f"{'COMPLETE' if metadata_complete else 'INCOMPLETE'}"
        )
        print(
            "    Source transport: "
            f"{'HTTPS' if secure_source else 'NOT HTTPS'}"
        )
        print(f"    Destination: {destination}")

        if conflict:
            print("    Destination check: CONFLICT")
        else:
            print("    Destination check: PASS")

        if installed:
            print("    Planned action: KEEP")
        elif not metadata_complete:
            print(
                "    Planned action: BLOCKED — record exact "
                "size and SHA-256 first"
            )
        elif not secure_source:
            print(
                "    Planned action: BLOCKED — source must use HTTPS"
            )
        else:
            print("    Planned action: DOWNLOAD AND VERIFY")

        print()

    return {
        "incomplete_metadata": incomplete_metadata,
        "required_missing": required_missing,
        "destination_conflicts": destination_conflicts,
        "insecure_sources": insecure_sources,
        "known_missing_bytes": known_missing_bytes,
        "manifest": manifest,
    }


def show_summary(result):
    manifest = result["manifest"]

    storage_path = CONTENT_ROOT
    while not storage_path.exists() and storage_path != storage_path.parent:
        storage_path = storage_path.parent

    usage = shutil.disk_usage(storage_path)

    estimated = result["known_missing_bytes"]
    if estimated == 0 and result["required_missing"] > 0:
        estimated = manifest["estimated_download_bytes"]

    enough_space = usage.free >= estimated

    blocked = any(
        (
            result["incomplete_metadata"],
            result["destination_conflicts"],
            result["insecure_sources"],
            not enough_space,
        )
    )

    print("Summary")
    print(
        "    Estimated remaining download: "
        f"{format_bytes(estimated)}"
    )
    print(f"    Available storage: {format_bytes(usage.free)}")
    print(
        "    Storage check: "
        f"{'PASS' if enough_space else 'FAIL'}"
    )
    print(
        "    Incomplete item metadata: "
        f"{result['incomplete_metadata']}"
    )
    print(
        "    Destination conflicts: "
        f"{result['destination_conflicts']}"
    )
    print(
        "    Insecure sources: "
        f"{result['insecure_sources']}"
    )
    print(
        "    Required items missing: "
        f"{result['required_missing']}"
    )
    print(
        "    Plan readiness: "
        f"{'BLOCKED' if blocked else 'READY'}"
    )

    return 1 if blocked else 0


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Create a read-only Offgrid Pi content-pack "
            "installation plan."
        )
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

    result = plan_manifest(args.manifest)
    return show_summary(result)


if __name__ == "__main__":
    raise SystemExit(main())
