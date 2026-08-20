#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER="$ROOT/scripts/offgridpi-map-server.py"

TEMP_DIR="$(mktemp -d)"
READER_ROOT="$TEMP_DIR/reader"
PACK_ROOT="$TEMP_DIR/packs"
PACK_DIR="$PACK_ROOT/test-pack/0.1.0"
OUTPUT="$TEMP_DIR/server.log"
PORT=18084
PID=""

cleanup() {
  if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
    kill "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
  fi

  rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

[[ -x "$SERVER" ]] ||
  fail "Map server is missing or not executable."

python3 -m py_compile "$SERVER"
pass "Map-server syntax is valid."

mkdir -p \
  "$READER_ROOT" \
  "$PACK_DIR/data" \
  "$PACK_DIR/licenses"

cat > "$READER_ROOT/index.html" <<'HTML'
<!doctype html>
<html>
<head><title>Offline Maps</title></head>
<body><h1>Offline Maps</h1></body>
</html>
HTML

printf '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ' \
  > "$PACK_DIR/data/basemap.pmtiles"

printf 'Synthetic license\n' \
  > "$PACK_DIR/licenses/test.txt"

printf 'Synthetic map pack\n' \
  > "$PACK_DIR/README.txt"

python3 - "$PACK_DIR" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

pack = Path(sys.argv[1])

files = []

for relative, role, media_type in [
    (
        "data/basemap.pmtiles",
        "basemap",
        "application/vnd.pmtiles",
    ),
    (
        "licenses/test.txt",
        "license",
        "text/plain",
    ),
    (
        "README.txt",
        "readme",
        "text/plain",
    ),
]:
    data = (pack / relative).read_bytes()

    files.append(
        {
            "path": relative,
            "role": role,
            "media_type": media_type,
            "size_bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
            "required": True,
        }
    )

manifest = {
    "schema_version": 1,
    "pack_format": "ogmap-zip-v1",
    "pack_id": "test-pack",
    "name": "Synthetic Reader Test",
    "version": "0.1.0",
    "status": "draft",
    "reader_compatibility": {
        "minimum_version": "0.1.0"
    },
    "description": "Synthetic reader fixture.",
    "region": {
        "name": "Synthetic Region",
        "bounds": [-123.0, 45.0, -122.0, 46.0],
        "default_center": [-122.5, 45.5],
        "min_zoom": 0,
        "max_zoom": 10
    },
    "data_date": "2026-08-15",
    "estimated_installed_bytes": sum(
        item["size_bytes"] for item in files
    ),
    "style_id": "emergency-basic",
    "tile_schema_id": "protomaps-basemap-v4",
    "files": files,
    "sources": [],
    "limitations": ["Synthetic test only."]
}

(pack / "manifest.json").write_text(
    json.dumps(manifest, indent=2) + "\n",
    encoding="utf-8",
)
PY

mkdir -p "$PACK_ROOT/broken-pack/0.1.0"
printf '{not valid json\n' \
  > "$PACK_ROOT/broken-pack/0.1.0/manifest.json"

mkdir -p "$PACK_ROOT/mismatched-pack/0.1.0"
cp "$PACK_DIR/manifest.json" \
  "$PACK_ROOT/mismatched-pack/0.1.0/manifest.json"

ln -s "$PACK_ROOT/test-pack" \
  "$PACK_ROOT/symlink-pack"

OFFGRIDPI_MAP_BIND="127.0.0.1" \
OFFGRIDPI_MAP_PORT="$PORT" \
OFFGRIDPI_MAP_READER_ROOT="$READER_ROOT" \
OFFGRIDPI_MAP_PACK_ROOT="$PACK_ROOT" \
  "$SERVER" >"$OUTPUT" 2>&1 &

PID=$!

for _ in $(seq 1 30); do
  if curl \
    --silent \
    --fail \
    --output /dev/null \
    "http://127.0.0.1:$PORT/"
  then
    break
  fi

  sleep 0.1
done

kill -0 "$PID" 2>/dev/null ||
  fail "Map server failed to start."

root_status="$(
  curl \
    --silent \
    --output "$TEMP_DIR/root.html" \
    --write-out '%{http_code}' \
    "http://127.0.0.1:$PORT/"
)"

[[ "$root_status" == "200" ]] ||
  fail "Reader root did not return HTTP 200."

grep -q 'Offline Maps' "$TEMP_DIR/root.html" ||
  fail "Reader root content is missing."

