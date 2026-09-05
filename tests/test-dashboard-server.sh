#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER="$ROOT/scripts/offgridpi-dashboard-server.py"

TEMP_DIR="$(mktemp -d)"
DASHBOARD_ROOT="$TEMP_DIR/dashboard"
OUTPUT="$TEMP_DIR/server.log"
PORT=18081
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
  fail "Dashboard server is missing or not executable."

python3 -m py_compile "$SERVER"
pass "Dashboard-server syntax is valid."

mkdir -p "$DASHBOARD_ROOT/css"

cat > "$DASHBOARD_ROOT/index.html" <<'HTML'
<!doctype html>
<html>
<head>
  <title>Offgrid Pi Dashboard</title>
  <link rel="stylesheet" href="/css/styles.css">
</head>
<body>
  <h1>Offgrid Pi</h1>
</body>
</html>
HTML

cat > "$DASHBOARD_ROOT/css/styles.css" <<'CSS'
body {
  background: #000;
}
CSS

OFFGRIDPI_DASHBOARD_BIND="127.0.0.1" \
OFFGRIDPI_DASHBOARD_PORT="$PORT" \
OFFGRIDPI_DASHBOARD_ROOT="$DASHBOARD_ROOT" \
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
  fail "Dashboard server failed to start."

root_status="$(
  curl \
    --silent \
    --show-error \
    --dump-header "$TEMP_DIR/root.headers" \
    --output "$TEMP_DIR/root.html" \
    --write-out '%{http_code}' \
    "http://127.0.0.1:$PORT/"
)"

[[ "$root_status" == "200" ]] ||
  fail "Dashboard root did not return HTTP 200."

grep -q 'Offgrid Pi' "$TEMP_DIR/root.html" ||
  fail "Dashboard root content is missing."

pass "Dashboard application root is served."

grep -qi '^Cache-Control: no-cache' "$TEMP_DIR/root.headers" ||
  fail "Dashboard root is missing Cache-Control: no-cache."

grep -qi '^X-Content-Type-Options: nosniff' "$TEMP_DIR/root.headers" ||
  fail "Dashboard root is missing X-Content-Type-Options."

grep -qi '^Referrer-Policy: no-referrer' "$TEMP_DIR/root.headers" ||
  fail "Dashboard root is missing Referrer-Policy."

pass "Dashboard response headers disable stale caching and add basic protections."

css_status="$(
  curl \
    --silent \
    --show-error \
    --dump-header "$TEMP_DIR/css.headers" \
    --output "$TEMP_DIR/styles.css" \
    --write-out '%{http_code}' \
    "http://127.0.0.1:$PORT/css/styles.css"
)"

[[ "$css_status" == "200" ]] ||
  fail "Dashboard stylesheet did not return HTTP 200."

grep -qi '^Cache-Control: no-cache' "$TEMP_DIR/css.headers" ||
  fail "Dashboard stylesheet is missing Cache-Control: no-cache."

grep -q 'background: #000' "$TEMP_DIR/styles.css" ||
  fail "Dashboard stylesheet content is missing."

pass "Dashboard static assets are served with revalidation."

head_status="$(
  curl \
    --silent \
    --show-error \
    --head \
    --output "$TEMP_DIR/head.headers" \
    --write-out '%{http_code}' \
    "http://127.0.0.1:$PORT/"
)"

[[ "$head_status" == "200" ]] ||
  fail "Dashboard HEAD request did not return HTTP 200."

grep -qi '^Cache-Control: no-cache' "$TEMP_DIR/head.headers" ||
  fail "Dashboard HEAD response is missing Cache-Control: no-cache."

pass "Dashboard HEAD responses use the same cache policy."

printf 'PASS: Dashboard server regression test completed.\n'
