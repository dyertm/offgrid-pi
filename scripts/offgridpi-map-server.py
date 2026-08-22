#!/usr/bin/env python3
"""Read-only HTTP server for the Offgrid Pi offline map reader."""

from __future__ import annotations

import json
import mimetypes
import os
import sys
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import BinaryIO
from urllib.parse import quote, unquote, urlsplit

DEFAULT_BIND = "0.0.0.0"
DEFAULT_PORT = 8084

DEFAULT_READER_ROOT = Path("/opt/offgridpi/maps")
DEFAULT_PACK_ROOT = Path("/srv/offgridpi/content/maps/packs")

READ_CHUNK_SIZE = 1024 * 1024

SECURITY_HEADERS = {
    "Content-Security-Policy": (
        "default-src 'self'; "
        "script-src 'self'; "
        "style-src 'self' 'unsafe-inline'; "
        "img-src 'self' data: blob:; "
        "connect-src 'self'; "
        "worker-src 'self' blob:; "
        "object-src 'none'; "
        "base-uri 'none'; "
        "form-action 'none'; "
        "frame-ancestors 'none'"
    ),
    "Referrer-Policy": "no-referrer",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Cross-Origin-Resource-Policy": "same-origin",
}


class RangeError(ValueError):
    """Raised when an HTTP Range header cannot be satisfied."""


def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def configuration() -> tuple[str, int, Path, Path]:
    bind_address = os.environ.get(
        "OFFGRIDPI_MAP_BIND",
        DEFAULT_BIND,
    ).strip()

    if not bind_address:
        raise RuntimeError(
            "Map-reader bind address may not be empty."
        )

    raw_port = os.environ.get(
        "OFFGRIDPI_MAP_PORT",
        str(DEFAULT_PORT),
    )

    try:
        port = int(raw_port)
    except ValueError as error:
        raise RuntimeError(
            "Map-reader port must be an integer."
        ) from error

    if not 1 <= port <= 65535:
        raise RuntimeError(
            "Map-reader port must be between 1 and 65535."
        )

    reader_root = Path(
        os.environ.get(
            "OFFGRIDPI_MAP_READER_ROOT",
            str(DEFAULT_READER_ROOT),
        )
    )

    pack_root = Path(
        os.environ.get(
            "OFFGRIDPI_MAP_PACK_ROOT",
            str(DEFAULT_PACK_ROOT),
        )
    )

    if reader_root.is_symlink() or not reader_root.is_dir():
        raise RuntimeError(
            "Map-reader application root is unavailable or unsafe."
        )

    if pack_root.is_symlink() or not pack_root.is_dir():
        raise RuntimeError(
            "Map-pack root is unavailable or unsafe."
        )

    return bind_address, port, reader_root, pack_root


def path_has_symlink_component(
    root: Path,
    destination: Path,
) -> bool:
    root = root.absolute()
    destination = destination.absolute()

    if root.is_symlink():
        return True

    try:
        relative = destination.relative_to(root)
    except ValueError:
        return True

    current = root

    for part in relative.parts:
        current = current / part

        if current.is_symlink():
            return True

    return False


def safe_relative_path(raw_path: str) -> Path:
    try:
        decoded = unquote(
            raw_path,
            errors="strict",
        )
    except UnicodeDecodeError as error:
        raise ValueError(
            "URL path is not valid UTF-8."
        ) from error

    if "\x00" in decoded:
        raise ValueError(
            "URL path contains a NUL byte."
        )

    if "\\" in decoded:
        raise ValueError(
            "Backslashes are not permitted in URL paths."
        )

    if not decoded.startswith("/"):
        raise ValueError(
            "URL path must be absolute."
        )

    components = decoded.split("/")[1:]

    for component in components:
        if component in {".", ".."}:
            raise ValueError(
                "Unsafe URL path component."
            )

    return Path(*components)