pass "Reader application root is served."

discovery_status="$(
  curl \
    --silent \
    --show-error \
    --dump-header "$TEMP_DIR/discovery.headers" \
    --output "$TEMP_DIR/discovery.json" \
    --write-out '%{http_code}' \
    "http://127.0.0.1:$PORT/api/packs"
)"

[[ "$discovery_status" == "200" ]] ||
  fail "Map-pack discovery did not return HTTP 200."

grep -qi '^Content-Type: application/json' "$TEMP_DIR/discovery.headers" ||
  fail "Map-pack discovery did not return JSON."

python3 - "$TEMP_DIR/discovery.json" <<'PYTEST'
import json
import sys
from pathlib import Path

payload = json.loads(
    Path(sys.argv[1]).read_text(encoding="utf-8")
)

if payload.get("schema_version") != 1:
    raise SystemExit(
        "Discovery schema version is incorrect."
    )

packs = payload.get("packs")

if not isinstance(packs, list) or len(packs) != 1:
    raise SystemExit(
        "Discovery did not return exactly one installed pack."
    )

pack = packs[0]

expected = {
    "pack_id": "test-pack",
    "name": "Synthetic Reader Test",
    "version": "0.1.0",
    "status": "draft",
    "description": "Synthetic reader fixture.",
    "data_date": "2026-08-15",
    "style_id": "emergency-basic",
    "tile_schema_id": "protomaps-basemap-v4",
    "limitations": ["Synthetic test only."],
    "manifest_url": "/packs/test-pack/0.1.0/manifest.json",
    "basemap_url": (
        "/packs/test-pack/0.1.0/data/basemap.pmtiles"
    ),
}

for key, value in expected.items():
    if pack.get(key) != value:
        raise SystemExit(
            f"Discovery field {key!r} is incorrect."
        )

region = pack.get("region")

if not isinstance(region, dict):
    raise SystemExit(
        "Discovery region metadata is missing."
    )

if region.get("name") != "Synthetic Region":
    raise SystemExit(
        "Discovery region name is incorrect."
    )

if region.get("bounds") != [-123.0, 45.0, -122.0, 46.0]:
    raise SystemExit(
        "Discovery region bounds are incorrect."
    )

if region.get("default_center") != [-122.5, 45.5]:
    raise SystemExit(
        "Discovery default center is incorrect."
    )

if region.get("min_zoom") != 0:
    raise SystemExit(
        "Discovery minimum zoom is incorrect."
    )

if region.get("max_zoom") != 10:
    raise SystemExit(
        "Discovery maximum zoom is incorrect."
    )
PYTEST

pass "Installed map packs are discoverable through the read-only API."

curl \
  --silent \
  --show-error \
  --dump-header "$TEMP_DIR/range.headers" \
  --output "$TEMP_DIR/range.body" \
  --header 'Range: bytes=5-9' \
  "http://127.0.0.1:$PORT/packs/test-pack/0.1.0/data/basemap.pmtiles"

grep -q '^HTTP/.* 206' "$TEMP_DIR/range.headers" ||
  fail "Byte-range request did not return HTTP 206."

grep -qi '^Accept-Ranges: bytes' "$TEMP_DIR/range.headers" ||
  fail "Accept-Ranges header is missing."

grep -qi '^Content-Range: bytes 5-9/36' "$TEMP_DIR/range.headers" ||
  fail "Content-Range header is incorrect."

[[ "$(cat "$TEMP_DIR/range.body")" == "56789" ]] ||
  fail "Byte-range response body is incorrect."

pass "PMTiles byte-range request returned the correct data."

curl \
  --silent \
  --show-error \
  --head \
  --dump-header "$TEMP_DIR/head.headers" \
  --output /dev/null \
  "http://127.0.0.1:$PORT/packs/test-pack/0.1.0/data/basemap.pmtiles"

grep -q '^HTTP/.* 200' "$TEMP_DIR/head.headers" ||
  fail "HEAD request did not return HTTP 200."

grep -qi '^Content-Length: 36' "$TEMP_DIR/head.headers" ||
  fail "HEAD request returned the wrong Content-Length."

grep -qi '^Accept-Ranges: bytes' "$TEMP_DIR/head.headers" ||
  fail "HEAD response is missing Accept-Ranges."

pass "HEAD requests expose PMTiles metadata without a body."

