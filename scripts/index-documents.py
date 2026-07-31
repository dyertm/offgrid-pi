#!/usr/bin/env python3

"""Generate the static Offgrid Pi document-library index."""

from __future__ import annotations

import argparse
import html
import os
from datetime import datetime
from pathlib import Path
from urllib.parse import quote


DEFAULT_ROOT = Path("/srv/offgridpi/content/documents/library")
DEFAULT_OUTPUT = Path("/opt/offgridpi/dashboard/documents/index.html")

SUPPORTED_EXTENSIONS = {
    ".pdf",
    ".txt",
    ".md",
    ".html",
    ".htm",
    ".epub",
    ".jpg",
    ".jpeg",
    ".png",
    ".gif",
    ".webp",
    ".svg",
    ".doc",
    ".docx",
    ".xls",
    ".xlsx",
    ".ppt",
    ".pptx",
    ".odt",
    ".ods",
    ".odp",
}

CATEGORY_NAMES = {
    "books": "Books and Literature",
    "communications": "Communications",
    "education": "Education",
    "emergency": "Emergency Preparedness",
    "equipment-manuals": "Equipment Manuals",
    "faith": "Faith",
    "first-aid": "Medical and First Aid",
    "food": "Food and Preservation",
    "gardening": "Gardening and Agriculture",
    "radio": "Radio",
    "repair": "Repair and Maintenance",
}


def humanize(value: str) -> str:
    """Convert a file or directory name into a readable title."""
    return value.replace("_", " ").replace("-", " ").strip().title()


def format_size(size: int) -> str:
    """Return a human-readable file size."""
    units = ("B", "KB", "MB", "GB", "TB")
    value = float(size)

    for unit in units:
        if value < 1024 or unit == units[-1]:
            if unit == "B":
                return f"{int(value)} {unit}"
            return f"{value:.1f} {unit}"
        value /= 1024

    return f"{size} B"


def discover_documents(root: Path) -> dict[str, list[dict[str, str]]]:
    """Scan the public library and group supported files by category."""
    categories: dict[str, list[dict[str, str]]] = {}

    for path in sorted(root.rglob("*"), key=lambda item: str(item).lower()):
        if not path.is_file():
            continue

        if path.name.startswith("."):
            continue

        if path.suffix.lower() not in SUPPORTED_EXTENSIONS:
            continue

        relative = path.relative_to(root)
        parts = relative.parts

        if not parts:
            continue

        category_key = parts[0]
        category_name = CATEGORY_NAMES.get(
            category_key,
            humanize(category_key),
        )

        stat = path.stat()
        encoded_path = quote(relative.as_posix(), safe="/")
        display_title = humanize(path.stem)

        if len(parts) > 2:
            subsection = " / ".join(humanize(part) for part in parts[1:-1])
        elif len(parts) == 2:
            subsection = ""
        else:
            subsection = "General"

        categories.setdefault(category_name, []).append(
            {
                "title": display_title,
                "subsection": subsection,
                "extension": path.suffix.lower().lstrip(".").upper() or "FILE",
                "size": format_size(stat.st_size),
                "modified": datetime.fromtimestamp(stat.st_mtime).strftime(
                    "%Y-%m-%d"
                ),
                "href": f"files/{encoded_path}",
                "search": " ".join(
                    (
                        category_name,
                        subsection,
                        display_title,
                        relative.as_posix(),
                    )
                ).lower(),
            }
        )

    return dict(sorted(categories.items()))


