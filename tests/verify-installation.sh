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

echo
echo "=== Services ==="
for service in \
  kiwix-serve.service \
  offgridpi-dashboard.service \
  offgridpi-documents.service \
  offgridpi-document-indexer.service
do
  check_service "$service"
done

echo
echo "=== Network listeners ==="
for port in 8080 8081 8082; do
  check_port "$port"
done

echo
echo "=== Local HTTP ==="
check_http "Kiwix" "http://127.0.0.1:8080/"
check_http "Dashboard" "http://127.0.0.1:8081/"
check_http "Document library" "http://127.0.0.1:8082/"

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
