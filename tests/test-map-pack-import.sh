#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMPORTER="$ROOT/content-packs/import-map-pack.py"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEMP_ROOT"' EXIT

ARCHIVE="$TEMP_ROOT/synthetic-import.ogmap"
DESTINATION_ROOT="$TEMP_ROOT/live/packs"
IMPORT_ROOT="$TEMP_ROOT/incoming"

python3 - "$ARCHIVE" <<'PY'
import hashlib
import json
import sys
import zipfile
from pathlib import Path

output = Path(sys.argv[1])

files = {
    "data/basemap.pmtiles": b"Synthetic PMTiles import payload\n",
    "licenses/public-domain.txt": b"Public-domain synthetic test data.\n",
    "README.txt": b"Synthetic Offgrid Pi import fixture.\n",
}

def sha256(data):
    return hashlib.sha256(data).hexdigest()

manifest = {
    "schema_version": 1,
    "pack_format": "ogmap-zip-v1",
    "pack_id": "synthetic-import-test",
    "name": "Synthetic Import Test",
    "version": "0.1.0",
    "status": "draft",
    "reader_compatibility": {
        "minimum_version": "0.1.0"
    },
    "description": "Synthetic fixture for map-pack import testing.",
    "region": {
        "name": "Synthetic Test Region",
        "bounds": [-123.0, 45.0, -122.0, 46.0],
        "default_center": [-122.5, 45.5],
        "min_zoom": 0,
        "max_zoom": 10
    },
    "data_date": "2026-08-14",
    "estimated_installed_bytes": sum(
        len(data) for data in files.values()
    ),
    "style_id": "emergency-basic",
    "tile_schema_id": "protomaps-basemap-v4",
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
            "source_page": "https://example.invalid/offgridpi/import-test",
            "source_version": "0.1.0",
            "data_date": "2026-08-14",
            "license": "Public domain test fixture",
            "redistribution": "permitted",
            "attribution": "Synthetic test data",
            "notes": "Contains no real geographic data."
        }
    ],
    "limitations": [
        "Synthetic import fixture only."
    ]
}

with zipfile.ZipFile(
    output,
    "w",
    compression=zipfile.ZIP_DEFLATED,
) as archive:
    archive.writestr(
        "manifest.json",
        json.dumps(manifest, indent=2) + "\n",
    )

    for name, data in files.items():
        archive.writestr(name, data)
PY

FINAL_DIRECTORY="$DESTINATION_ROOT/synthetic-import-test/0.1.0"

"$IMPORTER" \
  "$ARCHIVE" \
  --destination-root "$DESTINATION_ROOT" \
  --temporary-root "$IMPORT_ROOT" \
  >/dev/null

if [[ -e "$FINAL_DIRECTORY" ]]; then
  fail "Preview mode created the installed pack directory."
fi

pass "Preview mode made no installation changes."

"$IMPORTER" \
  "$ARCHIVE" \
  --destination-root "$DESTINATION_ROOT" \
  --temporary-root "$IMPORT_ROOT" \
  --confirm

for path in \
  "$FINAL_DIRECTORY/manifest.json" \
  "$FINAL_DIRECTORY/data/basemap.pmtiles" \
  "$FINAL_DIRECTORY/licenses/public-domain.txt" \
  "$FINAL_DIRECTORY/README.txt"
do
  if [[ ! -f "$path" || -L "$path" ]]; then
    fail "Expected installed regular file is missing or unsafe: $path"
  fi
done

pass "Confirmed import installed the complete versioned pack."

PACK_CONTAINER="$DESTINATION_ROOT/synthetic-import-test"

if [[ "$(stat -c '%a' "$PACK_CONTAINER")" != "2750" ]]; then
  fail "Pack container directory does not use mode 2750."
fi

pass "Pack container directory uses the setgid maintenance mode."

if find "$FINAL_DIRECTORY" -type f ! -perm 0640 -print -quit \
    | grep -q .
then
  fail "Installed map-pack files do not all use mode 0640."
