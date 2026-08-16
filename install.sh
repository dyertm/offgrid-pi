#!/usr/bin/env bash
set -Eeuo pipefail

INSTALLER_VERSION="0.7.6"
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOCUMENT_PUBLIC="/srv/offgridpi/content/documents/public"
DOCUMENT_PERSONAL="/srv/offgridpi/content/documents/personal"
DASHBOARD_ROOT="/opt/offgridpi/dashboard"
MAP_READER_ROOT="/opt/offgridpi/maps"
MAP_CONTENT_ROOT="/srv/offgridpi/content/maps"
MAP_PACK_ROOT="$MAP_CONTENT_ROOT/packs"
MAP_INCOMING_ROOT="$MAP_CONTENT_ROOT/incoming"
MAP_REJECTED_ROOT="$MAP_CONTENT_ROOT/rejected"
MAP_USER_DATA_ROOT="$MAP_CONTENT_ROOT/user-data"
KIWIX_ROOT="/srv/offgridpi/content/kiwix"
CATEGORIES=(
  emergency first-aid food gardening communications radio repair
  equipment-manuals education books faith
)

log() { printf '[offgridpi] %s\n' "$*"; }
die() { printf '[offgridpi] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<USAGE
Offgrid Pi installer checkpoint $INSTALLER_VERSION

Usage:
  sudo ./install.sh check
  sudo ./install.sh backup-config
  sudo ./install.sh list-backups
  sudo ./install.sh rollback-config SNAPSHOT --confirm
  sudo ./install.sh uninstall --dry-run
  sudo ./install.sh uninstall --confirm
  sudo ./install.sh install-all
  sudo ./install.sh install-management
  sudo ./install.sh install-documents
  sudo ./install.sh install-maps
  sudo ./install.sh install-dashboard
  sudo ./install.sh install-kiwix
  sudo ./install.sh verify

Commands:
  check              Validate the host and required repository payload.
  backup-config      Create a content-preserving configuration snapshot.
  list-backups       List available configuration snapshots.
  rollback-config    Restore a snapshot; requires --confirm.
  uninstall          Remove installed components while preserving content.
  install-all        Snapshot, then install all supported modules.
  install-management Install status, administration, protected logs,
                     and the localhost management viewer.
  install-documents  Idempotently install the validated document module.
  install-maps       Idempotently install the offline map-reader module.
  install-dashboard  Idempotently install the dashboard and desktop autostart.
  install-kiwix      Idempotently install Kiwix and discover approved ZIM files.
  verify             Run the repository verification script.

Environment:
  OFFGRIDPI_ADMIN_USER  Override the administrator account used for document ownership.
USAGE
}

require_root() {
  [[ "$EUID" -eq 0 ]] || die "Run this command with sudo."
}

resolve_admin_user() {
  local candidate="${OFFGRIDPI_ADMIN_USER:-${SUDO_USER:-}}"
  [[ -n "$candidate" && "$candidate" != "root" ]] \
    || die "Unable to determine the administrator. Use OFFGRIDPI_ADMIN_USER=username."
  id "$candidate" >/dev/null 2>&1 || die "Administrator account does not exist: $candidate"
  printf '%s\n' "$candidate"
}

resolve_admin_home() {
  local account="$1"
  local home_directory

  home_directory="$(getent passwd "$account" | cut -d: -f6)"

  [[ -n "$home_directory" && -d "$home_directory" ]] \
    || die "Unable to determine the home directory for $account."

  printf '%s\n' "$home_directory"
}

