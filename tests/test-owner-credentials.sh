#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$ROOT/scripts/offgridpi_owner_credentials.py"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

[[ -f "$MODULE" ]] ||
  fail "Shared Owner credential module is missing."

PYTHONPATH="$ROOT/scripts" python3 - <<'PY'
import json
import re

import offgridpi_owner_credentials as credentials


def fail(message):
    raise SystemExit(f"FAIL: {message}")


if credentials.CREDENTIAL_FORMAT_VERSION != 1:
    fail("Unexpected credential format version.")

if credentials.SCRYPT_N != 65536:
    fail("Owner credentials do not use the approved scrypt N value.")

if credentials.SCRYPT_R != 8:
    fail("Owner credentials do not use the approved scrypt r value.")

if credentials.SCRYPT_P != 1:
    fail("Owner credentials do not use the approved scrypt p value.")

pin = "482731"
wrong_pin = "482732"

pin_record = credentials.create_secret_record(pin)

if not credentials.verify_secret(pin, pin_record):
    fail("Correct Owner PIN did not verify.")

if credentials.verify_secret(wrong_pin, pin_record):
    fail("Incorrect Owner PIN unexpectedly verified.")

serialized_pin = json.dumps(pin_record, sort_keys=True)

if pin in serialized_pin:
    fail("Owner PIN appears in the stored credential record.")

required_record_keys = {
    "format_version",
    "algorithm",
    "n",
    "r",
    "p",
    "dklen",
    "salt",
    "digest",
}

if set(pin_record) != required_record_keys:
    fail("Stored PIN record has an unexpected schema.")

if pin_record["algorithm"] != "scrypt":
    fail("Stored PIN record does not identify scrypt.")

recovery = credentials.generate_recovery_credential()

if not isinstance(recovery, str):
    fail("Recovery credential is not text.")

if not re.fullmatch(
    r"[A-Z2-9]{4}(?:-[A-Z2-9]{4}){7}",
    recovery,
):
    fail("Recovery credential does not use the approved printable format.")

recovery_record = credentials.create_secret_record(recovery)

if not credentials.verify_secret(recovery, recovery_record):
    fail("Correct recovery credential did not verify.")

serialized_recovery = json.dumps(
    recovery_record,
    sort_keys=True,
)

if recovery in serialized_recovery:
    fail("Recovery credential appears in its stored verification record.")

second_recovery = credentials.generate_recovery_credential()

if recovery == second_recovery:
    fail("Recovery credential generation repeated a value.")

malformed_records = (
    {},
    {"format_version": 1},
    {**pin_record, "algorithm": "unknown"},
    {**pin_record, "n": 1},
    {**pin_record, "salt": "not-valid-base64%%%"},
    {**pin_record, "digest": "not-valid-base64%%%"},
)

for record in malformed_records:
    if credentials.verify_secret(pin, record):
        fail("Malformed credential record unexpectedly verified.")

print("PASS: Owner PIN hashing and verification are valid.")
print("PASS: Recovery credential generation and verification are valid.")
print("PASS: Stored credential records contain no plaintext secrets.")
print("PASS: Malformed credential records fail closed.")
PY

pass "Shared Owner credential module tests completed."

PYTHONPATH="$ROOT/scripts" python3 - <<'PY'
import json
import os
import stat
import tempfile
from pathlib import Path

import offgridpi_owner_credentials as credentials


def fail(message):
    raise SystemExit(f"FAIL: {message}")


with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    state_path = root / "owner" / "credentials.json"

    # Simulate private user content that must survive credential changes.
    user_data = root / "content" / "maps" / "user-data"
    user_data.mkdir(parents=True)
    waypoint = user_data / "waypoints-test.json"
    waypoint.write_text(
        '{"name":"Emergency meeting point"}\n',
        encoding="utf-8",
    )

    original_pin = "482731"
    replacement_pin = "917264"

    recovery = credentials.enroll_owner_credentials(
        state_path,
        original_pin,
    )

    if not state_path.is_file():
        fail("Credential enrollment did not create the state file.")

    mode = stat.S_IMODE(state_path.stat().st_mode)

    if mode != 0o600:
        fail(
            "Credential state file permissions are "
            f"{mode:04o}, expected 0600."
        )

    stored = json.loads(state_path.read_text(encoding="utf-8"))

    if stored.get("state_version") != 1:
        fail("Credential state version is missing or invalid.")

    if stored.get("credential_revision") != 1:
        fail("Initial credential revision is not 1.")

    if set(stored) != {
        "state_version",
        "credential_revision",
        "pin",
        "recovery",
    }:
        fail("Credential state has an unexpected schema.")

    serialized = json.dumps(stored, sort_keys=True)

    if original_pin in serialized:
        fail("Owner PIN appears in persistent credential state.")

    if recovery in serialized:
        fail("Recovery credential appears in persistent state.")

    if not credentials.verify_owner_pin(
        state_path,
        original_pin,
    ):
        fail("Persisted Owner PIN did not verify.")

    if credentials.verify_owner_pin(
        state_path,
        "000000",
    ):
        fail("Incorrect persisted Owner PIN unexpectedly verified.")

    if not credentials.verify_owner_recovery(
        state_path,
        recovery,
    ):
        fail("Persisted recovery credential did not verify.")

    try:
        credentials.enroll_owner_credentials(
            state_path,
            "111111",
        )
    except FileExistsError:
        pass
    else:
        fail("Enrollment overwrote existing credential state.")

    if not credentials.reset_owner_pin_with_recovery(
        state_path,
        recovery,
        replacement_pin,
    ):
        fail("Recovery credential did not reset the Owner PIN.")

    if credentials.verify_owner_pin(
        state_path,
        original_pin,
    ):
        fail("Old Owner PIN still verifies after recovery reset.")

    if not credentials.verify_owner_pin(
        state_path,
        replacement_pin,
    ):
        fail("Replacement Owner PIN does not verify.")

    updated = json.loads(state_path.read_text(encoding="utf-8"))

    if updated.get("credential_revision") != 2:
        fail("Credential revision did not advance after PIN reset.")

    if not credentials.verify_owner_recovery(
        state_path,
        recovery,
    ):
        fail("Recovery credential changed during PIN reset.")

    if not waypoint.is_file():
        fail("Credential reset deleted private user content.")

    if waypoint.read_text(encoding="utf-8") != (
        '{"name":"Emergency meeting point"}\n'
    ):
        fail("Credential reset modified private user content.")

    before_failed_reset = state_path.read_bytes()

    if credentials.reset_owner_pin_with_recovery(
        state_path,
        "AAAA-AAAA-AAAA-AAAA-AAAA-AAAA-AAAA-AAAA",
        "555555",
    ):
        fail("Incorrect recovery credential reset the Owner PIN.")

    if state_path.read_bytes() != before_failed_reset:
        fail("Failed recovery attempt modified credential state.")

print("PASS: Persistent Owner credential enrollment is valid.")
print("PASS: Credential state is stored with mode 0600.")
print("PASS: Recovery reset changes authentication state only.")
print("PASS: Owner content survives credential recovery unchanged.")
PY
