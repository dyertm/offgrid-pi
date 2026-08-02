#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="0.1.0"
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOCUMENT_PUBLIC="/srv/offgridpi/content/documents/public"
DOCUMENT_PERSONAL="/srv/offgridpi/content/documents/personal"
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
  sudo ./install.sh verify

Commands:
  check              Validate the host and required repository payload.
  install-documents  Idempotently install the validated Phase 4 document module.
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

check_payload() {
  local missing=0
  local path
  for path in \
    "$PROJECT_ROOT/scripts/index-documents.py" \
    "$PROJECT_ROOT/scripts/watch-documents.sh" \
    "$PROJECT_ROOT/systemd/offgridpi-documents.service" \
    "$PROJECT_ROOT/systemd/offgridpi-document-indexer.service.in" \
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
