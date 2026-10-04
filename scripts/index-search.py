#!/usr/bin/env python3
"""Build the Offgrid Pi full-text search index."""

from __future__ import annotations

import os
import sqlite3
import sys
from pathlib import Path


DEFAULT_ROOT = Path("/srv/offgridpi/content/documents/public")
DEFAULT_DB = Path("/srv/offgridpi/indexes/search.sqlite3")

ROOT = Path(os.environ.get("OFFGRIDPI_SEARCH_ROOT", str(DEFAULT_ROOT)))
DATABASE = Path(os.environ.get("OFFGRIDPI_SEARCH_DB", str(DEFAULT_DB)))


def fail(message: str) -> int:
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


def iter_text_files(root: Path):
    for current, directories, names in os.walk(root, followlinks=False):
        current_path = Path(current)

        directories[:] = sorted(
            name
            for name in directories
            if not name.startswith(".")
            and not (current_path / name).is_symlink()
        )

        for name in sorted(names, key=str.casefold):
            path = current_path / name

            if name.startswith(".") or path.is_symlink():
                continue

            if path.is_file() and path.suffix.lower() in {".txt", ".md"}:
                yield path


def main() -> int:
    if not ROOT.is_dir() or ROOT.is_symlink():
        return fail(f"Invalid search root: {ROOT}")

    DATABASE.parent.mkdir(parents=True, exist_ok=True)

    temporary = DATABASE.with_name(f".{DATABASE.name}.tmp")
    temporary.unlink(missing_ok=True)

    indexed = 0

    try:
        connection = sqlite3.connect(temporary)

        connection.execute(
            """
            CREATE VIRTUAL TABLE search_fts USING fts5(
                path UNINDEXED,
                title,
                content,
                tokenize='unicode61'
            )
            """
        )

        for path in iter_text_files(ROOT):
            relative = path.relative_to(ROOT).as_posix()
            content = path.read_text(
                encoding="utf-8",
                errors="replace",
            )

            connection.execute(
                """
                INSERT INTO search_fts(path, title, content)
                VALUES (?, ?, ?)
                """,
                (
                    relative,
                    path.stem,
                    content,
                ),
            )
            indexed += 1

        connection.commit()
        connection.close()
        temporary.replace(DATABASE)

    except (OSError, sqlite3.Error) as error:
        temporary.unlink(missing_ok=True)
        return fail(str(error))

    print(f"Indexed {indexed} searchable document(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
