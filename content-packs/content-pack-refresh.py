#!/usr/bin/env python3

import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
VALIDATOR = ROOT / "validate-manifest.py"
LIVE_CONTENT_ROOT = Path("/srv/offgridpi/content")


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
        for chunk in iter(
            lambda: handle.read(1024 * 1024),
            b"",
        ):
            digest.update(chunk)

    return digest.hexdigest()


def verify_file(path, item):
    expected_size = item["size_bytes"]
    actual_size = path.stat().st_size

    if actual_size != expected_size:
        return (
            False,
            f"size mismatch: expected {expected_size}, "
            f"found {actual_size}",
        )

    expected_hash = item["sha256"].lower()
    actual_hash = sha256_file(path)

    if actual_hash != expected_hash:
        return False, "SHA-256 mismatch"

    return True, "size and SHA-256 verified"


def mapped_destination(item, destination_root):
    declared = Path(item["destination"])

    try:
        relative = declared.relative_to(LIVE_CONTENT_ROOT)
    except ValueError as error:
        raise ValueError(
            "destination is outside the approved content root"
        ) from error

    return destination_root / relative


def run_service_command(command, description):
    print(f"    {description}")

    result = subprocess.run(
        command,
        capture_output=True,
        text=True,
        check=False,
    )

    if result.stdout.strip():
        for line in result.stdout.strip().splitlines():
            print(f"        {line}")

    if result.returncode != 0:
        print(
            f"    FAILED: {description}",
            file=sys.stderr,
        )

        if result.stderr.strip():
            for line in result.stderr.strip().splitlines():
                print(
                    f"        {line}",
                    file=sys.stderr,
                )

        return False

    return True


def refresh_kiwix():
    commands = (
        (
            ["systemctl", "enable", "kiwix-serve.service"],
            "Enable the Kiwix service.",
        ),
        (
            ["systemctl", "restart", "kiwix-serve.service"],
            "Restart Kiwix and rediscover approved ZIM files.",
        ),
        (
            [
                "systemctl",
                "is-active",
                "--quiet",
                "kiwix-serve.service",
            ],
            "Verify that Kiwix is active.",
        ),
    )

    return all(
        run_service_command(command, description)
        for command, description in commands
    )


def refresh_documents():
    commands = (
        (
            [
                "systemctl",
                "enable",
                "offgridpi-document-indexer.service",
            ],
            "Enable the document indexer.",
        ),
        (
            [
                "systemctl",
                "restart",
                "offgridpi-document-indexer.service",
            ],
            "Restart the indexer and rebuild the catalog.",
        ),
        (
            [
                "systemctl",
                "is-active",
                "--quiet",
                "offgridpi-document-indexer.service",
            ],
            "Verify that the document indexer is active.",
        ),
    )

    return all(
        run_service_command(command, description)
        for command, description in commands
    )


def refresh_manifest(
    manifest_path,
    destination_root,
    confirm,
):
    manifest = json.loads(
        manifest_path.read_text(encoding="utf-8")
    )

    blocked = 0
    verified = 0
    optional_missing = 0
    refresh_types = set()

    print(f"Pack: {manifest['name']}")
    print(f"Pack ID: {manifest['pack_id']}")
    print(f"Version: {manifest['version']}")
    print(f"Destination root: {destination_root}")
    print(
        "Mode: "
        f"{'REFRESH SERVICES' if confirm else 'PREVIEW'}"
    )
    print()

    for number, item in enumerate(
        manifest["items"],
        start=1,
    ):
        try:
            destination = mapped_destination(
                item,
                destination_root,
            )
        except ValueError as error:
            print(f"[{number}] {item['title']}")
            print(f"    Result: BLOCKED — {error}")
            blocked += 1
            print()
            continue

        metadata_complete = (
            item["size_bytes"] > 0
            and bool(item["sha256"])
        )

        print(f"[{number}] {item['title']}")
        print(f"    Item ID: {item['item_id']}")
        print(f"    Content type: {item['content_type']}")
        print(f"    Destination: {destination}")

        if not destination.exists():
            if item["required"]:
                if not metadata_complete:
                    print(
                        "    Result: BLOCKED — exact size and "
                        "SHA-256 are required"
                    )
                else:
                    print(
                        "    Result: BLOCKED — required "
                        "installed file is missing"
                    )

                blocked += 1
            else:
                print(
                    "    Result: SKIPPED — optional item "
                    "is not installed"
                )
                optional_missing += 1

            print()
            continue

        if destination.is_symlink():
            print(
                "    Result: BLOCKED — installed path "
                "is a symbolic link"
            )
            blocked += 1
            print()
            continue

        if not destination.is_file():
            print(
                "    Result: BLOCKED — installed path "
                "is not a regular file"
            )
            blocked += 1
            print()
            continue

        if not metadata_complete:
            print(
                "    Result: BLOCKED — exact size and "
                "SHA-256 are required"
            )
            blocked += 1
            print()
            continue

        valid, message = verify_file(
            destination,
            item,
        )

        if not valid:
            print(
                "    Result: BLOCKED — installed file "
                f"failed verification: {message}"
            )
            blocked += 1
            print()
            continue

        print(f"    Result: VERIFIED — {message}")
        verified += 1
        refresh_types.add(item["content_type"])
        print()

    refreshed = 0

    if blocked:
        print(
            "Refresh actions were not run because "
            "content verification failed."
        )
    else:
        if "zim" in refresh_types:
            print("Kiwix refresh")

            if confirm:
                if refresh_kiwix():
                    print("    Result: PASS")
                    refreshed += 1
                else:
                    print("    Result: FAIL")
                    blocked += 1
            else:
                print(
                    "    Result: WOULD ENABLE AND RESTART "
                    "kiwix-serve.service"
                )

            print()

        if "document" in refresh_types:
            print("Document catalog refresh")

            if confirm:
                if refresh_documents():
                    print("    Result: PASS")
                    refreshed += 1
                else:
                    print("    Result: FAIL")
                    blocked += 1
            else:
                print(
                    "    Result: WOULD ENABLE AND RESTART "
                    "offgridpi-document-indexer.service"
                )

            print()

        ignored_types = refresh_types - {
            "zim",
            "document",
        }

        for content_type in sorted(ignored_types):
            print(
                f"No refresh action is required for "
                f"content type: {content_type}"
            )

    print("Summary")
    print(f"    Verified installed items: {verified}")
    print(f"    Optional items missing: {optional_missing}")
    print(f"    Refresh actions completed: {refreshed}")
    print(f"    Blocked or failed: {blocked}")
    print(
        "    Refresh readiness: "
        f"{'BLOCKED' if blocked else 'READY'}"
    )

    return 1 if blocked else 0


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Verify installed Offgrid Pi content and refresh "
            "the affected local services."
        )
    )
    parser.add_argument(
        "manifest",
        type=Path,
        help="Path to a content-pack manifest.",
    )
    parser.add_argument(
        "--destination-root",
        type=Path,
        default=LIVE_CONTENT_ROOT,
        help=argparse.SUPPRESS,
    )
    parser.add_argument(
        "--confirm",
        action="store_true",
        help="Refresh affected services after verification.",
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

    live_destination = (
        args.destination_root.absolute()
        == LIVE_CONTENT_ROOT.absolute()
    )

    if args.confirm and live_destination and os.geteuid() != 0:
        print(
            "FAIL: Live service refresh requires root privileges.",
            file=sys.stderr,
        )
        return 2

    return refresh_manifest(
        args.manifest,
        args.destination_root,
        args.confirm,
    )


if __name__ == "__main__":
    raise SystemExit(main())
