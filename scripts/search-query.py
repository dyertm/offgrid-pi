#!/usr/bin/env python3
"""Offline query normalization for Offgrid Pi."""

from __future__ import annotations

import re

STOPWORDS = {
    "how",
    "long",
    "without",
    "the",
    "a",
    "an",
}

ALIASES = {
    "fridge": "refrigerator",
    "flooded": "flood",
}


def normalize_query(query: str) -> list[str]:
    """Convert natural-language input into normalized search terms."""
    words = re.findall(r"[a-z0-9]+", query.casefold())
    normalized = []

    for word in words:
        if word in STOPWORDS:
            continue

        normalized.append(ALIASES.get(word, word))

    return normalized


def build_fts_query(query: str) -> str:
    """Build a safe SQLite FTS5 query from natural-language input."""
    terms = normalize_query(query)

    if not terms:
        return ""

    return " AND ".join(f'"{term}"' for term in terms)
