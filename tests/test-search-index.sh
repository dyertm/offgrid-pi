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

cat > "$PUBLIC_ROOT/emergency/power.md" <<'MARKDOWN'
# Extended Power Outage

Disconnect unnecessary loads to conserve battery capacity.
MARKDOWN

cat > "$PUBLIC_ROOT/emergency/heat.html" <<'HTML'
<!doctype html>
<html><body><h1>Extreme Heat</h1><p>Move to a cooler location and drink water regularly.</p></body></html>
HTML

python3 - "$PUBLIC_ROOT/emergency/first-aid.docx" <<'PYDOCX'
import sys
import zipfile

document_xml = """<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body><w:p><w:r><w:t>Apply direct pressure to control severe bleeding.</w:t></w:r></w:p></w:body>
</w:document>
"""

with zipfile.ZipFile(sys.argv[1], "w") as archive:
    archive.writestr("word/document.xml", document_xml)
PYDOCX

printf %s "not-a-zip" > "$PUBLIC_ROOT/emergency/broken.docx"

cp "$ROOT/tests/fixtures/search/water-storage.pdf" "$PUBLIC_ROOT/emergency/water-storage.pdf"

printf %s "not-a-pdf" > "$PUBLIC_ROOT/emergency/broken.pdf"

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

row = database.execute(
    "SELECT path FROM search_fts WHERE search_fts MATCH ?",
    ('"battery capacity"',),
).fetchone()

if row != ("emergency/power.md",):
    raise SystemExit(f"Unexpected Markdown search result: {row!r}")

row = database.execute(
    "SELECT path FROM search_fts WHERE search_fts MATCH ?",
    ('"cooler location"',),
).fetchone()

if row != ("emergency/heat.html",):
    raise SystemExit(f"Unexpected HTML search result: {row!r}")

row = database.execute(
    "SELECT path FROM search_fts WHERE search_fts MATCH ?",
    ('"severe bleeding"',),
).fetchone()

if row != ("emergency/first-aid.docx",):
    raise SystemExit(f"Unexpected DOCX search result: {row!r}")

row = database.execute(
    "SELECT path FROM search_fts WHERE search_fts MATCH ?",
    ('"sealed containers"',),
).fetchone()

if row != ("emergency/water-storage.pdf",):
    raise SystemExit(f"Unexpected PDF search result: {row!r}")

rows = database.execute("SELECT path FROM search_fts").fetchall()
if len(rows) != 5:
    raise SystemExit(f"Expected 5 valid documents, got {len(rows)}")
if ("emergency/broken.docx",) in rows:
    raise SystemExit("Corrupted DOCX was indexed")
if ("emergency/broken.pdf",) in rows:
    raise SystemExit("Corrupted PDF was indexed")

PY

pass "Plain-text, Markdown, HTML, DOCX, and PDF document bodies are searchable through SQLite FTS5."
