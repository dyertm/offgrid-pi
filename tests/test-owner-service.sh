#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNIT="$ROOT/systemd/offgridpi-owner.service"
SERVER="$ROOT/scripts/offgridpi-owner-server.py"

TEMP_DIR="$(mktemp -d)"
TEMP_UNIT="$TEMP_DIR/offgridpi-owner.service"

cleanup() {
  rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

[[ -f "$UNIT" ]] ||
  fail "Owner Mode service unit is missing."

[[ -x "$SERVER" ]] ||
  fail "Owner Mode server is missing or not executable."

grep -q '^User=offgridpi$' "$UNIT" ||
  fail "Owner Mode service does not use the restricted account."

grep -q '^Group=offgridpi$' "$UNIT" ||
  fail "Owner Mode service does not use the restricted group."

grep -q \
  '^Environment=OFFGRIDPI_OWNER_BIND=127\.0\.0\.1$' \
  "$UNIT" ||
  fail "Owner Mode bootstrap service is not restricted to localhost."

grep -q \
  '^Environment=OFFGRIDPI_OWNER_PORT=8085$' \
  "$UNIT" ||
  fail "Owner Mode service does not use port 8085."

grep -q \
  '^Environment=OFFGRIDPI_OWNER_STATE_ROOT=/var/lib/offgridpi/owner$' \
  "$UNIT" ||
  fail "Owner Mode state root is incorrect."

grep -q \
  '^Environment=OFFGRIDPI_OWNER_MAP_DATA_ROOT=/srv/offgridpi/content/maps/user-data$' \
  "$UNIT" ||
  fail "Owner Mode private map-data root is incorrect."

grep -q \
  '^ExecStart=/opt/offgridpi/scripts/offgridpi-owner-server\.py$' \
  "$UNIT" ||
  fail "Owner Mode service has an unexpected executable."

grep -q '^UMask=0077$' "$UNIT" ||
  fail "Owner Mode private-file umask is missing."

grep -q '^NoNewPrivileges=yes$' "$UNIT" ||
  fail "NoNewPrivileges protection is missing."

grep -q '^ProtectSystem=strict$' "$UNIT" ||
  fail "Strict filesystem protection is missing."

grep -q '^ProtectHome=yes$' "$UNIT" ||
  fail "Home-directory protection is missing."

grep -q '^PrivateDevices=yes$' "$UNIT" ||
  fail "Private device protection is missing."

grep -q '^RestrictNamespaces=yes$' "$UNIT" ||
  fail "Namespace restriction is missing."

grep -q '^MemoryDenyWriteExecute=yes$' "$UNIT" ||
  fail "Executable-memory protection is missing."

grep -q '^RestrictAddressFamilies=AF_INET$' "$UNIT" ||
  fail "Network address families are not sufficiently restricted."

grep -q \
  '^ReadWritePaths=/var/lib/offgridpi/owner$' \
  "$UNIT" ||
  fail "Owner Mode state directory is not the approved writable path."

grep -q \
  '^ReadWritePaths=/srv/offgridpi/content/maps/user-data$' \
  "$UNIT" ||
  fail "Private map-data directory is not an approved writable path."

if grep -q \
  '^Environment=OFFGRIDPI_OWNER_BIND=0\.0\.0\.0$' \
  "$UNIT"
then
  fail "Owner Mode must not bind publicly before encrypted authentication exists."
fi

sed \
  "s#/opt/offgridpi/scripts/offgridpi-owner-server.py#$SERVER#g" \
  "$UNIT" > "$TEMP_UNIT"

systemd-analyze verify "$TEMP_UNIT"

pass "Owner Mode service uses the restricted account."
pass "Owner Mode bootstrap remains localhost-only on port 8085."
pass "Owner Mode writable paths are narrowly scoped."
pass "Owner Mode service hardening is present."
pass "Owner Mode service unit structure is valid."