check_payload() {
  local missing=0
  local path
  for path in \
    "$PROJECT_ROOT/scripts/index-documents.py" \
    "$PROJECT_ROOT/scripts/watch-documents.sh" \
    "$PROJECT_ROOT/systemd/offgridpi-documents.service" \
    "$PROJECT_ROOT/systemd/offgridpi-document-indexer.service.in" \
    "$PROJECT_ROOT/dashboard/index.html" \
    "$PROJECT_ROOT/dashboard/css/styles.css" \
    "$PROJECT_ROOT/dashboard/js/app.js" \
    "$PROJECT_ROOT/dashboard/status/index.html" \
    "$PROJECT_ROOT/dashboard/status/status.css" \
    "$PROJECT_ROOT/dashboard/status/status.js" \
    "$PROJECT_ROOT/dashboard/legal/legal.css" \
    "$PROJECT_ROOT/dashboard/data/.gitkeep" \
    "$PROJECT_ROOT/compliance/software-components.json" \
    "$PROJECT_ROOT/compliance/schema/software-components.schema.json" \
    "$PROJECT_ROOT/compliance/validate-software-components.py" \
    "$PROJECT_ROOT/scripts/generate-legal-notices.py" \
    "$PROJECT_ROOT/LICENSE" \
    "$PROJECT_ROOT/scripts/launch-dashboard.sh" \
    "$PROJECT_ROOT/systemd/offgridpi-dashboard.service" \
    "$PROJECT_ROOT/desktop/offgridpi-dashboard.desktop" \
    "$PROJECT_ROOT/scripts/start-kiwix.sh" \
    "$PROJECT_ROOT/systemd/kiwix-serve.service" \
    "$PROJECT_ROOT/scripts/offgridpi-status.py" \
    "$PROJECT_ROOT/scripts/offgridpi-admin.py" \
    "$PROJECT_ROOT/scripts/publish-system-status.sh" \
    "$PROJECT_ROOT/systemd/offgridpi-status-publisher.service" \
    "$PROJECT_ROOT/systemd/offgridpi-status-publisher.timer" \
    "$PROJECT_ROOT/scripts/publish-system-logs.py" \
    "$PROJECT_ROOT/systemd/offgridpi-log-publisher.service" \
    "$PROJECT_ROOT/systemd/offgridpi-log-publisher.timer" \
    "$PROJECT_ROOT/scripts/offgridpi-management-server.py" \
    "$PROJECT_ROOT/systemd/offgridpi-management.service" \
    "$PROJECT_ROOT/maps/index.html" \
    "$PROJECT_ROOT/scripts/offgridpi-map-server.py" \
    "$PROJECT_ROOT/systemd/offgridpi-maps.service" \
    "$PROJECT_ROOT/content-packs/import-map-pack.py" \
    "$PROJECT_ROOT/content-packs/inspect-map-pack.py" \
    "$PROJECT_ROOT/content-packs/validate-map-pack.py" \
    "$PROJECT_ROOT/content-packs/schema/map-pack.schema.json" \
    "$PROJECT_ROOT/scripts/manage-installation.sh" \
    "$PROJECT_ROOT/tests/verify-installation.sh"
  do
    if [[ -e "$path" ]]; then
      log "Found: ${path#$PROJECT_ROOT/}"
    else
      printf '[offgridpi] MISSING: %s\n' "${path#$PROJECT_ROOT/}" >&2
      missing=1
    fi
  done
  return "$missing"
}

check_host() {
  local architecture model
  log "Installer version: $INSTALLER_VERSION"

  architecture="$(uname -m)"
  log "Architecture: $architecture"
  case "$architecture" in
    aarch64|arm64) ;;
    *) die "Unsupported architecture: $architecture. The initial target is 64-bit Raspberry Pi OS on Raspberry Pi 4B." ;;
  esac

  [[ -r /etc/os-release ]] || die "/etc/os-release is unavailable."
  # shellcheck disable=SC1091
  . /etc/os-release
  log "Operating system: ${PRETTY_NAME:-unknown}"
  [[ "${ID:-}" == "debian" && "${VERSION_ID:-}" == "13" ]] \
    || die "Unsupported operating system. The validated baseline is Raspberry Pi OS 64-bit based on Debian 13."

  [[ -r /proc/device-tree/model ]] || die "Raspberry Pi model information is unavailable."
  model="$(tr -d '\0' </proc/device-tree/model)"
  log "Hardware: $model"
  [[ "$model" == *"Raspberry Pi 4 Model B"* ]] \
    || die "Unsupported hardware: $model. The initial target is Raspberry Pi 4 Model B."

  command -v systemctl >/dev/null || die "systemd is required."
  command -v python3 >/dev/null || die "Python 3 is required."
  command -v install >/dev/null || die "GNU install is required."
  check_payload || die "Repository payload is incomplete."
  log "Preflight check passed."
}

