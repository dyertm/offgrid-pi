#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTH_MODULE="$ROOT/scripts/offgridpi_owner_auth.py"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

[[ -f "$AUTH_MODULE" ]] ||
  fail "Shared Owner authentication module is missing."

PYTHONPATH="$ROOT/scripts" python3 - <<'PY'
import tempfile
from pathlib import Path

import offgridpi_owner_auth as auth
import offgridpi_owner_credentials as credentials


def fail(message):
    raise SystemExit(f"FAIL: {message}")


class FakeClock:
    def __init__(self):
        self.now = 1000.0

    def __call__(self):
        return self.now

    def advance(self, seconds):
        self.now += seconds


if auth.SESSION_IDLE_SECONDS != 3600:
    fail("Unexpected Owner session idle timeout.")

if auth.SESSION_ABSOLUTE_SECONDS != 43200:
    fail("Unexpected Owner session absolute timeout.")

if auth.MAX_FAILED_ATTEMPTS != 5:
    fail("Unexpected Owner authentication failure limit.")

if auth.FAILURE_WINDOW_SECONDS != 300:
    fail("Unexpected Owner authentication failure window.")

if auth.LOCKOUT_SECONDS != 300:
    fail("Unexpected Owner authentication lockout period.")


with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    state_path = root / "owner" / "credentials.json"

    original_pin = "482731"
    replacement_pin = "917264"

    recovery = credentials.enroll_owner_credentials(
        state_path,
        original_pin,
    )

    clock = FakeClock()

    authenticator = auth.OwnerAuthenticator(
        state_path,
        clock=clock,
    )

    result = authenticator.authenticate(
        original_pin,
        client_key="local-test",
    )

    if result.status != "authenticated":
        fail("Correct Owner PIN did not authenticate.")

    token = result.session_token

    if not isinstance(token, str) or len(token) < 40:
        fail("Authenticated session token is not sufficiently strong.")

    if original_pin in repr(result):
        fail("Authentication result exposes the Owner PIN.")

    if not authenticator.validate_session(token):
        fail("Fresh Owner session did not validate.")

    if authenticator.validate_session("not-a-session-token"):
        fail("Invalid Owner session token unexpectedly validated.")

    if not authenticator.lock_session(token):
        fail("Explicit Owner session lock did not succeed.")

    if authenticator.validate_session(token):
        fail("Locked Owner session remained valid.")

    # Four failures remain below the lockout threshold.
    for _ in range(auth.MAX_FAILED_ATTEMPTS - 1):
        attempt = authenticator.authenticate(
            "000000",
            client_key="rate-test",
        )

        if attempt.status != "invalid":
            fail("Owner authentication locked too early.")

    # The fifth failure triggers the lockout.
    attempt = authenticator.authenticate(
        "000000",
        client_key="rate-test",
    )

    if attempt.status != "locked":
        fail("Owner authentication did not enter lockout.")

    if not (
        isinstance(attempt.retry_after, int)
        and 1 <= attempt.retry_after <= auth.LOCKOUT_SECONDS
    ):
        fail("Owner lockout did not provide a valid retry interval.")

    # Even the correct PIN must not bypass an active lockout.
    attempt = authenticator.authenticate(
        original_pin,
        client_key="rate-test",
    )

    if attempt.status != "locked":
        fail("Correct PIN bypassed an active Owner lockout.")

    clock.advance(auth.LOCKOUT_SECONDS + 1)

    attempt = authenticator.authenticate(
        original_pin,
        client_key="rate-test",
    )

    if attempt.status != "authenticated":
        fail("Owner authentication did not recover after lockout.")

    recovered_token = attempt.session_token

    # A successful login clears the prior failed-attempt state.
    attempt = authenticator.authenticate(
        "000000",
        client_key="rate-test",
    )

    if attempt.status != "invalid":
        fail("Successful authentication did not clear failure state.")

    # Idle timeout invalidates an otherwise valid session.
    clock.advance(auth.SESSION_IDLE_SECONDS + 1)

    if authenticator.validate_session(recovered_token):
        fail("Idle Owner session did not expire.")

    # Exercise absolute expiration while keeping the session active.
    attempt = authenticator.authenticate(
        original_pin,
        client_key="absolute-test",
    )

    absolute_token = attempt.session_token

    if attempt.status != "authenticated":
        fail("Could not create session for absolute-timeout test.")

    for _ in range(12):
        clock.advance(3500)

        if not authenticator.validate_session(absolute_token):
            fail("Active Owner session expired before absolute timeout.")

    clock.advance(
        auth.SESSION_ABSOLUTE_SECONDS
        - (12 * 3500)
        + 1
    )

    if authenticator.validate_session(absolute_token):
        fail("Owner session exceeded its absolute lifetime.")

    # Credential changes must invalidate every session created
    # under the previous credential revision.
    attempt = authenticator.authenticate(
        original_pin,
        client_key="revision-test",
    )

    revision_token = attempt.session_token

    if attempt.status != "authenticated":
        fail("Could not create credential-revision test session.")

    if not credentials.reset_owner_pin_with_recovery(
        state_path,
        recovery,
        replacement_pin,
    ):
        fail("Could not reset Owner PIN for revision test.")

    if authenticator.validate_session(revision_token):
        fail("Credential revision change did not invalidate session.")

    attempt = authenticator.authenticate(
        replacement_pin,
        client_key="revision-test",
    )

    if attempt.status != "authenticated":
        fail("Replacement Owner PIN did not authenticate.")

    # Sessions and rate-limit state are runtime-only. Authentication
    # must not create persistent session databases or token files.
    persistent_files = {
        path.name
        for path in state_path.parent.iterdir()
        if path.is_file()
    }

    if persistent_files != {"credentials.json"}:
        fail(
            "Owner authentication persisted unexpected runtime state: "
            + ", ".join(sorted(persistent_files))
        )

print("PASS: Owner PIN authentication creates strong runtime sessions.")
print("PASS: Owner sessions support explicit lock and idle expiration.")
print("PASS: Owner sessions enforce an absolute lifetime.")
print("PASS: Owner PIN guessing is rate-limited with timed lockout.")
print("PASS: Credential changes invalidate existing Owner sessions.")
print("PASS: Owner session state remains runtime-only.")
PY

pass "Shared Owner authentication tests completed."