def safe_file(root: Path, relative: Path) -> Path:
    if relative.is_absolute():
        raise ValueError(
            "Absolute filesystem paths are not permitted."
        )

    if any(
        part in {"", ".", ".."}
        for part in relative.parts
    ):
        raise ValueError(
            "Unsafe filesystem path component."
        )

    destination = root / relative

    if path_has_symlink_component(
        root,
        destination,
    ):
        raise ValueError(
            "Filesystem path contains a symbolic link."
        )

    if destination.is_symlink():
        raise ValueError(
            "Filesystem target is a symbolic link."
        )

    try:
        resolved_root = root.resolve(strict=True)
        resolved_destination = destination.resolve(
            strict=True
        )
    except FileNotFoundError as error:
        raise FileNotFoundError(
            destination
        ) from error

    try:
        resolved_destination.relative_to(
            resolved_root
        )
    except ValueError as error:
        raise ValueError(
            "Filesystem target escapes its approved root."
        ) from error

    if not resolved_destination.is_file():
        raise FileNotFoundError(
            resolved_destination
        )

    return resolved_destination


def load_pack_manifest(
    pack_directory: Path,
) -> dict[str, object]:
    manifest_path = safe_file(
        pack_directory,
        Path("manifest.json"),
    )

    try:
        manifest = json.loads(
            manifest_path.read_text(
                encoding="utf-8"
            )
        )
    except (
        OSError,
        UnicodeDecodeError,
        json.JSONDecodeError,
    ) as error:
        raise RuntimeError(
            "Installed map-pack manifest is invalid."
        ) from error

    if not isinstance(manifest, dict):
        raise RuntimeError(
            "Installed map-pack manifest must be an object."
        )

    files = manifest.get("files")

    if not isinstance(files, list):
        raise RuntimeError(
            "Installed map-pack file declarations are invalid."
        )

    return manifest


def declared_pack_paths(
    manifest: dict[str, object],
) -> set[str]:
    declared: set[str] = set()

    files = manifest.get("files")

    if not isinstance(files, list):
        raise RuntimeError(
            "Installed map-pack file declarations are invalid."
        )

    for declaration in files:
        if not isinstance(declaration, dict):
            raise RuntimeError(
                "Installed map-pack file declaration is invalid."
            )

        path = declaration.get("path")

        if not isinstance(path, str) or not path:
            raise RuntimeError(
                "Installed map-pack file path is invalid."
            )

        declared.add(path)

    return declared


