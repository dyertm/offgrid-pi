#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$EUID" -eq 0 ]]; then
  echo "FAIL: Do not run Phase 7 tests with sudo."
  exit 1
fi

TESTS=(
  "tests/test-system-status.sh"
  "tests/test-system-admin.sh"
  "tests/test-system-admin-confirm.sh"
  "tests/test-system-admin-reindex.sh"
  "tests/test-system-admin-actions.sh"
)

echo "=== Offgrid Pi Phase 7 tests ==="

for test_file in "${TESTS[@]}"; do
  echo
  echo "--- $test_file ---"
  "$ROOT/$test_file"
done

echo
echo "PASS: All Phase 7 tests completed."
