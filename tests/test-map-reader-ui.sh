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

for control_id in map-zoom-in map-zoom-out map-reset-view map-measure map-help map-layers map-fullscreen; do
  grep -q "id=\"${control_id}\"" "$READER_ROOT/index.html" ||
    fail "Reader is missing navigation control: ${control_id}"
done

for binding_id in map-zoom-in map-zoom-out map-reset-view map-measure map-help map-layers map-fullscreen; do
  grep -q "getElementById(\"${binding_id}\")" "$READER_ROOT/js/app.js" ||
    fail "Reader does not bind navigation control: ${binding_id}"
done

grep -q 'id="map-layers-panel"' "$READER_ROOT/index.html" ||
  fail "Reader is missing the map-layer controls panel."

grep -q '^\.map-layers-panel {' "$READER_ROOT/css/styles.css" ||
  fail "Reader stylesheet lacks dedicated layer-panel sizing."

grep -q 'overflow-y: auto' "$READER_ROOT/css/styles.css" ||
  fail "Reader layer panel cannot scroll when map height is limited."

for layer_group in emergency medical supplies public-services transportation landmarks water; do
  grep -q "data-layer-group=\"${layer_group}\"" "$READER_ROOT/index.html" ||
    fail "Reader is missing layer toggle group: ${layer_group}"
done

grep -q 'setLayoutProperty' "$READER_ROOT/js/app.js" ||
  fail "Reader does not change MapLibre layer visibility from layer controls."

grep -q 'id="map-coordinates"' "$READER_ROOT/index.html" ||
  fail "Reader is missing the map-center coordinate readout."

grep -q 'id="map-center-crosshair"' "$READER_ROOT/index.html" ||
  fail "Reader is missing the visual map-center crosshair."

grep -q 'Center:' "$READER_ROOT/js/app.js" ||
  fail "Reader does not clearly label center coordinates."

grep -q 'toFixed(4)' "$READER_ROOT/js/app.js" ||
  fail "Reader coordinate display is not limited to four decimal places."

grep -A12 '^\.map-coordinates {' "$READER_ROOT/css/styles.css" |
  grep -q 'top: 12px' ||
  fail "Reader map-center coordinates are not positioned at the top."

grep -q '@media (max-width: 1100px)' "$READER_ROOT/css/styles.css" ||
  fail "Reader lacks a compact-screen map layout."

grep -A18 '@media (max-width: 1100px)' "$READER_ROOT/css/styles.css" |
  grep -q 'bottom: 12px' ||
  fail "Reader does not move coordinates to the lower-left on compact screens."

grep -A18 '@media (max-width: 1100px)' "$READER_ROOT/css/styles.css" |
  grep -q '\.maplibregl-ctrl-bottom-left' ||
  fail "Reader does not reposition the map scale on compact screens."

grep -A18 '@media (max-width: 1100px)' "$READER_ROOT/css/styles.css" |
  grep -q 'top: 12px' ||
  fail "Reader does not move the map scale to the upper-left on compact screens."

grep -q 'getCenter()' "$READER_ROOT/js/app.js" ||
  fail "Reader does not obtain the current MapLibre map center."

grep -q '"move"' "$READER_ROOT/js/app.js" ||
  fail "Reader does not update coordinates as the map moves."

grep -q 'measurementStart' "$READER_ROOT/js/app.js" ||
  fail "Reader does not track a map-center measurement start point."

grep -A12 '^function selectPack(pack)' "$READER_ROOT/js/app.js" |
  grep -q 'state.measurementStart = null' ||
  fail "Reader does not clear active measurements when switching map packs."

grep -q 'calculateDistance' "$READER_ROOT/js/app.js" ||
  fail "Reader does not calculate offline point-to-point distance."

grep -q 'calculateBearing' "$READER_ROOT/js/app.js" ||
  fail "Reader does not calculate offline point-to-point bearing."

grep -q 'Measure from center' "$READER_ROOT/index.html" ||
  fail "Reader navigation help does not explain center-based measurement."

grep -q 'requestFullscreen' "$READER_ROOT/js/app.js" ||
  fail "Reader does not support entering fullscreen mode."

