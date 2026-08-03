#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REFRESHER="$ROOT/content-pack-refresh.py"
FIXTURE="$ROOT/fixtures/incomplete-pack.json"
TEMP_DIR="$(mktemp -d)"

trap 'rm -rf "$TEMP_DIR"' EXIT

check_line() {
  local file="$1"
  local expected="$2"

  if grep -Fq -- "$expected" "$file"; then
    printf 'PASS: Found expected refresh result: %s\n' "$expected"
  else
    printf 'FAIL: Missing expected refresh result: %s\n' "$expected"
    cat "$file"
    exit 1
  fi
}

BLOCK_OUTPUT="$TEMP_DIR/blocked.out"

set +e
"$REFRESHER" \
  "$FIXTURE" \
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
check_line "$BLOCK_OUTPUT" "Refresh actions were not run"
check_line "$BLOCK_OUTPUT" "Refresh readiness: BLOCKED"

if [[ -e "$TEMP_DIR/empty-content" ]]; then
  echo "FAIL: Blocked refresh created destination content."
  exit 1
fi

echo "PASS: Blocked refresh created no destination content."

ZIM_PAYLOAD="$TEMP_DIR/test.zim"
DOC_PAYLOAD="$TEMP_DIR/test.txt"
MANIFEST="$TEMP_DIR/complete.json"

printf 'verified zim test content\n' >"$ZIM_PAYLOAD"
printf 'verified document test content\n' >"$DOC_PAYLOAD"

ZIM_SIZE="$(stat -c '%s' "$ZIM_PAYLOAD")"
ZIM_HASH="$(sha256sum "$ZIM_PAYLOAD" | awk '{print $1}')"
DOC_SIZE="$(stat -c '%s' "$DOC_PAYLOAD")"
DOC_HASH="$(sha256sum "$DOC_PAYLOAD" | awk '{print $1}')"

python3 - \
  "$FIXTURE" \
  "$MANIFEST" \
  "$ZIM_SIZE" \
  "$ZIM_HASH" \
  "$DOC_SIZE" \
  "$DOC_HASH" <<'PY'
import copy
import json
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])
zim_size = int(sys.argv[3])
zim_hash = sys.argv[4]
doc_size = int(sys.argv[5])
doc_hash = sys.argv[6]

manifest = json.loads(source.read_text())
manifest["pack_id"] = "refresh-test"
manifest["name"] = "Content-Pack Refresh Test"
manifest["estimated_download_bytes"] = zim_size + doc_size
manifest["estimated_installed_bytes"] = zim_size + doc_size

zim = manifest["items"][0]
zim["content_type"] = "zim"
zim["item_id"] = "verified-zim"
zim["title"] = "Verified Test ZIM"
zim["source_url"] = "https://example.invalid/test.zim"
zim["source_page"] = "https://example.invalid/"
zim["source_version"] = "test"
zim["license"] = "Test fixture; not for redistribution"
zim["redistribution"] = "prohibited"
zim["size_bytes"] = zim_size
zim["sha256"] = zim_hash
zim["destination"] = "/srv/offgridpi/content/kiwix/test.zim"
zim["notes"] = "Automated refresh test fixture."

document = copy.deepcopy(zim)
document["item_id"] = "verified-document"
document["title"] = "Verified Test Document"
document["content_type"] = "document"
document["source_url"] = "https://example.invalid/test.txt"
document["size_bytes"] = doc_size
document["sha256"] = doc_hash
document["destination"] = (
    "/srv/offgridpi/content/documents/public/"
    "test/test.txt"
)

manifest["items"] = [zim, document]
target.write_text(json.dumps(manifest, indent=2) + "\n")
PY

DESTINATION_ROOT="$TEMP_DIR/content"
ZIM_FILE="$DESTINATION_ROOT/kiwix/test.zim"
DOC_FILE="$DESTINATION_ROOT/documents/public/test/test.txt"

mkdir -p \
  "$(dirname "$ZIM_FILE")" \
  "$(dirname "$DOC_FILE")"