def discovery_entry(
    pack_root: Path,
    pack_directory: Path,
) -> dict[str, object] | None:
    if path_has_symlink_component(
        pack_root,
        pack_directory,
    ):
        return None

    if (
        pack_directory.is_symlink()
        or not pack_directory.is_dir()
    ):
        return None

    try:
        relative = pack_directory.relative_to(
            pack_root
        )
    except ValueError:
        return None

    if len(relative.parts) != 2:
        return None

    directory_pack_id, directory_version = (
        relative.parts
    )

    try:
        manifest = load_pack_manifest(
            pack_directory
        )
    except (
        OSError,
        RuntimeError,
        ValueError,
    ):
        return None

    pack_id = manifest.get("pack_id")
    version = manifest.get("version")
    name = manifest.get("name")
    status = manifest.get("status")
    description = manifest.get("description")
    data_date = manifest.get("data_date")
    style_id = manifest.get("style_id")
    tile_schema_id = manifest.get("tile_schema_id")
    sources = manifest.get("sources")
    limitations = manifest.get("limitations")
    region = manifest.get("region")
    files = manifest.get("files")

    if (
        not isinstance(pack_id, str)
        or pack_id != directory_pack_id
        or not isinstance(version, str)
        or version != directory_version
        or not isinstance(name, str)
        or not isinstance(status, str)
        or not isinstance(description, str)
        or not isinstance(data_date, str)
        or not isinstance(style_id, str)
        or not isinstance(tile_schema_id, str)
        or not isinstance(sources, list)
        or not isinstance(limitations, list)
        or not all(
            isinstance(item, str)
            for item in limitations
        )
        or not isinstance(region, dict)
        or not isinstance(files, list)
    ):
        return None

    region_name = region.get("name")
    bounds = region.get("bounds")
    default_center = region.get(
        "default_center"
    )
    min_zoom = region.get("min_zoom")
    max_zoom = region.get("max_zoom")

    if (
        not isinstance(region_name, str)
        or not isinstance(bounds, list)
        or len(bounds) != 4
        or not all(
            isinstance(value, (int, float))
            and not isinstance(value, bool)
            for value in bounds
        )
        or not isinstance(default_center, list)
        or len(default_center) != 2
        or not all(
            isinstance(value, (int, float))
            and not isinstance(value, bool)
            for value in default_center
        )
        or not isinstance(min_zoom, (int, float))
        or isinstance(min_zoom, bool)
        or not isinstance(max_zoom, (int, float))
        or isinstance(max_zoom, bool)
    ):
        return None

    basemap_path: str | None = None

    for declaration in files:
        if not isinstance(declaration, dict):
            return None

        if declaration.get("role") != "basemap":
            continue

        candidate = declaration.get("path")

        if (
            basemap_path is not None
            or not isinstance(candidate, str)
            or not candidate
        ):
            return None

        try:
            safe_file(
                pack_directory,
                Path(candidate),
            )
        except (
            FileNotFoundError,
            OSError,
            ValueError,
        ):
            return None

        basemap_path = candidate

    if basemap_path is None:
        return None

    attributions: list[dict[str, str]] = []

    for source in sources:
        if not isinstance(source, dict):
            return None

        source_name = source.get("name")
        source_attribution = source.get("attribution")

        if (
            not isinstance(source_name, str)
            or not source_name
            or not isinstance(source_attribution, str)
            or not source_attribution
        ):
            return None

        attributions.append(
            {
                "name": source_name,
                "attribution": source_attribution,
            }
        )

    encoded_pack_id = quote(
        pack_id,
        safe="",
    )
    encoded_version = quote(
        version,
        safe="",
    )
    encoded_basemap = "/".join(
        quote(part, safe="")
        for part in Path(
            basemap_path
        ).parts
    )

    return {
        "pack_id": pack_id,
        "name": name,
        "version": version,
        "status": status,
        "description": description,
        "data_date": data_date,
        "style_id": style_id,
        "tile_schema_id": tile_schema_id,
        "attributions": attributions,
        "limitations": limitations,
        "region": {
            "name": region_name,
            "bounds": bounds,
            "default_center": default_center,
            "min_zoom": min_zoom,
            "max_zoom": max_zoom,
        },
        "manifest_url": (
            f"/packs/{encoded_pack_id}/"
            f"{encoded_version}/manifest.json"
        ),
        "basemap_url": (
            f"/packs/{encoded_pack_id}/"
            f"{encoded_version}/{encoded_basemap}"
        ),
    }


def discover_installed_packs(
    pack_root: Path,
) -> list[dict[str, object]]:
    discovered: list[dict[str, object]] = []

    try:
        pack_directories = sorted(
            pack_root.iterdir(),
            key=lambda path: path.name,
        )
    except OSError:
        return discovered

    for pack_container in pack_directories:
        if (
            pack_container.is_symlink()
            or not pack_container.is_dir()
            or path_has_symlink_component(
                pack_root,
                pack_container,
            )
        ):
            continue

        try:
            version_directories = sorted(
                pack_container.iterdir(),
                key=lambda path: path.name,
            )
        except OSError:
            continue

        for pack_directory in version_directories:
            entry = discovery_entry(
                pack_root,
                pack_directory,
            )

            if entry is not None:
                discovered.append(entry)

    return discovered


def content_type_for(path: Path) -> str:
    if path.suffix.lower() == ".pmtiles":
        return "application/vnd.pmtiles"

    guessed, _ = mimetypes.guess_type(path.name)

    if guessed:
        if guessed.startswith("text/"):
            return f"{guessed}; charset=utf-8"

        return guessed

    return "application/octet-stream"


