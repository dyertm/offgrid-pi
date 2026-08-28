#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$EUID" -eq 0 ]]; then
  echo "FAIL: Do not run Phase 8 tests with sudo."
  exit 1
fi

TESTS=(
  "tests/test-map-pack-validator.sh"
  "tests/test-map-pack-archive.sh"
  "tests/test-map-pack-import.sh"
  "tests/test-map-server.sh"
  "tests/test-map-reader-ui.sh"
  "tests/test-map-service.sh"
  "tests/test-owner-service.sh"
  "tests/test-owner-credentials.sh"
  "tests/test-map-installer.sh"
  "tests/test-owner-installer.sh"
)

echo "=== Offgrid Pi Phase 8 tests ==="

for test_file in "${TESTS[@]}"; do
  echo
  echo "--- $test_file ---"
  "$ROOT/$test_file"
done

echo
echo "PASS: All Phase 8 tests completed."
