#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="0.3.0"
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOCUMENT_PUBLIC="/srv/offgridpi/content/documents/public"
DOCUMENT_PERSONAL="/srv/offgridpi/content/documents/personal"
DASHBOARD_ROOT="/opt/offgridpi/dashboard"
KIWIX_ROOT="/srv/offgridpi/content/kiwix"
CATEGORIES=(
  emergency first-aid food gardening communications radio repair
  equipment-manuals education books faith
)

log() { printf '[offgridpi] %s\n' "$*"; }
die() { printf '[offgridpi] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<USAGE
Offgrid Pi installer checkpoint $VERSION

Usage:
  sudo ./install.sh check
  sudo ./install.sh install-documents
  sudo ./install.sh install-dashboard
  sudo ./install.sh install-kiwix
  sudo ./install.sh verify

Commands:
  check              Validate the host and required repository payload.
  install-documents  Idempotently install the validated document module.
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
    "$PROJECT_ROOT/dashboard/documents/index.html" \
    "$PROJECT_ROOT/scripts/launch-dashboard.sh" \
    "$PROJECT_ROOT/systemd/offgridpi-dashboard.service" \
    "$PROJECT_ROOT/desktop/offgridpi-dashboard.desktop" \
    "$PROJECT_ROOT/scripts/start-kiwix.sh" \
    "$PROJECT_ROOT/systemd/kiwix-serve.service" \
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
  log "Installer version: $VERSION"

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
    /opt/offgridpi/scripts

  systemctl stop offgridpi-dashboard.service 2>/dev/null || true

  log "Installing dashboard files."
  rsync \
    --archive \
    --delete \
    "$PROJECT_ROOT/dashboard/" \
    "$DASHBOARD_ROOT/"

  chown -R root:root "$DASHBOARD_ROOT"
  find "$DASHBOARD_ROOT" -type d -exec chmod 0755 {} +
  find "$DASHBOARD_ROOT" -type f -exec chmod 0644 {} +

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


run_verifier() {
  [[ -x "$PROJECT_ROOT/tests/verify-installation.sh" ]] \
    || die "Verification script is missing or not executable."
  exec "$PROJECT_ROOT/tests/verify-installation.sh"
}

case "${1:-}" in
  check)
    check_host
    ;;
  install-documents)
    install_document_module
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