fi

if find "$FINAL_DIRECTORY" -type d ! -perm 0750 -print -quit \
    | grep -q .
then
  fail "Installed map-pack directories do not all use mode 0750."
fi

pass "Installed map-pack permissions are normalized."

if find "$IMPORT_ROOT" -mindepth 1 -print -quit 2>/dev/null \
    | grep -q .
then
  fail "Successful import left temporary extraction content behind."
fi

pass "Successful import cleaned temporary extraction content."

output="$(
  "$IMPORTER" \
    "$ARCHIVE" \
    --destination-root "$DESTINATION_ROOT" \
    --temporary-root "$IMPORT_ROOT" \
    --confirm
)"

if [[ "$output" != *"ALREADY INSTALLED"* ]]; then
  fail "Repeated import did not report the verified pack as already installed."
fi

pass "Repeated import is idempotent for an unchanged installed version."

chmod 0750 "$PACK_CONTAINER"

repair_output="$(
  "$IMPORTER"     "$ARCHIVE"     --destination-root "$DESTINATION_ROOT"     --temporary-root "$IMPORT_ROOT"     --confirm
)"

if [[ "$repair_output" != *"ALREADY INSTALLED"* ]]; then
  fail "Confirmed re-import did not recognize the valid installed pack."
fi

if [[ "$(stat -c '%a' "$PACK_CONTAINER")" != "2750" ]]; then
  fail "Confirmed re-import did not repair the pack-container mode."
fi

pass "Confirmed re-import repairs the pack-container maintenance mode."

VERSION_TWO_ARCHIVE="$TEMP_ROOT/synthetic-import-v2.ogmap"
VERSION_TWO_DIRECTORY="$DESTINATION_ROOT/synthetic-import-test/0.2.0"

python3 - "$ARCHIVE" "$VERSION_TWO_ARCHIVE" <<'PYVERSION'
import json
import sys
import zipfile
from pathlib import Path

source = Path(sys.argv[1])
destination = Path(sys.argv[2])

with zipfile.ZipFile(source, "r") as original:
    manifest = json.loads(original.read("manifest.json"))
    manifest["version"] = "0.2.0"

    with zipfile.ZipFile(
        destination,
        "w",
        compression=zipfile.ZIP_DEFLATED,
    ) as updated:
        updated.writestr(
            "manifest.json",
            json.dumps(manifest, indent=2) + "\n",
        )

        for info in original.infolist():
            if info.is_dir() or info.filename == "manifest.json":
                continue

            updated.writestr(
                info.filename,
                original.read(info.filename),
            )
PYVERSION

"$IMPORTER"   "$VERSION_TWO_ARCHIVE"   --destination-root "$DESTINATION_ROOT"   --temporary-root "$IMPORT_ROOT"   --confirm   >/dev/null

if [[ ! -d "$FINAL_DIRECTORY" || ! -d "$VERSION_TWO_DIRECTORY" ]]; then
  fail "Versioned import did not preserve both pack versions."
fi

if ! cmp -s     "$FINAL_DIRECTORY/README.txt"     "$VERSION_TWO_DIRECTORY/README.txt"
then
  fail "Installing a newer version modified the older pack version."
fi

pass "Newer pack version installed alongside the preserved older version."

INVALID_ARCHIVE="$TEMP_ROOT/invalid-import.ogmap"
INVALID_DESTINATION_ROOT="$TEMP_ROOT/invalid-live/packs"
INVALID_IMPORT_ROOT="$TEMP_ROOT/invalid-incoming"

python3 - "$ARCHIVE" "$INVALID_ARCHIVE" <<'PYINVALID'
import sys
import zipfile
from pathlib import Path

source = Path(sys.argv[1])
destination = Path(sys.argv[2])

with zipfile.ZipFile(source, "r") as original:
    with zipfile.ZipFile(
        destination,
        "w",
        compression=zipfile.ZIP_DEFLATED,
    ) as invalid:
        for info in original.infolist():
            if info.is_dir():
                continue

            invalid.writestr(
                info.filename,
                original.read(info.filename),
            )

        invalid.writestr(
            "undeclared.txt",
            b"This file is intentionally undeclared.\n",
        )
