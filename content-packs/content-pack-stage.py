#!/usr/bin/env python3

import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent
VALIDATOR = ROOT / "validate-manifest.py"
DEFAULT_STAGING_ROOT = Path(
    "/srv/offgridpi/staging/content-packs"
)


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


def sha256_file(path):
    digest = hashlib.sha256()

    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)

    return digest.hexdigest()


def verify_file(path, item):
    expected_size = item["size_bytes"]
    expected_hash = item["sha256"].lower()
    actual_size = path.stat().st_size

    if actual_size != expected_size:
        return (
            False,
            f"size mismatch: expected {expected_size}, "
            f"found {actual_size}",
        )

    actual_hash = sha256_file(path)

    if actual_hash != expected_hash:
        return (
            False,
            "SHA-256 mismatch",
        )

    return True, "size and SHA-256 verified"


def download_item(item, target):
    expected_size = item["size_bytes"]
    expected_hash = item["sha256"].lower()
    temporary = target.with_name(target.name + ".part")

    if temporary.exists():
        temporary.unlink()

    target.parent.mkdir(
        parents=True,
        exist_ok=True,
        mode=0o750,
    )

    request = Request(
        item["source_url"],
        headers={
            "User-Agent": "Offgrid-Pi-Content-Pack/1.0",
        },
    )

    digest = hashlib.sha256()
    downloaded = 0

    try:
        with urlopen(request, timeout=60) as response:
            with temporary.open("xb") as output:
                while True:
                    chunk = response.read(1024 * 1024)

                    if not chunk:
                        break

                    downloaded += len(chunk)

                    if downloaded > expected_size:
                        raise ValueError(
                            "download exceeded expected size"
                        )

                    digest.update(chunk)
                    output.write(chunk)

        if downloaded != expected_size:
            raise ValueError(
                f"size mismatch: expected {expected_size}, "
                f"downloaded {downloaded}"
            )

        actual_hash = digest.hexdigest()

        if actual_hash != expected_hash:
            raise ValueError("SHA-256 mismatch")

        os.chmod(temporary, 0o640)
        os.replace(temporary, target)

    except Exception:
        if temporary.exists():
            temporary.unlink()
        raise


def stage_manifest(manifest_path, staging_root, dry_run):
    manifest = json.loads(
        manifest_path.read_text(encoding="utf-8")
    )

    pack_directory = (
        staging_root
        / manifest["pack_id"]
        / manifest["version"]
    )

    blocked = 0
    staged = 0
    reused = 0
    installed = 0

    print(f"Pack: {manifest['name']}")
    print(f"Pack ID: {manifest['pack_id']}")
    print(f"Version: {manifest['version']}")
    print(f"Staging root: {staging_root}")
    print(
        "Mode: "
        f"{'DRY RUN' if dry_run else 'DOWNLOAD AND VERIFY'}"
    )
    print()

    for number, item in enumerate(
        manifest["items"],
        start=1,
    ):
        destination = Path(item["destination"])
        source_scheme = urlparse(
            item["source_url"]
        ).scheme.lower()

        metadata_complete = (
            item["size_bytes"] > 0
            and bool(item["sha256"])
        )

        filename = destination.name
        staged_file = (
            pack_directory
            / item["item_id"]
            / filename
        )

        print(f"[{number}] {item['title']}")
        print(f"    Item ID: {item['item_id']}")
        print(f"    Live destination: {destination}")
        print(f"    Staged file: {staged_file}")

        if not metadata_complete:
            print(
                "    Result: BLOCKED — exact size and "
                "SHA-256 are required"
            )
            blocked += 1
            print()
            continue

        if source_scheme != "https":
            print(
                "    Result: BLOCKED — source must use HTTPS"
            )
            blocked += 1
            print()
            continue

        if destination.exists():
            if not destination.is_file():
                print(
                    "    Result: BLOCKED — live destination "
                    "is not a regular file"
                )
                blocked += 1
            else:
                valid, message = verify_file(
                    destination,
                    item,
                )

                if valid:
                    print(
                        "    Result: ALREADY INSTALLED — "
                        f"{message}"
                    )
                    installed += 1
                else:
                    print(
                        "    Result: BLOCKED — existing live "
                        f"file failed verification: {message}"
                    )
                    blocked += 1

            print()
            continue

        if staged_file.exists():
            if not staged_file.is_file():
                print(
                    "    Result: BLOCKED — staging path "
                    "is not a regular file"
                )
                blocked += 1
            else:
                valid, message = verify_file(
                    staged_file,
                    item,
                )

                if valid:
                    print(
                        "    Result: REUSED — existing staged "
                        f"file {message}"
                    )
                    reused += 1
                else:
                    print(
                        "    Result: BLOCKED — existing staged "
                        f"file failed verification: {message}"
                    )
                    blocked += 1

            print()
            continue

        if dry_run:
            print(
                "    Result: WOULD DOWNLOAD AND VERIFY"
            )
            print()
            continue

        try:
            download_item(item, staged_file)
        except Exception as error:
            print(f"    Result: FAILED — {error}")
            blocked += 1
        else:
            print(
                "    Result: STAGED — size and SHA-256 verified"
            )
            staged += 1

        print()

    print("Summary")
    print(f"    Newly staged: {staged}")
    print(f"    Reused staged files: {reused}")
    print(f"    Already installed: {installed}")
    print(f"    Blocked or failed: {blocked}")
    print(
        "    Staging readiness: "
        f"{'BLOCKED' if blocked else 'READY'}"
    )

    return 1 if blocked else 0


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Safely download and verify Offgrid Pi "
            "content into a staging directory."
        )
    )
    parser.add_argument(
        "manifest",
        type=Path,
        help="Path to a content-pack manifest.",
    )
    parser.add_argument(
        "--staging-root",
        type=Path,
        default=DEFAULT_STAGING_ROOT,
        help=(
            "Staging directory. Defaults to "
            "/srv/offgridpi/staging/content-packs."
        ),
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Perform checks without downloading anything.",
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

    return stage_manifest(
        args.manifest,
        args.staging_root,
        args.dry_run,
    )


if __name__ == "__main__":
    raise SystemExit(main())
