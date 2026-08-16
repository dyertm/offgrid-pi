#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNIT="$ROOT/systemd/offgridpi-management.service"
SERVER="$ROOT/scripts/offgridpi-management-server.py"

TEMP_DIR="$(mktemp -d)"
TEMP_UNIT="$TEMP_DIR/offgridpi-management.service"

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
  fail "Management service unit is missing."

[[ -x "$SERVER" ]] ||
  fail "Management server is missing or not executable."

grep -q '^User=offgridpi$' "$UNIT" ||
  fail "Management service does not use the restricted account."

grep -q '^Group=offgridpi$' "$UNIT" ||
  fail "Management service does not use the restricted group."

grep -q \
  '^Environment=OFFGRIDPI_MANAGEMENT_BIND=127\.0\.0\.1$' \
  "$UNIT" ||
  fail "Management service is not explicitly bound to localhost."

grep -q \
  '^Environment=OFFGRIDPI_MANAGEMENT_PORT=8083$' \
  "$UNIT" ||
  fail "Management service does not use the approved port."

grep -q \
  '^ExecStart=/opt/offgridpi/scripts/offgridpi-management-server\.py$' \
  "$UNIT" ||
  fail "Management service has an unexpected executable."

if grep -qE '0\.0\.0\.0|::[^1]' "$UNIT"; then
  fail "Management service contains a public bind address."
fi

grep -q '^NoNewPrivileges=yes$' "$UNIT" ||
  fail "NoNewPrivileges protection is missing."

grep -q '^ProtectSystem=strict$' "$UNIT" ||
  fail "Strict filesystem protection is missing."

grep -q '^ProtectHome=yes$' "$UNIT" ||
  fail "Home-directory protection is missing."

grep -q '^PrivateDevices=yes$' "$UNIT" ||
  fail "Private device protection is missing."

grep -q '^RestrictAddressFamilies=AF_INET$' "$UNIT" ||
  fail "Network address families are not sufficiently restricted."

grep -q \
  '^ReadOnlyPaths=/var/lib/offgridpi/management$' \
  "$UNIT" ||
  fail "Protected management data is not explicitly read-only."

sed \
  "s#/opt/offgridpi/scripts/offgridpi-management-server.py#$SERVER#g" \
  "$UNIT" > "$TEMP_UNIT"

systemd-analyze verify "$TEMP_UNIT"

INSTALLER="$ROOT/install.sh"

grep -q '^INSTALLER_VERSION="0.7.6"$' "$INSTALLER" ||
  fail "Installer version was not advanced to 0.7.6."

grep -q   'scripts/offgridpi-management-server.py'   "$INSTALLER" ||
  fail "Installer does not validate or install the management server."

grep -q   'systemd/offgridpi-management.service'   "$INSTALLER" ||
  fail "Installer does not validate or install the management service."

grep -q   'systemctl enable --now offgridpi-management.service'   "$INSTALLER" ||
  fail "Installer does not enable the management service."

grep -q   'http://127.0.0.1:8083/'   "$INSTALLER" ||
  fail "Installer lacks localhost service validation."

grep -q   "ss -ltnH 'sport = :8083'"   "$INSTALLER" ||
  fail "Installer does not validate the live listener."

VERIFIER="$ROOT/tests/verify-installation.sh"

grep -qF   '=== Local management viewer ==='   "$VERIFIER" ||
  fail "Installed-system verifier lacks the management section."

grep -qF   'offgridpi-management.service'   "$VERIFIER" ||
  fail "Verifier does not check the management service."

grep -qF   "ss -ltnH 'sport = :8083'"   "$VERIFIER" ||
  fail "Verifier does not inspect the localhost listener."

grep -qF   'http://127.0.0.1:8083/'   "$VERIFIER" ||
  fail "Verifier does not test the management page."

grep -qF   'Raw protected-log JSON is not exposed.'   "$VERIFIER" ||
  fail "Verifier does not confirm raw logs remain protected."

grep -qF   'Local management viewer rejects write methods.'   "$VERIFIER" ||
  fail "Verifier does not confirm write methods are rejected."

pass "Installed-system verifier includes management safeguards."
pass "Installer includes localhost management safeguards."
pass "Management service uses the restricted account."
pass "Management service is fixed to localhost port 8083."
pass "Management data and application files are read-only."
pass "Management service hardening is present."
pass "Management service unit structure is valid."
