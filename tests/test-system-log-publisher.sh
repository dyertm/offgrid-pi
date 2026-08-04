#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLISHER="$ROOT/scripts/publish-system-logs.py"
TEMP_ROOT="$(mktemp -d)"
FAKE_JOURNAL="$TEMP_ROOT/journalctl"
OUTPUT="$TEMP_ROOT/system-logs.json"

cleanup() {
  rm -rf "$TEMP_ROOT"
}

trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

[[ -x "$PUBLISHER" ]] ||
  fail "Log publisher is missing or not executable."

cat > "$FAKE_JOURNAL" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail

case "${FAKE_JOURNAL_MODE:-valid}" in
  valid)
    python3 - <<'PY'
import json

records = [
    {
        "__REALTIME_TIMESTAMP": "1700000000000000",
        "PRIORITY": "6",
        "MESSAGE": "Oldest informational message",
    },
    {
        "__REALTIME_TIMESTAMP": "1700000001000000",
        "PRIORITY": "4",
        "MESSAGE": (
            "Authorization: topsecret "
            "token=abc123 "
            "url=https://example.invalid/?key=hunter2"
        ),
    },
    {
        "__REALTIME_TIMESTAMP": "1700000002000000",
        "PRIORITY": "3",
        "MESSAGE": "\u001b[31mNewest message " + ("x" * 700),
    },
]

for record in records:
    print(json.dumps(record))
PY
    ;;

  empty)
    exit 0
    ;;

  invalid)
    printf '{invalid journal json\n'
    ;;

  fail)
    printf 'Simulated journal failure\n' >&2
    exit 4
    ;;

  *)
    printf 'Unknown fake journal mode\n' >&2
    exit 9
    ;;
esac
FAKE

chmod 0755 "$FAKE_JOURNAL"

env \
  FAKE_JOURNAL_MODE=valid \
  OFFGRIDPI_JOURNALCTL="$FAKE_JOURNAL" \
  OFFGRIDPI_LOG_OUTPUT="$OUTPUT" \
  OFFGRIDPI_LOG_LIMIT=3 \
  "$PUBLISHER" >/dev/null

python3 - "$OUTPUT" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
report = json.loads(path.read_text(encoding="utf-8"))

assert report["schema_version"] == 1
assert report["entry_limit"] == 3
assert report["source_count"] == 5
assert len(report["sources"]) == 5
assert report["generated_at"].endswith("Z")

import stat

mode = stat.S_IMODE(path.stat().st_mode)
assert mode == 0o640, oct(mode)

expected_units = {
    "kiwix-serve.service",
    "offgridpi-dashboard.service",
    "offgridpi-documents.service",
    "offgridpi-document-indexer.service",
    "offgridpi-status-publisher.service",
}

actual_units = {
    source["unit"]
    for source in report["sources"]
}

assert actual_units == expected_units

for source in report["sources"]:
    assert source["entry_count"] == 3
    assert len(source["entries"]) == 3

    newest, warning, oldest = source["entries"]

    assert newest["priority"] == 3
    assert newest["priority_name"] == "Error"
    assert newest["timestamp"] > warning["timestamp"]
    assert warning["timestamp"] > oldest["timestamp"]

    assert "\x1b" not in newest["message"]
    assert len(newest["message"]) <= 600
    assert newest["message"].endswith("…")

    redacted = warning["message"]

    for secret in (
        "topsecret",
        "abc123",
        "hunter2",
    ):
        assert secret not in redacted

    assert "Authorization=[REDACTED]" in redacted
    assert "token=[REDACTED]" in redacted
    assert "key=[REDACTED]" in redacted

print(
    "PASS: Log snapshot structure, ordering, "
    "redaction, and truncation are valid."
)
PY

pass "Restricted fake journal data was published safely."

printf '{"sentinel": true}\n' > "$OUTPUT"

if env \
  FAKE_JOURNAL_MODE=invalid \
  OFFGRIDPI_JOURNALCTL="$FAKE_JOURNAL" \
  OFFGRIDPI_LOG_OUTPUT="$OUTPUT" \
  OFFGRIDPI_LOG_LIMIT=3 \
  "$PUBLISHER" >/dev/null 2>&1
then
  fail "Invalid journal JSON was unexpectedly accepted."
fi

grep -qF '"sentinel": true' "$OUTPUT" ||
  fail "Existing snapshot was changed after invalid JSON."

pass "Invalid journal JSON preserves the previous snapshot."

if env \
  FAKE_JOURNAL_MODE=fail \
  OFFGRIDPI_JOURNALCTL="$FAKE_JOURNAL" \
  OFFGRIDPI_LOG_OUTPUT="$OUTPUT" \
  OFFGRIDPI_LOG_LIMIT=3 \
  "$PUBLISHER" >/dev/null 2>&1
then
  fail "A journal command failure was unexpectedly accepted."
fi

grep -qF '"sentinel": true' "$OUTPUT" ||
  fail "Existing snapshot was changed after journal failure."

pass "Journal command failures preserve the previous snapshot."

if env \
  FAKE_JOURNAL_MODE=valid \
  OFFGRIDPI_JOURNALCTL="$FAKE_JOURNAL" \
  OFFGRIDPI_LOG_OUTPUT="$OUTPUT" \
  OFFGRIDPI_LOG_LIMIT=101 \
  "$PUBLISHER" >/dev/null 2>&1
then
  fail "An excessive log-entry limit was accepted."
fi

grep -qF '"sentinel": true' "$OUTPUT" ||
  fail "Existing snapshot was changed after invalid limit."

pass "Invalid entry limits are rejected safely."

env \
  FAKE_JOURNAL_MODE=empty \
  OFFGRIDPI_JOURNALCTL="$FAKE_JOURNAL" \
  OFFGRIDPI_LOG_OUTPUT="$OUTPUT" \
  OFFGRIDPI_LOG_LIMIT=5 \
  "$PUBLISHER" >/dev/null

python3 - "$OUTPUT" <<'PY'
import json
import sys
from pathlib import Path

report = json.loads(
    Path(sys.argv[1]).read_text(encoding="utf-8")
)

assert report["source_count"] == 5
assert report["entry_limit"] == 5

for source in report["sources"]:
    assert source["entry_count"] == 0
    assert source["entries"] == []

print("PASS: Empty journals produce a valid snapshot.")
PY

pass "System log publisher tests completed without live access."

if grep -qF \
  '/opt/offgridpi/dashboard/data/system-logs.json' \
  "$PUBLISHER"
then
  fail "Log publisher must not write into the dashboard web root."
fi

grep -qF \
  '/var/lib/offgridpi/management/system-logs.json' \
  "$PUBLISHER" ||
  fail "Protected default log-snapshot location is missing."

pass "Default log storage is outside the dashboard web root."
