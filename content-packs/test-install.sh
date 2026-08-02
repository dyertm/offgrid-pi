#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$ROOT/content-pack-install.py"
STARTER="$ROOT/manifests/starter.json"
TEMP_DIR="$(mktemp -d)"

trap 'rm -rf "$TEMP_DIR"' EXIT

check_line() {
  local file="$1"
  local expected="$2"

  if grep -Fq -- "$expected" "$file"; then
    printf 'PASS: Found expected installation result: %s\n' "$expected"
  else
    printf 'FAIL: Missing expected installation result: %s\n' "$expected"
    cat "$file"
    exit 1
  fi
}

BLOCK_OUTPUT="$TEMP_DIR/blocked.out"

set +e
"$INSTALLER" \
  "$STARTER" \
  --staging-root "$TEMP_DIR/empty-stage" \
  --destination-root "$TEMP_DIR/empty-content" \
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
check_line "$BLOCK_OUTPUT" "Installation readiness: BLOCKED"

if [[ -e "$TEMP_DIR/empty-content" ]]; then
  echo "FAIL: Blocked preview created destination content."
  exit 1
fi

echo "PASS: Blocked preview created no destination content."

PAYLOAD="$TEMP_DIR/verified.bin"
MANIFEST="$TEMP_DIR/complete.json"

printf 'verified installation test content\n' >"$PAYLOAD"

SIZE="$(stat -c '%s' "$PAYLOAD")"
HASH="$(sha256sum "$PAYLOAD" | awk '{print $1}')"

python3 - \
  "$STARTER" \
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
manifest["pack_id"] = "install-test"
manifest["name"] = "Content-Pack Installation Test"
manifest["estimated_download_bytes"] = size
manifest["estimated_installed_bytes"] = size

item = manifest["items"][0]
item["item_id"] = "verified-resource"
item["title"] = "Verified Installation Resource"
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
item["notes"] = "Automated installation test fixture."

target.write_text(json.dumps(manifest, indent=2) + "\n")
PY

STAGING_ROOT="$TEMP_DIR/stage"
STAGED_FILE="$STAGING_ROOT/install-test/1.0.0/verified-resource/verified.bin"

mkdir -p "$(dirname "$STAGED_FILE")"
cp "$PAYLOAD" "$STAGED_FILE"

DESTINATION_ROOT="$TEMP_DIR/content"
DESTINATION_FILE="$DESTINATION_ROOT/documents/public/test/verified.bin"

PREVIEW_OUTPUT="$TEMP_DIR/preview.out"

"$INSTALLER" \
  "$MANIFEST" \
  --staging-root "$STAGING_ROOT" \
  --destination-root "$DESTINATION_ROOT" \
  >"$PREVIEW_OUTPUT" 2>&1

check_line "$PREVIEW_OUTPUT" "Mode: PREVIEW"
check_line "$PREVIEW_OUTPUT" "Result: WOULD INSTALL"
check_line "$PREVIEW_OUTPUT" "Would install: 1"
check_line "$PREVIEW_OUTPUT" "Installation readiness: READY"

if [[ -e "$DESTINATION_FILE" ]]; then
  echo "FAIL: Preview installed content."
  exit 1
fi

echo "PASS: Preview made no content changes."

INSTALL_OUTPUT="$TEMP_DIR/install.out"

"$INSTALLER" \
  "$MANIFEST" \
  --staging-root "$STAGING_ROOT" \
  --destination-root "$DESTINATION_ROOT" \
  --confirm \
  >"$INSTALL_OUTPUT" 2>&1

check_line "$INSTALL_OUTPUT" "Mode: INSTALL"
check_line "$INSTALL_OUTPUT" "Result: INSTALLED"
check_line "$INSTALL_OUTPUT" "Newly installed: 1"
check_line "$INSTALL_OUTPUT" "Installation readiness: READY"

if ! cmp -s "$PAYLOAD" "$DESTINATION_FILE"; then
  echo "FAIL: Installed content does not match staged content."
  exit 1
fi

if [[ "$(stat -c '%a' "$DESTINATION_FILE")" != "640" ]]; then
  echo "FAIL: Installed file mode is not 640."
  exit 1
fi

echo "PASS: Verified staged content installed with mode 640."

RERUN_OUTPUT="$TEMP_DIR/rerun.out"

"$INSTALLER" \
  "$MANIFEST" \
  --staging-root "$STAGING_ROOT" \
  --destination-root "$DESTINATION_ROOT" \
  --confirm \
  >"$RERUN_OUTPUT" 2>&1

check_line "$RERUN_OUTPUT" "Result: ALREADY INSTALLED"
check_line "$RERUN_OUTPUT" "Already installed: 1"
check_line "$RERUN_OUTPUT" "Newly installed: 0"
check_line "$RERUN_OUTPUT" "Installation readiness: READY"

if ! cmp -s "$PAYLOAD" "$DESTINATION_FILE"; then
  echo "FAIL: Idempotent rerun changed installed content."
  exit 1
fi

echo "PASS: Idempotent rerun preserved installed content."

CONFLICT_ROOT="$TEMP_DIR/conflict-content"
CONFLICT_FILE="$CONFLICT_ROOT/documents/public/test/verified.bin"
CONFLICT_OUTPUT="$TEMP_DIR/conflict.out"

mkdir -p "$(dirname "$CONFLICT_FILE")"
printf 'existing conflicting content\n' >"$CONFLICT_FILE"

BEFORE_HASH="$(sha256sum "$CONFLICT_FILE" | awk '{print $1}')"

set +e
"$INSTALLER" \
  "$MANIFEST" \
  --staging-root "$STAGING_ROOT" \
  --destination-root "$CONFLICT_ROOT" \
  --confirm \
  >"$CONFLICT_OUTPUT" 2>&1
CONFLICT_RESULT=$?
set -e

if [[ "$CONFLICT_RESULT" -ne 1 ]]; then
  echo "FAIL: Existing conflict returned exit code $CONFLICT_RESULT."
  cat "$CONFLICT_OUTPUT"
  exit 1
fi

check_line "$CONFLICT_OUTPUT" "existing file failed verification"
check_line "$CONFLICT_OUTPUT" "Blocked or failed: 1"
check_line "$CONFLICT_OUTPUT" "Installation readiness: BLOCKED"

AFTER_HASH="$(sha256sum "$CONFLICT_FILE" | awk '{print $1}')"

if [[ "$BEFORE_HASH" != "$AFTER_HASH" ]]; then
  echo "FAIL: Conflicting existing file was changed."
  exit 1
fi

echo "PASS: Existing conflicting content was not overwritten."
echo "PASS: Content-pack installation tests succeeded."
