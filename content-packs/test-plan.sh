#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLANNER="$ROOT/content-pack-plan.py"
MANIFEST="$ROOT/fixtures/incomplete-pack.json"
OUTPUT="$(mktemp)"

trap 'rm -f "$OUTPUT"' EXIT

set +e
"$PLANNER" "$MANIFEST" >"$OUTPUT" 2>&1
RESULT=$?
set -e

if [[ "$RESULT" -ne 1 ]]; then
  echo "FAIL: Incomplete fixture plan returned exit code $RESULT."
  cat "$OUTPUT"
  exit 1
fi

echo "PASS: Incomplete fixture plan returned exit code 1."

check_line() {
  local expected="$1"

  if grep -Fq -- "$expected" "$OUTPUT"; then
    printf 'PASS: Found expected plan result: %s\n' "$expected"
  else
    printf 'FAIL: Missing expected plan result: %s\n' "$expected"
    printf '\nComplete output:\n'
    cat "$OUTPUT"
    exit 1
  fi
}

check_line "Mode: READ-ONLY"
check_line "Metadata: INCOMPLETE"
check_line "Source transport: HTTPS"
check_line "Destination check: PASS"
check_line "Planned action: BLOCKED"
check_line "Storage check: PASS"
check_line "Incomplete item metadata: 1"
check_line "Destination conflicts: 0"
check_line "Insecure sources: 0"
check_line "Required items missing: 1"
check_line "Plan readiness: BLOCKED"

if grep -Fq "alpinelinux_en_all_maxi" "$OUTPUT"; then
  echo "FAIL: Unrelated Alpine test content appeared in fixture plan."
  exit 1
fi

echo "PASS: Unrelated Alpine test content was ignored."
echo "PASS: Content-pack planner tests succeeded."
