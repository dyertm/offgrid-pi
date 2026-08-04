#!/usr/bin/env python3
"""Localhost-only read-only Offgrid Pi management viewer."""

from __future__ import annotations

import html
import json
import os
import sys
from datetime import datetime
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

DEFAULT_BIND = "127.0.0.1"
DEFAULT_PORT = 8083
DEFAULT_SNAPSHOT = Path(
    "/var/lib/offgridpi/management/system-logs.json"
)

ALLOWED_BIND_ADDRESSES = {
    "127.0.0.1",
    "::1",
    "localhost",
}

SECURITY_HEADERS = {
    "Content-Security-Policy": (
        "default-src 'none'; "
        "style-src 'unsafe-inline'; "
        "img-src 'self'; "
        "base-uri 'none'; "
        "form-action 'none'; "
        "frame-ancestors 'none'"
    ),
    "Referrer-Policy": "no-referrer",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Cross-Origin-Resource-Policy": "same-origin",
    "Cache-Control": "no-store",
}


def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def configuration() -> tuple[str, int, Path]:
    bind_address = os.environ.get(
        "OFFGRIDPI_MANAGEMENT_BIND",
        DEFAULT_BIND,
    ).strip()

    if bind_address not in ALLOWED_BIND_ADDRESSES:
        raise RuntimeError(
            "Management server may bind only to localhost."
        )

    raw_port = os.environ.get(
        "OFFGRIDPI_MANAGEMENT_PORT",
        str(DEFAULT_PORT),
    )

    try:
        port = int(raw_port)
    except ValueError as error:
        raise RuntimeError(
            "Management port must be an integer."
        ) from error

    if not 1 <= port <= 65535:
        raise RuntimeError(
            "Management port must be between 1 and 65535."
        )

    snapshot = Path(
        os.environ.get(
            "OFFGRIDPI_MANAGEMENT_LOG_SNAPSHOT",
            str(DEFAULT_SNAPSHOT),
        )
    )

    return bind_address, port, snapshot


def load_snapshot(path: Path) -> dict[str, Any]:
    try:
        report = json.loads(
            path.read_text(encoding="utf-8")
        )
    except FileNotFoundError as error:
        raise RuntimeError(
            "Protected log snapshot is unavailable."
        ) from error
    except PermissionError as error:
        raise RuntimeError(
            "Protected log snapshot cannot be read."
        ) from error
    except json.JSONDecodeError as error:
        raise RuntimeError(
            "Protected log snapshot is invalid."
        ) from error

    if not isinstance(report, dict):
        raise RuntimeError(
            "Protected log snapshot must be an object."
        )

    if report.get("schema_version") != 1:
        raise RuntimeError(
            "Unsupported protected log schema."
        )

    sources = report.get("sources")

    if not isinstance(sources, list):
        raise RuntimeError(
            "Protected log sources are invalid."
        )

    if report.get("source_count") != len(sources):
        raise RuntimeError(
            "Protected log source count is invalid."
        )

    for source in sources:
        if not isinstance(source, dict):
            raise RuntimeError(
                "Protected log source is invalid."
            )

        entries = source.get("entries")

        if not isinstance(entries, list):
            raise RuntimeError(
                "Protected log entries are invalid."
            )

        if source.get("entry_count") != len(entries):
            raise RuntimeError(
                "Protected log entry count is invalid."
            )

    return report


def safe_text(value: Any) -> str:
    return html.escape(
        str(value if value is not None else ""),
        quote=True,
    )


def display_timestamp(value: Any) -> str:
    if not isinstance(value, str) or not value:
        return "Unknown"

    normalized = value.replace("Z", "+00:00")

    try:
        timestamp = datetime.fromisoformat(normalized)
    except ValueError:
        return safe_text(value)

    return safe_text(
        timestamp.astimezone().strftime(
            "%Y-%m-%d %H:%M:%S %Z"
        )
    )


def priority_class(value: Any) -> str:
    try:
        priority = int(value)
    except (TypeError, ValueError):
        priority = 6

    if priority <= 3:
        return "priority-error"

    if priority == 4:
        return "priority-warning"

    return "priority-info"