PYINVALID

if "$IMPORTER"     "$INVALID_ARCHIVE"     --destination-root "$INVALID_DESTINATION_ROOT"     --temporary-root "$INVALID_IMPORT_ROOT"     --confirm     >/dev/null 2>&1
then
  fail "Invalid archive was incorrectly imported."
fi

if [[ -e "$INVALID_DESTINATION_ROOT" || -e "$INVALID_IMPORT_ROOT" ]]; then
  fail "Invalid archive created destination or temporary import content."
fi

pass "Invalid archive was rejected before installation changes."

printf 'tampered\n' >> "$FINAL_DIRECTORY/README.txt"

if "$IMPORTER" \
    "$ARCHIVE" \
    --destination-root "$DESTINATION_ROOT" \
    --temporary-root "$IMPORT_ROOT" \
    --confirm \
    >/dev/null 2>&1
then
  fail "Tampered installed pack was incorrectly accepted."
fi

if ! grep -q 'tampered' "$FINAL_DIRECTORY/README.txt"; then
  fail "Tampered installed content was overwritten unexpectedly."
fi

pass "Tampered existing version was blocked without overwrite."

SYMLINK_TARGET="$TEMP_ROOT/symlink-target"
SYMLINK_DEST="$TEMP_ROOT/symlink-destination"

mkdir -p "$SYMLINK_TARGET"
ln -s "$SYMLINK_TARGET" "$SYMLINK_DEST"

if "$IMPORTER" \
    "$ARCHIVE" \
    --destination-root "$SYMLINK_DEST" \
    --temporary-root "$TEMP_ROOT/safe-temp" \
    --confirm \
    >/dev/null 2>&1
then
  fail "Symlinked destination root was incorrectly accepted."
fi

pass "Symlinked destination path was rejected."

SAFE_DEST="$TEMP_ROOT/safe-destination"
REAL_TEMP="$TEMP_ROOT/real-import-root"
SYMLINK_TEMP="$TEMP_ROOT/symlink-import-root"

mkdir -p "$REAL_TEMP"
ln -s "$REAL_TEMP" "$SYMLINK_TEMP"

if "$IMPORTER" \
    "$ARCHIVE" \
    --destination-root "$SAFE_DEST" \
    --temporary-root "$SYMLINK_TEMP" \
    --confirm \
    >/dev/null 2>&1
then
  fail "Symlinked temporary root was incorrectly accepted."
fi

pass "Symlinked temporary import path was rejected."

python3 - "$ROOT" "$TEMP_ROOT" <<'PY'
import importlib.util
import sys
from pathlib import Path

root = Path(sys.argv[1])
temp_root = Path(sys.argv[2])
module_path = root / "content-packs" / "import-map-pack.py"

spec = importlib.util.spec_from_file_location(
    "offgridpi_map_import_test",
    module_path,
)

if spec is None or spec.loader is None:
    raise SystemExit("Unable to load importer module.")

module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

source = temp_root / "atomic-source"
destination = temp_root / "atomic-destination"

source.mkdir()
destination.mkdir()

(source / "source-marker").write_text(
    "source\n",
    encoding="utf-8",
)

(destination / "destination-marker").write_text(
    "destination\n",
    encoding="utf-8",
)

try:
    module.atomic_rename_noreplace(
        source,
        destination,
    )
except FileExistsError:
    pass
else:
    raise SystemExit(
        "Atomic no-replace rename overwrote an existing destination."
    )

if not source.is_dir():
    raise SystemExit(
        "Atomic no-replace failure removed the source directory."
    )

if not (destination / "destination-marker").is_file():
    raise SystemExit(
        "Atomic no-replace failure modified the existing destination."
    )
PY

pass "Atomic directory activation refuses an existing destination."
pass "Map-pack importer tests completed."
