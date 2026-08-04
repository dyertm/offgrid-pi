#!/usr/bin/env bash
set -u

FAILURES=0
WARNINGS=0

ADMIN_USER="${OFFGRIDPI_ADMIN_USER:-${SUDO_USER:-${USER:-}}}"
ADMIN_HOME=""

if [[ -n "$ADMIN_USER" ]]; then
  ADMIN_HOME="$(getent passwd "$ADMIN_USER" 2>/dev/null | cut -d: -f6)"
fi

AUTOSTART_FILE="${ADMIN_HOME:+$ADMIN_HOME/.config/autostart/offgridpi-dashboard.desktop}"

pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILURES=$((FAILURES + 1)); }
warn() { printf 'REVIEW: %s\n' "$*"; WARNINGS=$((WARNINGS + 1)); }

check_service() {
  local service="$1"
  if systemctl is-enabled --quiet "$service" 2>/dev/null; then
    pass "$service is enabled."
  else
    fail "$service is not enabled."
  fi

  if systemctl is-active --quiet "$service" 2>/dev/null; then
    pass "$service is active."
  else
    fail "$service is not active."
  fi
}

check_port() {
  local port="$1"
  if ss -ltn 2>/dev/null | grep -qE ":${port}([[:space:]]|$)"; then
    pass "TCP port $port is listening."
  else
    fail "TCP port $port is not listening."
  fi
}

check_http() {
  local name="$1"
  local url="$2"
  local code
  code="$(curl --max-time 5 -sS -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || true)"
  case "$code" in
    200|301|302) pass "$name returned HTTP $code." ;;
    *) fail "$name returned HTTP ${code:-no-response}." ;;
  esac
}

echo "=== Offgrid Pi verification ==="
echo "Host: $(hostname 2>/dev/null || echo unknown)"
echo "Date: $(date --iso-8601=seconds 2>/dev/null || date)"

echo
echo "=== Platform ==="
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  printf 'Operating system: %s\n' "${PRETTY_NAME:-unknown}"
else
  warn "/etc/os-release is unavailable."
fi
printf 'Architecture: %s\n' "$(uname -m)"
if [[ -r /proc/device-tree/model ]]; then
  printf 'Device: %s\n' "$(tr -d '\0' </proc/device-tree/model)"
fi

echo
echo "=== Required paths ==="
for path in \
  /opt/offgridpi/dashboard/index.html \
  /opt/offgridpi/dashboard/css/styles.css \
  /opt/offgridpi/dashboard/js/app.js \
  /opt/offgridpi/dashboard/documents/index.html \
  /opt/offgridpi/scripts/launch-dashboard.sh \
  /etc/systemd/system/offgridpi-dashboard.service \
  /opt/offgridpi/scripts/start-kiwix.sh \
  /opt/offgridpi/scripts/manage-installation.sh \
  /opt/offgridpi/scripts/offgridpi-status.py \
  /opt/offgridpi/scripts/offgridpi-admin.py \
  /etc/systemd/system/kiwix-serve.service \
  /opt/offgridpi/scripts/index-documents.py \
  /opt/offgridpi/scripts/watch-documents.sh \
  /srv/offgridpi/content/kiwix \
  /srv/offgridpi/content/documents/public \
  /srv/offgridpi/content/documents/personal \
  /srv/offgridpi/content/documents/public/index.html \
  /srv/offgridpi/content/documents/public/catalog.json
do
  if [[ -e "$path" ]]; then
    pass "$path exists."
  else
    fail "$path is missing."
  fi
done

if [[ -n "$AUTOSTART_FILE" && -f "$AUTOSTART_FILE" ]]; then
  pass "$AUTOSTART_FILE exists."
else
  fail "Dashboard desktop autostart file is missing."
fi

mapfile -d '' -t KIWIX_ZIMS < <(
  find /srv/offgridpi/content/kiwix \
    -type d -name rejected -prune -o \
    -type f \
    -name '*.zim' \
    -print0 2>/dev/null |
    sort -z
)

echo
echo "=== Services ==="

if [[ "${#KIWIX_ZIMS[@]}" -gt 0 ]]; then
  check_service kiwix-serve.service
