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

grep -q '^\.map-controls {' "$READER_ROOT/css/styles.css" ||
  fail "Reader stylesheet lacks map navigation controls."

grep -q '^\.map-control-button {' "$READER_ROOT/css/styles.css" ||
  fail "Reader stylesheet lacks touch-friendly map buttons."

grep -q '^\.map-help-panel {' "$READER_ROOT/css/styles.css" ||
  fail "Reader stylesheet lacks the navigation help panel."

grep -q 'new pmtiles.Protocol' "$READER_ROOT/js/app.js" ||
  fail "Reader does not initialize the PMTiles protocol."

grep -q 'maplibregl.addProtocol' "$READER_ROOT/js/app.js" ||
  fail "Reader does not register the PMTiles protocol with MapLibre."

for control_id in map-zoom-in map-zoom-out map-reset-view map-help; do
  grep -q "id=\"${control_id}\"" "$READER_ROOT/index.html" ||
    fail "Reader is missing navigation control: ${control_id}"
done

for binding_id in map-zoom-in map-zoom-out map-reset-view map-help; do
  grep -q "getElementById(\"${binding_id}\")" "$READER_ROOT/js/app.js" ||
    fail "Reader does not bind navigation control: ${binding_id}"
done

grep -q 'state.map.zoomIn' "$READER_ROOT/js/app.js" ||
  fail "Zoom-in control is not wired to MapLibre."

grep -q 'state.map.zoomOut' "$READER_ROOT/js/app.js" ||
  fail "Zoom-out control is not wired to MapLibre."

grep -q 'state.map.fitBounds' "$READER_ROOT/js/app.js" ||
  fail "Reset-view control does not restore the selected map bounds."

grep -q 'id="map-help-panel"' "$READER_ROOT/index.html" ||
  fail "Reader is missing the map navigation help panel."

grep -q 'addEventListener("keydown"' "$READER_ROOT/js/app.js" ||
  fail "Reader does not provide keyboard map navigation."

grep -q 'ArrowUp' "$READER_ROOT/js/app.js" ||
  fail "Reader keyboard navigation does not support arrow keys."

grep -q 'state.map.panBy(\[0, -panDistance\])' "$READER_ROOT/js/app.js" ||
  fail "Arrow Up does not pan the map upward."

grep -q 'state.map.panBy(\[0, panDistance\])' "$READER_ROOT/js/app.js" ||
  fail "Arrow Down does not pan the map downward."

grep -q 'state.map.panBy(\[-panDistance, 0\])' "$READER_ROOT/js/app.js" ||
  fail "Arrow Left does not pan the map left."

grep -q 'state.map.panBy(\[panDistance, 0\])' "$READER_ROOT/js/app.js" ||
  fail "Arrow Right does not pan the map right."

grep -q 'event.key === "Home"' "$READER_ROOT/js/app.js" ||
  fail "Reader keyboard navigation does not support Home reset."

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

grep -q '"source-layer": "water"' "$READER_ROOT/js/app.js" ||
  fail "Reader style does not include the Protomaps water layer."

grep -q '\["==", \["geometry-type"\], "Polygon"\]' "$READER_ROOT/js/app.js" ||
  fail "Reader water styling is not restricted to polygon geometry."

grep -q '"source-layer": "places"' "$READER_ROOT/js/app.js" ||
  fail "Reader style does not include offline place labels."

grep -q '"source-layer": "roads"' "$READER_ROOT/js/app.js" ||
  fail "Reader style does not include offline road labels."

grep -q '"text-font": \["sans-serif"\]' "$READER_ROOT/js/app.js" ||
  fail "Reader labels do not use the local generic font stack."

if grep -q 'glyphs:' "$READER_ROOT/js/app.js"; then
  fail "Reader style unexpectedly declares an external glyph source."
fi

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