ensure_service_account() {
  if id offgridpi >/dev/null 2>&1; then
    log "Service account already exists: offgridpi"
  else
    useradd --system --home-dir /nonexistent --shell /usr/sbin/nologin offgridpi
    log "Created restricted service account: offgridpi"
  fi
}

install_document_module() {
  require_root
  check_host
  local admin_user admin_group rendered
  admin_user="$(resolve_admin_user)"
  admin_group="$(id -gn "$admin_user")"
  rendered="$(mktemp)"
  trap "rm -f -- '$rendered'" EXIT

  log "Administrator: $admin_user"
  log "Installing required packages."
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y python3 inotify-tools

  ensure_service_account

  install -d -o root -g root -m 0755 /opt/offgridpi/scripts
  install -d -o root -g root -m 0755 /srv/offgridpi/content/documents
  install -d -o "$admin_user" -g offgridpi -m 2750 "$DOCUMENT_PUBLIC"
  install -d -o "$admin_user" -g "$admin_group" -m 0700 "$DOCUMENT_PERSONAL"

  local category
  for category in "${CATEGORIES[@]}"; do
    install -d -o "$admin_user" -g offgridpi -m 2750 "$DOCUMENT_PUBLIC/$category"
  done

  install -o root -g root -m 0755 \
    "$PROJECT_ROOT/scripts/index-documents.py" \
    /opt/offgridpi/scripts/index-documents.py
  install -o root -g root -m 0755 \
    "$PROJECT_ROOT/scripts/watch-documents.sh" \
    /opt/offgridpi/scripts/watch-documents.sh
  install -o root -g root -m 0644 \
    "$PROJECT_ROOT/systemd/offgridpi-documents.service" \
    /etc/systemd/system/offgridpi-documents.service

  sed "s/@ADMIN_USER@/$admin_user/g" \
    "$PROJECT_ROOT/systemd/offgridpi-document-indexer.service.in" >"$rendered"
  install -o root -g root -m 0644 "$rendered" \
    /etc/systemd/system/offgridpi-document-indexer.service

  log "Generating the initial document catalog."
  runuser -u "$admin_user" -g offgridpi -- \
    /opt/offgridpi/scripts/index-documents.py

  systemd-analyze verify \
    /etc/systemd/system/offgridpi-documents.service \
    /etc/systemd/system/offgridpi-document-indexer.service
  systemctl daemon-reload
  systemctl enable --now offgridpi-document-indexer.service
  systemctl enable --now offgridpi-documents.service

  log "Document module installation completed."
  log "Library URL: http://$(hostname):8082/"
}