else
  if systemctl is-enabled --quiet kiwix-serve.service 2>/dev/null; then
    warn "Kiwix is enabled even though no approved ZIM files exist."
  else
    pass "Kiwix is disabled because no approved ZIM files exist."
  fi

  if systemctl is-active --quiet kiwix-serve.service 2>/dev/null; then
    warn "Kiwix is active even though no approved ZIM files exist."
  else
    pass "Kiwix is inactive because no approved ZIM files exist."
  fi
fi

for service in \
  offgridpi-dashboard.service \
  offgridpi-documents.service \
  offgridpi-document-indexer.service
do
  check_service "$service"
done

echo
echo "=== Network listeners ==="

if [[ "${#KIWIX_ZIMS[@]}" -gt 0 ]]; then
  check_port 8080
else
  pass "TCP port 8080 is not required without approved ZIM files."
fi

check_port 8081
check_port 8082

echo
echo "=== Local HTTP ==="

if [[ "${#KIWIX_ZIMS[@]}" -gt 0 ]]; then
  check_http "Kiwix" "http://127.0.0.1:8080/"
else
  pass "Kiwix HTTP is not required without approved ZIM files."
fi

check_http "Dashboard" "http://127.0.0.1:8081/"
check_http "Document library" "http://127.0.0.1:8082/"


echo
echo "=== Kiwix content ==="

if command -v kiwix-serve >/dev/null 2>&1; then
  printf 'Kiwix version: %s\n' \
    "$(kiwix-serve --version 2>/dev/null | head -n 1)"
  pass "kiwix-serve is installed."
else
  fail "kiwix-serve is unavailable."
fi

if [[ "${#KIWIX_ZIMS[@]}" -gt 0 ]]; then
  pass "${#KIWIX_ZIMS[@]} approved ZIM file(s) detected."

  for zim in "${KIWIX_ZIMS[@]}"; do
    printf '  %s\n' "$zim"
  done
else
  pass "No approved ZIM files were detected; Kiwix remains available for future content."
fi

if [[ -x /opt/offgridpi/scripts/start-kiwix.sh ]]; then
  pass "Kiwix discovery launcher is executable."
else
  fail "Kiwix discovery launcher is not executable."
fi

if grep -qF \
  'ExecStart=/opt/offgridpi/scripts/start-kiwix.sh' \
  /etc/systemd/system/kiwix-serve.service 2>/dev/null
then
  pass "Kiwix service uses automatic ZIM discovery."
else
  fail "Kiwix service does not use the discovery launcher."
fi

if grep '^ExecStart=' \
    /etc/systemd/system/kiwix-serve.service 2>/dev/null |
    grep -q '\.zim'
then
  fail "Kiwix service still contains a hardcoded ZIM filename."
else
  pass "Kiwix service has no hardcoded ZIM filename."
fi

if pgrep -af '[k]iwix-serve' | grep -q '/rejected/'; then
  fail "The running Kiwix process includes a rejected ZIM file."
else
  pass "Rejected ZIM files are excluded from Kiwix."
fi

echo
echo "=== Document catalog ==="
if python3 - <<'PY'
import json
from pathlib import Path

catalog_path = Path("/srv/offgridpi/content/documents/public/catalog.json")
public_root = Path("/srv/offgridpi/content/documents/public").resolve()
personal_root = Path("/srv/offgridpi/content/documents/personal").resolve()

catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
paths = [
    item["path"]
    for category in catalog.get("categories", [])
    for item in category.get("files", [])
]

print(f"Catalog total: {catalog.get('total_files', 'unknown')}")
if any("personal" in path.split("/") for path in paths):
    raise SystemExit("Private path appears in catalog")
if public_root == personal_root or personal_root.is_relative_to(public_root):
    raise SystemExit("Personal root is inside public root")
print("Private content is excluded from the catalog.")
PY
then
  pass "Document catalog structure and isolation checks passed."
else
  fail "Document catalog validation failed."
fi

PRIVATE_CODE="$(curl --path-as-is --max-time 5 -sS -o /dev/null -w '%{http_code}' \
  http://127.0.0.1:8082/../personal/phase4-private-test.txt 2>/dev/null || true)"
if [[ "$PRIVATE_CODE" == "404" ]]; then
  pass "Parent traversal to the personal directory returned HTTP 404."
