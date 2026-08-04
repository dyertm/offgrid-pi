#!/usr/bin/env bash
set -uo pipefail

STATUS_COMMAND="${OFFGRIDPI_STATUS_COMMAND:-/opt/offgridpi/scripts/offgridpi-status.py}"
OUTPUT_PATH="${OFFGRIDPI_STATUS_OUTPUT:-/opt/offgridpi/dashboard/data/system-status.json}"
OUTPUT_DIR="$(dirname "$OUTPUT_PATH")"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -x "$STATUS_COMMAND" ]] ||
  fail "Status command is unavailable: $STATUS_COMMAND"

if [[ ! -d "$OUTPUT_DIR" ]]; then
  mkdir -p "$OUTPUT_DIR" ||
    fail "Could not create output directory."

  chmod 0755 "$OUTPUT_DIR" ||
    fail "Could not set output-directory permissions."
fi

[[ -w "$OUTPUT_DIR" ]] ||
  fail "Output directory is not writable: $OUTPUT_DIR"

TEMP_FILE="$(mktemp "$OUTPUT_DIR/.system-status.XXXXXX")" ||
  fail "Could not create temporary status file."

cleanup() {
  rm -f "$TEMP_FILE"
}
trap cleanup EXIT

if "$STATUS_COMMAND" --json > "$TEMP_FILE"; then
  STATUS_CODE=0
else
  STATUS_CODE=$?
fi

if [[ "$STATUS_CODE" -ne 0 && "$STATUS_CODE" -ne 1 ]]; then
  fail "Status command returned unsupported exit code $STATUS_CODE."
fi

if ! python3 - "$TEMP_FILE" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])

try:
    report = json.loads(path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as error:
    raise SystemExit(f"Invalid status JSON: {error}")

required = {
    "hostname",
    "uptime_seconds",
    "hardware",
    "storage",
    "services",
    "kiwix",
    "documents",
    "backups",
    "overall",
}

missing = sorted(required - report.keys())

if missing:
    raise SystemExit(
        "Missing status fields: " + ", ".join(missing)
    )

if report["overall"] not in {"HEALTHY", "ATTENTION"}:
    raise SystemExit("Invalid overall system state.")
PY
then
  fail "Generated status JSON failed validation."
fi

chmod 0644 "$TEMP_FILE" ||
  fail "Could not set status-file permissions."

mv -f "$TEMP_FILE" "$OUTPUT_PATH" ||
  fail "Could not publish status file."

trap - EXIT

printf 'PASS: Published system status: %s\n' "$OUTPUT_PATH"
exit "$STATUS_CODE"