curl \
  --silent \
  --show-error \
  --dump-header "$TEMP_DIR/open-range.headers" \
  --output "$TEMP_DIR/open-range.body" \
  --header 'Range: bytes=30-' \
  "http://127.0.0.1:$PORT/packs/test-pack/0.1.0/data/basemap.pmtiles"

grep -q '^HTTP/.* 206' "$TEMP_DIR/open-range.headers" ||
  fail "Open-ended byte range did not return HTTP 206."

[[ "$(cat "$TEMP_DIR/open-range.body")" == "UVWXYZ" ]] ||
  fail "Open-ended byte-range response body is incorrect."

curl \
  --silent \
  --show-error \
  --dump-header "$TEMP_DIR/suffix-range.headers" \
  --output "$TEMP_DIR/suffix-range.body" \
  --header 'Range: bytes=-4' \
  "http://127.0.0.1:$PORT/packs/test-pack/0.1.0/data/basemap.pmtiles"

grep -q '^HTTP/.* 206' "$TEMP_DIR/suffix-range.headers" ||
  fail "Suffix byte range did not return HTTP 206."

[[ "$(cat "$TEMP_DIR/suffix-range.body")" == "WXYZ" ]] ||
  fail "Suffix byte-range response body is incorrect."

pass "Open-ended and suffix byte ranges are supported."

curl \
  --silent \
  --show-error \
  --dump-header "$TEMP_DIR/invalid-range.headers" \
  --output /dev/null \
  --header 'Range: bytes=100-200' \
  "http://127.0.0.1:$PORT/packs/test-pack/0.1.0/data/basemap.pmtiles"

grep -q '^HTTP/.* 416' "$TEMP_DIR/invalid-range.headers" ||
  fail "Unsatisfiable byte range did not return HTTP 416."

grep -qi '^Content-Range: bytes \*/36' "$TEMP_DIR/invalid-range.headers" ||
  fail "HTTP 416 response has the wrong Content-Range."

pass "Unsatisfiable byte ranges return HTTP 416."

curl \
  --silent \
  --show-error \
  --dump-header "$TEMP_DIR/security.headers" \
  --output /dev/null \
  "http://127.0.0.1:$PORT/"

grep -qi '^Content-Security-Policy:' "$TEMP_DIR/security.headers" ||
  fail "Content Security Policy is missing."

grep -qi '^X-Content-Type-Options: nosniff' "$TEMP_DIR/security.headers" ||
  fail "MIME-sniffing protection is missing."

grep -qi '^X-Frame-Options: DENY' "$TEMP_DIR/security.headers" ||
  fail "Frame protection is missing."

pass "Map-reader security headers are present."

status="$(
  curl \
    --silent \
    --output "$TEMP_DIR/manifest.json" \
    --write-out '%{http_code}' \
    "http://127.0.0.1:$PORT/packs/test-pack/0.1.0/manifest.json"
)"

[[ "$status" == "200" ]] ||
  fail "Installed pack manifest did not return HTTP 200."

grep -q '"pack_id": "test-pack"' "$TEMP_DIR/manifest.json" ||
  fail "Installed pack manifest response is incorrect."

pass "Installed pack manifest is readable."

for unsafe_path in \
  '/packs/test-pack/0.1.0/%2e%2e/README.txt' \
  '/packs/test-pack/0.1.0/data%5cbasemap.pmtiles'
do
  status="$(
    curl \
      --silent \
      --path-as-is \
      --output /dev/null \
      --write-out '%{http_code}' \
      "http://127.0.0.1:$PORT$unsafe_path"
  )"

  [[ "$status" == "404" ]] ||
    fail "Unsafe request path was not rejected: $unsafe_path"
done

pass "Traversal and backslash request paths are rejected."

status="$(
  curl \
    --silent \
    --output /dev/null \
    --write-out '%{http_code}' \
    "http://127.0.0.1:$PORT/packs/test-pack/0.1.0/not-declared.txt"
)"

[[ "$status" == "404" ]] ||
  fail "Undeclared pack file did not return HTTP 404."

pass "Undeclared pack files are not exposed."

status="$(
  curl \
    --silent \
    --request POST \
    --output /dev/null \
    --write-out '%{http_code}' \
    "http://127.0.0.1:$PORT/"
)"

[[ "$status" == "405" ]] ||
  fail "POST request did not return HTTP 405."

pass "Unsupported methods are rejected."
pass "Map-server smoke tests completed."
