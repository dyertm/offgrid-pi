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
  /opt/offgridpi/dashboard/legal/index.html \
  /opt/offgridpi/dashboard/legal/legal.css \
  /opt/offgridpi/scripts/generate-legal-notices.py \
  /opt/offgridpi/compliance/software-components.json \
  /opt/offgridpi/compliance/schema/software-components.schema.json \
  /opt/offgridpi/compliance/validate-software-components.py \
  /opt/offgridpi/LICENSE \
  /opt/offgridpi/scripts/launch-dashboard.sh \
  /etc/systemd/system/offgridpi-dashboard.service \
  /opt/offgridpi/scripts/start-kiwix.sh \
  /opt/offgridpi/scripts/manage-installation.sh \
  /opt/offgridpi/scripts/offgridpi-status.py \
  /opt/offgridpi/scripts/offgridpi-admin.py \
  /etc/systemd/system/kiwix-serve.service \
  /opt/offgridpi/scripts/index-documents.py \
  /opt/offgridpi/scripts/watch-documents.sh \
  /opt/offgridpi/maps/index.html \
  /opt/offgridpi/scripts/offgridpi-map-server.py \
  /opt/offgridpi/content-packs/import-map-pack.py \
  /opt/offgridpi/content-packs/inspect-map-pack.py \
  /opt/offgridpi/content-packs/validate-map-pack.py \
  /opt/offgridpi/content-packs/schema/map-pack.schema.json \
  /etc/systemd/system/offgridpi-maps.service \
  /opt/offgridpi/scripts/offgridpi-owner-server.py \
  /etc/systemd/system/offgridpi-owner.service \
  /srv/offgridpi/content/maps \
  /srv/offgridpi/content/maps/packs \
  /srv/offgridpi/content/maps/incoming \
  /srv/offgridpi/content/maps/rejected \
  /srv/offgridpi/content/maps/user-data \
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
  offgridpi-document-indexer.service \
  offgridpi-maps.service
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
check_port 8084

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
echo "=== Offline Maps reader ==="

map_user="$(
  systemctl show \
    offgridpi-maps.service \
    --property=User \
    --value \
    2>/dev/null || true
)"

map_group="$(
  systemctl show \
    offgridpi-maps.service \
    --property=Group \
    --value \
    2>/dev/null || true
)"

if [[ "$map_user" == "offgridpi" ]]; then
  pass "Offline Maps service uses the restricted account."
else
  fail "Unexpected Offline Maps service user: ${map_user:-unknown}"
fi

if [[ "$map_group" == "offgridpi" ]]; then
  pass "Offline Maps service uses the restricted group."
else
  fail "Unexpected Offline Maps service group: ${map_group:-unknown}"
fi

map_listener="$(
  ss -ltnH 'sport = :8084' \
    2>/dev/null || true
)"

if grep -qE \
  '(^|[[:space:]])(0\.0\.0\.0|\*):8084([[:space:]]|$)' \
  <<< "$map_listener"
then
  pass "Offline Maps reader listens publicly on TCP port 8084."
else
  fail "Offline Maps reader is not listening on the approved public address."
fi

map_temp="$(
  mktemp -d
)"

map_headers="$map_temp/headers.txt"
map_body="$map_temp/body.html"

if curl \
  --silent \
  --show-error \
  --dump-header "$map_headers" \
  --output "$map_body" \
  http://127.0.0.1:8084/
then
  if grep -qE \
    '^HTTP/[^ ]+ 200([[:space:]]|$)' \
    "$map_headers"
  then
    pass "Offline Maps reader returns HTTP 200."
  else
    fail "Offline Maps reader did not return HTTP 200."
  fi

  if grep -qF \
    'Offline Maps' \
    "$map_body"
  then
    pass "Offline Maps reader page content is valid."
  else
    fail "Offline Maps reader returned unexpected content."
  fi

  if grep -qi \
    '^Content-Security-Policy:' \
    "$map_headers"
  then
    pass "Offline Maps Content Security Policy is present."
  else
    fail "Offline Maps Content Security Policy is missing."
  fi

  if grep -qi \
    '^X-Content-Type-Options: nosniff' \
    "$map_headers"
  then
    pass "Offline Maps MIME-sniffing protection is enabled."
  else
    fail "Offline Maps MIME-sniffing protection is missing."
  fi

  if grep -qi \
    '^X-Frame-Options: DENY' \
    "$map_headers"
  then
    pass "Offline Maps frame protection is enabled."
  else
    fail "Offline Maps frame protection is missing."
  fi
