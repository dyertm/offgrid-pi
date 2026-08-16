#!/usr/bin/env python3

import argparse
import ctypes
import errno
import grp
import hashlib
import importlib.util
import json
import os
import pwd
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
INSPECTOR_PATH = ROOT / "inspect-map-pack.py"

LIVE_PACK_ROOT = Path("/srv/offgridpi/content/maps/packs")
DEFAULT_TEMP_ROOT = Path("/srv/offgridpi/content/maps/incoming")

FILE_MODE = 0o640
DIRECTORY_MODE = 0o750
PACK_DIRECTORY_MODE = 0o2750

AT_FDCWD = -100
RENAME_NOREPLACE = 1


def fail(message):
    raise ValueError(message)


def load_inspector():
    spec = importlib.util.spec_from_file_location(
        "offgridpi_map_pack_inspector",
        INSPECTOR_PATH,
    )

    if spec is None or spec.loader is None:
        fail("Unable to load the map-pack archive inspector.")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def sha256_file(path):
    digest = hashlib.sha256()

    with path.open("rb") as source:
        while True:
            chunk = source.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)

    return digest.hexdigest()


def path_has_symlink_component(path):
    absolute = path.absolute()
    current = Path(absolute.anchor)

    for part in absolute.parts[1:]:
        current = current / part

        if current.is_symlink():
            return True

    return False


def path_contains_symlink(root, destination):
    root = root.absolute()
    destination = destination.absolute()

    if path_has_symlink_component(root):
        return True

    try:
        relative = destination.relative_to(root)
    except ValueError:
        return True

    current = root

    for part in relative.parts:
        current = current / part

        if current.is_symlink():
            return True

    return False


def atomic_rename_noreplace(source, destination):
    libc = ctypes.CDLL(None, use_errno=True)
    renameat2 = getattr(libc, "renameat2", None)

    if renameat2 is None:
        fail(
            "Atomic no-replace directory installation is "
            "not supported on this system."
        )

    renameat2.argtypes = [
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_uint,
    ]
    renameat2.restype = ctypes.c_int

    result = renameat2(
        AT_FDCWD,
        os.fsencode(source),
        AT_FDCWD,
        os.fsencode(destination),
        RENAME_NOREPLACE,
    )

    if result == 0:
        return

    error_number = ctypes.get_errno()

    if error_number == errno.EEXIST:
        raise FileExistsError(
            error_number,
            "Destination already exists",
            destination,
        )

    raise OSError(
        error_number,
        os.strerror(error_number),
        destination,
    )


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


def nearest_existing_parent(path):
    current = path.absolute()

    while not current.exists():
        if current.parent == current:
            fail(f"No existing parent found for: {path}")
        current = current.parent

    return current


def verify_available_space(path, required_bytes):
    existing_parent = nearest_existing_parent(path)
    free_bytes = shutil.disk_usage(existing_parent).free

    if required_bytes > free_bytes:
        fail(
            "Insufficient storage: pack requires "
            f"{required_bytes} bytes but only "
            f"{free_bytes} bytes are available."
        )

    return free_bytes


def verify_installed_pack(directory, manifest):
    manifest_path = directory / "manifest.json"

    if manifest_path.is_symlink() or not manifest_path.is_file():
        return False, "installed manifest.json is missing or unsafe"

    try:
        installed_manifest = json.loads(
            manifest_path.read_text(encoding="utf-8")
        )
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        return False, "installed manifest.json is invalid"

    if installed_manifest != manifest:
        return False, "installed manifest does not match the archive"

    expected = {"manifest.json"}

    for declaration in manifest["files"]:
        relative = Path(declaration["path"])
        target = directory / relative
        expected.add(declaration["path"])

        if path_contains_symlink(directory, target):
            return False, f"{declaration['path']} contains a symbolic link"

        if target.is_symlink() or not target.is_file():
            return False, f"{declaration['path']} is missing or unsafe"

        if target.stat().st_size != declaration["size_bytes"]:
            return False, f"{declaration['path']} has the wrong size"

        if sha256_file(target) != declaration["sha256"]:
            return False, f"{declaration['path']} failed SHA-256 verification"

    actual = set()

    for target in directory.rglob("*"):
        if target.is_symlink():
            return False, f"installed pack contains symlink: {target}"

        if target.is_file():
            actual.add(target.relative_to(directory).as_posix())

    if actual != expected:
        return False, "installed pack contains missing or undeclared files"

    return True, "manifest, sizes, and SHA-256 values verified"


