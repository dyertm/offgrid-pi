#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATUS="$ROOT/content-pack-status.py"
MANIFEST="$ROOT/fixtures/incomplete-pack.json"
OUTPUT="$(mktemp)"

trap 'rm -f "$OUTPUT"' EXIT

"$STATUS" "$MANIFEST" >"$OUTPUT"

check_line() {
  local expected="$1"

  if grep -Fq -- "$expected" "$OUTPUT"; then
    printf 'PASS: Found expected status: %s\n' "$expected"
  else
    printf 'FAIL: Missing expected status: %s\n' "$expected"
    printf '\nComplete output:\n'
    cat "$OUTPUT"
    exit 1
  fi
}

check_line "Pack ID: incomplete-test"
check_line "Installed items: 0/1"
check_line "Required items missing: 1"
check_line "Items with incomplete metadata: 1"
check_line "Pack readiness: NOT READY"

if grep -Fq "alpinelinux_en_all_maxi" "$OUTPUT"; then
  echo "FAIL: Unrelated Alpine test content appeared in fixture status."
  exit 1
fi

echo "PASS: Unrelated Alpine test content was ignored."
echo "PASS: Content-pack status tests succeeded."
