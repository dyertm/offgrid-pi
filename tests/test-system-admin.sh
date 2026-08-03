#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADMIN="$ROOT/scripts/offgridpi-admin.py"
TEMP_OUTPUT="$(mktemp)"

cleanup() {
  rm -f "$TEMP_OUTPUT"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*"
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

[[ -x "$ADMIN" ]] ||
  fail "Administration command is missing or not executable."

pass "Administration command exists and is executable."

python3 -c "from pathlib import Path; p=Path(\"$ADMIN\"); compile(p.read_text(), str(p), \"exec\")" ||
  fail "Administration-command syntax validation failed."

pass "Administration-command syntax is valid."

"$ADMIN" status --json > "$TEMP_OUTPUT"
STATUS_CODE=$?

if [[ "$STATUS_CODE" -ne 0 && "$STATUS_CODE" -ne 1 ]]; then
  fail "Unexpected status exit code: $STATUS_CODE"
fi

python3 -m json.tool "$TEMP_OUTPUT" >/dev/null ||
  fail "Status action did not return valid JSON."

pass "Administration status action returned valid JSON."

for SERVICE in kiwix dashboard documents indexer; do
  "$ADMIN" restart-service "$SERVICE" > "$TEMP_OUTPUT" ||
    fail "Restart preview failed for $SERVICE."

  grep -qF "No changes were made." "$TEMP_OUTPUT" ||
    fail "Preview safety message missing for $SERVICE."

  grep -qF "A confirmed action would:" "$TEMP_OUTPUT" ||
    fail "Confirmed-action explanation missing for $SERVICE."

  pass "Restart preview is safe for $SERVICE."
done

if "$ADMIN" restart-service invalid-service >/dev/null 2>&1; then
  fail "Invalid service alias was accepted."
fi

pass "Invalid service aliases are rejected."
pass "Administration preview tests completed."
