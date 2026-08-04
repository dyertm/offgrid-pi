#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER="$ROOT/scripts/offgridpi-management-server.py"

TEMP_DIR="$(mktemp -d)"
SNAPSHOT="$TEMP_DIR/system-logs.json"
OUTPUT="$TEMP_DIR/server-output.log"
HEADERS="$TEMP_DIR/headers.txt"
BODY="$TEMP_DIR/body.html"
PORT=18083
PID=""

cleanup() {
  if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
    kill "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
  fi

  rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

[[ -x "$SERVER" ]] ||
  fail "Management server is missing or not executable."

python3 -m py_compile "$SERVER"
pass "Management-server syntax is valid."

cat > "$SNAPSHOT" <<'JSON'
{
  "schema_version": 1,
  "generated_at": "2026-08-03T19:00:00-07:00",
  "source_count": 1,
  "sources": [
    {
      "name": "Dashboard",
      "unit": "offgridpi-dashboard.service",
      "entry_count": 2,
      "entries": [
        {
          "timestamp": "2026-08-03T18:58:00-07:00",
          "priority": 6,
          "priority_name": "Info",
          "message": "Dashboard service started successfully."
        },
        {
          "timestamp": "2026-08-03T18:59:00-07:00",
          "priority": 4,
          "priority_name": "Warning",
          "message": "Synthetic test warning."
        }
      ]
    }
  ]
}
JSON

OFFGRIDPI_MANAGEMENT_BIND="127.0.0.1" \
OFFGRIDPI_MANAGEMENT_PORT="$PORT" \
OFFGRIDPI_MANAGEMENT_LOG_SNAPSHOT="$SNAPSHOT" \
  "$SERVER" >"$OUTPUT" 2>&1 &

PID=$!

for _ in $(seq 1 30); do
  if curl \
    --silent \
    --fail \
    --output /dev/null \
    "http://127.0.0.1:$PORT/"
  then
    break
  fi

  sleep 0.1
done

kill -0 "$PID" 2>/dev/null ||
  fail "Management server failed to start."

curl \
  --silent \
  --show-error \
  --dump-header "$HEADERS" \
  --output "$BODY" \
  "http://127.0.0.1:$PORT/"

grep -q '^HTTP/.* 200' "$HEADERS" ||
  fail "Root page did not return HTTP 200."

grep -qi '^Cache-Control: no-store' "$HEADERS" ||
  fail "No-store cache protection is missing."

grep -qi '^X-Frame-Options: DENY' "$HEADERS" ||
  fail "Frame protection is missing."

grep -qi '^Content-Security-Policy:' "$HEADERS" ||
  fail "Content Security Policy is missing."

grep -q 'Protected System Logs' "$BODY" ||
  fail "Management-page title is missing."

grep -q 'Dashboard service started successfully' "$BODY" ||
  fail "Expected sanitized test entry is missing."

grep -q 'LOCALHOST ONLY' "$BODY" ||
  fail "Localhost-only indicator is missing."

status="$(
  curl \
    --silent \
    --output /dev/null \
    --write-out '%{http_code}' \
    "http://127.0.0.1:$PORT/unknown"
)"

[[ "$status" == "404" ]] ||
  fail "Unknown routes do not return HTTP 404."

status="$(
  curl \
    --silent \
    --request POST \
    --output /dev/null \
    --write-out '%{http_code}' \
    "http://127.0.0.1:$PORT/"
)"

[[ "$status" == "405" ]] ||
  fail "POST requests do not return HTTP 405."

if OFFGRIDPI_MANAGEMENT_BIND="0.0.0.0" \
   OFFGRIDPI_MANAGEMENT_PORT="18084" \
   OFFGRIDPI_MANAGEMENT_LOG_SNAPSHOT="$SNAPSHOT" \
   "$SERVER" >"$TEMP_DIR/public-bind.log" 2>&1
then
  fail "Management server accepted a public bind address."
fi

grep -q 'may bind only to localhost' \
  "$TEMP_DIR/public-bind.log" ||
  fail "Public-bind rejection message is missing."

pass "Root page renders protected data server-side."
pass "Security headers are present."
pass "Unknown routes and unsupported methods are rejected."
pass "Public bind addresses are rejected."
pass "Management-server tests completed without live access."