else
  fail "Unable to retrieve the Offline Maps reader page."
fi

map_unknown_code="$(
  curl \
    --silent \
    --output /dev/null \
    --write-out '%{http_code}' \
    http://127.0.0.1:8084/not-present \
    2>/dev/null || true
)"

if [[ "$map_unknown_code" == "404" ]]; then
  pass "Unknown Offline Maps routes return HTTP 404."
else
  fail "Unexpected Offline Maps unknown-route response: HTTP ${map_unknown_code:-000}"
fi

map_post_code="$(
  curl \
    --silent \
    --request POST \
    --output /dev/null \
    --write-out '%{http_code}' \
    http://127.0.0.1:8084/ \
    2>/dev/null || true
)"

if [[ "$map_post_code" == "405" ]]; then
  pass "Offline Maps reader rejects write methods."
else
  fail "Unexpected Offline Maps POST response: HTTP ${map_post_code:-000}"
fi

map_range_target="$(
  python3 - <<'PYMAP'
import json
from pathlib import Path
from urllib.parse import quote

root = Path("/srv/offgridpi/content/maps/packs")

for manifest_path in sorted(root.glob("*/*/manifest.json")):
    try:
        manifest = json.loads(
            manifest_path.read_text(encoding="utf-8")
        )
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        continue

    pack_id = manifest.get("pack_id")
    version = manifest.get("version")
    files = manifest.get("files")

    if (
        not isinstance(pack_id, str)
        or not isinstance(version, str)
        or not isinstance(files, list)
    ):
        continue

    for declaration in files:
        if not isinstance(declaration, dict):
            continue

        if declaration.get("role") != "basemap":
            continue

        relative = declaration.get("path")

        if not isinstance(relative, str) or not relative:
            continue

        target = manifest_path.parent / relative

        if target.is_symlink() or not target.is_file():
            continue

        print(
            "/packs/"
            + quote(pack_id, safe="")
            + "/"
            + quote(version, safe="")
            + "/"
            + quote(relative, safe="/")
        )
        raise SystemExit(0)
PYMAP
)"

if [[ -n "$map_range_target" ]]; then
  map_range_headers="$map_temp/range-headers.txt"

  curl \
    --silent \
    --show-error \
    --header 'Range: bytes=0-3' \
    --dump-header "$map_range_headers" \
    --output "$map_temp/range-body.bin" \
    "http://127.0.0.1:8084$map_range_target" \
    >/dev/null 2>&1 || true

  if grep -qE \
    '^HTTP/[^ ]+ 206([[:space:]]|$)' \
    "$map_range_headers" 2>/dev/null \
    && grep -qi \
      '^Accept-Ranges: bytes' \
      "$map_range_headers"
  then
    pass "Installed PMTiles content supports HTTP byte ranges."
  else
    fail "Installed PMTiles content failed HTTP byte-range verification."
  fi
else
  pass "PMTiles range verification is not required without installed map packs."
fi

rm -rf "$map_temp"

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

if grep -qF 'id="documents-link"' /opt/offgridpi/dashboard/index.html \
  && grep -qF 'documentsLink.href' /opt/offgridpi/dashboard/js/app.js \
  && grep -qF ':8082' /opt/offgridpi/dashboard/js/app.js; then
  pass "Local Documents uses the dashboard visitor hostname."
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

if grep -qF 'href="legal/"' \
  /opt/offgridpi/dashboard/index.html 2>/dev/null
then
  pass "Dashboard links to the Legal & Notices page."
else
  fail "Dashboard Legal & Notices link is missing."
fi


echo
echo "=== Legal & Notices ==="

