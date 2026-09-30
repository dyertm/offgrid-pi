#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INDEXER="$ROOT/scripts/index-search.py"
TEMP_ROOT="$(mktemp -d)"
PUBLIC_ROOT="$TEMP_ROOT/public"
SEARCH_DB="$TEMP_ROOT/search.sqlite3"

cleanup() {
  rm -rf -- "$TEMP_ROOT"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

mkdir -p "$PUBLIC_ROOT/emergency"

cat > "$PUBLIC_ROOT/emergency/water.txt" <<'TEXT'
During a boil water advisory, bring water to a rolling boil before use.
TEXT

OFFGRIDPI_SEARCH_ROOT="$PUBLIC_ROOT" \
OFFGRIDPI_SEARCH_DB="$SEARCH_DB" \
"$INDEXER"

python3 - "$SEARCH_DB" <<'PY'
import sqlite3
import sys

database = sqlite3.connect(sys.argv[1])

row = database.execute(
    """
    SELECT path
    FROM search_fts
    WHERE search_fts MATCH ?
    """,
    ('"boil water"',),
).fetchone()

if row != ("emergency/water.txt",):
    raise SystemExit(f"Unexpected search result: {row!r}")
PY

pass "Plain-text document body is searchable through SQLite FTS5."