install_map_module() {
  require_root
  check_host

  local admin_user attempt map_page
  admin_user="$(resolve_admin_user)"

  log "Administrator: $admin_user"
  log "Installing offline map-reader packages."

  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3 \
    curl \
    rsync

  ensure_service_account

  install -d -o root -g root -m 0755 \
    "$MAP_READER_ROOT" \
    /opt/offgridpi/scripts \
    /opt/offgridpi/content-packs \
    /opt/offgridpi/content-packs/schema

  install -d -o root -g root -m 0755 \
    "$MAP_CONTENT_ROOT"

  install -d -o "$admin_user" -g offgridpi -m 2750 \
    "$MAP_PACK_ROOT" \
    "$MAP_INCOMING_ROOT" \
    "$MAP_REJECTED_ROOT" \
    "$MAP_USER_DATA_ROOT"

  systemctl stop offgridpi-maps.service 2>/dev/null || true

  log "Installing map-reader application files."

  rsync \
    --archive \
    --delete \
    "$PROJECT_ROOT/maps/" \
    "$MAP_READER_ROOT/"

  chown -R root:root "$MAP_READER_ROOT"
  find "$MAP_READER_ROOT" -type d -exec chmod 0755 {} +
  find "$MAP_READER_ROOT" -type f -exec chmod 0644 {} +

  install -o root -g root -m 0755 \
    "$PROJECT_ROOT/scripts/offgridpi-map-server.py" \
    /opt/offgridpi/scripts/offgridpi-map-server.py

  install -o root -g root -m 0755 \
    "$PROJECT_ROOT/content-packs/import-map-pack.py" \
    /opt/offgridpi/content-packs/import-map-pack.py

  install -o root -g root -m 0755 \
    "$PROJECT_ROOT/content-packs/inspect-map-pack.py" \
    /opt/offgridpi/content-packs/inspect-map-pack.py

  install -o root -g root -m 0755 \
    "$PROJECT_ROOT/content-packs/validate-map-pack.py" \
    /opt/offgridpi/content-packs/validate-map-pack.py

  install -o root -g root -m 0644 \
    "$PROJECT_ROOT/content-packs/schema/map-pack.schema.json" \
    /opt/offgridpi/content-packs/schema/map-pack.schema.json

  install -o root -g root -m 0644 \
    "$PROJECT_ROOT/systemd/offgridpi-maps.service" \
    /etc/systemd/system/offgridpi-maps.service

  python3 -m py_compile \
    /opt/offgridpi/scripts/offgridpi-map-server.py \
    /opt/offgridpi/content-packs/import-map-pack.py \
    /opt/offgridpi/content-packs/inspect-map-pack.py \
    /opt/offgridpi/content-packs/validate-map-pack.py

  systemd-analyze verify \
    /etc/systemd/system/offgridpi-maps.service

  systemctl daemon-reload
  systemctl enable --now offgridpi-maps.service

  for attempt in $(seq 1 30); do
    if curl \
      --silent \
      --fail \
      --output /dev/null \
      http://127.0.0.1:8084/
    then
      log "Offline map reader answered on TCP port 8084."
      break
    fi

    sleep 1
  done

  map_page="$(
    curl \
      --silent \
      --fail \
      http://127.0.0.1:8084/
  )" || die "Offline map reader did not become available."

  grep -q 'Offline Maps' <<< "$map_page" \
    || die "Offline map reader returned unexpected content."

  log "Offline map-reader module installation completed."
  log "Map reader URL: http://$(hostname):8084/"
}


install_dashboard_module() {
  require_root
  check_host

  local admin_user admin_group admin_home
  local autostart_dir attempt

  admin_user="$(resolve_admin_user)"
  admin_group="$(id -gn "$admin_user")"
  admin_home="$(resolve_admin_home "$admin_user")"
  autostart_dir="$admin_home/.config/autostart"

  log "Administrator: $admin_user"
  log "Installing dashboard packages."

  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3 \
    curl \
    rsync \
    chromium

  ensure_service_account

  install -d -o root -g root -m 0755 \
    "$DASHBOARD_ROOT" \
    /opt/offgridpi/scripts \
    /opt/offgridpi/compliance \
    /opt/offgridpi/compliance/schema

  install -o root -g root -m 0755 \
    "$PROJECT_ROOT/scripts/generate-legal-notices.py" \
    /opt/offgridpi/scripts/generate-legal-notices.py

  install -o root -g root -m 0755 \
    "$PROJECT_ROOT/compliance/validate-software-components.py" \
    /opt/offgridpi/compliance/validate-software-components.py

  install -o root -g root -m 0644 \
    "$PROJECT_ROOT/compliance/software-components.json" \
    /opt/offgridpi/compliance/software-components.json

  install -o root -g root -m 0644 \
    "$PROJECT_ROOT/compliance/schema/software-components.schema.json" \
    /opt/offgridpi/compliance/schema/software-components.schema.json

  install -o root -g root -m 0644 \
    "$PROJECT_ROOT/LICENSE" \
    /opt/offgridpi/LICENSE

  systemctl stop offgridpi-dashboard.service 2>/dev/null || true

  log "Installing dashboard files."
  rsync \
    --archive \
    --delete \
    "$PROJECT_ROOT/dashboard/" \
    "$DASHBOARD_ROOT/"

  log "Generating the offline Legal & Notices page."

  /opt/offgridpi/scripts/generate-legal-notices.py \
    --output-root "$DASHBOARD_ROOT/legal" \
    --allow-missing

  chown -R root:root "$DASHBOARD_ROOT"
  find "$DASHBOARD_ROOT" -type d -exec chmod 0755 {} +
  find "$DASHBOARD_ROOT" -type f -exec chmod 0644 {} +

  if [[ -x /opt/offgridpi/scripts/publish-system-status.sh ]]; then
    if /opt/offgridpi/scripts/publish-system-status.sh; then
      log "Dashboard system status republished."
    else
      publisher_result=$?

      if [[ "$publisher_result" -eq 1 ]]; then
        log "Dashboard system status republished with ATTENTION state."
      else
        die "Dashboard system-status publication failed."
      fi
    fi
  fi

  install -o root -g root -m 0755 \
    "$PROJECT_ROOT/scripts/launch-dashboard.sh" \
    /opt/offgridpi/scripts/launch-dashboard.sh

  install -o root -g root -m 0644 \
    "$PROJECT_ROOT/systemd/offgridpi-dashboard.service" \
    /etc/systemd/system/offgridpi-dashboard.service

  install -d \
    -o "$admin_user" \
    -g "$admin_group" \
    -m 0755 \
    "$autostart_dir"

  install \
    -o "$admin_user" \
    -g "$admin_group" \
    -m 0644 \
    "$PROJECT_ROOT/desktop/offgridpi-dashboard.desktop" \
    "$autostart_dir/offgridpi-dashboard.desktop"

  systemd-analyze verify \
    /etc/systemd/system/offgridpi-dashboard.service

  systemctl daemon-reload
  systemctl enable --now offgridpi-dashboard.service

  for attempt in $(seq 1 30); do
    if curl \
      --silent \
      --fail \
      --output /dev/null \
      http://127.0.0.1:8081/
    then
      log "Dashboard service answered on TCP port 8081."
      break
    fi

    sleep 1
  done

  curl \
    --silent \
    --fail \
    --output /dev/null \
    http://127.0.0.1:8081/ \
    || die "Dashboard service did not become available."

  log "Dashboard module installation completed."
  log "Dashboard URL: http://$(hostname):8081/"
  log "Chromium autostart installed for: $admin_user"
}



