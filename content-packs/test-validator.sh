#!/usr/bin/env bash
set -u

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="$ROOT/validate-manifest.py"
EXAMPLE="$ROOT/examples/example-pack.json"
TEMP_DIR="$(mktemp -d)"

trap 'rm -rf "$TEMP_DIR"' EXIT

FAILURES=0

pass() {
  printf 'PASS: %s\n' "$1"
}

fail() {
  printf 'FAIL: %s\n' "$1"
  FAILURES=$((FAILURES + 1))
}

if "$VALIDATOR" "$EXAMPLE" >/dev/null; then
  pass "Valid example manifest accepted."
else
  fail "Valid example manifest rejected."
fi

cp "$EXAMPLE" "$TEMP_DIR/unsafe.json"

python3 -c '
import json
from pathlib import Path

p = Path("'"$TEMP_DIR"'/unsafe.json")
d = json.loads(p.read_text())
d["items"][0]["destination"] = (
    "/srv/offgridpi/content/documents/personal/secret.pdf"
)
p.write_text(json.dumps(d, indent=2) + "\n")
'

if "$VALIDATOR" "$TEMP_DIR/unsafe.json" >/dev/null; then
  fail "Unsafe personal destination accepted."
else
  pass "Unsafe personal destination rejected."
fi

cp "$EXAMPLE" "$TEMP_DIR/checksum.json"

python3 -c '
import json
from pathlib import Path

p = Path("'"$TEMP_DIR"'/checksum.json")
d = json.loads(p.read_text())
d["items"][0]["sha256"] = "invalid"
p.write_text(json.dumps(d, indent=2) + "\n")
'

if "$VALIDATOR" "$TEMP_DIR/checksum.json" >/dev/null; then
  fail "Malformed checksum accepted."
else
  pass "Malformed checksum rejected."
fi

cp "$EXAMPLE" "$TEMP_DIR/duplicate.json"

python3 -c '
import json
from pathlib import Path

p = Path("'"$TEMP_DIR"'/duplicate.json")
d = json.loads(p.read_text())
d["items"].append(dict(d["items"][0]))
p.write_text(json.dumps(d, indent=2) + "\n")
'

if "$VALIDATOR" "$TEMP_DIR/duplicate.json" >/dev/null; then
  fail "Duplicate item ID accepted."
else
  pass "Duplicate item ID rejected."
fi

printf '\nFailures: %d\n' "$FAILURES"

if [[ "$FAILURES" -eq 0 ]]; then
  pass "Content-pack validator tests succeeded."
  exit 0
fi

exit 1
