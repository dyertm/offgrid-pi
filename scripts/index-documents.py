#!/usr/bin/env python3
"""Build the Offgrid Pi public document catalog."""
from __future__ import annotations

import html
import json
import os
import sys
from datetime import datetime
from pathlib import Path
from urllib.parse import quote

ROOT = Path("/srv/offgridpi/content/documents/public")
INDEX = ROOT / "index.html"
CATALOG = ROOT / "catalog.json"

CATEGORIES = (
    ("emergency", "Emergency Preparedness"),
    ("first-aid", "Medical and First Aid"),
    ("food", "Food and Preservation"),
    ("gardening", "Gardening and Agriculture"),
    ("communications", "Communications"),
    ("radio", "Radio"),
    ("repair", "Repair and Maintenance"),
    ("equipment-manuals", "Equipment Manuals"),
    ("education", "Education"),
    ("books", "Books and Literature"),
    ("faith", "Faith"),
)

TYPE_NAMES = {
    ".pdf": "PDF", ".txt": "Text", ".md": "Markdown",
    ".html": "HTML", ".htm": "HTML", ".epub": "EPUB",
    ".jpg": "Image", ".jpeg": "Image", ".png": "Image",
    ".gif": "Image", ".webp": "Image", ".svg": "Image",
    ".doc": "Document", ".docx": "Document", ".odt": "Document",
}


def size_label(size: int) -> str:
    value = float(size)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if value < 1024 or unit == "TB":
            return f"{int(value)} {unit}" if unit == "B" else f"{value:.1f} {unit}"
        value /= 1024
    return f"{size} B"


def atomic_write(path: Path, text: str) -> None:
    temp = path.with_name(f".{path.name}.tmp")
    temp.write_text(text, encoding="utf-8")
    os.chmod(temp, 0o644)
    temp.replace(path)


def scan(category: Path) -> tuple[list[dict[str, object]], list[str]]:
    files: list[dict[str, object]] = []
    warnings: list[str] = []

    for current, directories, names in os.walk(category, followlinks=False):
        current_path = Path(current)
        directories[:] = sorted(
            d for d in directories
            if not d.startswith(".") and not (current_path / d).is_symlink()
        )

        for name in sorted(names, key=str.casefold):
            path = current_path / name
            if name.startswith("."):
                continue
            if path.is_symlink():
                warnings.append(f"Skipped symlink: {path}")
                continue
            if not path.is_file():
                continue

            relative = path.relative_to(ROOT)
            stat = path.stat()
            files.append({
                "name": path.name,
                "path": relative.as_posix(),
                "display_path": relative.relative_to(category.name).as_posix(),
                "url": quote(relative.as_posix(), safe="/"),
                "type": TYPE_NAMES.get(path.suffix.lower(), path.suffix[1:].upper() or "File"),
                "size": size_label(stat.st_size),
                "size_bytes": stat.st_size,
                "modified": datetime.fromtimestamp(stat.st_mtime).astimezone().strftime("%Y-%m-%d"),
            })

    files.sort(key=lambda item: str(item["display_path"]).casefold())
    return files, warnings


def file_row(item: dict[str, object]) -> str:
    name = html.escape(str(item["name"]))
    display_path = html.escape(str(item["display_path"]))
    url = html.escape(str(item["url"]), quote=True)
    kind = html.escape(str(item["type"]))
    size = html.escape(str(item["size"]))
    modified = html.escape(str(item["modified"]))
    search = html.escape(f"{name} {display_path} {kind}".lower(), quote=True)
    return (
        f'<li data-file data-search="{search}"><a href="{url}" target="_blank" rel="noopener">'
        f'<span><strong>{name}</strong><small>{display_path}</small></span>'
        f'<span class="meta"><b>{kind}</b><small>{size}</small><small>{modified}</small></span>'
        '</a></li>'
    )


def main() -> int:
    expected = Path("/srv/offgridpi/content/documents/public").resolve()
    if not ROOT.is_dir() or ROOT.resolve() != expected:
        print(f"ERROR: Invalid public document root: {ROOT}", file=sys.stderr)
        return 1

    generated = datetime.now().astimezone()
    sections: list[str] = []
    nav: list[str] = []
    catalog_categories: list[dict[str, object]] = []
    warnings: list[str] = []
    total = 0

    for slug, title in CATEGORIES:
        category = ROOT / slug
        if category.is_dir():
            items, category_warnings = scan(category)
            warnings.extend(category_warnings)
        else:
            items = []
            warnings.append(f"Missing category: {category}")

        total += len(items)
        catalog_categories.append({"slug": slug, "title": title, "files": items})
        nav.append(f'<a href="#{slug}">{html.escape(title)} <b>{len(items)}</b></a>')
        rows = "".join(file_row(item) for item in items)
        if not rows:
            rows = '<li class="empty">No documents added yet.</li>'
        sections.append(
            f'<section id="{slug}" data-category><header><div><p>Document category</p>'
            f'<h2>{html.escape(title)}</h2></div><span>{len(items)} file{"s" if len(items) != 1 else ""}</span>'
            f'</header><ul>{rows}</ul></section>'
        )

    generated_text = generated.strftime("%B %d, %Y at %I:%M %p %Z")
    page = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Local Documents | Offgrid Pi</title>
