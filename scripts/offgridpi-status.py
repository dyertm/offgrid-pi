#!/usr/bin/env python3
"""Read-only Offgrid Pi system status report."""

from __future__ import annotations

import argparse
import json
import shutil
import socket
import subprocess
import time
from pathlib import Path
from urllib.error import URLError
from urllib.request import urlopen

SERVICES = (
    ("Kiwix", "kiwix-serve.service", 8080),
    ("Dashboard", "offgridpi-dashboard.service", 8081),
    ("Documents", "offgridpi-documents.service", 8082),
    (
        "Document indexer",
        "offgridpi-document-indexer.service",
        None,
    ),
)

KIWIX_ROOT = Path("/srv/offgridpi/content/kiwix")
DOCUMENT_ROOT = Path(
    "/srv/offgridpi/content/documents/public"
)
CATALOG = DOCUMENT_ROOT / "catalog.json"
BACKUP_ROOT = Path(
    "/srv/offgridpi/backups/configuration"
)


def run_command(*command: str) -> tuple[int, str]:
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=False,
            timeout=10,
        )
    except (
        FileNotFoundError,
        subprocess.TimeoutExpired,
    ):
        return 127, ""

    output = (
        result.stdout.strip()
        or result.stderr.strip()
    )
    return result.returncode, output


def service_state(service: str) -> dict[str, str]:
    enabled_code, enabled_output = run_command(
        "systemctl",
        "is-enabled",
        service,
    )
    active_code, active_output = run_command(
        "systemctl",
        "is-active",
        service,
    )

    return {
        "enabled": (
            enabled_output
            if enabled_output
            else (
                "enabled"
                if enabled_code == 0
                else "unknown"
            )
        ),
        "active": (
            active_output
            if active_output
            else (
                "active"
                if active_code == 0
                else "unknown"
            )
        ),
    }


def port_listening(port: int) -> bool:
    try:
        with socket.create_connection(
            ("127.0.0.1", port),
            timeout=2,
        ):
            return True
    except OSError:
        return False


def http_status(port: int) -> str:
    try:
        with urlopen(
            f"http://127.0.0.1:{port}/",
            timeout=3,
        ) as response:
            return str(response.status)
    except URLError:
        return "unavailable"


def storage_status(path: Path) -> dict[str, object]:
    target = path if path.exists() else Path("/")

    usage = shutil.disk_usage(target)

    return {
        "path": str(target),
        "total_bytes": usage.total,
        "used_bytes": usage.used,
        "free_bytes": usage.free,
        "used_percent": round(
            usage.used / usage.total * 100,
            1,
        ),
    }


def format_bytes(value: int) -> str:
    amount = float(value)

    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if amount < 1024 or unit == "TiB":
            if unit == "B":
                return f"{int(amount)} {unit}"
            return f"{amount:.1f} {unit}"

        amount /= 1024

    return f"{value} B"


def hardware_status() -> dict[str, str]:
    temperature = "unavailable"
    throttled = "unavailable"

    if shutil.which("vcgencmd"):
        _, temperature_output = run_command(
            "vcgencmd",
            "measure_temp",
        )
        _, throttled_output = run_command(
            "vcgencmd",
            "get_throttled",
        )

        if temperature_output:
            temperature = temperature_output

        if throttled_output:
            throttled = throttled_output

    return {
        "temperature": temperature,
        "throttled": throttled,
    }


def approved_zims() -> list[str]:
    if not KIWIX_ROOT.is_dir():
        return []

    files: list[str] = []

    for path in KIWIX_ROOT.rglob("*.zim"):
        try:
            relative = path.relative_to(KIWIX_ROOT)
        except ValueError:
            continue

        if "rejected" in relative.parts:
            continue

        if path.is_file() and not path.is_symlink():
            files.append(str(path))

    return sorted(files)


def document_catalog_status() -> dict[str, object]:
    if not CATALOG.is_file():
        return {
            "available": False,
            "total_files": 0,
        }

    try:
        catalog = json.loads(
            CATALOG.read_text(encoding="utf-8")
        )
    except (OSError, json.JSONDecodeError):
        return {
            "available": False,
            "total_files": 0,
        }

    return {
        "available": True,
        "total_files": catalog.get(
            "total_files",
            0,
        ),
        "generated_at": catalog.get(
            "generated_at",
            "unknown",
        ),
    }


