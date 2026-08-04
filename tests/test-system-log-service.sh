#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE="$ROOT/systemd/offgridpi-log-publisher.service"
TIMER="$ROOT/systemd/offgridpi-log-publisher.timer"
PUBLISHER="$ROOT/scripts/publish-system-logs.py"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

for path in "$SERVICE" "$TIMER" "$PUBLISHER"; do
  [[ -s "$path" ]] ||
    fail "Required component is missing: $path"
done

[[ -x "$PUBLISHER" ]] ||
  fail "Log publisher is not executable."

pass "Protected log-publisher components exist."

for directive in \
  'Type=oneshot' \
  'User=root' \
  'Group=offgridpi' \
  'ExecStart=/opt/offgridpi/scripts/publish-system-logs.py' \
  'StateDirectory=offgridpi' \
  'StateDirectoryMode=0750' \
  'UMask=0027' \
  'NoNewPrivileges=yes' \
  'PrivateTmp=yes' \
  'ProtectSystem=strict' \
  'ProtectHome=yes' \
  'MemoryDenyWriteExecute=yes' \
  'RestrictAddressFamilies=AF_UNIX'
do
  grep -qF "$directive" "$SERVICE" ||
    fail "Service directive is missing: $directive"
done

for directive in \
  'OnBootSec=90s' \
  'OnUnitActiveSec=5min' \
  'Persistent=true' \
  'Unit=offgridpi-log-publisher.service' \
  'WantedBy=timers.target'
do
  grep -qF "$directive" "$TIMER" ||
    fail "Timer directive is missing: $directive"
done

pass "Log-publisher unit structure is valid."

if grep -Eq \
  '/opt/offgridpi/dashboard|dashboard/data|system-logs\.json' \
  "$SERVICE" "$TIMER"
then
  fail "Systemd units reference the dashboard web root."
fi

grep -qF \
  '/var/lib/offgridpi/management/system-logs.json' \
  "$PUBLISHER" ||
  fail "Protected default log location is missing."

if grep -qF \
  '/opt/offgridpi/dashboard/data/system-logs.json' \
  "$PUBLISHER"
then
  fail "Publisher references the public dashboard path."
fi

pass "Log publisher remains outside the dashboard web root."
pass "Protected log-publisher service tests completed."

grep -qF \
  '"$PROJECT_ROOT/scripts/publish-system-logs.py"' \
  "$ROOT/install.sh" ||
  fail "Installer payload does not include the log publisher."

grep -qF \
  'offgridpi-log-publisher.timer' \
  "$ROOT/install.sh" ||
  fail "Installer does not deploy the log-publisher timer."

grep -qF \
  '/var/lib/offgridpi/management' \
  "$ROOT/install.sh" ||
  fail "Installer does not create protected log storage."

pass "Installer includes protected log-publisher safeguards."
