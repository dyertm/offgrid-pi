#!/usr/bin/env python3

import json
import re
import sys
from pathlib import Path, PurePosixPath

ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
SHA256_PATTERN = re.compile(r"^[0-9a-fA-F]{64}$")

ALLOWED_DESTINATIONS = (
    PurePosixPath("/srv/offgridpi/content/kiwix"),
    PurePosixPath("/srv/offgridpi/content/documents/public"),
)

PACK_FIELDS = {
    "schema_version",
    "pack_id",
    "name",
    "version",
    "description",
    "category",
    "status",
    "language",
    "region",
    "estimated_download_bytes",
    "estimated_installed_bytes",
    "items",
}

ITEM_FIELDS = {
    "item_id",
    "title",
    "content_type",
    "source_url",
    "source_page",
    "source_version",
    "license",
    "redistribution",
    "size_bytes",
    "sha256",
    "destination",
    "required",
    "notes",
}


def destination_is_safe(value):
    if not isinstance(value, str) or not value.startswith("/"):
        return False

    destination = PurePosixPath(value)

    if ".." in destination.parts:
        return False

    personal = PurePosixPath(
        "/srv/offgridpi/content/documents/personal"
    )

    if destination == personal or personal in destination.parents:
        return False

    return any(
        destination == root or root in destination.parents
        for root in ALLOWED_DESTINATIONS
    )


def validate_manifest(manifest):
    errors = []

    missing = sorted(PACK_FIELDS - set(manifest))
    if missing:
        errors.append(
            "Missing pack fields: " + ", ".join(missing)
        )

    if manifest.get("schema_version") != 1:
        errors.append("schema_version must equal 1.")

    pack_id = manifest.get("pack_id")
    if not isinstance(pack_id, str) or not ID_PATTERN.fullmatch(pack_id):
        errors.append(
            "pack_id must contain lowercase letters, numbers, "
            "dots, underscores, or hyphens."
        )

    for field in (
        "estimated_download_bytes",
        "estimated_installed_bytes",
    ):
        value = manifest.get(field)
        if not isinstance(value, int) or value < 0:
            errors.append(f"{field} must be a nonnegative integer.")

    items = manifest.get("items")
    if not isinstance(items, list) or not items:
        errors.append("items must be a nonempty list.")
        return errors

    seen_item_ids = set()

    for number, item in enumerate(items, start=1):
        label = f"Item {number}"

        if not isinstance(item, dict):
            errors.append(f"{label} must be an object.")
            continue

        missing = sorted(ITEM_FIELDS - set(item))
        if missing:
            errors.append(
                f"{label} is missing fields: " + ", ".join(missing)
            )

        item_id = item.get("item_id")
        if not isinstance(item_id, str) or not ID_PATTERN.fullmatch(item_id):
            errors.append(f"{label} has an invalid item_id.")
        elif item_id in seen_item_ids:
            errors.append(f"Duplicate item_id: {item_id}")
        else:
            seen_item_ids.add(item_id)

        license_name = item.get("license")
        if not isinstance(license_name, str) or not license_name.strip():
            errors.append(f"{label} must document a license.")

        checksum = item.get("sha256")
        if checksum and (
            not isinstance(checksum, str)
            or not SHA256_PATTERN.fullmatch(checksum)
        ):
            errors.append(
                f"{label} sha256 must be empty or exactly "
                "64 hexadecimal characters."
            )

        size = item.get("size_bytes")
        if not isinstance(size, int) or size < 0:
            errors.append(
                f"{label} size_bytes must be a nonnegative integer."
            )

        destination = item.get("destination")
        if not destination_is_safe(destination):
            errors.append(
                f"{label} has an unsafe destination: {destination!r}"
            )

        required = item.get("required")
        if not isinstance(required, bool):
            errors.append(f"{label} required must be true or false.")

    return errors


def main():
    if len(sys.argv) != 2:
        print(
            "Usage: validate-manifest.py MANIFEST.json",
            file=sys.stderr,
        )
        return 2

    path = Path(sys.argv[1])

    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        print(f"FAIL: Manifest not found: {path}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as error:
        print(f"FAIL: Invalid JSON: {error}", file=sys.stderr)
        return 1

    if not isinstance(manifest, dict):
        print("FAIL: Manifest root must be an object.")
        return 1

    errors = validate_manifest(manifest)

    if errors:
        for error in errors:
            print(f"FAIL: {error}")
        return 1

    print(
        f"PASS: {path} contains "
        f"{len(manifest['items'])} valid item(s)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
