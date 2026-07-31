#!/usr/bin/env bash

# Offgrid Pi first-generation installer
#
# This installer is designed to be safe to re-run on the validated
# Raspberry Pi OS 64-bit / Debian 13 baseline. It installs application
# files and services while preserving downloaded ZIM archives and
# user-managed documents.

set -Eeuo pipefail

PROJECT_NAME="Offgrid Pi"
APP_ROOT="/opt/offgridpi"
CONTENT_ROOT="/srv/offgridpi"
LOG_ROOT="/var/log/offgridpi"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="${LOG_ROOT}/install-${TIMESTAMP}.log"

PASS_COUNT=0
WARN_COUNT=0

log() {
    printf '%s\n' "$*"
}

pass() {
    printf 'PASS: %s\n' "$*"
    PASS_COUNT=$((PASS_COUNT + 1))
}

warn() {
    printf 'WARN: %s\n' "$*" >&2
    WARN_COUNT=$((WARN_COUNT + 1))
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

on_error() {
    local exit_code=$?
    local line_number="${1:-unknown}"
    printf '\nERROR: Installation stopped at line %s with exit code %s.\n' \
        "${line_number}" "${exit_code}" >&2
    printf 'Review the log: %s\n' "${LOG_FILE}" >&2
    exit "${exit_code}"
}

trap 'on_error ${LINENO}' ERR

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        die "Run this installer with sudo: sudo ./install.sh"
    fi
}

resolve_desktop_user() {
    local selected_user="${OFFGRIDPI_DESKTOP_USER:-${SUDO_USER:-}}"

    if [[ -z "${selected_user}" || "${selected_user}" == "root" ]]; then
        selected_user="$(
            getent passwd 1000 |
            cut -d: -f1
        )"
    fi

    [[ -n "${selected_user}" ]] ||
        die "Unable to determine the desktop user. Set OFFGRIDPI_DESKTOP_USER."

    getent passwd "${selected_user}" >/dev/null ||
        die "Desktop user does not exist: ${selected_user}"

    DESKTOP_USER="${selected_user}"
    DESKTOP_GROUP="$(id -gn "${DESKTOP_USER}")"
    DESKTOP_HOME="$(getent passwd "${DESKTOP_USER}" | cut -d: -f6)"

    [[ -d "${DESKTOP_HOME}" ]] ||
        die "Desktop-user home directory does not exist: ${DESKTOP_HOME}"
}

require_repo_file() {
    local relative_path="$1"

    [[ -f "${REPO_ROOT}/${relative_path}" ]] ||
        die "Required repository file is missing: ${relative_path}"
}

validate_repository() {
    local required_files=(
        "dashboard/index.html"
        "dashboard/css/styles.css"
        "dashboard/js/app.js"
        "scripts/index-documents.py"
        "scripts/launch-dashboard.sh"
        "systemd/kiwix-serve.service"
        "systemd/offgridpi-dashboard.service"
        "systemd/offgridpi-document-index.service"
        "systemd/offgridpi-document-index.timer"
        "config/autostart/offgridpi-dashboard.desktop"
        "verify-installation.sh"
    )

    for relative_path in "${required_files[@]}"; do
        require_repo_file "${relative_path}"
    done

    pass "Required repository files are present"
}

validate_platform() {
    [[ -r /etc/os-release ]] ||
        die "Unable to read /etc/os-release"

    # shellcheck disable=SC1091
    source /etc/os-release

    if [[ "${VERSION_ID:-}" != "13" ]]; then
        die "Unsupported operating-system version: ${PRETTY_NAME:-unknown}. Expected Debian 13."
    fi

    if [[ "$(uname -m)" != "aarch64" ]]; then
        die "Unsupported architecture: $(uname -m). Expected aarch64."
    fi

    if [[ -r /proc/device-tree/model ]]; then
        local model
        model="$(tr -d '\0' </proc/device-tree/model)"

        if [[ "${model}" != *"Raspberry Pi 4"* ]]; then
            warn "This hardware has not been validated by the project: ${model}"
        else
            pass "Validated hardware detected: ${model}"
        fi
    else
        warn "Unable to read the Raspberry Pi model"
    fi

    pass "Supported operating system detected: ${PRETTY_NAME}"
    pass "Supported architecture detected: aarch64"
}

