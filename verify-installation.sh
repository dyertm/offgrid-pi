#!/usr/bin/env bash

set -uo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run this script with sudo:"
    echo "  sudo ./verify-installation.sh"
    exit 2
fi

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

LOG_DIR="/var/log/offgridpi"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="${LOG_DIR}/verification-${TIMESTAMP}.log"

mkdir -p "${LOG_DIR}"
exec > >(tee -a "${LOG_FILE}") 2>&1

pass() {
    printf 'PASS: %s\n' "$1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    printf 'FAIL: %s\n' "$1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
    printf 'WARN: %s\n' "$1"
    WARN_COUNT=$((WARN_COUNT + 1))
}

check_command() {
    local command_name="$1"

    if command -v "${command_name}" >/dev/null 2>&1; then
        pass "Command available: ${command_name}"
    else
        fail "Command missing: ${command_name}"
    fi
}

check_directory() {
    local path="$1"

    if [[ -d "${path}" ]]; then
        pass "Directory exists: ${path}"
    else
        fail "Directory missing: ${path}"
    fi
}

check_file() {
    local path="$1"

    if [[ -f "${path}" ]]; then
        pass "File exists: ${path}"
    else
        fail "File missing: ${path}"
    fi
}

check_service_active() {
    local service="$1"

    if systemctl is-active --quiet "${service}"; then
        pass "Service active: ${service}"
    else
        fail "Service not active: ${service}"
    fi
}

check_unit_enabled() {
    local unit="$1"

    if systemctl is-enabled --quiet "${unit}"; then
        pass "Unit enabled: ${unit}"
    else
        fail "Unit not enabled: ${unit}"
    fi
}

check_port() {
    local port="$1"
    local description="$2"

    if ss -H -ltn | grep -q ":${port}"; then
        pass "${description} listening on TCP ${port}"
    else
        fail "${description} not listening on TCP ${port}"
    fi
}

check_http() {
    local url="$1"
    local description="$2"

    if curl \
        --silent \
        --fail \
        --max-time 5 \
        --output /dev/null \
        "${url}"
    then
        pass "${description} answered: ${url}"
    else
        fail "${description} did not answer: ${url}"
    fi
}

echo "============================================================"
echo "Offgrid Pi Installation Verification"
echo "Date: $(date --iso-8601=seconds)"
echo "Hostname: $(hostname)"
echo "Log: ${LOG_FILE}"
echo "============================================================"
echo

echo "SYSTEM BASELINE"

if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release

    if [[ "${VERSION_ID:-}" == "13" ]]; then
        pass "Supported Debian version detected: ${PRETTY_NAME:-Debian 13}"
    else
        warn "Untested operating-system version: ${PRETTY_NAME:-Unknown}"
    fi
else
    fail "Unable to read /etc/os-release"
fi

ARCHITECTURE="$(uname -m)"

if [[ "${ARCHITECTURE}" == "aarch64" ]]; then
    pass "Architecture is aarch64"
else
    fail "Unsupported architecture detected: ${ARCHITECTURE}"
fi

if [[ -r /proc/device-tree/model ]]; then
    MODEL="$(tr -d '\0' </proc/device-tree/model)"

    if [[ "${MODEL}" == *"Raspberry Pi 4"* ]]; then
        pass "Supported hardware detected: ${MODEL}"
    else
        warn "Hardware has not been validated by this build: ${MODEL}"
    fi
else
    warn "Unable to read Raspberry Pi model"
fi

echo
echo "REQUIRED COMMANDS"

for command_name in \
    git \
    curl \
    wget \
    rsync \
    python3 \
    chromium \
    kiwix-serve \
    kiwix-manage \
    zimcheck \
    systemctl \
    ss
do
    check_command "${command_name}"
done

echo
echo "APPLICATION DIRECTORIES"

for directory in \
    /opt/offgridpi/dashboard \
    /opt/offgridpi/dashboard/css \
    /opt/offgridpi/dashboard/js \
    /opt/offgridpi/dashboard/documents \
    /opt/offgridpi/scripts \
    /srv/offgridpi/content/kiwix \
    /srv/offgridpi/content/documents/library
do
    check_directory "${directory}"
done

echo
echo "APPLICATION FILES"

for file in \
    /opt/offgridpi/dashboard/index.html \
    /opt/offgridpi/dashboard/css/styles.css \
    /opt/offgridpi/dashboard/js/app.js \
    /opt/offgridpi/dashboard/documents/index.html \
    /opt/offgridpi/scripts/index-documents.py \
    /opt/offgridpi/scripts/launch-dashboard.sh \
    /etc/systemd/system/kiwix-serve.service \
    /etc/systemd/system/offgridpi-dashboard.service \
    /etc/systemd/system/offgridpi-document-index.service \
    /etc/systemd/system/offgridpi-document-index.timer
