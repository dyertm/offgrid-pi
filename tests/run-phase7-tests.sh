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
  "tests/test-status-publisher.sh"
  "tests/test-dashboard-status.sh"
  "tests/test-secondary-navigation.sh"
  "tests/test-software-components.sh"
  "tests/test-legal-notices.sh"
  "tests/test-legal-installer.sh"
  "tests/test-system-log-publisher.sh"
  "tests/test-system-log-service.sh"
  "tests/test-management-server.sh"
  "tests/test-management-service.sh"
)

echo "=== Offgrid Pi Phase 7 tests ==="

for test_file in "${TESTS[@]}"; do
  echo
  echo "--- $test_file ---"
  "$ROOT/$test_file"
done

echo
echo "PASS: All Phase 7 tests completed."