def build_category_html(
    categories: dict[str, list[dict[str, str]]],
) -> tuple[str, int]:
    """Build the category markup and return it with the file count."""
    sections: list[str] = []
    total_files = 0

    for category_name, documents in categories.items():
        total_files += len(documents)
        items: list[str] = []

        for document in documents:
            subsection = (
                f'<span class="doc-path">{html.escape(document["subsection"])}</span>'
                if document["subsection"]
                else ""
            )

            items.append(
                f"""
                <a class="doc-item"
                   href="{html.escape(document["href"], quote=True)}"
                   data-search="{html.escape(document["search"], quote=True)}">
                  <div class="doc-main">
                    <span class="doc-type">{html.escape(document["extension"])}</span>
                    <div>
                      <h3>{html.escape(document["title"])}</h3>
                      {subsection}
                    </div>
                  </div>
                  <div class="doc-meta">
                    <span>{html.escape(document["size"])}</span>
                    <span>{html.escape(document["modified"])}</span>
                  </div>
                </a>
                """
            )

        sections.append(
            f"""
            <section class="category">
              <div class="category-heading">
                <h2>{html.escape(category_name)}</h2>
                <span>{len(documents)} file{"s" if len(documents) != 1 else ""}</span>
              </div>
              <div class="document-list">
                {"".join(items)}
              </div>
            </section>
            """
        )

    if not sections:
        sections.append(
            """
            <div class="empty-state">
              <h2>No public documents found</h2>
              <p>Add supported files to the public document folders and regenerate the index.</p>
            </div>
            """
        )

    return "\n".join(sections), total_files


def render_page(category_html: str, total_files: int) -> str:
    """Render the complete self-contained document-library page."""
    generated = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M %Z")

    template = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="Offgrid Pi local document library">
  <title>Local Documents | Offgrid Pi</title>

  <style>
    :root {
      color-scheme: dark;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      --background: #0b1118;
      --surface: #141e29;
      --surface-hover: #1a2836;
      --border: #2b3a49;
      --text: #f3f6f8;
      --muted: #aebbc7;
      --accent: #71c49b;
      --accent-dark: #183b2d;
    }

    * {
      box-sizing: border-box;
    }

    body {
      min-height: 100vh;
      margin: 0;
      background:
        radial-gradient(circle at top right, #172a36 0, transparent 35%),
        var(--background);
      color: var(--text);
    }

    .page {
      width: min(1050px, 100%);
      margin: 0 auto;
      padding: 20px;
    }

    .topbar {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 18px;
      margin-bottom: 18px;
    }

    .eyebrow {
      margin: 0 0 5px;
      color: var(--accent);
      font-size: 0.75rem;
      font-weight: 700;
      letter-spacing: 0.13em;
      text-transform: uppercase;
    }

    h1 {
      margin: 0;
      font-size: clamp(1.9rem, 5vw, 3rem);
    }

    .subtitle {
      margin: 7px 0 0;
      color: var(--muted);
    }

    .back-link {
      flex-shrink: 0;
      padding: 9px 13px;
      border: 1px solid var(--accent);
      border-radius: 999px;
      background: var(--accent-dark);
      color: var(--accent);
      font-size: 0.8rem;
      font-weight: 700;
      text-decoration: none;
    }

    .search-panel {
      margin-bottom: 18px;
      padding: 14px;
      border: 1px solid var(--border);
      border-radius: 14px;
      background: var(--surface);
    }

    .search-panel label {
      display: block;
      margin-bottom: 7px;
      color: var(--muted);
      font-size: 0.8rem;
      font-weight: 700;
    }

    #document-search {
      width: 100%;
      padding: 11px 12px;
      border: 1px solid var(--border);
      border-radius: 9px;
      background: var(--background);
      color: var(--text);
      font: inherit;
    }

    #document-search:focus {
      border-color: var(--accent);
      outline: none;
    }

    .library-summary {
      margin: 8px 0 0;
      color: var(--muted);
      font-size: 0.76rem;
    }

    .category {
      margin-bottom: 18px;
    }

    .category-heading {
      display: flex;
      align-items: baseline;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 8px;
    }

    .category-heading h2 {
      margin: 0;
      font-size: 1.15rem;
    }

    .category-heading span {
      color: var(--muted);
      font-size: 0.75rem;
    }

    .document-list {
      display: grid;
      gap: 8px;
    }

    .doc-item {
      padding: 12px;
      border: 1px solid var(--border);
      border-radius: 11px;
      background: var(--surface);
      color: var(--text);
      text-decoration: none;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 14px;
    }

    .doc-item:hover,
    .doc-item:focus-visible {
      border-color: var(--accent);
      background: var(--surface-hover);
      outline: none;
    }

    .doc-main {
      min-width: 0;
      display: flex;
      align-items: center;
      gap: 11px;
    }

    .doc-type {
      min-width: 44px;
      padding: 5px 7px;
      border-radius: 7px;
      background: var(--accent-dark);
      color: var(--accent);
      font-size: 0.66rem;
      font-weight: 800;
      text-align: center;
    }

    .doc-item h3 {
      margin: 0;
      font-size: 0.93rem;
    }

    .doc-path {
      display: block;
      margin-top: 3px;
      color: var(--muted);
      font-size: 0.7rem;
    }

    .doc-meta {
      flex-shrink: 0;
      color: var(--muted);
      display: flex;
      gap: 12px;
      font-size: 0.68rem;
    }

    .empty-state,
    #no-results {
      padding: 24px;
      border: 1px solid var(--border);
      border-radius: 14px;
      background: var(--surface);
      text-align: center;
    }

    #no-results {
      display: none;
    }

    footer {
      margin-top: 18px;
      padding-top: 12px;
      border-top: 1px solid var(--border);
      color: var(--muted);
      font-size: 0.7rem;
    }

    @media (max-width: 600px) {
      .topbar {
        flex-direction: column;
      }

      .doc-item {
        align-items: flex-start;
        flex-direction: column;
      }

      .doc-meta {
        margin-left: 55px;
      }
    }
  </style>