do
    check_file "${file}"
done

echo
echo "DOCUMENT-LIBRARY CONNECTION"

DOCUMENT_LINK="/opt/offgridpi/dashboard/documents/files"
EXPECTED_DOCUMENT_TARGET="/srv/offgridpi/content/documents/library"

if [[ -L "${DOCUMENT_LINK}" ]]; then
    ACTUAL_DOCUMENT_TARGET="$(readlink -f "${DOCUMENT_LINK}")"

    if [[ "${ACTUAL_DOCUMENT_TARGET}" == "${EXPECTED_DOCUMENT_TARGET}" ]]; then
        pass "Document-library link points to ${EXPECTED_DOCUMENT_TARGET}"
    else
        fail "Document-library link points to ${ACTUAL_DOCUMENT_TARGET}"
    fi
else
    fail "Document-library symbolic link is missing"
fi

echo
echo "SYSTEMD SERVICES"

check_unit_enabled "kiwix-serve.service"
check_service_active "kiwix-serve.service"

check_unit_enabled "offgridpi-dashboard.service"
check_service_active "offgridpi-dashboard.service"

check_unit_enabled "offgridpi-document-index.timer"
check_service_active "offgridpi-document-index.timer"

INDEX_RESULT="$(
    systemctl show \
        offgridpi-document-index.service \
        --property=Result \
        --value
)"

if [[ "${INDEX_RESULT}" == "success" ]]; then
    pass "Most recent document-index run succeeded"
else
    fail "Most recent document-index result: ${INDEX_RESULT:-unknown}"
fi

echo
echo "NETWORK SERVICES"

check_port "8080" "Kiwix"
check_port "8081" "Dashboard"

check_http "http://127.0.0.1:8080/" "Kiwix"
check_http "http://127.0.0.1:8081/" "Dashboard"
check_http "http://127.0.0.1:8081/documents/" "Document library"

echo
echo "CONTENT CHECKS"

ZIM_FILE="$(
    find /srv/offgridpi/content/kiwix \
        -maxdepth 1 \
        -type f \
        -name '*.zim' \
        -print \
        -quit
)"

if [[ -n "${ZIM_FILE}" ]]; then
    pass "At least one ZIM file is installed: ${ZIM_FILE}"

    if runuser -u offgridpi -- test -r "${ZIM_FILE}"; then
        pass "Kiwix service account can read the installed ZIM"
    else
        fail "Kiwix service account cannot read ${ZIM_FILE}"
    fi
else
    fail "No ZIM file found in /srv/offgridpi/content/kiwix"
fi

DOCUMENT_FILE="$(
    find /srv/offgridpi/content/documents/library \
        -type f \
        -print \
        -quit
)"

if [[ -n "${DOCUMENT_FILE}" ]]; then
    pass "At least one local document is installed: ${DOCUMENT_FILE}"

    if runuser -u offgridpi -- test -r "${DOCUMENT_FILE}"; then
        pass "Dashboard service account can read local documents"
    else
        fail "Dashboard service account cannot read ${DOCUMENT_FILE}"
    fi
else
    warn "No files found in the document library"
fi

echo
echo "SYSTEM HEALTH"

if command -v vcgencmd >/dev/null 2>&1; then
    TEMPERATURE="$(vcgencmd measure_temp 2>/dev/null || true)"
    THROTTLE_STATUS="$(vcgencmd get_throttled 2>/dev/null || true)"

    if [[ -n "${TEMPERATURE}" ]]; then
        pass "Temperature reading available: ${TEMPERATURE}"
    else
        warn "Unable to read CPU temperature"
    fi

    if [[ "${THROTTLE_STATUS}" == "throttled=0x0" ]]; then
        pass "No undervoltage or throttling flags detected"
    else
        warn "Throttle status requires review: ${THROTTLE_STATUS:-unknown}"
    fi
else
    warn "vcgencmd is unavailable; hardware health was not checked"
fi

FAILED_UNITS="$(
    systemctl --failed \
        --no-legend \
        --plain \
        2>/dev/null |
    sed '/^[[:space:]]*$/d' |
    wc -l
)"

if [[ "${FAILED_UNITS}" -eq 0 ]]; then
    pass "No failed systemd units detected"
else
    fail "${FAILED_UNITS} failed systemd unit(s) detected"
fi

echo
echo "============================================================"
echo "VERIFICATION SUMMARY"
echo "Passed:   ${PASS_COUNT}"
echo "Warnings: ${WARN_COUNT}"
echo "Failed:   ${FAIL_COUNT}"
echo "Log file: ${LOG_FILE}"
echo "============================================================"

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
    echo "Offgrid Pi verification FAILED."
    exit 1
fi

echo "Offgrid Pi verification PASSED."
exit 0
