#!/usr/bin/env python3
"""Tests for Offgrid Pi search query normalization."""

import importlib.util
from pathlib import Path

module_path = (
    Path(__file__).resolve().parents[1]
    / "scripts/search-query.py"
)

spec = importlib.util.spec_from_file_location(
    "offgridpi_search_query", module_path
)
if spec is None or spec.loader is None:
    raise SystemExit("Search query module is unavailable")

module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

cases = [
    (
        "how long refrigerator without power",
        ["refrigerator", "power"],
    ),
    ("flooded road", ["flood", "road"]),
    ("fridge", ["refrigerator"]),
]

for query, expected in cases:
    actual = module.normalize_query(query)
    if actual != expected:
        raise SystemExit(
            f"FAIL: {query!r}: {actual!r} != {expected!r}"
        )
    print(f"PASS: {query}")

fts_cases = [
    ("fridge", '"refrigerator"'),
    ("flooded road", '"flood" AND "road"'),
    ("John 3:16", '"john" AND "3" AND "16"'),
    ("how long refrigerator without power", '"refrigerator" AND "power"'),
    ("the", ""),
]

for query, expected in fts_cases:
    actual = module.build_fts_query(query)
    if actual != expected:
        raise SystemExit(
            f"FAIL: FTS5 {query!r}: {actual!r} != {expected!r}"
        )
    print(f"PASS: FTS5 {query}")