def parse_range_header(
    value: str,
    file_size: int,
) -> tuple[int, int]:
    if file_size <= 0:
        raise RangeError(
            "Range cannot be satisfied for an empty file."
        )

    if not value.startswith("bytes="):
        raise RangeError(
            "Only byte ranges are supported."
        )

    specification = value[6:].strip()

    if not specification or "," in specification:
        raise RangeError(
            "Exactly one byte range is supported."
        )

    if "-" not in specification:
        raise RangeError(
            "Malformed byte range."
        )

    first, last = specification.split("-", 1)

    if not first:
        try:
            suffix_length = int(last)
        except ValueError as error:
            raise RangeError(
                "Malformed suffix byte range."
            ) from error

        if suffix_length <= 0:
            raise RangeError(
                "Suffix byte range must be positive."
            )

        start = max(
            file_size - suffix_length,
            0,
        )
        end = file_size - 1

        return start, end

    try:
        start = int(first)
    except ValueError as error:
        raise RangeError(
            "Malformed byte-range start."
        ) from error

    if start < 0 or start >= file_size:
        raise RangeError(
            "Byte-range start is outside the file."
        )

    if not last:
        return start, file_size - 1

    try:
        end = int(last)
    except ValueError as error:
        raise RangeError(
            "Malformed byte-range end."
        ) from error

    if end < start:
        raise RangeError(
            "Byte-range end precedes its start."
        )

    return start, min(
        end,
        file_size - 1,
    )


def stream_bytes(
    source: BinaryIO,
    output: BinaryIO,
    count: int,
) -> None:
    remaining = count

    while remaining > 0:
        chunk = source.read(
            min(
                READ_CHUNK_SIZE,
                remaining,
            )
        )

        if not chunk:
            break

        output.write(chunk)
        remaining -= len(chunk)

    if remaining != 0:
        raise OSError(
            "File changed while it was being served."
        )


