#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATUS_HTML="$ROOT/dashboard/status/index.html"
SHARED_CSS="$ROOT/dashboard/css/styles.css"
INDEXER="$ROOT/scripts/index-documents.py"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

grep -qF 'class="dashboard-return" href="../"' \
  "$STATUS_HTML" ||
  fail "System Status lacks its header Dashboard link."

grep -qF '.dashboard-return {' "$SHARED_CSS" ||
  fail "Shared Dashboard-link styling is missing."

status_footer="$(
  sed -n \
    '/<footer class="site-footer">/,/<\/footer>/p' \
    "$STATUS_HTML"
)"

if grep -qi 'dashboard' <<< "$status_footer"; then
  fail "System Status still contains a footer Dashboard link."
fi

grep -qF \
  'class="dashboard-return" id="dashboard"' \
  "$INDEXER" ||
  fail "Local Documents lacks the standardized link class."

grep -qF '← Dashboard' "$INDEXER" ||
  fail "Local Documents Dashboard label is inconsistent."

grep -qF '.dashboard-return{{display:inline-flex' \
  "$INDEXER" ||
  fail "Local Documents navigation styling is missing."

pass "Secondary-page Dashboard navigation is consistent."