LEGAL_ROOT="/opt/offgridpi/dashboard/legal"
LEGAL_PAGE="$LEGAL_ROOT/index.html"
LEGAL_TEMP="$(mktemp)"

for notice in \
  offgrid-pi-license.txt \
  python3.txt \
  inotify-tools.txt \
  curl.txt \
  rsync.txt \
  chromium.txt \
  kiwix-tools.txt \
  zim-tools.txt \
  maplibre-gl-js.txt \
  pmtiles-js.txt \
  fflate.txt
do
  notice_path="$LEGAL_ROOT/notices/$notice"

  if [[ -s "$notice_path" ]]; then
    pass "Local notice exists: $notice"
  else
    fail "Local notice is missing or empty: $notice"
  fi
done

if /opt/offgridpi/compliance/validate-software-components.py \
    /opt/offgridpi/compliance/software-components.json \
    /opt/offgridpi/LICENSE \
    >/dev/null 2>&1
then
  pass "Installed software-component register is valid."
else
  fail "Installed software-component register validation failed."
fi

if curl \
    --max-time 5 \
    --fail \
    --silent \
    --show-error \
    --output "$LEGAL_TEMP" \
    http://127.0.0.1:8081/legal/ \
    2>/dev/null
then
  pass "Legal & Notices page returned HTTP 200."

  if grep -qF \
      'class="dashboard-return" href="../"' \
      "$LEGAL_TEMP" \
    && grep -qF '← Dashboard' "$LEGAL_TEMP"
  then
    pass "Legal page has standardized Dashboard navigation."
  else
    fail "Legal page Dashboard navigation is incomplete."
  fi

  component_count="$(
    grep -cF '<article class="component">' \
      "$LEGAL_TEMP" 2>/dev/null || true
  )"

  if [[ "$component_count" -eq 10 ]]; then
    pass "Legal page lists all ten registered components."
  else
    fail "Legal page lists ${component_count:-0} component(s), expected 10."
  fi

  if grep -qF 'Not installed' "$LEGAL_TEMP"; then
    fail "Legal page reports a missing registered component."
  else
    pass "All registered legal components are installed."
  fi

  if grep -qi '<script' "$LEGAL_TEMP"; then
    fail "Legal page unexpectedly contains JavaScript."
  else
    pass "Legal page contains no JavaScript."
  fi

  if grep -Eqi \
      'src="https?://|href="https?://[^"]+\.(css|js)([?"#]|")' \
      "$LEGAL_TEMP"
  then
    fail "Legal page contains a remote executable asset."
  else
    pass "Legal page uses only local presentation assets."
  fi

  kiwix_package_version="$(
    dpkg-query \
      -W \
      -f='${Version}' \
      kiwix-tools \
      2>/dev/null || true
  )"

  if [[ -n "$kiwix_package_version" ]] \
    && grep -qF "$kiwix_package_version" "$LEGAL_TEMP"
  then
    pass "Legal page records the installed Kiwix package version."
  else
    fail "Legal page does not record the installed Kiwix package version."
  fi
else
  fail "Unable to retrieve the Legal & Notices page."
fi

rm -f "$LEGAL_TEMP"


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

printf '\n=== Protected system logs ===\n'

if [[ "$EUID" -eq 0 ]]; then
  privileged=()
elif sudo -v; then
  privileged=(sudo)
else
  fail "Protected log verification requires administrative access."
  privileged=(false)
fi

for path in \
  /opt/offgridpi/scripts/publish-system-logs.py \
  /etc/systemd/system/offgridpi-log-publisher.service \
  /etc/systemd/system/offgridpi-log-publisher.timer \
  /var/lib/offgridpi/management/system-logs.json
do
  if "${privileged[@]}" test -s "$path"; then
    pass "Protected log component exists: $path"
  else
    fail "Protected log component is missing: $path"
  fi
done

if systemctl is-enabled --quiet \
  offgridpi-log-publisher.timer
then
  pass "Protected log publisher timer is enabled."
else
  fail "Protected log publisher timer is not enabled."
fi

if systemctl is-active --quiet \
  offgridpi-log-publisher.timer
then
  pass "Protected log publisher timer is active."