install_kiwix_module() {
  require_root
  check_host

  local admin_user attempt zim
  local -a zim_files=()

  admin_user="$(resolve_admin_user)"

  log "Administrator: $admin_user"
  log "Installing Kiwix packages."

  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    kiwix-tools \
    zim-tools \
    curl

  ensure_service_account

  install -d \
    -o "$admin_user" \
    -g offgridpi \
    -m 2750 \
    "$KIWIX_ROOT"

  install -d \
    -o root \
    -g root \
    -m 0755 \
    /opt/offgridpi/scripts

  find "$KIWIX_ROOT" \
    -type d \
    -exec chown "$admin_user:offgridpi" {} + \
    -exec chmod 2750 {} +

  find "$KIWIX_ROOT" \
    -type f \
    -name '*.zim' \
    -exec chown "$admin_user:offgridpi" {} + \
    -exec chmod 0640 {} +

  install \
    -o root \
    -g root \
    -m 0755 \
    "$PROJECT_ROOT/scripts/start-kiwix.sh" \
    /opt/offgridpi/scripts/start-kiwix.sh

  install \
    -o root \
    -g root \
    -m 0644 \
    "$PROJECT_ROOT/systemd/kiwix-serve.service" \
    /etc/systemd/system/kiwix-serve.service

  mapfile -d '' -t zim_files < <(
    find "$KIWIX_ROOT" \
      -type d -name rejected -prune -o \
      -type f \
      -name '*.zim' \
      -print0 |
      sort -z
  )

  systemd-analyze verify \
    /etc/systemd/system/kiwix-serve.service

  systemctl daemon-reload

  if [[ "${#zim_files[@]}" -eq 0 ]]; then
    systemctl disable --now \
      kiwix-serve.service \
      2>/dev/null || true

    log "Kiwix software and service were installed."
    log "No approved ZIM files were found."
    log "The Kiwix service was not started."
    log "Add ZIM files under: $KIWIX_ROOT"
    return 0
  fi

  for zim in "${zim_files[@]}"; do
    runuser -u offgridpi -- test -r "$zim" \
      || die "The Kiwix service account cannot read: $zim"
  done

  (
    cd /
    runuser -u offgridpi -- \
      /opt/offgridpi/scripts/start-kiwix.sh \
      --check
  )

  systemctl enable kiwix-serve.service
  systemctl restart kiwix-serve.service

  for attempt in $(seq 1 30); do
    if curl \
      --silent \
      --fail \
      --output /dev/null \
      http://127.0.0.1:8080/
    then
      log "Kiwix answered on TCP port 8080."
      break
    fi

    sleep 1
  done

  curl \
    --silent \
    --fail \
    --output /dev/null \
    http://127.0.0.1:8080/ \
    || die "Kiwix did not become available."

  if pgrep -af '[k]iwix-serve' | grep -q '/rejected/'; then
    die "A rejected ZIM file appears in the running Kiwix command."
  fi

  log "Kiwix module installation completed."
  log "Approved ZIM files: ${#zim_files[@]}"
  log "Kiwix URL: http://$(hostname):8080/"
}