install_packages() {
    log
    log "Installing required packages..."

    apt-get update

    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        git \
        curl \
        wget \
        rsync \
        python3 \
        chromium \
        kiwix-tools \
        zim-tools

    pass "Required packages installed"
}

ensure_service_account() {
    if id offgridpi >/dev/null 2>&1; then
        pass "Service account already exists: offgridpi"
        return
    fi

    useradd \
        --system \
        --home-dir /nonexistent \
        --shell /usr/sbin/nologin \
        offgridpi

    pass "Created restricted service account: offgridpi"
}

create_directories() {
    log
    log "Creating application and content directories..."

    install -d -o root -g root -m 0755 \
        "${APP_ROOT}" \
        "${APP_ROOT}/dashboard" \
        "${APP_ROOT}/dashboard/css" \
        "${APP_ROOT}/dashboard/js" \
        "${APP_ROOT}/dashboard/documents" \
        "${APP_ROOT}/scripts" \
        "${CONTENT_ROOT}" \
        "${CONTENT_ROOT}/content" \
        "${CONTENT_ROOT}/content/kiwix" \
        "${CONTENT_ROOT}/content/documents" \
        "${CONTENT_ROOT}/logs" \
        "${CONTENT_ROOT}/backups"

    local library_root="${CONTENT_ROOT}/content/documents/library"

    install -d \
        -o "${DESKTOP_USER}" \
        -g "${DESKTOP_GROUP}" \
        -m 0755 \
        "${library_root}" \
        "${library_root}/emergency" \
        "${library_root}/first-aid" \
        "${library_root}/food" \
        "${library_root}/gardening" \
        "${library_root}/communications" \
        "${library_root}/radio" \
        "${library_root}/repair" \
        "${library_root}/equipment-manuals" \
        "${library_root}/education" \
        "${library_root}/books" \
        "${library_root}/faith" \
        "${library_root}/faith/bibles" \
        "${library_root}/faith/devotionals" \
        "${library_root}/faith/study" \
        "${library_root}/faith/theology"

    # Preserve existing content ownership. Only ensure the root content
    # directory is usable by the desktop administrator.
    chown "${DESKTOP_USER}:${DESKTOP_GROUP}" \
        "${CONTENT_ROOT}/content/kiwix"

    chmod 0755 "${CONTENT_ROOT}/content/kiwix"

    pass "Application and content directories are ready"
}

install_application_files() {
    log
    log "Installing dashboard and scripts..."

    rsync -a \
        --exclude 'documents/' \
        "${REPO_ROOT}/dashboard/" \
        "${APP_ROOT}/dashboard/"

    install \
        -o root \
        -g root \
        -m 0755 \
        "${REPO_ROOT}/scripts/index-documents.py" \
        "${APP_ROOT}/scripts/index-documents.py"

    install \
        -o root \
        -g root \
        -m 0755 \
        "${REPO_ROOT}/scripts/launch-dashboard.sh" \
        "${APP_ROOT}/scripts/launch-dashboard.sh"

    local document_link="${APP_ROOT}/dashboard/documents/files"
    local document_target="${CONTENT_ROOT}/content/documents/library"

    if [[ -e "${document_link}" && ! -L "${document_link}" ]]; then
        die "Refusing to replace non-symbolic path: ${document_link}"
    fi

    ln -sfn "${document_target}" "${document_link}"

    pass "Dashboard and application scripts installed"
    pass "Document-library link configured"
}

