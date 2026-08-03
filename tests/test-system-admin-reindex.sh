#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADMIN="$ROOT/scripts/offgridpi-admin.py"
TEMP_ROOT="$(mktemp -d)"
FAKE_INDEXER="$TEMP_ROOT/index-documents.py"
CATALOG="$TEMP_ROOT/catalog.json"
OUTPUT="$TEMP_ROOT/output.txt"

cleanup() {
  rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*"
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

[[ "$EUID" -ne 0 ]] ||
  fail "Do not run this test with sudo."

cat > "$FAKE_INDEXER" <<'FAKE'
#!/usr/bin/env bash
set -u

case "${OFFGRIDPI_FAKE_MODE:-success}" in
  success)
    printf '%s\n' \
      '{"total_files": 7, "categories": []}' \
      > "$OFFGRIDPI_FAKE_CATALOG"
    echo "Indexed 7 public document(s)."
    exit 0
    ;;
  invalid)
    printf '%s\n' 'not-json' \
      > "$OFFGRIDPI_FAKE_CATALOG"
    echo "Generated an invalid catalog."
    exit 0
    ;;
  fail)
    echo "simulated indexer failure" >&2
    exit 1
    ;;
  *)
    exit 2
    ;;
esac
FAKE

chmod 0755 "$FAKE_INDEXER"

run_confirmed_reindex() {
  OFFGRIDPI_TEST_MODE=1 \
  OFFGRIDPI_INDEX_COMMAND="$FAKE_INDEXER" \
  OFFGRIDPI_CATALOG_PATH="$CATALOG" \
  OFFGRIDPI_FAKE_CATALOG="$CATALOG" \
  OFFGRIDPI_FAKE_MODE="$1" \
  "$ADMIN" reindex-documents --confirm \
    > "$OUTPUT" 2>&1
}

"$ADMIN" reindex-documents > "$OUTPUT"

grep -qF "No changes were made." "$OUTPUT" ||
  fail "Reindex preview safety message is missing."

pass "Document reindex defaults to preview mode."

run_confirmed_reindex success

grep -qF "PASS: Public document catalog is valid." "$OUTPUT" ||
  fail "Valid generated catalog was not accepted."

grep -qF "PASS: Indexed document count: 7" "$OUTPUT" ||
  fail "Generated document count was not reported."

pass "Confirmed reindex accepts a valid generated catalog."

set +e
run_confirmed_reindex invalid
STATUS_CODE=$?
set -e

[[ "$STATUS_CODE" -eq 1 ]] ||
  fail "Invalid catalog returned exit code $STATUS_CODE."

grep -qF "FAIL: Generated catalog is invalid:" "$OUTPUT" ||
  fail "Invalid generated catalog was not rejected."

pass "Invalid generated catalogs are rejected."

set +e
run_confirmed_reindex fail
STATUS_CODE=$?
set -e

[[ "$STATUS_CODE" -eq 1 ]] ||
  fail "Failed indexer returned exit code $STATUS_CODE."

grep -qF "FAIL: Reindexing failed:" "$OUTPUT" ||
  fail "Indexer failure was not reported."

pass "Indexer failures are detected and reported."
pass "Reindex tests completed without live changes."
