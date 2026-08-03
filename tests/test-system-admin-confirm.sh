#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADMIN="$ROOT/scripts/offgridpi-admin.py"
TEMP_ROOT="$(mktemp -d)"
FAKE_SYSTEMCTL="$TEMP_ROOT/systemctl"
LOG="$TEMP_ROOT/systemctl.log"
OUTPUT="$TEMP_ROOT/output.txt"

cat > "$FAKE_SYSTEMCTL" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$OFFGRIDPI_TEST_LOG"

case "${1:-}" in
  restart)
    exit "${OFFGRIDPI_FAKE_RESTART_EXIT:-0}"
    ;;
  is-active)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
FAKE

chmod 0755 "$FAKE_SYSTEMCTL"


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

OFFGRIDPI_TEST_MODE=1 \
OFFGRIDPI_SYSTEMCTL="$FAKE_SYSTEMCTL" \
OFFGRIDPI_TEST_LOG="$LOG" \
"$ADMIN" restart-service indexer --confirm \
  > "$OUTPUT"

[[ "$?" -eq 0 ]] ||
  fail "Simulated confirmed restart failed."

grep -qF "restart offgridpi-document-indexer.service" "$LOG" ||
  fail "Fake restart command was not called."

grep -qF "is-active --quiet offgridpi-document-indexer.service" "$LOG" ||
  fail "Post-restart active check was not called."

grep -qF "PASS: offgridpi-document-indexer.service is active." "$OUTPUT" ||
  fail "Successful restart result was not reported."

pass "Confirmed restart succeeds through the fake service manager."

: > "$LOG"
set +e
OFFGRIDPI_TEST_MODE=1 \
OFFGRIDPI_SYSTEMCTL="$FAKE_SYSTEMCTL" \
OFFGRIDPI_TEST_LOG="$LOG" \
OFFGRIDPI_FAKE_RESTART_EXIT=1 \
"$ADMIN" restart-service indexer --confirm \
  > "$OUTPUT"
STATUS_CODE=$?
set -e

[[ "$STATUS_CODE" -eq 1 ]] ||
  fail "Failed restart returned unexpected exit code: $STATUS_CODE"

grep -qF "FAIL: Restart failed:" "$OUTPUT" ||
  fail "Failed restart was not reported."

pass "Failed confirmed restarts are detected and reported."
pass "Confirmed administration tests completed without live changes."