else
  fail "Protected log publisher timer is not active."
fi

publisher_result="$(
  systemctl show \
    offgridpi-log-publisher.service \
    --property=Result \
    --value
)"

if [[ "$publisher_result" == "success" ]]; then
  pass "Protected log publisher completed successfully."
else
  fail "Protected log publisher result: $publisher_result"
fi

log_directory_mode="$(
  "${privileged[@]}" stat -c '%U:%G:%a' \
    /var/lib/offgridpi/management \
    2>/dev/null || true
)"

if [[ "$log_directory_mode" == "root:offgridpi:750" ]]; then
  pass "Protected log directory permissions are correct."
else
  fail "Protected log directory permissions: $log_directory_mode"
fi

log_file_mode="$(
  "${privileged[@]}" stat -c '%U:%G:%a' \
    /var/lib/offgridpi/management/system-logs.json \
    2>/dev/null || true
)"

if [[ "$log_file_mode" == "root:offgridpi:640" ]]; then
  pass "Protected log snapshot permissions are correct."
else
  fail "Protected log snapshot permissions: $log_file_mode"
fi

if "${privileged[@]}" python3 - <<'PY'
import json
from pathlib import Path

path = Path(
    "/var/lib/offgridpi/management/system-logs.json"
)
report = json.loads(path.read_text(encoding="utf-8"))

if report.get("schema_version") != 1:
    raise SystemExit("Invalid schema version.")

if report.get("source_count") != 5:
    raise SystemExit("Unexpected source count.")

sources = report.get("sources")

if not isinstance(sources, list) or len(sources) != 5:
    raise SystemExit("Invalid sources collection.")

for source in sources:
    entries = source.get("entries")

    if not isinstance(entries, list):
        raise SystemExit("Invalid log entries.")

    if source.get("entry_count") != len(entries):
        raise SystemExit("Entry count mismatch.")
PY
then
  pass "Protected log snapshot structure is valid."
else
  fail "Protected log snapshot validation failed."
fi

public_code="$(
  curl \
    --silent \
    --output /dev/null \
    --write-out '%{http_code}' \
    http://127.0.0.1:8081/data/system-logs.json
)"

if [[ "$public_code" == "404" ]]; then
  pass "Protected logs are not exposed through the dashboard."
else
  fail "Unexpected public log endpoint response: HTTP $public_code"
fi

printf '\n=== Local management viewer ===\n'

for path in \
  /opt/offgridpi/scripts/offgridpi-management-server.py \
  /etc/systemd/system/offgridpi-management.service
do
  if [[ -s "$path" ]]; then
    pass "Local management component exists: $path"
  else
    fail "Local management component is missing: $path"
  fi
done

if systemctl is-enabled --quiet \
  offgridpi-management.service
then
  pass "Local management service is enabled."
else
  fail "Local management service is not enabled."
fi

if systemctl is-active --quiet \
  offgridpi-management.service
then
  pass "Local management service is active."
else
  fail "Local management service is not active."
fi

management_user="$(
  systemctl show \
    offgridpi-management.service \
    --property=User \
    --value \
    2>/dev/null || true
)"

management_group="$(
  systemctl show \
    offgridpi-management.service \
    --property=Group \
    --value \
    2>/dev/null || true
)"

if [[ "$management_user" == "offgridpi" ]]; then
  pass "Local management service uses the restricted account."
else
  fail "Unexpected management service user: ${management_user:-unknown}"
fi

if [[ "$management_group" == "offgridpi" ]]; then
  pass "Local management service uses the restricted group."
else
  fail "Unexpected management service group: ${management_group:-unknown}"
fi

management_listener="$(
  ss -ltnH 'sport = :8083' \
    2>/dev/null || true
)"

if grep -qE \
  '(^|[[:space:]])127\.0\.0\.1:8083([[:space:]]|$)' \
  <<< "$management_listener"
then
  pass "Local management viewer listens on 127.0.0.1:8083."
else
  fail "Local management viewer is not listening on localhost."
fi

