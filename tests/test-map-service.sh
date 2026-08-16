#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNIT="$ROOT/systemd/offgridpi-maps.service"
SERVER="$ROOT/scripts/offgridpi-map-server.py"

TEMP_DIR="$(mktemp -d)"
TEMP_UNIT="$TEMP_DIR/offgridpi-maps.service"

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
  fail "Map-reader service unit is missing."

[[ -x "$SERVER" ]] ||
  fail "Map server is missing or not executable."

grep -q '^User=offgridpi$' "$UNIT" ||
  fail "Map-reader service does not use the restricted account."

grep -q '^Group=offgridpi$' "$UNIT" ||
  fail "Map-reader service does not use the restricted group."

grep -q \
  '^Environment=OFFGRIDPI_MAP_BIND=0\.0\.0\.0$' \
  "$UNIT" ||
  fail "Map-reader service does not use the approved public bind."

grep -q \
  '^Environment=OFFGRIDPI_MAP_PORT=8084$' \
  "$UNIT" ||
  fail "Map-reader service does not use port 8084."

grep -q \
  '^Environment=OFFGRIDPI_MAP_READER_ROOT=/opt/offgridpi/maps$' \
  "$UNIT" ||
  fail "Map-reader application root is incorrect."

grep -q \
  '^Environment=OFFGRIDPI_MAP_PACK_ROOT=/srv/offgridpi/content/maps/packs$' \
  "$UNIT" ||
  fail "Installed map-pack root is incorrect."

grep -q \
  '^ExecStart=/opt/offgridpi/scripts/offgridpi-map-server\.py$' \
  "$UNIT" ||
  fail "Map-reader service has an unexpected executable."

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
  '^ReadOnlyPaths=/opt/offgridpi/maps$' \
  "$UNIT" ||
  fail "Reader application files are not explicitly read-only."

grep -q \
  '^ReadOnlyPaths=/srv/offgridpi/content/maps/packs$' \
  "$UNIT" ||
  fail "Installed map packs are not explicitly read-only."

if grep -q '^ReadWritePaths=' "$UNIT"; then
  fail "Public map-reader service unexpectedly has writable paths."
fi

sed \
  "s#/opt/offgridpi/scripts/offgridpi-map-server.py#$SERVER#g" \
  "$UNIT" > "$TEMP_UNIT"

systemd-analyze verify "$TEMP_UNIT"

pass "Map-reader service uses the restricted account."
pass "Map-reader service is configured for public port 8084."
pass "Reader application and installed map packs are read-only."
pass "Map-reader service has no explicit writable paths."
pass "Map-reader service hardening is present."
pass "Map-reader service unit structure is valid."
