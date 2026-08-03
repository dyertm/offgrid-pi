#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADMIN="$ROOT/scripts/offgridpi-admin.py"
TEMP_ROOT="$(mktemp -d)"
FAKE_SYSTEMCTL="$TEMP_ROOT/systemctl"
LOG="$TEMP_ROOT/systemctl.log"
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

cat > "$FAKE_SYSTEMCTL" <<'FAKE'
#!/usr/bin/env bash
set -u

printf '%s\n' "$*" >> "$OFFGRIDPI_TEST_LOG"
exit "${OFFGRIDPI_FAKE_SYSTEMCTL_EXIT:-0}"
FAKE

chmod 0755 "$FAKE_SYSTEMCTL"

for ACTION in reboot poweroff; do
  "$ADMIN" system-action "$ACTION" > "$OUTPUT"

  grep -qF "No changes were made." "$OUTPUT" ||
    fail "$ACTION did not default to preview mode."

  pass "$ACTION defaults to preview mode."
done

set +e
"$ADMIN" system-action reboot \
  --confirm WRONG > "$OUTPUT" 2>&1
STATUS_CODE=$?
set -e

[[ "$STATUS_CODE" -eq 2 ]] ||
  fail "Incorrect confirmation returned exit code $STATUS_CODE."

grep -qF \
  "ERROR: Confirmation phrase was not accepted." \
  "$OUTPUT" ||
  fail "Incorrect confirmation phrase was not rejected."

pass "Incorrect confirmation phrases are rejected."

for ACTION in reboot poweroff; do
  : > "$LOG"

  OFFGRIDPI_TEST_MODE=1 \
  OFFGRIDPI_SYSTEMCTL="$FAKE_SYSTEMCTL" \
  OFFGRIDPI_TEST_LOG="$LOG" \
  "$ADMIN" system-action "$ACTION" \
    --confirm OFFGRIDPI > "$OUTPUT"

  grep -qF -- "--no-block $ACTION" "$LOG" ||
    fail "Fake $ACTION request was not sent correctly."

  grep -qF \
    "PASS: System $ACTION request was accepted." \
    "$OUTPUT" ||
    fail "Accepted $ACTION was not reported."

  pass "Confirmed $ACTION succeeds through fake systemctl."
done

set +e
OFFGRIDPI_TEST_MODE=1 \
OFFGRIDPI_SYSTEMCTL="$FAKE_SYSTEMCTL" \
OFFGRIDPI_TEST_LOG="$LOG" \
OFFGRIDPI_FAKE_SYSTEMCTL_EXIT=1 \
"$ADMIN" system-action poweroff \
  --confirm OFFGRIDPI > "$OUTPUT" 2>&1
STATUS_CODE=$?
set -e

[[ "$STATUS_CODE" -eq 1 ]] ||
  fail "Rejected system action returned exit code $STATUS_CODE."

grep -qF \
  "FAIL: System action was rejected:" \
  "$OUTPUT" ||
  fail "Rejected system action was not reported."

pass "Rejected system actions are detected."
pass "System-action tests completed without live changes."