def render_entry(entry: dict[str, Any]) -> str:
    timestamp = display_timestamp(
        entry.get("timestamp")
    )
    priority = safe_text(
        entry.get("priority_name", "Info")
    )
    message = safe_text(
        entry.get("message", "")
    )
    css_class = priority_class(
        entry.get("priority")
    )

    return (
        '<li class="log-entry">'
        '<div class="entry-meta">'
        f'<time>{timestamp}</time>'
        f'<span class="priority {css_class}">'
        f'{priority}</span>'
        '</div>'
        f'<p>{message or "No message recorded."}</p>'
        '</li>'
    )


def render_source(source: dict[str, Any]) -> str:
    name = safe_text(
        source.get("name", "Unknown service")
    )
    unit = safe_text(
        source.get("unit", "unknown.service")
    )
    entries = source.get("entries", [])

    rendered_entries = "".join(
        render_entry(entry)
        for entry in entries
        if isinstance(entry, dict)
    )

    if not rendered_entries:
        rendered_entries = (
            '<li class="empty">No recent entries.</li>'
        )

    return (
        '<section class="service-log">'
        '<header>'
        '<div>'
        '<p class="eyebrow">Protected journal snapshot</p>'
        f'<h2>{name}</h2>'
        f'<p class="unit">{unit}</p>'
        '</div>'
        f'<span class="count">{len(entries)} entries</span>'
        '</header>'
        f'<ol>{rendered_entries}</ol>'
        '</section>'
    )


def render_page(report: dict[str, Any]) -> bytes:
    generated = display_timestamp(
        report.get("generated_at")
    )
    sources = report.get("sources", [])

    rendered_sources = "".join(
        render_source(source)
        for source in sources
        if isinstance(source, dict)
    )

    page = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>Protected Logs | Offgrid Pi</title>
