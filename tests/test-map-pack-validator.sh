#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$ROOT/content-packs/validate-map-pack.py"
MANIFEST="$ROOT/content-packs/manifests/maps/synthetic-test.json"
SCHEMA="$ROOT/content-packs/schema/map-pack.schema.json"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEMP_ROOT"' EXIT

python3 -m json.tool "$SCHEMA" >/dev/null
python3 -m json.tool "$MANIFEST" >/dev/null
pass "Map-pack schema and synthetic manifest are valid JSON."

"$VALIDATOR" "$MANIFEST"
pass "Known-good synthetic map manifest was accepted."

create_fixture() {
  local mutation="$1"
  local output="$2"

  python3 - "$MANIFEST" "$output" "$mutation" <<'PY'
import copy
import json
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])
mutation = sys.argv[3]

data = json.loads(source.read_text(encoding="utf-8"))

if mutation == "duplicate_path":
    data["files"][1]["path"] = data["files"][0]["path"]
    data["files"][1]["role"] = "basemap"
    data["files"][1]["media_type"] = "application/vnd.pmtiles"

elif mutation == "second_basemap":
    duplicate = copy.deepcopy(data["files"][0])
    duplicate["path"] = "data/second.pmtiles"
    data["files"].append(duplicate)
    data["estimated_installed_bytes"] += duplicate["size_bytes"]

elif mutation == "missing_license":
    data["files"] = [
        item for item in data["files"]
        if item["role"] != "license"
    ]
    data["estimated_installed_bytes"] = sum(
        item["size_bytes"] for item in data["files"]
    )

elif mutation == "wrong_media":
    data["files"][0]["media_type"] = "text/plain"

elif mutation == "unsafe_path":
    data["files"][0]["path"] = "../basemap.pmtiles"

elif mutation == "bad_bounds":
    data["region"]["bounds"] = [-122.0, 45.0, -123.0, 46.0]

elif mutation == "center_outside":
    data["region"]["default_center"] = [-120.0, 45.5]

elif mutation == "zoom_order":
    data["region"]["min_zoom"] = 12
    data["region"]["max_zoom"] = 10

elif mutation == "byte_total":
    data["estimated_installed_bytes"] += 1

elif mutation == "unsupported_style":
    data["style_id"] = "unknown-style"

elif mutation == "published_restricted":
    data["status"] = "published"
    data["sources"][0]["redistribution"] = "restricted"

elif mutation == "source_newer":
    data["sources"][0]["data_date"] = "2026-08-07"

elif mutation == "non_https_source":
    data["sources"][0]["source_page"] = (
        "http://example.invalid/offgridpi/synthetic-map"
    )

else:
    raise SystemExit(f"Unknown mutation: {mutation}")

target.write_text(
    json.dumps(data, indent=2) + "\n",
    encoding="utf-8",
)
PY
}

expect_failure() {
  local mutation="$1"
  local description="$2"
  local fixture="$TEMP_ROOT/${mutation}.json"

  create_fixture "$mutation" "$fixture"

  if "$VALIDATOR" "$fixture" >/dev/null 2>&1; then
    fail "$description was incorrectly accepted."
  fi

  pass "$description was rejected."
}

expect_failure duplicate_path "Duplicate file path"
expect_failure second_basemap "Second basemap"
expect_failure missing_license "Manifest without a license file"
expect_failure wrong_media "Role/media-type mismatch"
expect_failure unsafe_path "Unsafe file path"
expect_failure bad_bounds "Reversed geographic bounds"
expect_failure center_outside "Default center outside bounds"
expect_failure zoom_order "Reversed zoom range"
expect_failure byte_total "Incorrect installed-byte total"
expect_failure unsupported_style "Unsupported reader-owned style"
expect_failure published_restricted "Published pack without permitted redistribution"
expect_failure source_newer "Source date newer than pack date"
expect_failure non_https_source "Non-HTTPS source URL"

pass "Map-pack manifest validator tests completed."
