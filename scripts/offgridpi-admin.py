#!/usr/bin/env python3
"""Safe Offgrid Pi administration command."""

from __future__ import annotations

import argparse
import json
import os
import socket
import subprocess
import time
from pathlib import Path

STATUS_COMMAND = (
    Path(__file__).resolve().parent
    / "offgridpi-status.py"
)

DEFAULT_INDEX_COMMAND = (
    Path(__file__).resolve().parent
    / "index-documents.py"
)
INDEX_COMMAND = Path(
    os.environ.get(
        "OFFGRIDPI_INDEX_COMMAND",
        str(DEFAULT_INDEX_COMMAND),
    )
)
CATALOG_PATH = Path(
    os.environ.get(
        "OFFGRIDPI_CATALOG_PATH",
        "/srv/offgridpi/content/documents/public/catalog.json",
    )
)

SERVICES = {
    "kiwix": "kiwix-serve.service",
    "dashboard": "offgridpi-dashboard.service",
    "documents": "offgridpi-documents.service",
    "indexer": "offgridpi-document-indexer.service",
}

SERVICE_PORTS = {
    "kiwix": 8080,
    "dashboard": 8081,
    "documents": 8082,
    "indexer": None,
}


def show_status(as_json: bool) -> int:
    command = [str(STATUS_COMMAND)]

    if as_json:
        command.append("--json")

    result = subprocess.run(
        command,
        check=False,
    )
    return result.returncode


def preview_restart(service_alias: str) -> int:
    service = SERVICES[service_alias]

    print("=== Offgrid Pi Administration Preview ===")
    print("Action: Restart service")
    print(f"Service alias: {service_alias}")
    print(f"Systemd unit: {service}")
    print()
    print("No changes were made.")
    print()
    print("A confirmed action would:")
    print(f"  1. Restart {service}")
    print("  2. Verify that the service is active")
    print("  3. Verify its listener or dependent function")
    print("  4. Report success or failure")

    return 0



SYSTEMCTL_COMMAND = os.environ.get(
    "OFFGRIDPI_SYSTEMCTL",
    "systemctl",
)


def test_mode_enabled() -> bool:
    injected_dependency = (
        SYSTEMCTL_COMMAND != "systemctl"
        or "OFFGRIDPI_INDEX_COMMAND" in os.environ
        or "OFFGRIDPI_CATALOG_PATH" in os.environ
    )

    return (
        os.environ.get("OFFGRIDPI_TEST_MODE") == "1"
        and injected_dependency
    )


def run_systemctl(*arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [SYSTEMCTL_COMMAND, *arguments],
        capture_output=True,
        text=True,
        check=False,
    )


def port_listening(port: int) -> bool:
    try:
        with socket.create_connection(
            ("127.0.0.1", port),
            timeout=2,
        ):
            return True
    except OSError:
        return False


def restart_service(
    service_alias: str,
    confirm: bool,
) -> int:
    if not confirm:
        return preview_restart(service_alias)

    service = SERVICES[service_alias]
    port = SERVICE_PORTS[service_alias]

    if os.geteuid() != 0 and not test_mode_enabled():
        print("ERROR: Confirmed restarts require root.")
        print()
        print("Run:")
        print(
            "  sudo scripts/offgridpi-admin.py "
            f"restart-service {service_alias} --confirm"
        )
        return 2

    print("=== Offgrid Pi Administration ===")
    print(f"Restarting: {service}")

    result = run_systemctl("restart", service)

    if result.returncode != 0:
        message = (
            result.stderr.strip()
            or result.stdout.strip()
            or "Unknown systemctl error"
        )
        print(f"FAIL: Restart failed: {message}")
        return 1

    deadline = time.monotonic() + 10

    while time.monotonic() < deadline:
        active = (
            run_systemctl(
                "is-active",
                "--quiet",
                service,
            ).returncode
            == 0
        )

        listener_ready = (
            port is None
            or port_listening(port)
        )

        if active and listener_ready:
            print(f"PASS: {service} is active.")

            if port is not None:
                print(f"PASS: TCP port {port} is listening.")

            return 0

        time.sleep(1)

    print(
        f"FAIL: {service} did not become "
        "fully ready within 10 seconds."
    )
    return 1




def preview_reindex() -> int:
    print("=== Offgrid Pi Administration Preview ===")
    print("Action: Rebuild public document catalog")
    print(f"Indexer: {INDEX_COMMAND}")
    print()
    print("No changes were made.")
    print()
    print("A confirmed action would:")
    print("  1. Scan approved public document categories")
    print("  2. Rebuild index.html and catalog.json atomically")
    print("  3. Validate the generated JSON catalog")
    print("  4. Report the indexed document count")
    return 0