<style>
:root{{color-scheme:dark;font-family:Arial,Helvetica,sans-serif}}
*{{box-sizing:border-box}}
body{{margin:0;background:#0c1218;color:#edf4f7}}
.page{{width:min(1100px,calc(100% - 28px));margin:auto;padding:22px 0 34px}}
.page-header{{display:flex;justify-content:space-between;gap:18px;align-items:flex-start;margin-bottom:18px}}
.eyebrow{{margin:0 0 5px;color:#7fd2ad;font-size:.72rem;font-weight:800;letter-spacing:.12em;text-transform:uppercase}}
h1{{margin:0;font-size:clamp(1.8rem,5vw,3rem)}}
.subtitle,.unit,.generated{{color:#9baab2}}
.local-badge,.count,.priority{{border-radius:999px;padding:6px 9px;font-size:.72rem;font-weight:800}}
.local-badge{{border:1px solid #7fd2ad;background:#193126;color:#9ce6c1;white-space:nowrap}}
.notice{{border:1px solid #33434e;border-radius:10px;background:#111a22;padding:11px 13px;margin-bottom:16px;color:#b8c5ca;font-size:.82rem}}
.service-log{{border:1px solid #293640;border-radius:13px;background:#101820;margin-bottom:16px;overflow:hidden}}
.service-log>header{{display:flex;justify-content:space-between;gap:16px;padding:15px 17px;border-bottom:1px solid #293640}}
.service-log h2{{margin:0;font-size:1.15rem}}
.unit{{margin:4px 0 0;font-size:.75rem}}
.count{{background:#193126;color:#94e2bd;height:max-content}}
ol{{list-style:none;margin:0;padding:0}}
.log-entry,.empty{{padding:12px 17px}}
.log-entry+.log-entry,.empty+.log-entry{{border-top:1px solid #24313a}}
.entry-meta{{display:flex;gap:10px;align-items:center;flex-wrap:wrap;font-size:.72rem;color:#90a0a8}}
.log-entry p{{margin:7px 0 0;line-height:1.45;overflow-wrap:anywhere}}
.priority-error{{background:#442025;color:#ffb2b9}}
.priority-warning{{background:#3b2d16;color:#f0c676}}
.priority-info{{background:#1b2d38;color:#a9d8ef}}
.empty{{color:#84969f;font-style:italic}}
footer{{border-top:1px solid #293640;margin-top:18px;padding-top:12px;color:#7f919b;font-size:.75rem}}
@media(max-width:650px){{.page-header,.service-log>header{{flex-direction:column}}}}
</style>
</head>
<body>
<div class="page">
<header class="page-header">
<div>
<p class="eyebrow">Read-only local management</p>
<h1>Protected System Logs</h1>
<p class="subtitle">Recent sanitized entries from approved Offgrid Pi services</p>
</div>
<span class="local-badge">LOCALHOST ONLY</span>
</header>
<p class="notice">
This page is read-only. Logs remain outside the public dashboard and document web roots.
</p>
<p class="generated">Snapshot generated: {generated}</p>
<main>{rendered_sources}</main>
<footer>No privileged actions are available from this service.</footer>
</div>
</body>
</html>
"""

    return page.encode("utf-8")


class ManagementHandler(BaseHTTPRequestHandler):
    server_version = "OffgridPiManagement/1"
    sys_version = ""

    def send_security_headers(self) -> None:
        for name, value in SECURITY_HEADERS.items():
            self.send_header(name, value)

    def send_body(
        self,
        status: HTTPStatus,
        body: bytes,
        content_type: str,
        *,
        include_body: bool = True,
    ) -> None:
        self.send_response(status)
        self.send_header(
            "Content-Type",
            content_type,
        )
        self.send_header(
            "Content-Length",
            str(len(body)),
        )
        self.send_security_headers()
        self.end_headers()

        if include_body:
            self.wfile.write(body)

    def handle_page(self, *, include_body: bool) -> None:
        path = urlsplit(self.path).path

        if path != "/":
            body = b"Not found.\n"
            self.send_body(
                HTTPStatus.NOT_FOUND,
                body,
                "text/plain; charset=utf-8",
                include_body=include_body,
            )
            return

        snapshot_path = self.server.snapshot_path

        try:
            report = load_snapshot(snapshot_path)
            body = render_page(report)
            status = HTTPStatus.OK
            content_type = "text/html; charset=utf-8"
        except RuntimeError:
            body = (
                b"Protected log snapshot is unavailable.\n"
            )
            status = HTTPStatus.SERVICE_UNAVAILABLE
            content_type = "text/plain; charset=utf-8"

        self.send_body(
            status,
            body,
            content_type,
            include_body=include_body,
        )

    def do_GET(self) -> None:
        self.handle_page(include_body=True)

    def do_HEAD(self) -> None:
        self.handle_page(include_body=False)

    def reject_method(self) -> None:
        body = b"Method not allowed.\n"
        self.send_response(
            HTTPStatus.METHOD_NOT_ALLOWED
        )
        self.send_header("Allow", "GET, HEAD")
        self.send_header(
            "Content-Type",
            "text/plain; charset=utf-8",
        )
        self.send_header(
            "Content-Length",
            str(len(body)),
        )
        self.send_security_headers()
        self.end_headers()
        self.wfile.write(body)

    do_POST = reject_method
    do_PUT = reject_method
    do_PATCH = reject_method
    do_DELETE = reject_method
    do_OPTIONS = reject_method

    def log_message(
        self,
        format_string: str,
        *arguments: object,
    ) -> None:
        print(
            f"{self.client_address[0]} "
            f"{format_string % arguments}",
            file=sys.stderr,
        )


class ManagementServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(
        self,
        address: tuple[str, int],
        snapshot_path: Path,
    ) -> None:
        self.snapshot_path = snapshot_path
        super().__init__(
            address,
            ManagementHandler,
        )


def main() -> int:
    try:
        bind_address, port, snapshot = configuration()
        server = ManagementServer(
            (bind_address, port),
            snapshot,
        )
    except (OSError, RuntimeError) as error:
        return fail(str(error))

    print(
        "Offgrid Pi management viewer listening on "
        f"http://{bind_address}:{port}/"
    )

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
