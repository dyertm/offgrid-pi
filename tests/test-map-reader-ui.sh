#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
READER_ROOT="$ROOT/maps"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

[[ -f "$READER_ROOT/index.html" ]] ||
  fail "Offline Maps reader index is missing."

[[ -f "$READER_ROOT/css/styles.css" ]] ||
  fail "Offline Maps reader stylesheet is missing."

[[ -f "$READER_ROOT/js/app.js" ]] ||
  fail "Offline Maps reader JavaScript is missing."

python3 - "$READER_ROOT" <<'PY'
from html.parser import HTMLParser
from pathlib import Path
import sys

root = Path(sys.argv[1])
html_path = root / "index.html"


class ReaderParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.stylesheets = []
        self.scripts = []
        self.ids = set()

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)

        if "id" in attributes:
            self.ids.add(attributes["id"])

        if (
            tag == "link"
            and attributes.get("rel") == "stylesheet"
        ):
            self.stylesheets.append(
                attributes.get("href")
            )

        if (
            tag == "script"
            and attributes.get("src")
        ):
            self.scripts.append(
                attributes["src"]
            )


parser = ReaderParser()
parser.feed(
    html_path.read_text(encoding="utf-8")
)

required_ids = {
    "pack-status",
    "pack-count",
    "catalog-message",
    "pack-list",
    "map-workspace",
    "map-canvas",
    "render-message",
    "details-panel",
    "selected-map-heading",
    "selected-status",
    "selected-description",
    "selected-region",
    "selected-version",
    "selected-data-date",
    "selected-zoom",
    "limitations-section",
    "selected-limitations",
    "dashboard-link",
    "reader-host",
}

missing = sorted(
    required_ids - parser.ids
)

if missing:
    raise SystemExit(
        "Missing reader element IDs: "
        + ", ".join(missing)
    )

for asset in (
    parser.stylesheets
    + parser.scripts
):
    if not asset:
        raise SystemExit(
            "Reader contains an empty asset reference."
        )

    if "://" in asset or asset.startswith("//"):
        raise SystemExit(
            f"Remote reader asset is not permitted: {asset}"
        )

    path = root / asset

    if not path.is_file():
        raise SystemExit(
            f"Missing reader asset: {path}"
        )

if parser.stylesheets != [
    "vendor/maplibre-gl-js/maplibre-gl.css",
    "css/styles.css",
]:
    raise SystemExit(
        "Reader stylesheet references are unexpected."
    )

if parser.scripts != [
    "vendor/maplibre-gl-js/maplibre-gl.js",
    "vendor/pmtiles-js/pmtiles.js",
    "js/app.js",
]:
    raise SystemExit(
        "Reader script references are unexpected."
    )
PY

pass "Offline Maps reader structure and local assets are valid."

grep -q 'fetch(' "$READER_ROOT/js/app.js" ||
  fail "Reader does not request map-pack discovery."

grep -q '"/api/packs"' "$READER_ROOT/js/app.js" ||
  fail "Reader does not use the local map-pack discovery API."

grep -q '^\.map-canvas {' "$READER_ROOT/css/styles.css" ||
  fail "Reader stylesheet lacks the map canvas."

grep -q '^\.render-message {' "$READER_ROOT/css/styles.css" ||
  fail "Reader stylesheet lacks the render-status overlay."

grep -q 'new pmtiles.Protocol' "$READER_ROOT/js/app.js" ||
  fail "Reader does not initialize the PMTiles protocol."

grep -q 'maplibregl.addProtocol' "$READER_ROOT/js/app.js" ||
  fail "Reader does not register the PMTiles protocol with MapLibre."

grep -q 'getElementById("map-canvas")' "$READER_ROOT/js/app.js" ||
  fail "Reader does not bind the MapLibre canvas."

if grep -q 'elements.mapWorkspace.hidden = true' "$READER_ROOT/js/app.js"; then
  fail "Selecting a map hides the renderer workspace."
fi

grep -q 'typeof pack.tile_schema_id === "string"' "$READER_ROOT/js/app.js" ||
  fail "Reader does not validate the tile schema identifier."

grep -q 'new pmtiles.PMTiles' "$READER_ROOT/js/app.js" ||
  fail "Reader does not create a PMTiles archive instance."

grep -q 'state.protocol.add' "$READER_ROOT/js/app.js" ||
  fail "Reader does not register selected PMTiles archives."

grep -q 'new maplibregl.Map' "$READER_ROOT/js/app.js" ||
  fail "Reader does not create a MapLibre map instance."

grep -q 'pmtiles://' "$READER_ROOT/js/app.js" ||
  fail "Reader does not connect MapLibre to the local PMTiles vector source."

for source_layer in earth water landcover landuse roads buildings boundaries; do
  grep -q "\"source-layer\": \"${source_layer}\"" "$READER_ROOT/js/app.js" ||
    fail "Reader style is missing Protomaps source layer: ${source_layer}"
done

grep -q 'bounds: pack.region.bounds' "$READER_ROOT/js/app.js" ||
  fail "Reader does not frame the selected map to its declared bounds."

grep -q 'state.map.on("load"' "$READER_ROOT/js/app.js" ||
  fail "Reader does not react to successful map loading."

grep -q 'elements.renderMessage.hidden = true' "$READER_ROOT/js/app.js" ||
  fail "Reader does not clear the loading message after rendering."

if grep -En \
  'https?://|src="//|href="//' \
  "$READER_ROOT/index.html" \
  "$READER_ROOT/css/styles.css" \
  "$READER_ROOT/js/app.js" \
  >/dev/null
then
  fail "Offline Maps reader contains a remote runtime dependency."
fi

pass "Offline Maps reader uses local-only discovery and assets."
pass "Map-reader UI tests completed."