cp "$ZIM_PAYLOAD" "$ZIM_FILE"
cp "$DOC_PAYLOAD" "$DOC_FILE"

PREVIEW_OUTPUT="$TEMP_DIR/preview.out"

"$REFRESHER" \
  "$MANIFEST" \
  --destination-root "$DESTINATION_ROOT" \
  >"$PREVIEW_OUTPUT" 2>&1

check_line "$PREVIEW_OUTPUT" "Mode: PREVIEW"
check_line "$PREVIEW_OUTPUT" "Verified installed items: 2"
check_line "$PREVIEW_OUTPUT" "WOULD ENABLE AND RESTART kiwix-serve.service"
check_line "$PREVIEW_OUTPUT" "WOULD ENABLE AND RESTART offgridpi-document-indexer.service"
check_line "$PREVIEW_OUTPUT" "Refresh readiness: READY"

echo "PASS: Refresh preview verified content without service changes."

FAKE_BIN="$TEMP_DIR/bin"
SYSTEMCTL_LOG="$TEMP_DIR/systemctl.log"
CONFIRM_OUTPUT="$TEMP_DIR/confirm.out"

mkdir -p "$FAKE_BIN"

cat >"$FAKE_BIN/systemctl" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$SYSTEMCTL_LOG"
exit 0
SH

chmod 0755 "$FAKE_BIN/systemctl"

PATH="$FAKE_BIN:$PATH" \
SYSTEMCTL_LOG="$SYSTEMCTL_LOG" \
"$REFRESHER" \
  "$MANIFEST" \
  --destination-root "$DESTINATION_ROOT" \
  --confirm \
  >"$CONFIRM_OUTPUT" 2>&1

check_line "$CONFIRM_OUTPUT" "Mode: REFRESH SERVICES"
check_line "$CONFIRM_OUTPUT" "Verified installed items: 2"
check_line "$CONFIRM_OUTPUT" "Refresh actions completed: 2"
check_line "$CONFIRM_OUTPUT" "Refresh readiness: READY"

grep -Fxq "enable kiwix-serve.service" "$SYSTEMCTL_LOG"
grep -Fxq "restart kiwix-serve.service" "$SYSTEMCTL_LOG"
grep -Fxq "is-active --quiet kiwix-serve.service" "$SYSTEMCTL_LOG"
grep -Fxq "enable offgridpi-document-indexer.service" "$SYSTEMCTL_LOG"
grep -Fxq "restart offgridpi-document-indexer.service" "$SYSTEMCTL_LOG"
grep -Fxq "is-active --quiet offgridpi-document-indexer.service" "$SYSTEMCTL_LOG"

echo "PASS: Expected Kiwix and document refresh commands were invoked."

printf 'corrupted document\n' >"$DOC_FILE"

CORRUPT_LOG="$TEMP_DIR/corrupt-systemctl.log"
CORRUPT_OUTPUT="$TEMP_DIR/corrupt.out"

set +e
PATH="$FAKE_BIN:$PATH" \
SYSTEMCTL_LOG="$CORRUPT_LOG" \
"$REFRESHER" \
  "$MANIFEST" \
  --destination-root "$DESTINATION_ROOT" \
  --confirm \
  >"$CORRUPT_OUTPUT" 2>&1
CORRUPT_RESULT=$?
set -e

if [[ "$CORRUPT_RESULT" -ne 1 ]]; then
  echo "FAIL: Corrupted content returned exit code $CORRUPT_RESULT."
  cat "$CORRUPT_OUTPUT"
  exit 1
fi

check_line "$CORRUPT_OUTPUT" "installed file failed verification"
check_line "$CORRUPT_OUTPUT" "Refresh actions were not run"
check_line "$CORRUPT_OUTPUT" "Refresh readiness: BLOCKED"

if [[ -e "$CORRUPT_LOG" && -s "$CORRUPT_LOG" ]]; then
  echo "FAIL: Service commands ran after verification failed."
  cat "$CORRUPT_LOG"
  exit 1
fi

echo "PASS: Corrupted installed content prevented all refresh actions."
echo "PASS: Content-pack refresh tests succeeded."