if grep -Eq \
  '(^|[[:space:]])(0\.0\.0\.0|\*|\[::\]):8083([[:space:]]|$)' \
  <<< "$management_listener"
then
  fail "Local management viewer is exposed beyond localhost."
else
  pass "Local management viewer has no public listener."
fi

management_temp="$(
  mktemp -d
)"

management_headers="$management_temp/headers.txt"
management_body="$management_temp/body.html"

if curl \
  --silent \
  --show-error \
  --dump-header "$management_headers" \
  --output "$management_body" \
  http://127.0.0.1:8083/
then
  if grep -qE \
    '^HTTP/[^ ]+ 200([[:space:]]|$)' \
    "$management_headers"
  then
    pass "Local management page returns HTTP 200."
  else
    fail "Local management page did not return HTTP 200."
  fi

  if grep -qF \
    'Protected System Logs' \
    "$management_body"
  then
    pass "Local management page content is valid."
  else
    fail "Local management page returned unexpected content."
  fi

  if grep -qi \
    '^Cache-Control: no-store' \
    "$management_headers"
  then
    pass "Local management responses disable browser caching."
  else
    fail "Local management no-store protection is missing."
  fi

  if grep -qi \
    '^X-Frame-Options: DENY' \
    "$management_headers"
  then
    pass "Local management frame protection is enabled."
  else
    fail "Local management frame protection is missing."
  fi

  if grep -qi \
    '^Content-Security-Policy:' \
    "$management_headers"
  then
    pass "Local management Content Security Policy is present."
  else
    fail "Local management Content Security Policy is missing."
  fi
else
  fail "Unable to retrieve the local management page."
fi

management_unknown_code="$(
  curl \
    --silent \
    --output /dev/null \
    --write-out '%{http_code}' \
    http://127.0.0.1:8083/unknown \
    2>/dev/null || true
)"

if [[ "$management_unknown_code" == "404" ]]; then
  pass "Unknown management routes return HTTP 404."
else
  fail "Unexpected unknown-route response: HTTP ${management_unknown_code:-000}"
fi

management_raw_code="$(
  curl \
    --silent \
    --output /dev/null \
    --write-out '%{http_code}' \
    http://127.0.0.1:8083/system-logs.json \
    2>/dev/null || true
)"

if [[ "$management_raw_code" == "404" ]]; then
  pass "Raw protected-log JSON is not exposed."
else
  fail "Unexpected raw-log response: HTTP ${management_raw_code:-000}"
fi

management_post_code="$(
  curl \
    --silent \
    --request POST \
    --output /dev/null \
    --write-out '%{http_code}' \
    http://127.0.0.1:8083/ \
    2>/dev/null || true
)"

if [[ "$management_post_code" == "405" ]]; then
  pass "Local management viewer rejects write methods."
else
  fail "Unexpected POST response: HTTP ${management_post_code:-000}"
fi

rm -rf "$management_temp"

printf '\n=== Owner Mode foundation ===\n'

for path in \
  /opt/offgridpi/scripts/offgridpi-owner-server.py \
  /opt/offgridpi/scripts/offgridpi_owner_credentials.py \
  /opt/offgridpi/scripts/offgridpi_owner_auth.py \
  /etc/systemd/system/offgridpi-owner.service \
  /var/lib/offgridpi/owner
do
  if "${privileged[@]}" test -e "$path"; then
    pass "Owner Mode component exists: $path"
  else
    fail "Owner Mode component is missing: $path"
  fi
done

waypoint_mode="$(
  stat -c '%a' /srv/offgridpi/content/maps/user-data 2>/dev/null || true
)"

waypoint_group="$(
  stat -c '%G' /srv/offgridpi/content/maps/user-data 2>/dev/null || true
)"

if [[ "$waypoint_mode" == "2770" && "$waypoint_group" == "offgridpi" ]]; then
  pass "Private waypoint directory permissions are correct."
else
  fail "Unexpected private waypoint directory permissions: mode=${waypoint_mode:-unknown} group=${waypoint_group:-unknown}"
fi

if systemctl is-enabled --quiet \
  offgridpi-owner.service
then
  pass "Owner Mode service is enabled."