def reindex_documents(confirm: bool) -> int:
    if not confirm:
        return preview_reindex()

    if os.geteuid() != 0 and not test_mode_enabled():
        print("ERROR: Confirmed reindexing requires root.")
        print()
        print("Run:")
        print(
            "  sudo scripts/offgridpi-admin.py "
            "reindex-documents --confirm"
        )
        return 2

    if not INDEX_COMMAND.is_file():
        print(f"FAIL: Document indexer is missing: {INDEX_COMMAND}")
        return 1

    print("=== Offgrid Pi Administration ===")
    print("Rebuilding the public document catalog.")

    result = subprocess.run(
        [str(INDEX_COMMAND)],
        capture_output=True,
        text=True,
        check=False,
    )

    if result.stdout.strip():
        print(result.stdout.strip())

    if result.returncode != 0:
        message = (
            result.stderr.strip()
            or "Document indexer returned an error."
        )
        print(f"FAIL: Reindexing failed: {message}")
        return 1

    try:
        catalog = json.loads(
            CATALOG_PATH.read_text(encoding="utf-8")
        )
    except (OSError, json.JSONDecodeError) as error:
        print(f"FAIL: Generated catalog is invalid: {error}")
        return 1

    total = catalog.get("total_files")

    if not isinstance(total, int) or total < 0:
        print("FAIL: Generated catalog has an invalid file count.")
        return 1

    print("PASS: Public document catalog is valid.")
    print(f"PASS: Indexed document count: {total}")
    return 0




def preview_system_action(action: str) -> int:
    descriptions = {
        "reboot": "Restart the complete Offgrid Pi system",
        "poweroff": "Shut down and power off Offgrid Pi",
    }

    print("=== Offgrid Pi Administration Preview ===")
    print(f"Action: {descriptions[action]}")
    print()
    print("No changes were made.")
    print()
    print("This action requires:")
    print("  1. Root privileges")
    print("  2. The explicit confirmation phrase OFFGRIDPI")
    print()
    print("A confirmed action would:")
    print("  1. Request the action through systemd")
    print("  2. Return whether systemd accepted the request")
    print("  3. End local services and active sessions")
    return 0


def perform_system_action(
    action: str,
    confirmation: str | None,
) -> int:
    if confirmation is None:
        return preview_system_action(action)

    if confirmation != "OFFGRIDPI":
        print("ERROR: Confirmation phrase was not accepted.")
        print("Required phrase: OFFGRIDPI")
        return 2

    if os.geteuid() != 0 and not test_mode_enabled():
        print("ERROR: Confirmed system actions require root.")
        print()
        print("Example:")
        print(
            "  sudo scripts/offgridpi-admin.py "
            f"system-action {action} "
            "--confirm OFFGRIDPI"
        )
        return 2

    descriptions = {
        "reboot": "reboot",
        "poweroff": "power off",
    }

    print("=== Offgrid Pi Administration ===")
    print(
        f"Requesting system {descriptions[action]}."
    )

    result = run_systemctl("--no-block", action)

    if result.returncode != 0:
        message = (
            result.stderr.strip()
            or result.stdout.strip()
            or "Unknown systemctl error"
        )
        print(
            "FAIL: System action was rejected: "
            f"{message}"
        )
        return 1

    print(
        f"PASS: System {action} request was accepted."
    )
    return 0



def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Inspect and safely administer "
            "Offgrid Pi services."
        )
    )

    subparsers = parser.add_subparsers(
        dest="command",
        required=True,
    )

    status_parser = subparsers.add_parser(
        "status",
        help="Display the read-only system status.",
    )
    status_parser.add_argument(
        "--json",
        action="store_true",
        help="Display machine-readable JSON.",
    )

    restart_parser = subparsers.add_parser(
        "restart-service",
        help="Preview a service restart.",
    )
    restart_parser.add_argument(
        "service",
        choices=sorted(SERVICES),
        help="Service to preview.",
    )

    restart_parser.add_argument(
        "--confirm",
        action="store_true",
        help="Perform the restart instead of previewing it.",
    )

    reindex_parser = subparsers.add_parser(
        "reindex-documents",
        help="Preview or rebuild the public document catalog.",
    )
    reindex_parser.add_argument(
        "--confirm",
        action="store_true",
        help="Perform the catalog rebuild.",
    )

    system_parser = subparsers.add_parser(
        "system-action",
        help="Preview or request a system reboot or power-off.",
    )
    system_parser.add_argument(
        "action",
        choices=("reboot", "poweroff"),
        help="Whole-system action to preview.",
    )
    system_parser.add_argument(
        "--confirm",
        metavar="PHRASE",
        help=(
            "Perform the action only when PHRASE "
            "is exactly OFFGRIDPI."
        ),
    )

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    if args.command == "status":
        return show_status(args.json)

    if args.command == "restart-service":
        return restart_service(args.service, args.confirm)

    if args.command == "reindex-documents":
        return reindex_documents(args.confirm)

    if args.command == "system-action":
        return perform_system_action(
            args.action,
            args.confirm,
        )

    parser.error("Unsupported command")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