def normalize_tree_permissions(root, owner_uid, group_gid):
    for directory, subdirectories, filenames in os.walk(root):
        directory_path = Path(directory)

        os.chmod(directory_path, DIRECTORY_MODE)

        if owner_uid is not None and group_gid is not None:
            os.chown(directory_path, owner_uid, group_gid)

        for name in subdirectories:
            path = directory_path / name
            os.chmod(path, DIRECTORY_MODE)

            if owner_uid is not None and group_gid is not None:
                os.chown(path, owner_uid, group_gid)

        for name in filenames:
            path = directory_path / name
            os.chmod(path, FILE_MODE)

            if owner_uid is not None and group_gid is not None:
                os.chown(path, owner_uid, group_gid)


def write_member(archive, info, destination, expected_size, expected_hash):
    destination.parent.mkdir(
        parents=True,
        exist_ok=True,
        mode=DIRECTORY_MODE,
    )

    digest = hashlib.sha256()
    written = 0

    with archive.open(info, "r") as source:
        with destination.open("xb") as output:
            while True:
                chunk = source.read(1024 * 1024)

                if not chunk:
                    break

                written += len(chunk)

                if written > expected_size:
                    fail(
                        f"{info.filename} exceeded its declared size "
                        "during extraction."
                    )

                digest.update(chunk)
                output.write(chunk)

            output.flush()
            os.fsync(output.fileno())

    if written != expected_size:
        fail(
            f"{info.filename} extraction size mismatch: "
            f"expected {expected_size}, wrote {written}."
        )

    actual_hash = digest.hexdigest()

    if actual_hash != expected_hash:
        fail(
            f"{info.filename} extraction SHA-256 mismatch."
        )


def write_manifest(archive, info, destination):
    data = archive.read(info)

    with destination.open("xb") as output:
        output.write(data)
        output.flush()
        os.fsync(output.fileno())


def extract_verified_pack(
    archive_path,
    temporary_directory,
    manifest,
):
    declared = {
        item["path"]: item
        for item in manifest["files"]
    }

    with zipfile.ZipFile(archive_path, "r") as archive:
        members = {
            info.filename: info
            for info in archive.infolist()
            if not info.is_dir()
        }

        manifest_info = members["manifest.json"]

        write_manifest(
            archive,
            manifest_info,
            temporary_directory / "manifest.json",
        )

        for name, declaration in declared.items():
            write_member(
                archive,
                members[name],
                temporary_directory / name,
                declaration["size_bytes"],
                declaration["sha256"],
            )