def backup_status() -> dict[str, object]:
    if not BACKUP_ROOT.is_dir():
        return {
            "count": 0,
            "latest": None,
        }

    snapshots = sorted(
        path
        for path in BACKUP_ROOT.glob("snapshot-*")
        if path.is_dir()
    )

    return {
        "count": len(snapshots),
        "latest": (
            str(snapshots[-1])
            if snapshots
            else None
        ),
    }


def build_report() -> dict[str, object]:
    zims = approved_zims()
    service_report = []

    for name, service, port in SERVICES:
        state = service_state(service)

        item: dict[str, object] = {
            "name": name,
            "service": service,
            "enabled": state["enabled"],
            "active": state["active"],
            "required": (
                service != "kiwix-serve.service"
                or bool(zims)
            ),
        }

        if port is not None:
            item["port"] = port
            item["listening"] = port_listening(port)
            item["http_status"] = http_status(port)

        service_report.append(item)

    failed_code, failed_output = run_command(
        "systemctl",
        "--failed",
        "--no-legend",
    )

    uptime_seconds = int(
        time.clock_gettime(
            time.CLOCK_BOOTTIME
        )
    )

    return {
        "hostname": socket.gethostname(),
        "uptime_seconds": uptime_seconds,
        "hardware": hardware_status(),
        "storage": storage_status(
            Path("/srv/offgridpi")
        ),
        "services": service_report,
        "failed_units": (
            []
            if failed_code == 0 and not failed_output
            else failed_output.splitlines()
        ),
        "kiwix": {
            "approved_zim_count": len(zims),
            "approved_zims": zims,
        },
        "documents": document_catalog_status(),
        "backups": backup_status(),
    }


def overall_state(report: dict[str, object]) -> str:
    services = report["services"]

    for item in services:
        if not item.get("required", True):
            continue

        if item["active"] != "active":
            return "ATTENTION"

        if (
            "port" in item
            and not item.get("listening", False)
        ):
            return "ATTENTION"

        if (
            "http_status" in item
            and item["http_status"]
            not in {"200", "301", "302"}
        ):
            return "ATTENTION"

    if report["failed_units"]:
        return "ATTENTION"

    return "HEALTHY"


def print_report(report: dict[str, object]) -> None:
    state = overall_state(report)
    storage = report["storage"]
    hardware = report["hardware"]

    print("=== Offgrid Pi System Status ===")
    print(f"Overall: {state}")
    print(f"Hostname: {report['hostname']}")
    print(
        "Uptime: "
        f"{report['uptime_seconds'] // 3600} hour(s)"
    )
    print(
        f"Temperature: {hardware['temperature']}"
    )
    print(
        f"Throttle status: {hardware['throttled']}"
    )
    print()

    print("Storage")
    print(
        f"  Used: {format_bytes(storage['used_bytes'])}"
    )
    print(
        f"  Free: {format_bytes(storage['free_bytes'])}"
    )
    print(
        f"  Utilization: {storage['used_percent']}%"
    )
    print()

    print("Services")

    for item in report["services"]:
        if not item.get("required", True):
            print(
                f"  {item['name']}: not required "
                "(no approved ZIM files)"
            )
            continue

        line = (
            f"  {item['name']}: "
            f"{item['active']} / {item['enabled']}"
        )

        if "port" in item:
            line += (
                f" | TCP {item['port']}: "
                f"{'listening' if item['listening'] else 'closed'}"
                f" | HTTP: {item['http_status']}"
            )

        print(line)

    print()
    print("Content")
    print(
        "  Approved ZIM files: "
        f"{report['kiwix']['approved_zim_count']}"
    )
    print(
        "  Indexed documents: "
        f"{report['documents']['total_files']}"
    )
    print(
        "  Configuration snapshots: "
        f"{report['backups']['count']}"
    )
    print(
        "  Failed systemd units: "
        f"{len(report['failed_units'])}"
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Display read-only Offgrid Pi "
            "system health information."
        )
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output machine-readable JSON.",
    )
    args = parser.parse_args()

    report = build_report()
    report["overall"] = overall_state(report)

    if args.json:
        print(
            json.dumps(
                report,
                indent=2,
                ensure_ascii=False,
            )
        )
    else:
        print_report(report)

    return (
        0
        if report["overall"] == "HEALTHY"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
