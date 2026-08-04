#!/usr/bin/env python3
"""Publish a restricted Offgrid Pi service-log snapshot."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

DEFAULT_JOURNALCTL = "/usr/bin/journalctl"
DEFAULT_OUTPUT = (
    "/var/lib/offgridpi/management/system-logs.json"
)
DEFAULT_ENTRY_LIMIT = 25
MAX_ENTRY_LIMIT = 100
MAX_MESSAGE_LENGTH = 600

LOG_SOURCES = (
    ("Kiwix", "kiwix-serve.service"),
    ("Dashboard", "offgridpi-dashboard.service"),
    ("Documents", "offgridpi-documents.service"),
    (
        "Document Indexer",
        "offgridpi-document-indexer.service",
    ),
    (
        "Status Publisher",
        "offgridpi-status-publisher.service",
    ),
)

PRIORITY_NAMES = {
    0: "Emergency",
    1: "Alert",
    2: "Critical",
    3: "Error",
    4: "Warning",
    5: "Notice",
    6: "Info",
    7: "Debug",
}

ANSI_PATTERN = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")

SENSITIVE_PATTERN = re.compile(
    r"(?i)\b"
    r"(authorization|token|password|secret|api[_-]?key)"
    r"\b\s*[:=]\s*\S+"
)

URL_SECRET_PATTERN = re.compile(
    r"(?i)([?&](?:token|key|secret|password)=)"
    r"[^&\s]+"
)


def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def configured_limit() -> int:
    raw_value = os.environ.get(
        "OFFGRIDPI_LOG_LIMIT",
        str(DEFAULT_ENTRY_LIMIT),
    )

    try:
        value = int(raw_value)
    except ValueError as error:
        raise RuntimeError(
            "OFFGRIDPI_LOG_LIMIT must be an integer."
        ) from error

    if not 1 <= value <= MAX_ENTRY_LIMIT:
        raise RuntimeError(
            "OFFGRIDPI_LOG_LIMIT must be between "
            f"1 and {MAX_ENTRY_LIMIT}."
        )

    return value


def resolve_command() -> str:
    configured = os.environ.get(
        "OFFGRIDPI_JOURNALCTL",
        DEFAULT_JOURNALCTL,
    )

    if "/" in configured:
        path = Path(configured)

        if not path.is_file() or not os.access(path, os.X_OK):
            raise RuntimeError(
                f"journalctl command is not executable: {configured}"
            )

        return configured

    resolved = shutil.which(configured)

    if resolved is None:
        raise RuntimeError(
            f"journalctl command was not found: {configured}"
        )

    return resolved


def format_timestamp(value: Any) -> str | None:
    try:
        microseconds = int(value)
    except (TypeError, ValueError):
        return None

    timestamp = datetime.fromtimestamp(
        microseconds / 1_000_000,
        tz=timezone.utc,
    )

    return timestamp.isoformat().replace("+00:00", "Z")


def sanitize_message(value: Any) -> str:
    if isinstance(value, list):
        text = " ".join(str(item) for item in value)
    else:
        text = str(value or "")

    text = ANSI_PATTERN.sub("", text)
    text = text.replace("\r", " ")
    text = text.replace("\n", " ")
    text = text.replace("\t", " ")

    text = "".join(
        character if character.isprintable() else " "
        for character in text
    )

    text = " ".join(text.split())

    text = SENSITIVE_PATTERN.sub(
        lambda match: (
            f"{match.group(1)}=[REDACTED]"
        ),
        text,
    )

    text = URL_SECRET_PATTERN.sub(
        lambda match: (
            f"{match.group(1)}[REDACTED]"
        ),
        text,
    )

    if len(text) > MAX_MESSAGE_LENGTH:
        text = (
            text[: MAX_MESSAGE_LENGTH - 1].rstrip()
            + "…"
        )

    return text


def normalize_entry(record: dict[str, Any]) -> dict[str, Any]:
    raw_priority = record.get("PRIORITY", 6)

    try:
        priority = int(raw_priority)
    except (TypeError, ValueError):
        priority = 6

    if priority not in PRIORITY_NAMES:
        priority = 6

    return {
        "timestamp": format_timestamp(
            record.get("__REALTIME_TIMESTAMP")
        ),
        "priority": priority,
        "priority_name": PRIORITY_NAMES[priority],
        "message": sanitize_message(
            record.get("MESSAGE")
        ),
    }


def collect_source(
    journalctl: str,
    display_name: str,
    unit: str,
    limit: int,
) -> dict[str, Any]:
    command = [
        journalctl,
        "--no-pager",
        "--output=json",
        "--unit",
        unit,
        "--lines",
        str(limit),
    ]

    result = subprocess.run(
        command,
        check=False,
        capture_output=True,
        text=True,
        timeout=30,
    )

    if result.returncode != 0:
        detail = result.stderr.strip() or "unknown error"
        raise RuntimeError(
            f"Could not read {unit}: {detail}"
        )

    entries: list[dict[str, Any]] = []

    for line_number, line in enumerate(
        result.stdout.splitlines(),
        start=1,
    ):
        if not line.strip():
            continue

        try:
            record = json.loads(line)
        except json.JSONDecodeError as error:
            raise RuntimeError(
                f"Invalid journal JSON for {unit} "
                f"on line {line_number}."
            ) from error

        if not isinstance(record, dict):
            raise RuntimeError(
                f"Unexpected journal record for {unit}."
            )

        entries.append(normalize_entry(record))

    entries.reverse()

    return {
        "name": display_name,
        "unit": unit,
        "entry_count": len(entries),
        "entries": entries,
    }


def write_report(
    report: dict[str, Any],
    output_path: Path,
) -> None:
    output_directory = output_path.parent

    if not output_directory.exists():
        output_directory.mkdir(
            parents=True,
            mode=0o750,
        )

    if not output_directory.is_dir():
        raise RuntimeError(
            f"Output directory is invalid: {output_directory}"
        )

    if not os.access(output_directory, os.W_OK):
        raise RuntimeError(
            f"Output directory is not writable: "
            f"{output_directory}"
        )

    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{output_path.name}.",
        dir=output_directory,
        text=True,
    )

    temporary_path = Path(temporary_name)

    try:
        with os.fdopen(
            descriptor,
            "w",
            encoding="utf-8",
        ) as handle:
            json.dump(
                report,
                handle,
                indent=2,
                sort_keys=True,
            )
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())

        temporary_path.chmod(0o640)
        os.replace(temporary_path, output_path)
    except Exception:
        temporary_path.unlink(missing_ok=True)
        raise


def main() -> int:
    try:
        journalctl = resolve_command()
        entry_limit = configured_limit()

        output_path = Path(
            os.environ.get(
                "OFFGRIDPI_LOG_OUTPUT",
                DEFAULT_OUTPUT,
            )
        )

        sources = [
            collect_source(
                journalctl,
                display_name,
                unit,
                entry_limit,
            )
            for display_name, unit in LOG_SOURCES
        ]

        report = {
            "schema_version": 1,
            "generated_at": (
                datetime.now(timezone.utc)
                .isoformat()
                .replace("+00:00", "Z")
            ),
            "entry_limit": entry_limit,
            "source_count": len(sources),
            "sources": sources,
        }

        write_report(report, output_path)

    except (
        OSError,
        RuntimeError,
        subprocess.SubprocessError,
    ) as error:
        return fail(str(error))

    print(
        "PASS: Restricted system-log snapshot published "
        f"to {output_path}."
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