def import_pack(
    archive_path,
    destination_root,
    temporary_root,
    confirm,
):
    inspector = load_inspector()
    manifest = inspector.validate_archive(
        archive_path,
        inspector.DEFAULT_MAX_INSTALLED_BYTES,
    )

    final_directory = (
        destination_root
        / manifest["pack_id"]
        / manifest["version"]
    )

    required_bytes = (
        manifest["estimated_installed_bytes"]
        + 1024 * 1024
    )

    print(f"Pack: {manifest['name']}")
    print(f"Pack ID: {manifest['pack_id']}")
    print(f"Version: {manifest['version']}")
    print(f"Archive: {archive_path}")
    print(f"Destination: {final_directory}")
    print(f"Temporary root: {temporary_root}")
    print(
        "Mode: "
        f"{'IMPORT' if confirm else 'PREVIEW'}"
    )
    print()

    if path_contains_symlink(destination_root, final_directory):
        fail("Destination path contains a symbolic link.")

    if path_has_symlink_component(temporary_root):
        fail("Temporary import path contains a symbolic link.")

    if final_directory.exists() or final_directory.is_symlink():
        if final_directory.is_symlink():
            fail("Installed pack destination is a symbolic link.")

        if not final_directory.is_dir():
            fail("Installed pack destination is not a directory.")

        valid, message = verify_installed_pack(
            final_directory,
            manifest,
        )

        if valid:
            if confirm:
                owner_uid, group_gid = installation_ownership()
                pack_container = final_directory.parent

                if path_contains_symlink(
                    destination_root,
                    pack_container,
                ):
                    fail(
                        "Map-pack container path contains a symbolic link."
                    )

                if owner_uid is not None and group_gid is not None:
                    os.chown(
                        pack_container,
                        owner_uid,
                        group_gid,
                    )

                os.chmod(
                    pack_container,
                    PACK_DIRECTORY_MODE,
                )

            print(f"Result: ALREADY INSTALLED — {message}")
            return 0

        fail(
            "An existing installation of this pack version "
            f"failed verification: {message}"
        )

    free_bytes = verify_available_space(
        destination_root,
        required_bytes,
    )

    print(
        "Storage check: "
        f"{required_bytes} bytes required; "
        f"{free_bytes} bytes available."
    )

    if not confirm:
        print("Result: READY — archive passed import preview.")
        return 0

    owner_uid, group_gid = installation_ownership()

    destination_parent = final_directory.parent
    destination_parent.mkdir(
        parents=True,
        exist_ok=True,
        mode=PACK_DIRECTORY_MODE,
    )

    if path_contains_symlink(
        destination_root,
        destination_parent,
    ):
        fail(
            "Map-pack container path contains a symbolic link."
        )

    if owner_uid is not None and group_gid is not None:
        os.chown(
            destination_parent,
            owner_uid,
            group_gid,
        )

    os.chmod(
        destination_parent,
        PACK_DIRECTORY_MODE,
    )

    temporary_root.mkdir(
        parents=True,
        exist_ok=True,
        mode=DIRECTORY_MODE,
    )

    if (
        destination_parent.stat().st_dev
        != temporary_root.stat().st_dev
    ):
        fail(
            "Temporary and destination directories must be "
            "on the same filesystem for atomic installation."
        )

    temporary_path = Path(
        tempfile.mkdtemp(
            prefix=(
                f".{manifest['pack_id']}-"
                f"{manifest['version']}-"
            ),
            suffix=".importing",
            dir=temporary_root,
        )
    )

    installed = False

    try:
        extract_verified_pack(
            archive_path,
            temporary_path,
            manifest,
        )

        normalize_tree_permissions(
            temporary_path,
            owner_uid,
            group_gid,
        )

        valid, message = verify_installed_pack(
            temporary_path,
            manifest,
        )

        if not valid:
            fail(
                "Temporary map-pack extraction failed "
                f"verification: {message}"
            )

        try:
            atomic_rename_noreplace(
                temporary_path,
                final_directory,
            )
        except FileExistsError:
            fail(
                "Destination appeared during installation; "
                "nothing was overwritten."
            )
        except OSError as error:
            if final_directory.exists():
                fail(
                    "Destination appeared during installation; "
                    "nothing was overwritten."
                )
            raise error

        installed = True

        valid, message = verify_installed_pack(
            final_directory,
            manifest,
        )

        if not valid:
            if (
                final_directory.exists()
                and final_directory.is_dir()
                and not final_directory.is_symlink()
            ):
                shutil.rmtree(final_directory)

            installed = False

            fail(
                "Installed map pack failed final verification; "
                f"the new installation was removed: {message}"
            )

        print(f"Result: INSTALLED — {message}")
        return 0

    finally:
        if not installed and temporary_path.exists():
            shutil.rmtree(temporary_path)


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Safely import a verified Offgrid Pi .ogmap archive."
        )
    )

    parser.add_argument(
        "archive",
        type=Path,
        help="Path to the .ogmap archive.",
    )

    parser.add_argument(
        "--confirm",
        action="store_true",
        help="Perform the import. Without this flag, preview only.",
    )

    parser.add_argument(
        "--destination-root",
        type=Path,
        default=LIVE_PACK_ROOT,
        help=argparse.SUPPRESS,
    )

    parser.add_argument(
        "--temporary-root",
        type=Path,
        default=DEFAULT_TEMP_ROOT,
        help=argparse.SUPPRESS,
    )

    return parser.parse_args()


def main():
    args = parse_args()

    if not args.archive.is_file():
        print(
            f"FAIL: Archive not found: {args.archive}",
            file=sys.stderr,
        )
        return 2

    if (
        args.confirm
        and args.destination_root.absolute()
        == LIVE_PACK_ROOT.absolute()
        and os.geteuid() != 0
    ):
        print(
            "FAIL: Live map-pack import requires root privileges.",
            file=sys.stderr,
        )
        return 2

    try:
        return import_pack(
            args.archive,
            args.destination_root,
            args.temporary_root,
            args.confirm,
        )
    except (
        OSError,
        ValueError,
        KeyError,
        zipfile.BadZipFile,
    ) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