grep -q 'exitFullscreen' "$READER_ROOT/js/app.js" ||
  fail "Reader does not support leaving fullscreen mode."

grep -q 'state.map.resize' "$READER_ROOT/js/app.js" ||
  fail "Reader does not resize MapLibre after fullscreen changes."

grep -q 'new maplibregl.ScaleControl' "$READER_ROOT/js/app.js" ||
  fail "Reader does not provide an on-map distance scale."

grep -q 'state.map.dragRotate.disable' "$READER_ROOT/js/app.js" ||
  fail "Reader does not disable mouse/touchpad map rotation."

grep -q 'state.map.touchZoomRotate.disableRotation' "$READER_ROOT/js/app.js" ||
  fail "Reader does not disable touch rotation."

grep -q 'state.map.touchPitch.disable' "$READER_ROOT/js/app.js" ||
  fail "Reader does not disable accidental map pitching."

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

grep -q 'id="map-attribution"' "$READER_ROOT/index.html" ||
  fail "Reader is missing persistent map attribution."

grep -q '^\.map-attribution {' "$READER_ROOT/css/styles.css" ||
  fail "Reader stylesheet lacks persistent map attribution."

grep -q 'getElementById("map-attribution")' "$READER_ROOT/js/app.js" ||
  fail "Reader does not bind the map attribution element."

grep -q 'Array.isArray(pack.attributions)' "$READER_ROOT/js/app.js" ||
  fail "Reader does not validate map-pack attribution metadata."

grep -q 'typeof item.attribution === "string"' "$READER_ROOT/js/app.js" ||
  fail "Reader does not validate attribution text."

grep -q 'elements.mapAttribution.textContent' "$READER_ROOT/js/app.js" ||
  fail "Reader does not display attribution from the selected map pack."

grep -q 'new pmtiles.PMTiles' "$READER_ROOT/js/app.js" ||
  fail "Reader does not create a PMTiles archive instance."

grep -q 'state.protocol.add' "$READER_ROOT/js/app.js" ||
  fail "Reader does not register selected PMTiles archives."

grep -q 'new maplibregl.Map' "$READER_ROOT/js/app.js" ||
  fail "Reader does not create a MapLibre map instance."

grep -q 'pmtiles://' "$READER_ROOT/js/app.js" ||
  fail "Reader does not connect MapLibre to the local PMTiles vector source."

for source_layer in earth water landcover landuse roads buildings boundaries pois; do
  grep -q "\"source-layer\": \"${source_layer}\"" "$READER_ROOT/js/app.js" ||
    fail "Reader style is missing Protomaps source layer: ${source_layer}"
done

for poi_kind in hospital fire_station police clinic doctors pharmacy chemist supermarket fuel hardware doityourself townhall library community_centre post_office station bus_station ferry_terminal; do
  grep -q "\"${poi_kind}\"" "$READER_ROOT/js/app.js" ||
    fail "Reader POI styling is missing preparedness category: ${poi_kind}"
done

grep -q 'id: "water-point-labels"' "$READER_ROOT/js/app.js" ||
  fail "Reader does not label named bodies of water."

grep -q 'id: "water-line-labels"' "$READER_ROOT/js/app.js" ||
  fail "Reader does not label named rivers, canals, and streams."

for water_kind in water bay river canal stream; do
  grep -q "\"${water_kind}\"" "$READER_ROOT/js/app.js" ||
    fail "Reader water-label styling is missing category: ${water_kind}"
done

grep -q 'id: "major-landmark-labels"' "$READER_ROOT/js/app.js" ||
  fail "Reader does not provide major navigation landmark labels."

for landmark_kind in park nature_reserve forest aerodrome peak viewpoint attraction; do
  grep -q "\"${landmark_kind}\"" "$READER_ROOT/js/app.js" ||
    fail "Reader landmark styling is missing category: ${landmark_kind}"
done

grep -q '\["get", "min_zoom"\]' "$READER_ROOT/js/app.js" ||
  fail "Reader does not use source importance metadata to limit landmark clutter."

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