else
  fail "Owner Mode service is not enabled."
fi

if systemctl is-active --quiet \
  offgridpi-owner.service
then
  pass "Owner Mode service is active."
else
  fail "Owner Mode service is not active."
fi

owner_user="$(
  systemctl show \
    offgridpi-owner.service \
    --property=User \
    --value \
    2>/dev/null || true
)"

owner_group="$(
  systemctl show \
    offgridpi-owner.service \
    --property=Group \
    --value \
    2>/dev/null || true
)"

if [[ "$owner_user" == "offgridpi" ]]; then
  pass "Owner Mode service uses the restricted account."
else
  fail "Unexpected Owner Mode service user: ${owner_user:-unknown}"
fi

if [[ "$owner_group" == "offgridpi" ]]; then
  pass "Owner Mode service uses the restricted group."
else
  fail "Unexpected Owner Mode service group: ${owner_group:-unknown}"
fi

owner_listener="$(
  ss -ltnH 'sport = :8085' \
    2>/dev/null || true
)"

if grep -qE \
  '(^|[[:space:]])127\.0\.0\.1:8085([[:space:]]|$)' \
  <<< "$owner_listener"
then
  pass "Owner Mode bootstrap listens on 127.0.0.1:8085."
else
  fail "Owner Mode bootstrap is not listening on localhost."
fi

if grep -Eq \
  '(^|[[:space:]])(0\.0\.0\.0|\*|\[::\]):8085([[:space:]]|$)' \
  <<< "$owner_listener"
then
  fail "Owner Mode bootstrap is exposed beyond localhost."
else
  pass "Owner Mode bootstrap has no public listener."
fi

owner_temp="$(
  mktemp -d
)"

owner_headers="$owner_temp/headers.txt"
owner_body="$owner_temp/body.html"

if curl \
  --silent \
  --show-error \
  --dump-header "$owner_headers" \
  --output "$owner_body" \
  http://127.0.0.1:8085/
then
  if grep -qE \
    '^HTTP/[^ ]+ 200([[:space:]]|$)' \
    "$owner_headers"
  then
    pass "Owner Mode bootstrap returns HTTP 200."
  else
    fail "Owner Mode bootstrap did not return HTTP 200."
  fi

  if grep -qF \
    'Offgrid Pi Owner Mode' \
    "$owner_body"
  then
    pass "Owner Mode bootstrap page content is valid."
  else
    fail "Owner Mode bootstrap returned unexpected content."
  fi

  if grep -qi \
    '^Cache-Control: no-store' \
    "$owner_headers"
  then
    pass "Owner Mode responses disable browser caching."
  else
    fail "Owner Mode no-store protection is missing."
  fi

  if grep -qi \
    '^X-Frame-Options: DENY' \
    "$owner_headers"
  then
    pass "Owner Mode frame protection is enabled."
  else
    fail "Owner Mode frame protection is missing."
  fi

  if grep -qi \
    '^Content-Security-Policy:' \
    "$owner_headers"
  then
    pass "Owner Mode Content Security Policy is present."
  else
    fail "Owner Mode Content Security Policy is missing."
  fi
else
  fail "Unable to retrieve the Owner Mode bootstrap page."
fi

owner_unknown_code="$(
  curl \
    --silent \
    --output /dev/null \
    --write-out '%{http_code}' \
    http://127.0.0.1:8085/unknown \
    2>/dev/null || true
)"

if [[ "$owner_unknown_code" == "404" ]]; then
  pass "Unknown Owner Mode routes return HTTP 404."
else
  fail "Unexpected Owner Mode unknown-route response: HTTP ${owner_unknown_code:-000}"
fi

owner_post_code="$(
  curl \
    --silent \
    --request POST \
    --output /dev/null \
    --write-out '%{http_code}' \
    http://127.0.0.1:8085/ \
    2>/dev/null || true
)"

if [[ "$owner_post_code" == "405" ]]; then
  pass "Owner Mode bootstrap rejects write methods."
else
  fail "Unexpected Owner Mode POST response: HTTP ${owner_post_code:-000}"
fi

rm -rf "$owner_temp"

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
