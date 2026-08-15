#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSPECTOR="$ROOT/content-packs/inspect-map-pack.py"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEMP_ROOT"' EXIT

create_archive() {
  local mutation="$1"
  local output="$2"

  python3 - "$mutation" "$output" <<'PY'
import hashlib
import json
import stat
import sys
import warnings
import zipfile
from pathlib import Path

mutation = sys.argv[1]
output = Path(sys.argv[2])

files = {
    "data/basemap.pmtiles": b"Synthetic PMTiles test payload\n",
    "licenses/public-domain.txt": b"Public-domain synthetic test data.\n",
    "README.txt": b"Synthetic Offgrid Pi map-pack fixture.\n",
}

def sha256(data):
    return hashlib.sha256(data).hexdigest()

manifest = {
    "schema_version": 1,
    "pack_format": "ogmap-zip-v1",
    "pack_id": "synthetic-archive-test",
    "name": "Synthetic Archive Test",
    "version": "0.1.0",
    "status": "draft",
    "reader_compatibility": {
        "minimum_version": "0.1.0"
    },
    "description": "Synthetic archive fixture for safe map-pack inspection.",
    "region": {
        "name": "Synthetic Test Region",
        "bounds": [-123.0, 45.0, -122.0, 46.0],
        "default_center": [-122.5, 45.5],
        "min_zoom": 0,
        "max_zoom": 10
    },
    "data_date": "2026-08-14",
    "estimated_installed_bytes": sum(len(data) for data in files.values()),
    "style_id": "emergency-basic",
    "files": [
        {
            "path": "data/basemap.pmtiles",
            "role": "basemap",
            "media_type": "application/vnd.pmtiles",
            "size_bytes": len(files["data/basemap.pmtiles"]),
            "sha256": sha256(files["data/basemap.pmtiles"]),
            "required": True
        },
        {
            "path": "licenses/public-domain.txt",
            "role": "license",
            "media_type": "text/plain",
            "size_bytes": len(files["licenses/public-domain.txt"]),
            "sha256": sha256(files["licenses/public-domain.txt"]),
            "required": True
        },
        {
            "path": "README.txt",
            "role": "readme",
            "media_type": "text/plain",
            "size_bytes": len(files["README.txt"]),
            "sha256": sha256(files["README.txt"]),
            "required": True
        }
    ],
    "sources": [
        {
            "source_id": "synthetic",
            "name": "Synthetic Test Data",
            "source_page": "https://example.invalid/offgridpi/archive-test",
            "source_version": "0.1.0",
            "data_date": "2026-08-14",
            "license": "Public domain test fixture",
            "redistribution": "permitted",
            "attribution": "Synthetic test data",
            "notes": "Contains no real geographic data."
        }
    ],
    "limitations": [
        "Synthetic archive fixture only."
    ]
}

if mutation == "bad_size":
    manifest["files"][0]["size_bytes"] += 1
    manifest["estimated_installed_bytes"] += 1

elif mutation == "bad_hash":
    manifest["files"][0]["sha256"] = "0" * 64

with zipfile.ZipFile(
    output,
    "w",
    compression=zipfile.ZIP_DEFLATED,
) as archive:

    if mutation != "missing_manifest":
        archive.writestr(
            "manifest.json",
            json.dumps(manifest, indent=2) + "\n",
        )

    for name, data in files.items():
        if mutation == "missing_declared" and name == "README.txt":
            continue

        if mutation == "unsupported_compression" and name == "README.txt":
            archive.writestr(
                name,
                data,
                compress_type=zipfile.ZIP_BZIP2,
            )
            continue

        archive.writestr(name, data)

    if mutation == "undeclared_file":
        archive.writestr("extra.txt", b"undeclared\n")

    elif mutation == "unsafe_path":
        archive.writestr("../escape.txt", b"unsafe\n")

    elif mutation == "absolute_path":
        archive.writestr("/absolute.txt", b"unsafe\n")

    elif mutation == "backslash_path":
        archive.writestr(r"data\evil.pmtiles", b"unsafe\n")

    elif mutation == "duplicate_member":
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            archive.writestr("README.txt", b"duplicate\n")

    elif mutation == "symlink":
        info = zipfile.ZipInfo("overlays/link.geojson")
        info.create_system = 3
        info.external_attr = (
            (stat.S_IFLNK | 0o777) << 16
        )
        archive.writestr(info, "README.txt")

    elif mutation == "compression_ratio":
        archive.writestr(
            "overlays/bomb.geojson",
            b"0" * (8 * 1024 * 1024),
        )
PY
}

expect_failure() {
  local mutation="$1"
  local description="$2"
  local archive="$TEMP_ROOT/${mutation}.ogmap"

  create_archive "$mutation" "$archive"

  if "$INSPECTOR" "$archive" >/dev/null 2>&1; then
    fail "$description was incorrectly accepted."
  fi

  pass "$description was rejected."
}

GOOD_ARCHIVE="$TEMP_ROOT/good.ogmap"
create_archive good "$GOOD_ARCHIVE"

"$INSPECTOR" "$GOOD_ARCHIVE"
pass "Known-good .ogmap archive was accepted."

expect_failure missing_manifest "Archive without manifest.json"
expect_failure missing_declared "Archive missing a declared file"
expect_failure undeclared_file "Archive containing an undeclared file"
expect_failure unsafe_path "Parent-directory traversal path"
expect_failure absolute_path "Absolute archive path"
expect_failure backslash_path "Backslash archive path"
expect_failure duplicate_member "Duplicate archive member"
expect_failure symlink "Symbolic-link archive member"
expect_failure bad_size "Declared file-size mismatch"
expect_failure bad_hash "Declared SHA-256 mismatch"
expect_failure compression_ratio "Excessive compression ratio"
expect_failure unsupported_compression "Unsupported ZIP compression method"

WRONG_EXTENSION="$TEMP_ROOT/good.zip"
cp "$GOOD_ARCHIVE" "$WRONG_EXTENSION"

if "$INSPECTOR" "$WRONG_EXTENSION" >/dev/null 2>&1; then
  fail "Archive without the .ogmap extension was incorrectly accepted."
fi

pass "Non-.ogmap archive extension was rejected."

if "$INSPECTOR" \
    --max-installed-bytes 1 \
    "$GOOD_ARCHIVE" \
    >/dev/null 2>&1
then
  fail "Installed-size ceiling was not enforced."
fi

pass "Installed-size ceiling was enforced."
pass "Map-pack archive inspection tests completed."
