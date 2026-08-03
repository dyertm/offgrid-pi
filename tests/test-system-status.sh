#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMAND="$ROOT/scripts/offgridpi-status.py"
TEMP_JSON="$(mktemp)"

cleanup() {
  rm -f "$TEMP_JSON"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*"
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

[[ -x "$COMMAND" ]] ||
  fail "System-status command is missing or not executable."

pass "System-status command exists and is executable."

python3 -c \
  'from pathlib import Path; p=Path("'"$COMMAND"'"); compile(p.read_text(), str(p), "exec")' ||
  fail "Python syntax validation failed."

pass "Python syntax is valid."

"$COMMAND" --json > "$TEMP_JSON"
STATUS_CODE=$?

if [[ "$STATUS_CODE" -ne 0 && "$STATUS_CODE" -ne 1 ]]; then
  fail "Unexpected status-command exit code: $STATUS_CODE"
fi

pass "Status command returned a supported exit code."

python3 - "$TEMP_JSON" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
report = json.loads(path.read_text(encoding="utf-8"))

required = {
    "hostname",
    "uptime_seconds",
    "hardware",
    "storage",
    "services",
    "failed_units",
    "kiwix",
    "documents",
    "backups",
    "overall",
}

missing = sorted(required - report.keys())
if missing:
    raise SystemExit(
        "Missing report fields: " + ", ".join(missing)
    )

if report["overall"] not in {"HEALTHY", "ATTENTION"}:
    raise SystemExit("Invalid overall state")

if not isinstance(report["services"], list):
    raise SystemExit("Services field is not a list")

expected_services = {
    "kiwix-serve.service",
    "offgridpi-dashboard.service",
    "offgridpi-documents.service",
    "offgridpi-document-indexer.service",
}

reported_services = {
    item.get("service")
    for item in report["services"]
}

missing_services = sorted(
    expected_services - reported_services
)

if missing_services:
    raise SystemExit(
        "Missing services: " + ", ".join(missing_services)
    )

storage = report["storage"]
for field in (
    "total_bytes",
    "used_bytes",
    "free_bytes",
    "used_percent",
):
    if field not in storage:
        raise SystemExit(
            f"Storage field missing: {field}"
        )

print("PASS: JSON status report structure is valid.")
print(f"Overall system state: {report['overall']}")
PY

python3 - "$COMMAND" <<'PY'
import importlib.util
import sys
from pathlib import Path

command = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location(
    "offgridpi_status",
    command,
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

report = {
    "services": [
        {
            "name": "Kiwix",
            "service": "kiwix-serve.service",
            "active": "inactive",
            "enabled": "disabled",
            "required": False,
            "port": 8080,
            "listening": False,
            "http_status": "unavailable",
        }
    ],
    "failed_units": [],
}

if module.overall_state(report) != "HEALTHY":
    raise SystemExit(
        "Optional empty-library Kiwix state was not healthy."
    )

print(
    "PASS: Empty Kiwix libraries are accepted as healthy."
)
PY