install_systemd_units() {
    log
    log "Installing systemd units..."

    local unit

    for unit in \
        kiwix-serve.service \
        offgridpi-dashboard.service \
        offgridpi-document-index.service \
        offgridpi-document-index.timer
    do
        install \
            -o root \
            -g root \
            -m 0644 \
            "${REPO_ROOT}/systemd/${unit}" \
            "/etc/systemd/system/${unit}"
    done

    systemd-analyze verify \
        /etc/systemd/system/kiwix-serve.service \
        /etc/systemd/system/offgridpi-dashboard.service \
        /etc/systemd/system/offgridpi-document-index.service \
        /etc/systemd/system/offgridpi-document-index.timer

    systemctl daemon-reload

    pass "Systemd units installed and validated"
}

install_desktop_autostart() {
    log
    log "Installing Chromium dashboard autostart..."

    local autostart_dir="${DESKTOP_HOME}/.config/autostart"
    local autostart_file="${autostart_dir}/offgridpi-dashboard.desktop"

    install -d \
        -o "${DESKTOP_USER}" \
        -g "${DESKTOP_GROUP}" \
        -m 0755 \
        "${autostart_dir}"

    install \
        -o "${DESKTOP_USER}" \
        -g "${DESKTOP_GROUP}" \
        -m 0644 \
        "${REPO_ROOT}/config/autostart/offgridpi-dashboard.desktop" \
        "${autostart_file}"

    pass "Desktop autostart installed for ${DESKTOP_USER}"
}

enable_services() {
    log
    log "Enabling services..."

    systemctl enable --now offgridpi-dashboard.service

    # Generate the initial document index before enabling the timer.
    systemctl start offgridpi-document-index.service
    systemctl enable --now offgridpi-document-index.timer

    pass "Dashboard service enabled and started"
    pass "Document index generated and timer enabled"

    local zim_file
    zim_file="$(
        find "${CONTENT_ROOT}/content/kiwix" \
            -maxdepth 1 \
            -type f \
            -name '*.zim' \
            -print \
            -quit
    )"

    if [[ -z "${zim_file}" ]]; then
        warn "No ZIM archive is installed; Kiwix service was not enabled"
        return
    fi

    if systemctl enable --now kiwix-serve.service; then
        pass "Kiwix service enabled and started"
    else
        warn "A ZIM file exists, but the Kiwix service did not start"
        journalctl -u kiwix-serve.service -n 20 --no-pager || true
    fi
}

run_verification() {
    log
    log "Running installation verification..."

    local zim_file
    zim_file="$(
        find "${CONTENT_ROOT}/content/kiwix" \
            -maxdepth 1 \
            -type f \
            -name '*.zim' \
            -print \
            -quit
    )"

    if [[ -z "${zim_file}" ]]; then
        warn "Full verification skipped because no ZIM archive is installed"
        return
    fi

    if "${REPO_ROOT}/verify-installation.sh"; then
        pass "Full installation verification passed"
    else
        die "Installation completed, but verification failed"
    fi
}

print_summary() {
    log
    log "============================================================"
    log "${PROJECT_NAME} installation complete"
    log "Desktop user: ${DESKTOP_USER}"
    log "Dashboard: http://127.0.0.1:8081/"
    log "Kiwix:     http://127.0.0.1:8080/"
    log "Log file:  ${LOG_FILE}"
    log "Passed steps: ${PASS_COUNT}"
    log "Warnings:     ${WARN_COUNT}"
    log "============================================================"

    if [[ "${WARN_COUNT}" -gt 0 ]]; then
        log "Review the warnings above before treating the installation as complete."
    fi
}

main() {
    require_root

    install -d -o root -g root -m 0755 "${LOG_ROOT}"
    touch "${LOG_FILE}"
    chmod 0644 "${LOG_FILE}"

    exec > >(tee -a "${LOG_FILE}") 2>&1

    log "============================================================"
    log "${PROJECT_NAME} Installer"
    log "Started: $(date --iso-8601=seconds)"
    log "Repository: ${REPO_ROOT}"
    log "Log: ${LOG_FILE}"
    log "============================================================"

    resolve_desktop_user
    validate_repository
    validate_platform
    install_packages
    ensure_service_account
    create_directories
    install_application_files
    install_systemd_units
    install_desktop_autostart
    enable_services
    run_verification
    print_summary
}

main "$@"
