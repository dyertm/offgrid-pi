#!/bin/bash

set -u

DASHBOARD_URL="http://127.0.0.1:8081/"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/offgridpi"
LOG_FILE="${LOG_DIR}/dashboard-launch.log"

mkdir -p "$LOG_DIR"

exec >>"$LOG_FILE" 2>&1

echo
echo "Dashboard launch started: $(date --iso-8601=seconds)"

# Do not open a second dashboard window if one already exists.
if pgrep -f "chromium.*127.0.0.1:8081" >/dev/null; then
    echo "Dashboard Chromium window already appears to be running."
    exit 0
fi

# Wait up to 30 seconds for the dashboard service.
for attempt in $(seq 1 30); do
    if /usr/bin/curl \
        --silent \
        --fail \
        --output /dev/null \
        "$DASHBOARD_URL"
    then
        echo "Dashboard service is available."
        exec /usr/bin/chromium \
            --new-window \
            --start-maximized \
            --no-first-run \
            --no-default-browser-check \
            --disable-session-crashed-bubble \
            --password-store=basic \
            "$DASHBOARD_URL"
    fi

    sleep 1
done

echo "Dashboard service did not become available."
exit 1