install_management_tool() {
  ensure_service_account

  install -d \
    -o root \
    -g root \
    -m 0755 \
    /opt/offgridpi/scripts

  install \
    -o root \
    -g root \
    -m 0755 \
    "$PROJECT_ROOT/scripts/manage-installation.sh" \
    /opt/offgridpi/scripts/manage-installation.sh

  install \
    -o root \
    -g root \
    -m 0755 \
    "$PROJECT_ROOT/scripts/offgridpi-status.py" \
    /opt/offgridpi/scripts/offgridpi-status.py

  install \
    -o root \
    -g root \
    -m 0755 \
    "$PROJECT_ROOT/scripts/offgridpi-admin.py" \
    /opt/offgridpi/scripts/offgridpi-admin.py

  install \
    -o root \
    -g root \
    -m 0755 \
    "$PROJECT_ROOT/scripts/publish-system-status.sh" \
    /opt/offgridpi/scripts/publish-system-status.sh

  install -d \
    -o root \
    -g root \
    -m 0755 \
    /opt/offgridpi/dashboard/data

  install \
    -o root \
    -g root \
    -m 0644 \
    "$PROJECT_ROOT/systemd/offgridpi-status-publisher.service" \
    /etc/systemd/system/offgridpi-status-publisher.service

  install \
    -o root \
    -g root \
    -m 0644 \
    "$PROJECT_ROOT/systemd/offgridpi-status-publisher.timer" \
    /etc/systemd/system/offgridpi-status-publisher.timer

  systemd-analyze verify \
    /etc/systemd/system/offgridpi-status-publisher.service \
    /etc/systemd/system/offgridpi-status-publisher.timer

  systemctl daemon-reload
  systemctl enable --now offgridpi-status-publisher.timer
  systemctl start offgridpi-status-publisher.service

  [[ -s /opt/offgridpi/dashboard/data/system-status.json ]] \
    || die "Dashboard status file was not published."

  log "Dashboard system-status publishing enabled."

  getent group offgridpi >/dev/null ||
    die "Required offgridpi group does not exist."

  install \
    -o root \
    -g offgridpi \
    -m 0755 \
    "$PROJECT_ROOT/scripts/publish-system-logs.py" \
    /opt/offgridpi/scripts/publish-system-logs.py

  install \
    -o root \
    -g root \
    -m 0755 \
    "$PROJECT_ROOT/scripts/offgridpi-management-server.py" \
    /opt/offgridpi/scripts/offgridpi-management-server.py

  install -d \
    -o root \
    -g offgridpi \
    -m 0750 \
    /var/lib/offgridpi/management

  install \
    -o root \
    -g root \
    -m 0644 \
    "$PROJECT_ROOT/systemd/offgridpi-log-publisher.service" \
    /etc/systemd/system/offgridpi-log-publisher.service

  install \
    -o root \
    -g root \
    -m 0644 \
    "$PROJECT_ROOT/systemd/offgridpi-log-publisher.timer" \
    /etc/systemd/system/offgridpi-log-publisher.timer

  install \
    -o root \
    -g root \
    -m 0644 \
    "$PROJECT_ROOT/systemd/offgridpi-management.service" \
    /etc/systemd/system/offgridpi-management.service

  systemd-analyze verify \
    /etc/systemd/system/offgridpi-log-publisher.service \
    /etc/systemd/system/offgridpi-log-publisher.timer \
    /etc/systemd/system/offgridpi-management.service

  systemctl daemon-reload
  systemctl enable --now offgridpi-log-publisher.timer
  systemctl start offgridpi-log-publisher.service

  [[ -s /var/lib/offgridpi/management/system-logs.json ]] ||
    die "Protected system-log snapshot was not created."

  python3 -c '
import json
from pathlib import Path

path = Path(
    "/var/lib/offgridpi/management/system-logs.json"
)
report = json.loads(path.read_text(encoding="utf-8"))

if report.get("schema_version") != 1:
    raise SystemExit("Invalid log-snapshot schema.")

if not isinstance(report.get("sources"), list):
    raise SystemExit("Invalid log-snapshot sources.")
'

  log "Protected system-log publishing enabled."

  systemctl enable --now offgridpi-management.service
  systemctl restart offgridpi-management.service

  management_ready=0

  for attempt in $(seq 1 30); do
    if curl \
      --silent \
      --fail \
      --output /dev/null \
      http://127.0.0.1:8083/
    then
      management_ready=1
      break
    fi

    sleep 1
  done

  [[ "$management_ready" -eq 1 ]] ||
    die "Local management viewer did not become available."

  management_page="$(
    curl \
      --silent \
      --fail \
      http://127.0.0.1:8083/
  )" ||
    die "Unable to retrieve the local management page."

  grep -q 'Protected System Logs' <<< "$management_page" ||
    die "Local management page returned unexpected content."

  management_listener="$(
    ss -ltnH 'sport = :8083'
  )"

  grep -q '127.0.0.1:8083' <<< "$management_listener" ||
    die "Management viewer is not listening on localhost."

  if grep -Eq \
    '0\.0\.0\.0:8083|\*:8083|\[::\]:8083' \
    <<< "$management_listener"
  then
    die "Management viewer is exposed beyond localhost."
  fi

  log "Localhost-only management viewer enabled: http://127.0.0.1:8083/"
  log "Management, administration, status, protected log-publishing, and local viewer tools installed."
}

