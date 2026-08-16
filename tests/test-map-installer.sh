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

[[ -f "$MANAGER" ]] ||
  fail "Installation-management script is missing."

[[ -f "$VERIFIER" ]] ||
  fail "Installed-system verifier is missing."

grep -q '^INSTALLER_VERSION="0\.7\.6"$' "$INSTALLER" ||
  fail "Installer is not at the Phase 8 checkpoint version."

for payload in \
  'maps/index.html' \
  'scripts/offgridpi-map-server.py' \
  'systemd/offgridpi-maps.service' \
  'content-packs/import-map-pack.py' \
  'content-packs/inspect-map-pack.py' \
  'content-packs/validate-map-pack.py' \
  'content-packs/schema/map-pack.schema.json'
do
  grep -qF "$payload" "$INSTALLER" ||
    fail "Installer preflight omits map payload: $payload"
done

pass "Installer preflight includes the complete map-reader payload."

grep -q '^install_map_module() {' "$INSTALLER" ||
  fail "Installer lacks the map-module function."

for definition in \
  'MAP_READER_ROOT="/opt/offgridpi/maps"' \
  'MAP_CONTENT_ROOT="/srv/offgridpi/content/maps"' \
  'MAP_PACK_ROOT="$MAP_CONTENT_ROOT/packs"' \
  'MAP_INCOMING_ROOT="$MAP_CONTENT_ROOT/incoming"' \
  'MAP_REJECTED_ROOT="$MAP_CONTENT_ROOT/rejected"' \
  'MAP_USER_DATA_ROOT="$MAP_CONTENT_ROOT/user-data"'
do
  grep -qF "$definition" "$INSTALLER" ||
    fail "Map installer path definition is missing: $definition"
done

for variable in \
  '"$MAP_READER_ROOT"' \
  '"$MAP_CONTENT_ROOT"' \
  '"$MAP_PACK_ROOT"' \
  '"$MAP_INCOMING_ROOT"' \
  '"$MAP_REJECTED_ROOT"' \
  '"$MAP_USER_DATA_ROOT"'
do
  grep -qF "$variable" "$INSTALLER" ||
    fail "Map installation does not use path variable: $variable"
done

for path in \
  '/opt/offgridpi/content-packs/import-map-pack.py' \
  '/opt/offgridpi/scripts/offgridpi-map-server.py' \
  '/etc/systemd/system/offgridpi-maps.service'
do
  grep -qF "$path" "$INSTALLER" ||
    fail "Map installation path is missing: $path"
done

grep -qF \
  'systemctl enable --now offgridpi-maps.service' \
  "$INSTALLER" ||
  fail "Installer does not enable the map-reader service."

grep -qF \
  'http://127.0.0.1:8084/' \
  "$INSTALLER" ||
  fail "Installer does not validate the map-reader HTTP endpoint."

grep -qF \
  'install-maps)' \
  "$INSTALLER" ||
  fail "Standalone install-maps command is missing."

grep -qF \
  'Step 3 of 4: Offline Maps module.' \
  "$INSTALLER" ||
  fail "install-all does not include Maps in the expected sequence."

pass "Installer deploys and activates the map-reader module."

grep -qF \
  'offgridpi-maps.service' \
  "$MANAGER" ||
  fail "Installation management does not track the map service."

for path in \
  '/etc/systemd/system/offgridpi-maps.service' \
  '/opt/offgridpi/maps' \
  '/opt/offgridpi/content-packs' \
  '/opt/offgridpi/scripts/offgridpi-map-server.py'
do
  grep -qF "$path" "$MANAGER" ||
    fail "Installation management omits map path: $path"
done

if grep -qE \
  'MANAGED_PATHS=.*srv/offgridpi/content/maps|^[[:space:]]+/srv/offgridpi/content/maps' \
  "$MANAGER"
then
  fail "Persistent map content was incorrectly made an uninstall target."
fi

pass "Backup, rollback, and uninstall tracking preserves map content."

for marker in \
  '/opt/offgridpi/maps/index.html' \
  '/etc/systemd/system/offgridpi-maps.service' \
  '/srv/offgridpi/content/maps/packs' \
  'offgridpi-maps.service' \
  'check_port 8084' \
  'http://127.0.0.1:8084/' \
  '=== Offline Maps reader ===' \
  'Installed PMTiles content supports HTTP byte ranges.' \
  'Offline Maps reader rejects write methods.'
do
  grep -qF "$marker" "$VERIFIER" ||
    fail "Installed-system verifier omits Maps safeguard: $marker"
done

pass "Installed-system verifier includes Offline Maps safeguards."

bash -n "$INSTALLER"
bash -n "$MANAGER"
bash -n "$VERIFIER"

pass "Map installer integration scripts are shell-syntax valid."
pass "Map installer integration tests completed."
