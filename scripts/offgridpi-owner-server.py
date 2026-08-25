#!/usr/bin/env python3
"""Localhost-only bootstrap service for Offgrid Pi Owner Mode."""

from __future__ import annotations

import html
import os
import sys
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

DEFAULT_BIND = "127.0.0.1"
DEFAULT_PORT = 8085
DEFAULT_STATE_ROOT = Path("/var/lib/offgridpi/owner")
DEFAULT_MAP_DATA_ROOT = Path(
    "/srv/offgridpi/content/maps/user-data"
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


def configuration() -> tuple[str, int, Path, Path]:
    bind_address = os.environ.get(
        "OFFGRIDPI_OWNER_BIND",
        DEFAULT_BIND,
    ).strip()

    if bind_address not in ALLOWED_BIND_ADDRESSES:
        raise RuntimeError(
            "Owner Mode bootstrap may bind only to localhost."
        )

    raw_port = os.environ.get(
        "OFFGRIDPI_OWNER_PORT",
        str(DEFAULT_PORT),
    )

    try:
        port = int(raw_port)
    except ValueError as error:
        raise RuntimeError(
            "Owner Mode port must be an integer."
        ) from error

    if not 1 <= port <= 65535:
        raise RuntimeError(
            "Owner Mode port must be between 1 and 65535."
        )

    state_root = Path(
        os.environ.get(
            "OFFGRIDPI_OWNER_STATE_ROOT",
            str(DEFAULT_STATE_ROOT),
        )
    )

    map_data_root = Path(
        os.environ.get(
            "OFFGRIDPI_OWNER_MAP_DATA_ROOT",
            str(DEFAULT_MAP_DATA_ROOT),
        )
    )

    return bind_address, port, state_root, map_data_root


def render_page() -> bytes:
    title = html.escape("Offgrid Pi Owner Mode")

    page = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>{title}</title>
<style>
:root{{color-scheme:dark;font-family:Arial,Helvetica,sans-serif}}
*{{box-sizing:border-box}}
body{{margin:0;background:#0c1218;color:#edf4f7}}
main{{width:min(720px,calc(100% - 32px));margin:12vh auto;padding:24px}}
.card{{border:1px solid #33434e;border-radius:14px;background:#111a22;padding:24px}}
.eyebrow{{margin:0 0 8px;color:#7fd2ad;font-size:.75rem;font-weight:800;letter-spacing:.12em;text-transform:uppercase}}
h1{{margin:0 0 12px;font-size:clamp(1.8rem,5vw,2.8rem)}}
p{{color:#b8c5ca;line-height:1.55}}
.badge{{display:inline-block;margin-top:8px;border:1px solid #7fd2ad;border-radius:999px;padding:6px 10px;color:#9ce6c1;font-size:.72rem;font-weight:800}}
</style>
</head>
<body>
<main>
<section class="card">
<p class="eyebrow">Protected owner service</p>
<h1>{title}</h1>
<p>
The Owner Mode security foundation is installed. Authentication and protected
owner features have not been enabled yet.
</p>
<span class="badge">LOCALHOST BOOTSTRAP ONLY</span>
</section>
</main>
</body>
</html>
"""

    return page.encode("utf-8")


class OwnerHandler(BaseHTTPRequestHandler):
    server_version = "OffgridPiOwner/1"
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
        self.send_header("Content-Type", content_type)
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
            self.send_body(
                HTTPStatus.NOT_FOUND,
                b"Not found.\n",
                "text/plain; charset=utf-8",
                include_body=include_body,
            )
            return

        self.send_body(
            HTTPStatus.OK,
            render_page(),
            "text/html; charset=utf-8",
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


class OwnerServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main() -> int:
    try:
        bind_address, port, _, _ = configuration()
        server = OwnerServer(
            (bind_address, port),
            OwnerHandler,
        )
    except (OSError, RuntimeError) as error:
        return fail(str(error))

    print(
        "Offgrid Pi Owner Mode bootstrap listening on "
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