</head>

<body>
  <div class="page">
    <header class="topbar">
      <div>
        <p class="eyebrow">Offline Reference Library</p>
        <h1>Local Documents</h1>
        <p class="subtitle">
          Manuals, books, preparedness references, faith resources, and locally stored files.
        </p>
      </div>

      <a class="back-link" href="../">← Dashboard</a>
    </header>

    <main>
      <section class="search-panel">
        <label for="document-search">Search the local library</label>
        <input
          id="document-search"
          type="search"
          placeholder="Search titles, categories, folders, or filenames"
          autocomplete="off"
        >
        <p class="library-summary">
          __TOTAL_FILES__ indexed file(s) • Generated __GENERATED__
        </p>
      </section>

      <div id="library-content">
        __CATEGORY_HTML__
      </div>

      <div id="no-results">
        No documents matched your search.
      </div>
    </main>

    <footer>
      Files placed in this library are available through the local Offgrid Pi dashboard.
    </footer>
  </div>

  <script>
    "use strict";

    const searchInput = document.getElementById("document-search");
    const documents = Array.from(document.querySelectorAll(".doc-item"));
    const categories = Array.from(document.querySelectorAll(".category"));
    const noResults = document.getElementById("no-results");

    function filterDocuments() {
      const query = searchInput.value.trim().toLowerCase();
      let visibleCount = 0;

      for (const documentLink of documents) {
        const matches = !query || documentLink.dataset.search.includes(query);
        documentLink.hidden = !matches;

        if (matches) {
          visibleCount += 1;
        }
      }

      for (const category of categories) {
        const visibleDocuments = category.querySelectorAll(".doc-item:not([hidden])");
        category.hidden = visibleDocuments.length === 0;
      }

      noResults.style.display =
        documents.length > 0 && visibleCount === 0 ? "block" : "none";
    }

    searchInput.addEventListener("input", filterDocuments);
  </script>
</body>
</html>
"""

    return (
        template
        .replace("__TOTAL_FILES__", str(total_files))
        .replace("__GENERATED__", html.escape(generated))
        .replace("__CATEGORY_HTML__", category_html)
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate the Offgrid Pi static document index."
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=DEFAULT_ROOT,
        help=f"Public document root (default: {DEFAULT_ROOT})",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Generated HTML path (default: {DEFAULT_OUTPUT})",
    )

    args = parser.parse_args()
    root = args.root.resolve()
    output = args.output

    if not root.is_dir():
        raise SystemExit(f"Document root does not exist: {root}")

    categories = discover_documents(root)
    category_html, total_files = build_category_html(categories)
    page = render_page(category_html, total_files)

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(page, encoding="utf-8")

    print(f"Indexed {total_files} public document(s).")
    print(f"Generated: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