<style>
:root{{color-scheme:dark;font-family:Arial,Helvetica,sans-serif}}*{{box-sizing:border-box}}html{{scroll-behavior:smooth}}body{{margin:0;background:#0c1218;color:#edf4f7}}a{{color:inherit}}.wrap{{width:min(1050px,calc(100% - 28px));margin:auto}}.top{{position:sticky;top:0;z-index:5;background:#0c1218f2;border-bottom:1px solid #293640}}.top .wrap{{min-height:62px;display:flex;align-items:center;justify-content:space-between}}.brand{{font-weight:800;letter-spacing:.08em;text-decoration:none}}main{{padding:28px 0}}h1{{font-size:clamp(2rem,6vw,3.3rem);margin:0}}.intro{{color:#b4c2c9;max-width:760px;line-height:1.5}}.stats{{display:flex;gap:9px;flex-wrap:wrap;margin:16px 0}}.stats span,.nav a{{border:1px solid #33434e;background:#111a22;border-radius:9px;padding:9px 11px}}.search{{display:grid;grid-template-columns:1fr auto;gap:10px;margin:18px 0}}input,button{{font:inherit;border:1px solid #3a4b56;border-radius:9px;background:#111a22;color:#fff;padding:12px}}button{{font-weight:700;cursor:pointer}}.nav{{display:grid;grid-template-columns:repeat(auto-fit,minmax(175px,1fr));gap:8px;margin-bottom:24px}}.nav a{{display:flex;justify-content:space-between;text-decoration:none;color:#cbd7dc}}.nav b,header p{{color:#7fd2ad}}section{{scroll-margin-top:74px;border:1px solid #293640;border-radius:12px;background:#101820;margin:0 0 16px;overflow:hidden}}section header{{padding:16px 18px;display:flex;justify-content:space-between;gap:18px;border-bottom:1px solid #293640}}section header p{{font-size:.7rem;font-weight:800;letter-spacing:.12em;text-transform:uppercase;margin:0 0 4px}}h2{{font-size:1.2rem;margin:0}}section header>span{{font-size:.8rem;background:#193126;color:#94e2bd;padding:6px 9px;border-radius:999px;height:max-content}}ul{{list-style:none;margin:0;padding:0}}li+li{{border-top:1px solid #24313a}}li a{{display:flex;justify-content:space-between;gap:16px;padding:13px 18px;text-decoration:none}}li a:hover{{background:#17232d}}li span:first-child{{min-width:0;display:grid;gap:3px}}li strong,li small{{overflow-wrap:anywhere}}small{{color:#84969f}}.meta{{display:flex;align-items:center;gap:10px;flex:0 0 auto;font-size:.75rem}}.meta b{{border:1px solid #40525e;border-radius:5px;padding:4px 7px}}.empty{{padding:15px 18px;color:#84969f;font-style:italic}}#none{{display:none;text-align:center;border:1px dashed #52636d;border-radius:9px;padding:14px;color:#c1cdd2}}footer{{padding:5px 0 30px;color:#7f919b;text-align:center;font-size:.75rem}}@media(max-width:650px){{.search{{grid-template-columns:1fr}}section header,li a{{flex-direction:column}}.meta{{flex-wrap:wrap}}}}
.dashboard-return{{display:inline-flex;align-items:center;min-height:34px;padding:7px 11px;border:1px solid #33434e;border-radius:9px;background:#111a22;color:#7fd2ad;font-size:.78rem;font-weight:700;text-decoration:none;white-space:nowrap}}.dashboard-return:hover,.dashboard-return:focus-visible{{border-color:#7fd2ad;background:#193126}}
</style>
</head>
<body>
<header class="top"><div class="wrap"><a class="brand" href="/">OFFGRID PI</a><a class="dashboard-return" id="dashboard" href="http://localhost:8081/">← Dashboard</a></div></header>
<main class="wrap">
<p style="color:#7fd2ad;font-weight:800;letter-spacing:.12em;text-transform:uppercase">Offline reference library</p>
<h1>Local Documents</h1>
<p class="intro">Browse approved public documents stored on this Offgrid Pi. Personal files are maintained in a separate protected directory and are not included here.</p>
<div class="stats"><span><b>{total}</b> indexed file{"s" if total != 1 else ""}</span><span><b>{len(CATEGORIES)}</b> categories</span><span>Generated {html.escape(generated_text)}</span></div>
<div class="search"><input id="q" type="search" placeholder="Search file names, paths, or types"><button id="clear" type="button">Clear</button></div>
<nav class="nav">{''.join(nav)}</nav><p id="none">No documents match your search.</p>
{''.join(sections)}
</main>
<footer class="wrap">Public files only — /srv/offgridpi/content/documents/public</footer>
<script>
const q=document.getElementById('q'),rows=[...document.querySelectorAll('[data-file]')],sections=[...document.querySelectorAll('[data-category]')],none=document.getElementById('none');
function filter(){{const value=q.value.trim().toLowerCase();let shown=0;rows.forEach(row=>{{const show=!value||row.dataset.search.includes(value);row.hidden=!show;if(show)shown++}});sections.forEach(section=>{{const items=[...section.querySelectorAll('[data-file]')];section.hidden=!!value&&items.length>0&&!items.some(item=>!item.hidden)}});none.style.display=value&&shown===0?'block':'none'}}
q.addEventListener('input',filter);document.getElementById('clear').addEventListener('click',()=>{{q.value='';filter();q.focus()}});document.getElementById('dashboard').href=`${{location.protocol}}//${{location.hostname}}:8081/`;
</script>
</body>
</html>
"""

    catalog = {
        "generated_at": generated.isoformat(),
        "public_root": str(ROOT),
        "total_files": total,
        "categories": catalog_categories,
        "warnings": warnings,
    }
    atomic_write(INDEX, page)
    atomic_write(CATALOG, json.dumps(catalog, indent=2, ensure_ascii=False) + "\n")

    print(f"Indexed {total} public document(s) across {len(CATEGORIES)} categories.")
    print(f"HTML catalog: {INDEX}")
    print(f"JSON catalog: {CATALOG}")
    print(f"Warnings: {len(warnings)}")
    for warning in warnings:
        print(f"  - {warning}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
