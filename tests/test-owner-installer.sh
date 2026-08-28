#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/install.sh"
MANAGER="$ROOT/scripts/manage-installation.sh"
VERIFIER="$ROOT/tests/verify-installation.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

[[ -f "$INSTALLER" ]] ||
  fail "Installer is missing."

[[ -f "$VERIFIER" ]] ||
  fail "Installed-system verifier is missing."

[[ -f "$MANAGER" ]] ||
  fail "Installation-management script is missing."

grep -q '^INSTALLER_VERSION="0\.7\.6"$' "$INSTALLER" ||
  fail "Installer is not at the current Phase 8 checkpoint version."

for payload in \
  'scripts/offgridpi-owner-server.py' \
  'scripts/offgridpi_owner_credentials.py' \
  'systemd/offgridpi-owner.service'
do
  grep -qF "$payload" "$INSTALLER" ||
    fail "Installer preflight omits Owner Mode payload: $payload"
done

pass "Installer preflight includes the Owner Mode payload."

for definition in \
  'OWNER_STATE_ROOT="/var/lib/offgridpi/owner"' \
  'OWNER_PORT="8085"'
do
  grep -qF "$definition" "$INSTALLER" ||
    fail "Owner Mode installer definition is missing: $definition"
done

grep -q '^install_owner_module() {' "$INSTALLER" ||
  fail "Installer lacks the Owner Mode module function."

for path in \
  '/opt/offgridpi/scripts/offgridpi-owner-server.py' \
  '/opt/offgridpi/scripts/offgridpi_owner_credentials.py' \
  '/etc/systemd/system/offgridpi-owner.service' \
  '/var/lib/offgridpi/owner' \
  '/srv/offgridpi/content/maps/user-data'
do
  grep -qF "$path" "$INSTALLER" ||
    fail "Owner Mode installation path is missing: $path"
done

grep -qF \
  'python3 -m py_compile /opt/offgridpi/scripts/offgridpi-owner-server.py' \
  "$INSTALLER" ||
  fail "Installer does not syntax-check the Owner Mode server."

grep -qF \
  'python3 -m py_compile /opt/offgridpi/scripts/offgridpi_owner_credentials.py' \
  "$INSTALLER" ||
  fail "Installer does not syntax-check the Owner credential module."

grep -qF \
  'systemd-analyze verify /etc/systemd/system/offgridpi-owner.service' \
  "$INSTALLER" ||
  fail "Installer does not validate the Owner Mode service unit."

grep -qF \
  'systemctl enable --now offgridpi-owner.service' \
  "$INSTALLER" ||
  fail "Installer does not enable the Owner Mode service."

grep -qF \
  'http://127.0.0.1:8085/' \
  "$INSTALLER" ||
  fail "Installer does not validate the localhost Owner Mode endpoint."

grep -B5 -A1 \
  '/srv/offgridpi/content/maps/user-data' \
  "$INSTALLER" |
  grep -q -- '-m 2770' ||
  fail "Private waypoint storage does not grant the Owner Mode group write access."

grep -qF \
  'install-owner)' \
  "$INSTALLER" ||
  fail "Standalone install-owner command is missing."

grep -qF \
  'sudo ./install.sh install-owner' \
  "$INSTALLER" ||
  fail "Installer help omits the install-owner command."

grep -qF \
  'Step 4 of 5: Owner Mode foundation.' \
  "$INSTALLER" ||
  fail "install-all does not include Owner Mode in the expected sequence."

grep -qF \
  'Step 5 of 5: Dashboard module.' \
  "$INSTALLER" ||
  fail "install-all does not place Dashboard after Owner Mode."

grep -qF \
  'offgridpi-owner.service' \
  "$MANAGER" ||
  fail "Installation management does not track the Owner Mode service."

for path in \
  '/etc/systemd/system/offgridpi-owner.service' \
  '/opt/offgridpi/scripts/offgridpi-owner-server.py' \
  '/opt/offgridpi/scripts/offgridpi_owner_credentials.py' \
  '/var/lib/offgridpi/owner'
do
  grep -qF "$path" "$MANAGER" ||
    fail "Installation management omits Owner Mode path: $path"
done

if grep -qE \
  'MANAGED_PATHS=.*srv/offgridpi/content/maps/user-data|^[[:space:]]+/srv/offgridpi/content/maps/user-data' \
  "$MANAGER"
then
  fail "Private waypoint data was incorrectly made an uninstall target."
fi

pass "Backup, rollback, and uninstall tracking preserves private waypoint data."

for marker in \
  '/opt/offgridpi/scripts/offgridpi-owner-server.py' \
  '/opt/offgridpi/scripts/offgridpi_owner_credentials.py' \
  '/etc/systemd/system/offgridpi-owner.service' \
  '/var/lib/offgridpi/owner' \
  'offgridpi-owner.service' \
  '127.0.0.1:8085' \
  '=== Owner Mode foundation ===' \
  'Owner Mode bootstrap has no public listener.' \
  'Owner Mode bootstrap rejects write methods.' \
  'Private waypoint directory permissions are correct.'
do
  grep -qF "$marker" "$VERIFIER" ||
    fail "Installed-system verifier omits Owner Mode safeguard: $marker"
done

bash -n "$INSTALLER"
bash -n "$MANAGER"
bash -n "$VERIFIER"

pass "Installed-system verifier includes Owner Mode safeguards."
pass "Owner Mode installer integration syntax is valid."
pass "Owner Mode installer integration tests completed."
