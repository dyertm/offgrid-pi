#!/usr/bin/env python3
"""Static HTTP server for the Offgrid Pi dashboard."""

from __future__ import annotations

import os
import sys
from functools import partial
from http.server import (
    SimpleHTTPRequestHandler,
    ThreadingHTTPServer,
)
from pathlib import Path

DEFAULT_BIND = "0.0.0.0"
DEFAULT_PORT = 8081
DEFAULT_DASHBOARD_ROOT = Path("/opt/offgridpi/dashboard")


def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def configuration() -> tuple[str, int, Path]:
    bind_address = os.environ.get(
        "OFFGRIDPI_DASHBOARD_BIND",
        DEFAULT_BIND,
    ).strip()

    if not bind_address:
        raise RuntimeError(
            "Dashboard bind address may not be empty."
        )

    raw_port = os.environ.get(
        "OFFGRIDPI_DASHBOARD_PORT",
        str(DEFAULT_PORT),
    )

    try:
        port = int(raw_port)
    except ValueError as error:
        raise RuntimeError(
            "Dashboard port must be an integer."
        ) from error

    if not 1 <= port <= 65535:
        raise RuntimeError(
            "Dashboard port must be between 1 and 65535."
        )

    dashboard_root = Path(
        os.environ.get(
            "OFFGRIDPI_DASHBOARD_ROOT",
            str(DEFAULT_DASHBOARD_ROOT),
        )
    )

    if (
        dashboard_root.is_symlink()
        or not dashboard_root.is_dir()
    ):
        raise RuntimeError(
            "Dashboard root is unavailable or unsafe."
        )

    return bind_address, port, dashboard_root


class DashboardHandler(SimpleHTTPRequestHandler):
    server_version = "OffgridPiDashboard/1"
    sys_version = ""

    def end_headers(self) -> None:
        self.send_header(
            "Cache-Control",
            "no-cache",
        )
        self.send_header(
            "X-Content-Type-Options",
            "nosniff",
        )
        self.send_header(
            "Referrer-Policy",
            "no-referrer",
        )
        super().end_headers()

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


class DashboardServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main() -> int:
    try:
        bind_address, port, dashboard_root = configuration()

        handler = partial(
            DashboardHandler,
            directory=str(dashboard_root),
        )

        server = DashboardServer(
            (bind_address, port),
            handler,
        )
    except (
        OSError,
        RuntimeError,
    ) as error:
        return fail(str(error))

    print(
        "Offgrid Pi dashboard listening on "
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
