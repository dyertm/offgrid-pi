#!/usr/bin/env python3

import argparse
import json
import re
import sys
from datetime import date
from pathlib import Path
from urllib.parse import urlparse

IDENTIFIER = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
VERSION = re.compile(r"^[0-9]+[.][0-9]+[.][0-9]+$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")

TOP_FIELDS = {
    "schema_version", "pack_format", "pack_id", "name", "version",
    "status", "reader_compatibility", "description", "region",
    "data_date", "estimated_installed_bytes", "style_id",
    "tile_schema_id", "files", "sources", "limitations",
}

READER_FIELDS = {"minimum_version"}
REGION_FIELDS = {
    "name", "bounds", "default_center", "min_zoom", "max_zoom",
}
FILE_FIELDS = {
    "path", "role", "media_type", "size_bytes", "sha256", "required",
}
SOURCE_FIELDS = {
    "source_id", "name", "source_page", "source_version",
    "data_date", "license", "redistribution", "attribution", "notes",
}

ROLE_RULES = {
    "basemap": (
        "application/vnd.pmtiles",
        re.compile(r"^data/[A-Za-z0-9._-]+[.]pmtiles$"),
    ),
    "overlay": (
        "application/geo+json",
        re.compile(r"^overlays/[A-Za-z0-9._-]+[.]geojson$"),
    ),
    "license": (
        "text/plain",
        re.compile(r"^licenses/[A-Za-z0-9._-]+[.]txt$"),
    ),
    "readme": (
        "text/plain",
        re.compile(r"^README[.]txt$"),
    ),
}

APPROVED_STYLES = {"emergency-basic"}
APPROVED_TILE_SCHEMAS = {"protomaps-basemap-v4"}

def require(condition, message):
    if not condition:
        raise ValueError(message)

def require_exact_fields(value, expected, label):
    require(isinstance(value, dict), f"{label} must be an object.")
    actual = set(value)
    missing = sorted(expected - actual)
    extra = sorted(actual - expected)
    require(not missing, f"{label} is missing fields: {missing}")
    require(not extra, f"{label} has unsupported fields: {extra}")

def require_text(value, label):
    require(isinstance(value, str) and bool(value.strip()),
            f"{label} must be a non-empty string.")

def require_identifier(value, label):
    require_text(value, label)
    require(bool(IDENTIFIER.fullmatch(value)),
            f"{label} is not a valid identifier.")

def require_version(value, label):
    require_text(value, label)
    require(bool(VERSION.fullmatch(value)),
            f"{label} must use major.minor.patch format.")

def parse_date(value, label):
    require_text(value, label)
    try:
        return date.fromisoformat(value)
    except ValueError as error:
        raise ValueError(f"{label} must use YYYY-MM-DD format.") from error

def require_number(value, label):
    require(type(value) in (int, float),
            f"{label} must be a number.")

def require_integer(value, label, minimum=0, maximum=None):
    require(type(value) is int, f"{label} must be an integer.")
    require(value >= minimum, f"{label} must be at least {minimum}.")
    if maximum is not None:
        require(value <= maximum,
                f"{label} must not exceed {maximum}.")

def require_https(value, label):
    require_text(value, label)
    parsed = urlparse(value)
    require(parsed.scheme == "https" and bool(parsed.netloc),
            f"{label} must be an absolute HTTPS URL.")

def validate_region(region):
    require_exact_fields(region, REGION_FIELDS, "region")
    require_text(region["name"], "region.name")

    bounds = region["bounds"]
    require(isinstance(bounds, list) and len(bounds) == 4,
            "region.bounds must contain west, south, east, north.")
    for index, coordinate in enumerate(bounds):
        require_number(coordinate, f"region.bounds[{index}]")

    west, south, east, north = bounds
    require(-180 <= west <= 180 and -180 <= east <= 180,
            "Region longitudes must be between -180 and 180.")
    require(-90 <= south <= 90 and -90 <= north <= 90,
            "Region latitudes must be between -90 and 90.")
    require(west < east, "Region west longitude must be less than east.")
    require(south < north, "Region south latitude must be less than north.")

    center = region["default_center"]
    require(isinstance(center, list) and len(center) == 2,
            "region.default_center must contain longitude and latitude.")
    require_number(center[0], "region.default_center[0]")
    require_number(center[1], "region.default_center[1]")
    require(west <= center[0] <= east and south <= center[1] <= north,
            "Default center must fall inside the region bounds.")

    require_integer(region["min_zoom"], "region.min_zoom", 0, 24)
    require_integer(region["max_zoom"], "region.max_zoom", 0, 24)
    require(region["min_zoom"] <= region["max_zoom"],
            "Minimum zoom must not exceed maximum zoom.")