install_all_modules() {
  require_root
  check_host

  log "Starting complete Offgrid Pi installation."
  log "Creating pre-install configuration snapshot."

  "$PROJECT_ROOT/scripts/manage-installation.sh" backup

  install_management_tool

  log "Step 1 of 4: Kiwix module."
  install_kiwix_module

  log "Step 2 of 4: Document module."
  install_document_module

  log "Step 3 of 4: Offline Maps module."
  install_map_module

  log "Step 4 of 4: Dashboard module."
  install_dashboard_module

  log "Running complete installation verification."

  "$PROJECT_ROOT/tests/verify-installation.sh" \
    || die "Installation completed, but verification failed."

  log "Complete Offgrid Pi installation succeeded."
  log "Dashboard URL: http://$(hostname):8081/"
  log "Kiwix URL: http://$(hostname):8080/"
  log "Document URL: http://$(hostname):8082/"
}

run_verifier() {
  [[ -x "$PROJECT_ROOT/tests/verify-installation.sh" ]] \
    || die "Verification script is missing or not executable."
  exec "$PROJECT_ROOT/tests/verify-installation.sh"
}

case "${1:-}" in
  check)
    check_host
    ;;

  backup-config)
    "$PROJECT_ROOT/scripts/manage-installation.sh" backup
    ;;

  list-backups)
    "$PROJECT_ROOT/scripts/manage-installation.sh" list
    ;;

  rollback-config)
    "$PROJECT_ROOT/scripts/manage-installation.sh"       rollback       "${2:-latest}"       "${3:-}"
    ;;

  uninstall)
    "$PROJECT_ROOT/scripts/manage-installation.sh"       uninstall       "${2:-}"
    ;;

  install-management)
    require_root
    install_management_tool
    ;;
  install-all)
    install_all_modules
    ;;
  install-documents)
    install_document_module
    ;;
  install-maps)
    install_map_module
    ;;
  install-dashboard)
    install_dashboard_module
    ;;
  install-kiwix)
    install_kiwix_module
    ;;
  verify)
    run_verifier
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
