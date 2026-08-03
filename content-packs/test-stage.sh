#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAGER="$ROOT/content-pack-stage.py"
FIXTURE="$ROOT/fixtures/incomplete-pack.json"
TEMP_DIR="$(mktemp -d)"

trap 'rm -rf "$TEMP_DIR"' EXIT

check_line() {
  local file="$1"
  local expected="$2"

  if grep -Fq -- "$expected" "$file"; then
    printf 'PASS: Found expected staging result: %s\n' "$expected"
  else
    printf 'FAIL: Missing expected staging result: %s\n' "$expected"
    cat "$file"
    exit 1
  fi
}

BLOCK_OUTPUT="$TEMP_DIR/blocked.out"

set +e
"$STAGER" \
  "$FIXTURE" \
  --staging-root "$TEMP_DIR/blocked-stage" \
  --dry-run \
  >"$BLOCK_OUTPUT" 2>&1
BLOCK_RESULT=$?
set -e

if [[ "$BLOCK_RESULT" -ne 1 ]]; then
  echo "FAIL: Incomplete manifest returned exit code $BLOCK_RESULT."
  cat "$BLOCK_OUTPUT"
  exit 1
fi

check_line "$BLOCK_OUTPUT" "Result: BLOCKED"
check_line "$BLOCK_OUTPUT" "Blocked or failed: 1"
check_line "$BLOCK_OUTPUT" "Staging readiness: BLOCKED"

if [[ -e "$TEMP_DIR/blocked-stage" ]]; then
  echo "FAIL: Blocked dry-run created a staging directory."
  exit 1
fi

echo "PASS: Blocked dry-run created no staging directory."

PAYLOAD="$TEMP_DIR/verified.bin"
MANIFEST="$TEMP_DIR/complete.json"

printf 'verified test content\n' >"$PAYLOAD"

SIZE="$(stat -c '%s' "$PAYLOAD")"
HASH="$(sha256sum "$PAYLOAD" | awk '{print $1}')"

python3 - \
  "$FIXTURE" \
  "$MANIFEST" \
  "$SIZE" \
  "$HASH" <<'PY'
import json
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])
size = int(sys.argv[3])
checksum = sys.argv[4]

manifest = json.loads(source.read_text())
manifest["pack_id"] = "stage-test"
manifest["name"] = "Content-Pack Staging Test"
manifest["estimated_download_bytes"] = size
manifest["estimated_installed_bytes"] = size

item = manifest["items"][0]
item["item_id"] = "verified-resource"
item["title"] = "Verified Test Resource"
item["source_url"] = "https://example.invalid/verified.bin"
item["source_page"] = "https://example.invalid/"
item["source_version"] = "test"
item["license"] = "Test fixture; not for redistribution"
item["redistribution"] = "prohibited"
item["size_bytes"] = size
item["sha256"] = checksum
item["destination"] = (
    "/srv/offgridpi/content/documents/public/"
    "test/verified.bin"
)
item["notes"] = "Automated staging test fixture."

target.write_text(json.dumps(manifest, indent=2) + "\n")
PY

STAGED_FILE="$TEMP_DIR/reuse-stage/stage-test/1.0.0/verified-resource/verified.bin"

mkdir -p "$(dirname "$STAGED_FILE")"
cp "$PAYLOAD" "$STAGED_FILE"

REUSE_OUTPUT="$TEMP_DIR/reuse.out"

"$STAGER" \
  "$MANIFEST" \
  --staging-root "$TEMP_DIR/reuse-stage" \
  >"$REUSE_OUTPUT" 2>&1

check_line "$REUSE_OUTPUT" "Result: REUSED"
check_line "$REUSE_OUTPUT" "Reused staged files: 1"
check_line "$REUSE_OUTPUT" "Staging readiness: READY"

BAD_FILE="$TEMP_DIR/bad-stage/stage-test/1.0.0/verified-resource/verified.bin"
BAD_OUTPUT="$TEMP_DIR/bad.out"

mkdir -p "$(dirname "$BAD_FILE")"
printf 'corrupted content\n' >"$BAD_FILE"

set +e
"$STAGER" \
  "$MANIFEST" \
  --staging-root "$TEMP_DIR/bad-stage" \
  >"$BAD_OUTPUT" 2>&1
BAD_RESULT=$?
set -e

if [[ "$BAD_RESULT" -ne 1 ]]; then
  echo "FAIL: Corrupted staged file returned exit code $BAD_RESULT."
  cat "$BAD_OUTPUT"
  exit 1
fi

check_line "$BAD_OUTPUT" "existing staged file failed verification"
check_line "$BAD_OUTPUT" "Blocked or failed: 1"
check_line "$BAD_OUTPUT" "Staging readiness: BLOCKED"

echo "PASS: Corrupted staged content was rejected."
echo "PASS: Content-pack staging tests succeeded."
