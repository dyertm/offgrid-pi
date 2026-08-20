#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$ROOT/compliance/validate-software-components.py"
REGISTER="$ROOT/compliance/software-components.json"
LICENSE_FILE="$ROOT/LICENSE"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEMP_ROOT"' EXIT

python3 -m json.tool \
  "$ROOT/compliance/schema/software-components.schema.json" \
  >/dev/null

python3 -m json.tool \
  "$REGISTER" \
  >/dev/null

pass "Compliance JSON files are syntactically valid."

"$VALIDATOR" "$REGISTER" "$LICENSE_FILE"

python3 - "$REGISTER" <<'PYTEST'
import json
import sys
from pathlib import Path

register = json.loads(
    Path(sys.argv[1]).read_text(encoding="utf-8")
)

packages = register.get("packages")

if not isinstance(packages, list) or len(packages) != 7:
    raise SystemExit(
        "Register must preserve the seven approved Debian packages."
    )

vendored = register.get("vendored_components")

if not isinstance(vendored, list):
    raise SystemExit(
        "Register is missing vendored_components."
    )

expected_ids = {
    "maplibre-gl-js",
    "pmtiles-js",
    "fflate",
}

actual_ids = {
    component.get("component_id")
    for component in vendored
    if isinstance(component, dict)
}

if actual_ids != expected_ids:
    raise SystemExit(
        "Vendored component IDs are incorrect."
    )
PYTEST

pass "Register separates Debian packages from approved vendored components."

create_fixture() {
  local mutation="$1"
  local output="$2"

  python3 - \
    "$REGISTER" \
    "$output" \
    "$mutation" <<'PY'
import copy
import json
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])
mutation = sys.argv[3]

data = json.loads(source.read_text(encoding="utf-8"))

if mutation == "duplicate":
    data["packages"].append(
        copy.deepcopy(data["packages"][0])
    )
elif mutation == "unapproved":
    package = data["packages"][0]
    package["component_id"] = "wget"
    package["package_name"] = "wget"
    package["copyright_file"] = (
        "/usr/share/doc/wget/copyright"
    )
elif mutation == "copyright":
    data["packages"][0]["copyright_file"] = (
        "/tmp/unsafe-copyright"
    )
elif mutation == "license":
    data["project"]["license_expression"] = "Apache-2.0"
elif mutation == "vendored-unapproved":
    component = data["vendored_components"][0]
    component["component_id"] = "unknown-map-library"
elif mutation == "vendored-version":
    data["vendored_components"][0]["version"] = "99.0.0"
elif mutation == "vendored-license-path":
    data["vendored_components"][0]["license_file"] = (
        "../unsafe-license.txt"
    )
elif mutation == "vendored-asset-path":
    data["vendored_components"][0]["asset_paths"][0] = (
        "../unsafe-maplibre.js"
    )
else:
    raise SystemExit(f"Unknown mutation: {mutation}")

target.write_text(
    json.dumps(data, indent=2) + "\n",
    encoding="utf-8",
)
PY
}

expect_failure() {
  local fixture="$1"
  local description="$2"

  if "$VALIDATOR" \
      "$fixture" \
      "$LICENSE_FILE" \
      >/dev/null 2>&1
  then
    fail "$description was incorrectly accepted."
  fi

  pass "$description was rejected."
}

for mutation in \
  duplicate \
  unapproved \
  copyright \
  license \
  vendored-unapproved \
  vendored-version \
  vendored-license-path \
  vendored-asset-path
do
  fixture="$TEMP_ROOT/${mutation}.json"
  create_fixture "$mutation" "$fixture"

  case "$mutation" in
    duplicate)
      description="Duplicate package"
      ;;
    unapproved)
      description="Unapproved package"
      ;;
    copyright)
      description="Unsafe copyright path"
      ;;
    license)
      description="Mismatched project license"
      ;;
    vendored-unapproved)
      description="Unapproved vendored component"
      ;;
    vendored-version)
      description="Unapproved vendored version"
      ;;
    vendored-license-path)
      description="Unsafe vendored license path"
      ;;
    vendored-asset-path)
      description="Unsafe vendored asset path"
      ;;
  esac

  expect_failure "$fixture" "$description"
done

pass "Software-component register tests completed."
