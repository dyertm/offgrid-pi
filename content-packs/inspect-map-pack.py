#!/usr/bin/env python3

import argparse
import hashlib
import importlib.util
import json
import re
import stat
import sys
import zipfile
from pathlib import Path

MANIFEST_NAME = "manifest.json"
MAX_MANIFEST_BYTES = 1024 * 1024
MAX_ARCHIVE_MEMBERS = 2048
DEFAULT_MAX_INSTALLED_BYTES = 1024 ** 4  # 1 TiB safety ceiling
MAX_COMPRESSION_RATIO = 1000
ALLOWED_COMPRESSION_METHODS = {
    zipfile.ZIP_STORED,
    zipfile.ZIP_DEFLATED,
}

DRIVE_PATH = re.compile(r"^[A-Za-z]:")


def fail(message):
    raise ValueError(message)


def load_manifest_validator():
    validator_path = Path(__file__).with_name("validate-map-pack.py")

    spec = importlib.util.spec_from_file_location(
        "offgridpi_map_manifest_validator",
        validator_path,
    )

    if spec is None or spec.loader is None:
        fail("Unable to load the map manifest validator.")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def validate_member_path(name, is_directory):
    if not name:
        fail("Archive contains an empty member name.")

    if "\x00" in name:
        fail("Archive member contains a NUL character.")

    if "\\" in name:
        fail(f"Archive member uses backslashes: {name}")

    if name.startswith("/") or DRIVE_PATH.match(name):
        fail(f"Archive member uses an absolute path: {name}")

    path = name[:-1] if is_directory and name.endswith("/") else name

    if not path:
        fail(f"Archive contains an invalid path: {name}")

    parts = path.split("/")

    if any(part in {"", ".", ".."} for part in parts):
        fail(f"Archive member contains an unsafe path component: {name}")


def validate_member_type(info):
    mode = (info.external_attr >> 16) & 0xFFFF
    file_type = stat.S_IFMT(mode)

    if stat.S_ISLNK(mode):
        fail(f"Symbolic links are not permitted: {info.filename}")

    if info.is_dir():
        if file_type not in {0, stat.S_IFDIR}:
            fail(
                "Archive directory has an unsupported file type: "
                f"{info.filename}"
            )
        return

    if file_type not in {0, stat.S_IFREG}:
        fail(f"Special files are not permitted: {info.filename}")


def validate_compression(info):
    if info.compress_type not in ALLOWED_COMPRESSION_METHODS:
        fail(
            "Archive member uses an unsupported compression method: "
            f"{info.filename}"
        )

    if info.file_size == 0:
        return

    if info.compress_size == 0:
        fail(
            "Archive member has invalid compressed size: "
            f"{info.filename}"
        )

    ratio = info.file_size / info.compress_size

    if ratio > MAX_COMPRESSION_RATIO:
        fail(
            "Archive member exceeds the permitted compression ratio: "
            f"{info.filename}"
        )


def sha256_member(archive, info):
    digest = hashlib.sha256()

    with archive.open(info, "r") as source:
        while True:
            chunk = source.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)

    return digest.hexdigest()


def validate_archive(path, max_installed_bytes):
    if path.suffix.lower() != ".ogmap":
        fail("Map pack archive must use the .ogmap extension.")

    manifest_validator = load_manifest_validator()

    try:
        archive = zipfile.ZipFile(path, "r")
    except (OSError, zipfile.BadZipFile) as error:
        fail(f"Unable to open map pack: {error}")

    with archive:
        members = archive.infolist()

        if not members:
            fail("Map pack archive is empty.")

        if len(members) > MAX_ARCHIVE_MEMBERS:
            fail(
                "Map pack contains too many archive members: "
                f"{len(members)}"
            )

        names = set()
        regular_members = {}
        directory_members = []

        for info in members:
            validate_member_path(info.filename, info.is_dir())
            validate_member_type(info)

            if info.flag_bits & 0x1:
                fail(
                    "Encrypted archive members are not permitted: "
                    f"{info.filename}"
                )

            if info.filename in names:
                fail(f"Duplicate archive member: {info.filename}")

            names.add(info.filename)

            if info.is_dir():
                directory_members.append(info.filename)
                continue

            validate_compression(info)
            regular_members[info.filename] = info

        manifest_info = regular_members.get(MANIFEST_NAME)

        if manifest_info is None:
            fail("Map pack does not contain manifest.json.")

        if manifest_info.file_size > MAX_MANIFEST_BYTES:
            fail("manifest.json exceeds the permitted size.")

        try:
            manifest_bytes = archive.read(manifest_info)
            manifest = json.loads(manifest_bytes.decode("utf-8"))
        except UnicodeDecodeError as error:
            fail(f"manifest.json is not valid UTF-8: {error}")
        except json.JSONDecodeError as error:
            fail(f"manifest.json is not valid JSON: {error}")
        except zipfile.BadZipFile as error:
            fail(f"Unable to read manifest.json: {error}")

        manifest_validator.validate_manifest(manifest)

        declared = {
            item["path"]: item
            for item in manifest["files"]
        }

        expected_names = set(declared)
        actual_names = set(regular_members) - {MANIFEST_NAME}

        missing = sorted(expected_names - actual_names)
        undeclared = sorted(actual_names - expected_names)

        if missing:
            fail(f"Archive is missing declared files: {missing}")

        if undeclared:
            fail(f"Archive contains undeclared files: {undeclared}")

        for directory in directory_members:
            prefix = directory.rstrip("/") + "/"

            if not any(
                name.startswith(prefix)
                for name in expected_names
            ):
                fail(f"Archive contains an undeclared directory: {directory}")

        if manifest["estimated_installed_bytes"] > max_installed_bytes:
            fail(
                "Pack exceeds the permitted installed-size ceiling: "
                f"{manifest['estimated_installed_bytes']} bytes"
            )

        for name, declaration in declared.items():
            info = regular_members[name]

            if info.file_size != declaration["size_bytes"]:
                fail(
                    f"{name} size mismatch: manifest declares "
                    f"{declaration['size_bytes']} bytes but archive contains "
                    f"{info.file_size} bytes."
                )

            try:
                actual_hash = sha256_member(archive, info)
            except (
                OSError,
                RuntimeError,
                NotImplementedError,
                zipfile.BadZipFile,
            ) as error:
                fail(f"Unable to verify {name}: {error}")

            if actual_hash != declaration["sha256"]:
                fail(
                    f"{name} SHA-256 mismatch: expected "
                    f"{declaration['sha256']} but calculated {actual_hash}."
                )

        return manifest


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Safely inspect and validate an Offgrid Pi .ogmap archive."
        )
    )

    parser.add_argument(
        "archive",
        type=Path,
        help="Path to the .ogmap ZIP-compatible archive.",
    )

    parser.add_argument(
        "--max-installed-bytes",
        type=int,
        default=DEFAULT_MAX_INSTALLED_BYTES,
        help=(
            "Maximum permitted installed file total. "
            "Defaults to 1 TiB."
        ),
    )

    return parser.parse_args()


def main():
    args = parse_args()

    if args.max_installed_bytes < 1:
        print(
            "FAIL: --max-installed-bytes must be at least 1.",
            file=sys.stderr,
        )
        return 1

    try:
        manifest = validate_archive(
            args.archive,
            args.max_installed_bytes,
        )
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1

    print(
        "PASS: Valid map-pack archive: "
        f"{manifest['pack_id']} {manifest['version']} "
        f"({len(manifest['files'])} declared files)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
