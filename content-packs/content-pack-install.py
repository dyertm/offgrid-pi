#!/usr/bin/env python3

import argparse
import grp
import hashlib
import json
import os
import pwd
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
VALIDATOR = ROOT / "validate-manifest.py"

LIVE_CONTENT_ROOT = Path("/srv/offgridpi/content")
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
    actual_size = path.stat().st_size
    expected_size = item["size_bytes"]

    if actual_size != expected_size:
        return (
            False,
            f"size mismatch: expected {expected_size}, "
            f"found {actual_size}",
        )

    actual_hash = sha256_file(path)
    expected_hash = item["sha256"].lower()

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


def staged_file_path(manifest, item, staging_root):
    destination = Path(item["destination"])

    return (
        staging_root
        / manifest["pack_id"]
        / manifest["version"]
        / item["item_id"]
        / destination.name
    )


def path_contains_symlink(root, destination):
    root = root.absolute()
    destination = destination.absolute()

    if root.is_symlink():
        return True

    try:
        relative = destination.relative_to(root)
    except ValueError:
        return True

    current = root

    for part in relative.parts:
        current = current / part

        if current.exists() and current.is_symlink():
            return True

    return False


def installation_ownership():
    if os.geteuid() != 0:
        return None, None

    username = os.environ.get("SUDO_USER")

    if username and username != "root":
        owner_uid = pwd.getpwnam(username).pw_uid
    else:
        owner_uid = 0

    group_gid = grp.getgrnam("offgridpi").gr_gid
    return owner_uid, group_gid


def install_verified_file(
    staged_file,
    destination,
    item,
    owner_uid,
    group_gid,
):
    destination.parent.mkdir(
        parents=True,
        exist_ok=True,
        mode=0o750,
    )

    file_descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{destination.name}.",
        suffix=".installing",
        dir=destination.parent,
    )

    temporary = Path(temporary_name)

    try:
        with os.fdopen(file_descriptor, "wb") as output:
            with staged_file.open("rb") as source:
                for chunk in iter(
                    lambda: source.read(1024 * 1024),
                    b"",
                ):
                    output.write(chunk)

            output.flush()
            os.fsync(output.fileno())

        valid, message = verify_file(temporary, item)

        if not valid:
            return False, f"temporary copy failed: {message}"

        os.chmod(temporary, 0o640)

        if owner_uid is not None and group_gid is not None:
            os.chown(temporary, owner_uid, group_gid)

        try:
            os.link(temporary, destination)
        except FileExistsError:
            return (
                False,
                "destination appeared during installation; "
                "nothing was overwritten",
            )

        valid, message = verify_file(destination, item)

        if not valid:
            destination.unlink(missing_ok=True)
            return (
                False,
                f"installed file failed verification: {message}",
            )

        return True, message

    finally:
        temporary.unlink(missing_ok=True)


def install_manifest(
    manifest_path,
    staging_root,
    destination_root,
    confirm,
):
    manifest = json.loads(
        manifest_path.read_text(encoding="utf-8")
    )

    installed = 0
    already_installed = 0
    would_install = 0
    blocked = 0

    owner_uid = None
    group_gid = None

    if confirm and os.geteuid() == 0:
        try:
            owner_uid, group_gid = installation_ownership()
        except (KeyError, OSError) as error:
            print(
                f"FAIL: Could not resolve installation ownership: "
                f"{error}",
                file=sys.stderr,
            )
            return 2

    print(f"Pack: {manifest['name']}")
    print(f"Pack ID: {manifest['pack_id']}")
    print(f"Version: {manifest['version']}")
    print(f"Staging root: {staging_root}")
    print(f"Destination root: {destination_root}")
    print(
        "Mode: "
        f"{'INSTALL' if confirm else 'PREVIEW'}"
    )
    print()

    for number, item in enumerate(
        manifest["items"],
        start=1,
    ):
        metadata_complete = (
            item["size_bytes"] > 0
            and bool(item["sha256"])
        )

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

        staged_file = staged_file_path(
            manifest,
            item,
            staging_root,
        )

        print(f"[{number}] {item['title']}")
        print(f"    Item ID: {item['item_id']}")
        print(f"    Staged file: {staged_file}")
        print(f"    Destination: {destination}")

        if not metadata_complete:
            print(
                "    Result: BLOCKED — exact size and "
                "SHA-256 are required"
            )
            blocked += 1
            print()
            continue

        if path_contains_symlink(
            destination_root,
            destination,
        ):
            print(
                "    Result: BLOCKED — destination path "
                "contains a symbolic link"
            )
            blocked += 1
            print()
            continue

        if destination.exists() or destination.is_symlink():
            if destination.is_symlink():
                print(
                    "    Result: BLOCKED — destination is "
                    "a symbolic link"
                )
                blocked += 1
            elif not destination.is_file():
                print(
                    "    Result: BLOCKED — destination is "
                    "not a regular file"
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
                    already_installed += 1
                else:
                    print(
                        "    Result: BLOCKED — existing file "
                        f"failed verification: {message}"
                    )
                    blocked += 1

            print()
            continue

        if staged_file.is_symlink():
            print(
                "    Result: BLOCKED — staged file is "
                "a symbolic link"
            )
            blocked += 1
            print()
            continue

        if not staged_file.is_file():
            print(
                "    Result: BLOCKED — verified staged "
                "file is missing"
            )
            blocked += 1
            print()
            continue

        valid, message = verify_file(staged_file, item)

        if not valid:
            print(
                "    Result: BLOCKED — staged file failed "
                f"verification: {message}"
            )
            blocked += 1
            print()
            continue

        if not confirm:
            print(
                "    Result: WOULD INSTALL — "
                f"{message}"
            )
            would_install += 1
            print()
            continue

        success, message = install_verified_file(
            staged_file,
            destination,
            item,
            owner_uid,
            group_gid,
        )

        if success:
            print(f"    Result: INSTALLED — {message}")
            installed += 1
        else:
            print(f"    Result: BLOCKED — {message}")
            blocked += 1

        print()

    print("Summary")
    print(f"    Newly installed: {installed}")
    print(f"    Already installed: {already_installed}")
    print(f"    Would install: {would_install}")
    print(f"    Blocked or failed: {blocked}")
    print(
        "    Installation readiness: "
        f"{'BLOCKED' if blocked else 'READY'}"
    )

    return 1 if blocked else 0


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Install only verified staged Offgrid Pi content "
            "without overwriting existing files."
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
        help="Install verified staged files.",
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

    if (
        args.confirm
        and args.destination_root.absolute()
        == LIVE_CONTENT_ROOT.absolute()
        and os.geteuid() != 0
    ):
        print(
            "FAIL: Live installation requires root privileges.",
            file=sys.stderr,
        )
        return 2

    return install_manifest(
        args.manifest,
        args.staging_root,
        args.destination_root,
        args.confirm,
    )


if __name__ == "__main__":
    raise SystemExit(main())