def validate_files(files, estimated_bytes):
    require(isinstance(files, list) and bool(files),
            "files must be a non-empty array.")

    paths = set()
    role_counts = {role: 0 for role in ROLE_RULES}
    total_bytes = 0

    for index, item in enumerate(files):
        label = f"files[{index}]"
        require_exact_fields(item, FILE_FIELDS, label)

        path = item["path"]
        role = item["role"]
        media_type = item["media_type"]

        require_text(path, f"{label}.path")
        require(role in ROLE_RULES, f"{label}.role is unsupported.")
        require(path not in paths, f"Duplicate file path: {path}")
        paths.add(path)

        expected_media, path_pattern = ROLE_RULES[role]
        require(bool(path_pattern.fullmatch(path)),
                f"{path} is not valid for role {role}.")
        require(media_type == expected_media,
                f"{path} has the wrong media type for role {role}.")

        require_integer(item["size_bytes"], f"{label}.size_bytes", 1)
        require(isinstance(item["sha256"], str)
                and bool(SHA256.fullmatch(item["sha256"])),
                f"{label}.sha256 must be 64 lowercase hexadecimal characters.")
        require(type(item["required"]) is bool,
                f"{label}.required must be a boolean.")

        if role in {"basemap", "license", "readme"}:
            require(item["required"], f"{path} must be required.")

        role_counts[role] += 1
        total_bytes += item["size_bytes"]

    require(role_counts["basemap"] == 1,
            "A map pack must contain exactly one basemap.")
    require(role_counts["readme"] == 1,
            "A map pack must contain exactly one README.txt.")
    require(role_counts["license"] >= 1,
            "A map pack must contain at least one license file.")
    require(total_bytes == estimated_bytes,
            "estimated_installed_bytes must equal the declared file-size total.")

def validate_sources(sources, status, pack_date):
    require(isinstance(sources, list) and bool(sources),
            "sources must be a non-empty array.")

    source_ids = set()

    for index, source in enumerate(sources):
        label = f"sources[{index}]"
        require_exact_fields(source, SOURCE_FIELDS, label)
        require_identifier(source["source_id"], f"{label}.source_id")
        require(source["source_id"] not in source_ids,
                f"Duplicate source ID: {source["source_id"]}")
        source_ids.add(source["source_id"])

        require_text(source["name"], f"{label}.name")
        require_https(source["source_page"], f"{label}.source_page")
        require_text(source["source_version"], f"{label}.source_version")
        source_date = parse_date(source["data_date"], f"{label}.data_date")
        require(source_date <= pack_date,
                f"{label}.data_date cannot be newer than the pack data date.")
        require_text(source["license"], f"{label}.license")

        redistribution = source["redistribution"]
        require(redistribution in {"permitted", "restricted", "prohibited", "unknown"},
                f"{label}.redistribution is unsupported.")
        require(redistribution != "prohibited",
                f"{label} prohibits redistribution.")
        if status in {"published", "deprecated"}:
            require(redistribution == "permitted",
                    f"{label} must permit redistribution for {status} packs.")

        require_text(source["attribution"], f"{label}.attribution")
        require(isinstance(source["notes"], str),
                f"{label}.notes must be a string.")

def validate_manifest(data):
    require_exact_fields(data, TOP_FIELDS, "manifest")
    require(data["schema_version"] == 1,
            "schema_version must be 1.")
    require(data["pack_format"] == "ogmap-zip-v1",
            "pack_format must be ogmap-zip-v1.")
    require_identifier(data["pack_id"], "pack_id")
    require_text(data["name"], "name")
    require_version(data["version"], "version")
    require(data["status"] in {"draft", "published", "deprecated"},
            "status is unsupported.")

    compatibility = data["reader_compatibility"]
    require_exact_fields(compatibility, READER_FIELDS,
                         "reader_compatibility")
    require_version(compatibility["minimum_version"],
                    "reader_compatibility.minimum_version")

    require_text(data["description"], "description")
    validate_region(data["region"])
    pack_date = parse_date(data["data_date"], "data_date")
    require_integer(data["estimated_installed_bytes"],
                    "estimated_installed_bytes", 1)
    require_identifier(data["style_id"], "style_id")
    require(data["style_id"] in APPROVED_STYLES,
            f"Unsupported reader-owned style: {data["style_id"]}")

    require_identifier(data["tile_schema_id"], "tile_schema_id")
    require(data["tile_schema_id"] in APPROVED_TILE_SCHEMAS,
            f"Unsupported tile schema: {data["tile_schema_id"]}")

    validate_files(data["files"], data["estimated_installed_bytes"])
    validate_sources(data["sources"], data["status"], pack_date)

    limitations = data["limitations"]
    require(isinstance(limitations, list),
            "limitations must be an array.")
    for index, limitation in enumerate(limitations):
        require_text(limitation, f"limitations[{index}]")

def parse_args():
    parser = argparse.ArgumentParser(
        description="Validate an Offgrid Pi map-pack manifest."
    )
    parser.add_argument("manifest", type=Path)
    return parser.parse_args()

def main():
    args = parse_args()
    try:
        data = json.loads(args.manifest.read_text(encoding="utf-8"))
        validate_manifest(data)
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1

    print(
        "PASS: Valid map-pack manifest: "
        f"{data["pack_id"]} {data["version"]} "
        f"({len(data["files"])} files, {len(data["sources"])} sources)."
    )
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