else
  fail "Personal-directory traversal returned HTTP ${PRIVATE_CODE:-no-response}."
fi

echo
echo "=== Dashboard integration ==="

if grep -qF 'id="kiwix-link"' /opt/offgridpi/dashboard/index.html \
  && grep -qF 'window.location.hostname' /opt/offgridpi/dashboard/js/app.js; then
  pass "Kiwix uses the dashboard visitor hostname."
else
  fail "Dynamic Kiwix routing was not detected."
fi

if curl --max-time 5 -fsS http://127.0.0.1:8081/documents/ 2>/dev/null \
  | grep -qF 'window.location.hostname'; then
  pass "Local Documents uses a dynamic hostname redirect."
else
  fail "Dynamic Local Documents routing was not detected."
fi

if [[ -x /opt/offgridpi/scripts/launch-dashboard.sh ]]; then
  pass "Dashboard launcher is executable."
else
  fail "Dashboard launcher is not executable."
fi

if [[ -n "$AUTOSTART_FILE" ]] \
  && grep -qF 'Exec=/opt/offgridpi/scripts/launch-dashboard.sh' \
    "$AUTOSTART_FILE" 2>/dev/null; then
  pass "Desktop autostart launches the Offgrid Pi dashboard."
else
  fail "Dashboard desktop autostart is not configured correctly."
fi


echo
echo "=== Installation management ==="

BACKUP_ROOT="/srv/offgridpi/backups/configuration"

if [[ -x /opt/offgridpi/scripts/manage-installation.sh ]]; then
  pass "Installation management tool is executable."
else
  fail "Installation management tool is unavailable."
fi

if [[ -d "$BACKUP_ROOT" ]]; then
  pass "Configuration backup directory exists."
else
  fail "Configuration backup directory is missing."
fi

LATEST_SNAPSHOT="$(
  find "$BACKUP_ROOT" \
    -mindepth 1 \
    -maxdepth 1 \
    -type d \
    -name 'snapshot-*' \
    -printf '%p\n' 2>/dev/null |
    sort |
    tail -n 1
)"

if [[ -n "$LATEST_SNAPSHOT" ]]; then
  pass "At least one configuration snapshot exists."

  if [[ -f "$LATEST_SNAPSHOT/manifest.txt" ]]; then
    pass "Latest snapshot contains a manifest."
  else
    fail "Latest snapshot manifest is missing."
  fi

  if [[ -f "$LATEST_SNAPSHOT/service-states.tsv" ]]; then
    pass "Latest snapshot contains service states."
  else
    fail "Latest snapshot service-state record is missing."
  fi

  if find "$LATEST_SNAPSHOT/rootfs" \
      -path '*/srv/offgridpi/content*' \
      -print -quit 2>/dev/null |
      grep -q .
  then
    fail "Configuration snapshot contains user content."
  else
    pass "Configuration snapshots exclude user content."
  fi
else
  fail "No configuration snapshot was found."
fi

echo
echo "=== System administration ==="

if [[ -x /opt/offgridpi/scripts/offgridpi-status.py ]]; then
  pass "System-status command is executable."
else
  fail "System-status command is unavailable."
fi

if [[ -x /opt/offgridpi/scripts/offgridpi-admin.py ]]; then
  pass "Administration command is executable."
else
  fail "Administration command is unavailable."
fi

if /opt/offgridpi/scripts/offgridpi-status.py --json 2>/dev/null |
    python3 -c '
import json
import sys

report = json.load(sys.stdin)
if report.get("overall") not in {"HEALTHY", "ATTENTION"}:
    raise SystemExit(1)
' 2>/dev/null
then
  pass "System-status command returned valid JSON."
else
  fail "System-status command did not return valid JSON."
fi

if /opt/offgridpi/scripts/offgridpi-admin.py \
    restart-service kiwix 2>/dev/null |
    grep -qF "No changes were made."
then
  pass "Administration restart defaults to preview mode."
else
  fail "Administration restart preview validation failed."
fi

if /opt/offgridpi/scripts/offgridpi-admin.py \
    reindex-documents 2>/dev/null |
    grep -qF "No changes were made."
