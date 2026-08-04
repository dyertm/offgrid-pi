#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLISHER="$ROOT/scripts/publish-system-status.sh"
TEMP_ROOT="$(mktemp -d)"
FAKE_STATUS="$TEMP_ROOT/offgridpi-status.py"
OUTPUT="$TEMP_ROOT/system-status.json"
LOG="$TEMP_ROOT/output.txt"

cleanup() {
  rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

[[ "$EUID" -ne 0 ]] ||
  fail "Do not run this test with sudo."

[[ -x "$PUBLISHER" ]] ||
  fail "Status publisher is missing or not executable."

cat > "$FAKE_STATUS" <<'FAKE'
#!/usr/bin/env bash
set -u

case "${OFFGRIDPI_FAKE_MODE:-healthy}" in
  healthy)
    cat <<'JSON'
{
  "hostname": "test-offgridpi",
  "uptime_seconds": 3600,
  "hardware": {},
  "storage": {},
  "services": [],
  "kiwix": {},
  "documents": {},
  "backups": {},
  "overall": "HEALTHY"
}
JSON
    exit 0
    ;;
  attention)
    cat <<'JSON'
{
  "hostname": "test-offgridpi",
  "uptime_seconds": 3600,
  "hardware": {},
  "storage": {},
  "services": [],
  "kiwix": {},
  "documents": {},
  "backups": {},
  "overall": "ATTENTION"
}
JSON
    exit 1
    ;;
  invalid)
    echo "not-json"
    exit 0
    ;;
  unsupported)
    echo "{}"
    exit 3
    ;;
esac
FAKE

chmod 0755 "$FAKE_STATUS"

run_publisher() {
  OFFGRIDPI_STATUS_COMMAND="$FAKE_STATUS" \
  OFFGRIDPI_STATUS_OUTPUT="$OUTPUT" \
  OFFGRIDPI_FAKE_MODE="$1" \
  "$PUBLISHER" > "$LOG" 2>&1
}

run_publisher healthy

grep -qF '"overall": "HEALTHY"' "$OUTPUT" ||
  fail "Healthy report was not published."

pass "Healthy status reports are published."

set +e
run_publisher attention
RESULT=$?
set -e

[[ "$RESULT" -eq 1 ]] ||
  fail "Attention report returned exit code $RESULT."

grep -qF '"overall": "ATTENTION"' "$OUTPUT" ||
  fail "Attention report was not published."

pass "Attention reports are published with exit code 1."

rm -f "$OUTPUT"

set +e
run_publisher invalid
RESULT=$?
set -e

[[ "$RESULT" -eq 1 ]] ||
  fail "Invalid JSON returned exit code $RESULT."

[[ ! -e "$OUTPUT" ]] ||
  fail "Invalid JSON was published."

pass "Invalid JSON is rejected without publication."

set +e
run_publisher unsupported
RESULT=$?
set -e

[[ "$RESULT" -eq 1 ]] ||
  fail "Unsupported status exit returned $RESULT."

[[ ! -e "$OUTPUT" ]] ||
  fail "Unsupported status output was published."

pass "Unsupported status-command exits are rejected."
pass "Status publisher tests completed without live changes."