class MapReaderHandler(BaseHTTPRequestHandler):
    server_version = "OffgridPiMaps/1"
    sys_version = ""
    protocol_version = "HTTP/1.1"

    def send_security_headers(self) -> None:
        for name, value in SECURITY_HEADERS.items():
            self.send_header(name, value)

    def send_error_body(
        self,
        status: HTTPStatus,
        message: str,
        *,
        include_body: bool,
        allow: str | None = None,
        content_range: str | None = None,
    ) -> None:
        body = (
            f"{message}\n"
        ).encode("utf-8")

        self.send_response(status)

        if allow is not None:
            self.send_header(
                "Allow",
                allow,
            )

        if content_range is not None:
            self.send_header(
                "Content-Range",
                content_range,
            )

        self.send_header(
            "Content-Type",
            "text/plain; charset=utf-8",
        )
        self.send_header(
            "Content-Length",
            str(len(body)),
        )
        self.send_header(
            "Cache-Control",
            "no-store",
        )
        self.send_security_headers()
        self.end_headers()

        if include_body:
            self.wfile.write(body)

    def is_pack_discovery_request(self) -> bool:
        request_path = urlsplit(
            self.path
        ).path

        try:
            relative = safe_relative_path(
                request_path
            )
        except ValueError:
            return False

        return relative == Path("api/packs")

    def serve_pack_discovery(
        self,
        *,
        include_body: bool,
    ) -> None:
        payload = {
            "schema_version": 1,
            "packs": discover_installed_packs(
                self.server.pack_root
            ),
        }

        body = (
            json.dumps(
                payload,
                separators=(",", ":"),
                ensure_ascii=False,
            )
            + "\n"
        ).encode("utf-8")

        self.send_response(
            HTTPStatus.OK
        )
        self.send_header(
            "Content-Type",
            "application/json; charset=utf-8",
        )
        self.send_header(
            "Content-Length",
            str(len(body)),
        )
        self.send_header(
            "Cache-Control",
            "no-cache",
        )
        self.send_security_headers()
        self.end_headers()

        if include_body:
            self.wfile.write(body)

    def resolve_request_path(self) -> tuple[Path, bool]:
        request_path = urlsplit(
            self.path
        ).path

        relative = safe_relative_path(
            request_path
        )

        parts = relative.parts

        if not parts:
            return (
                safe_file(
                    self.server.reader_root,
                    Path("index.html"),
                ),
                False,
            )

        if parts[0] != "packs":
            return (
                safe_file(
                    self.server.reader_root,
                    relative,
                ),
                False,
            )

        if len(parts) < 4:
            raise FileNotFoundError(
                request_path
            )

        pack_id = parts[1]
        version = parts[2]
        requested_relative = Path(
            *parts[3:]
        )

        pack_directory = (
            self.server.pack_root
            / pack_id
            / version
        )

        if path_has_symlink_component(
            self.server.pack_root,
            pack_directory,
        ):
            raise ValueError(
                "Map-pack path contains a symbolic link."
            )

        if (
            pack_directory.is_symlink()
            or not pack_directory.is_dir()
        ):
            raise FileNotFoundError(
                pack_directory
            )

        manifest = load_pack_manifest(
            pack_directory
        )

        requested_name = (
            requested_relative.as_posix()
        )

        if requested_name != "manifest.json":
            declared = declared_pack_paths(
                manifest
            )

            if requested_name not in declared:
                raise FileNotFoundError(
                    requested_name
                )

        return (
            safe_file(
                pack_directory,
                requested_relative,
            ),
            True,
        )

    def serve_file(
        self,
        *,
        include_body: bool,
    ) -> None:
        try:
            path, is_pack_file = (
                self.resolve_request_path()
            )
        except FileNotFoundError:
            self.send_error_body(
                HTTPStatus.NOT_FOUND,
                "Not found.",
                include_body=include_body,
            )
            return
        except (
            OSError,
            RuntimeError,
            ValueError,
        ):
            self.send_error_body(
                HTTPStatus.NOT_FOUND,
                "Not found.",
                include_body=include_body,
            )
            return

        try:
            file_size = path.stat().st_size
        except OSError:
            self.send_error_body(
                HTTPStatus.NOT_FOUND,
                "Not found.",
                include_body=include_body,
            )
            return

        range_header = self.headers.get(
            "Range"
        )

        start = 0
        end = max(
            file_size - 1,
            0,
        )
        status = HTTPStatus.OK

        if range_header is not None:
            try:
                start, end = parse_range_header(
                    range_header,
                    file_size,
                )
            except RangeError:
                self.send_error_body(
                    HTTPStatus.REQUESTED_RANGE_NOT_SATISFIABLE,
                    "Requested byte range is not satisfiable.",
                    include_body=include_body,
                    content_range=(
                        f"bytes */{file_size}"
                    ),
                )
                return

            status = HTTPStatus.PARTIAL_CONTENT

        if file_size == 0:
            content_length = 0
        else:
            content_length = end - start + 1

        self.send_response(status)
        self.send_header(
            "Content-Type",
            content_type_for(path),
        )
        self.send_header(
            "Content-Length",
            str(content_length),
        )
        self.send_header(
            "Accept-Ranges",
            "bytes",
        )

        if status == HTTPStatus.PARTIAL_CONTENT:
            self.send_header(
                "Content-Range",
                (
                    f"bytes {start}-{end}/"
                    f"{file_size}"
                ),
            )

        if is_pack_file:
            self.send_header(
                "Cache-Control",
                "public, max-age=3600",
            )
        else:
            self.send_header(
                "Cache-Control",
                "no-cache",
            )

        self.send_security_headers()
        self.end_headers()

        if not include_body or content_length == 0:
            return

        try:
            with path.open("rb") as source:
                source.seek(start)

                stream_bytes(
                    source,
                    self.wfile,
                    content_length,
                )
        except (
            BrokenPipeError,
            ConnectionResetError,
        ):
            return

    def do_GET(self) -> None:
        if self.is_pack_discovery_request():
            self.serve_pack_discovery(
                include_body=True
            )
            return

        self.serve_file(
            include_body=True
        )

    def do_HEAD(self) -> None:
        if self.is_pack_discovery_request():
            self.serve_pack_discovery(
                include_body=False
            )
            return

        self.serve_file(
            include_body=False
        )

    def reject_method(self) -> None:
        self.send_error_body(
            HTTPStatus.METHOD_NOT_ALLOWED,
            "Method not allowed.",
            include_body=True,
            allow="GET, HEAD",
        )

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


class MapReaderServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(
        self,
        address: tuple[str, int],
        reader_root: Path,
        pack_root: Path,
    ) -> None:
        self.reader_root = reader_root
        self.pack_root = pack_root

        super().__init__(
            address,
            MapReaderHandler,
        )


def main() -> int:
    try:
        (
            bind_address,
            port,
            reader_root,
            pack_root,
        ) = configuration()

        server = MapReaderServer(
            (bind_address, port),
            reader_root,
            pack_root,
        )
    except (
        OSError,
        RuntimeError,
    ) as error:
        return fail(str(error))

    print(
        "Offgrid Pi map reader listening on "
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