then
  pass "Document reindexing defaults to preview mode."
else
  fail "Document reindex preview validation failed."
fi

if /opt/offgridpi/scripts/offgridpi-admin.py \
    system-action reboot 2>/dev/null |
    grep -qF "No changes were made."
then
  pass "System reboot defaults to preview mode."
else
  fail "System reboot preview validation failed."
fi

if /opt/offgridpi/scripts/offgridpi-admin.py \
    system-action poweroff 2>/dev/null |
    grep -qF "No changes were made."
then
  pass "System power-off defaults to preview mode."
else
  fail "System power-off preview validation failed."
fi

echo
printf '\n=== Dashboard system status ===\n'

for path in \
  /opt/offgridpi/dashboard/status/index.html \
  /opt/offgridpi/dashboard/status/status.css \
  /opt/offgridpi/dashboard/status/status.js \
  /opt/offgridpi/dashboard/data/system-status.json \
  /opt/offgridpi/scripts/publish-system-status.sh \
  /etc/systemd/system/offgridpi-status-publisher.service \
  /etc/systemd/system/offgridpi-status-publisher.timer
do
  if [[ -s "$path" ]]; then
    pass "Installed status component exists: $path"
  else
    fail "Installed status component is missing: $path"
  fi
done

if systemctl is-enabled --quiet \
  offgridpi-status-publisher.timer
then
  pass "Status publisher timer is enabled."
else
  fail "Status publisher timer is not enabled."
fi

if systemctl is-active --quiet \
  offgridpi-status-publisher.timer
then
  pass "Status publisher timer is active."
else
  fail "Status publisher timer is not active."
fi

publisher_result="$(
  systemctl show \
    offgridpi-status-publisher.service \
    --property=Result \
    --value
)"

if [[ "$publisher_result" == "success" ]]; then
  pass "Status publisher service completed successfully."
else
  fail "Status publisher service result: $publisher_result"
fi

if curl \
  --silent \
  --fail \
  --output /dev/null \
  http://127.0.0.1:8081/status/
then
  pass "Dashboard system-status page is available."
else
  fail "Dashboard system-status page is unavailable."
fi

if curl \
  --silent \
  --fail \
  http://127.0.0.1:8081/data/system-status.json |
  python3 -c '
import json
import sys

report = json.load(sys.stdin)

required = {
    "hostname",
    "uptime_seconds",
    "hardware",
    "storage",
    "services",
    "kiwix",
    "documents",
    "backups",
    "overall",
}

missing = required - report.keys()

if missing:
    raise SystemExit(
        "Missing fields: " + ", ".join(sorted(missing))
    )

if report["overall"] not in {"HEALTHY", "ATTENTION"}:
    raise SystemExit("Invalid overall state.")
'
then
  pass "Dashboard system-status JSON is valid."
else
  fail "Dashboard system-status JSON validation failed."
fi

if grep -qF \
  'href="status/"' \
  /opt/offgridpi/dashboard/index.html
then
  pass "Dashboard links to the System Status page."
else
  fail "Dashboard System Status link is missing."
fi

echo "=== System health ==="
FAILED_UNITS="$(systemctl --failed --no-legend 2>/dev/null || true)"
if [[ -z "$FAILED_UNITS" ]]; then
  pass "No failed systemd units."
else
  printf '%s\n' "$FAILED_UNITS"
  warn "One or more systemd units are failed."
fi

if pgrep -af chromium >/dev/null 2>&1; then
  pass "Chromium is running."
else
  warn "Chromium was not detected; this may be normal over SSH before desktop login."
fi

if command -v vcgencmd >/dev/null 2>&1; then
  printf 'Temperature: %s\n' "$(vcgencmd measure_temp 2>/dev/null || echo unavailable)"
  printf 'Throttle status: %s\n' "$(vcgencmd get_throttled 2>/dev/null || echo unavailable)"
fi

echo
echo "=== Result ==="
printf 'Failures: %d\n' "$FAILURES"
printf 'Review items: %d\n' "$WARNINGS"
if [[ "$FAILURES" -eq 0 ]]; then
  pass "Core Offgrid Pi verification succeeded."
  exit 0
fi
fail "Core Offgrid Pi verification did not pass."
exit 1
