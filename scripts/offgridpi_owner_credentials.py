#!/usr/bin/env python3
"""Shared credential primitives for Offgrid Pi Owner Mode."""

from __future__ import annotations

import base64
import binascii
import hashlib
import hmac
import secrets
from typing import Any

CREDENTIAL_FORMAT_VERSION = 1

SCRYPT_N = 65536
SCRYPT_R = 8
SCRYPT_P = 1
SCRYPT_DKLEN = 32
SCRYPT_MAXMEM = 256 * 1024 * 1024

SALT_BYTES = 16

RECOVERY_GROUPS = 8
RECOVERY_GROUP_LENGTH = 4

# Avoid visually ambiguous I, O, 0, and 1 while retaining
# a compact uppercase printable recovery format.
RECOVERY_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

RECORD_KEYS = {
    "format_version",
    "algorithm",
    "n",
    "r",
    "p",
    "dklen",
    "salt",
    "digest",
}


def _encode_bytes(value: bytes) -> str:
    return base64.b64encode(value).decode("ascii")


def _decode_bytes(value: Any) -> bytes:
    if not isinstance(value, str) or not value:
        raise ValueError("Encoded credential field is invalid.")

    try:
        return base64.b64decode(
            value.encode("ascii"),
            validate=True,
        )
    except (
        UnicodeEncodeError,
        binascii.Error,
        ValueError,
    ) as error:
        raise ValueError(
            "Encoded credential field is invalid."
        ) from error


def _secret_bytes(secret: Any) -> bytes:
    if not isinstance(secret, str):
        raise ValueError("Credential secret must be text.")

    if not secret:
        raise ValueError("Credential secret may not be empty.")

    return secret.encode("utf-8")


def _derive(
    secret: str,
    salt: bytes,
    *,
    n: int = SCRYPT_N,
    r: int = SCRYPT_R,
    p: int = SCRYPT_P,
    dklen: int = SCRYPT_DKLEN,
) -> bytes:
    return hashlib.scrypt(
        _secret_bytes(secret),
        salt=salt,
        n=n,
        r=r,
        p=p,
        dklen=dklen,
        maxmem=SCRYPT_MAXMEM,
    )


def create_secret_record(secret: str) -> dict[str, Any]:
    """Create a versioned scrypt verification record."""

    salt = secrets.token_bytes(SALT_BYTES)
    digest = _derive(secret, salt)

    return {
        "format_version": CREDENTIAL_FORMAT_VERSION,
        "algorithm": "scrypt",
        "n": SCRYPT_N,
        "r": SCRYPT_R,
        "p": SCRYPT_P,
        "dklen": SCRYPT_DKLEN,
        "salt": _encode_bytes(salt),
        "digest": _encode_bytes(digest),
    }


def verify_secret(
    secret: str,
    record: Any,
) -> bool:
    """Verify a secret against a stored record, failing closed."""

    try:
        if not isinstance(record, dict):
            return False

        if set(record) != RECORD_KEYS:
            return False

        if (
            record.get("format_version")
            != CREDENTIAL_FORMAT_VERSION
        ):
            return False

        if record.get("algorithm") != "scrypt":
            return False

        if record.get("n") != SCRYPT_N:
            return False

        if record.get("r") != SCRYPT_R:
            return False

        if record.get("p") != SCRYPT_P:
            return False

        if record.get("dklen") != SCRYPT_DKLEN:
            return False

        salt = _decode_bytes(record.get("salt"))
        expected = _decode_bytes(record.get("digest"))

        if len(salt) != SALT_BYTES:
            return False

        if len(expected) != SCRYPT_DKLEN:
            return False

        actual = _derive(
            secret,
            salt,
            n=record["n"],
            r=record["r"],
            p=record["p"],
            dklen=record["dklen"],
        )

        return hmac.compare_digest(
            actual,
            expected,
        )
    except (
        KeyError,
        TypeError,
        ValueError,
        MemoryError,
    ):
        return False


def generate_recovery_credential() -> str:
    """Generate a high-entropy human-recordable recovery credential."""

    groups = []

    for _ in range(RECOVERY_GROUPS):
        group = "".join(
            secrets.choice(RECOVERY_ALPHABET)
            for _ in range(RECOVERY_GROUP_LENGTH)
        )
        groups.append(group)

    return "-".join(groups)


OWNER_STATE_VERSION = 1

OWNER_STATE_KEYS = {
    "state_version",
    "credential_revision",
    "pin",
    "recovery",
}


def _load_owner_state(
    state_path: Any,
) -> dict[str, Any]:
    """Load and validate persistent Owner credential state."""

    from pathlib import Path
    import json

    path = Path(state_path)

    try:
        raw = path.read_text(encoding="utf-8")
        state = json.loads(raw)
    except (
        OSError,
        UnicodeError,
        json.JSONDecodeError,
    ) as error:
        raise ValueError(
            "Owner credential state could not be read."
        ) from error

    if not isinstance(state, dict):
        raise ValueError(
            "Owner credential state is invalid."
        )

    if set(state) != OWNER_STATE_KEYS:
        raise ValueError(
            "Owner credential state schema is invalid."
        )

    if state.get("state_version") != OWNER_STATE_VERSION:
        raise ValueError(
            "Owner credential state version is unsupported."
        )

    revision = state.get("credential_revision")

    if (
        not isinstance(revision, int)
        or isinstance(revision, bool)
        or revision < 1
    ):
        raise ValueError(
            "Owner credential revision is invalid."
        )

    pin_record = state.get("pin")
    recovery_record = state.get("recovery")

    if not isinstance(pin_record, dict):
        raise ValueError(
            "Owner PIN record is invalid."
        )

    if not isinstance(recovery_record, dict):
        raise ValueError(
            "Owner recovery record is invalid."
        )

    return state


def _write_owner_state(
    state_path: Any,
    state: dict[str, Any],
) -> None:
    """Atomically persist Owner credential state with mode 0600."""

    from pathlib import Path
    import json
    import os
    import tempfile

    path = Path(state_path)
    parent = path.parent

    parent.mkdir(
        mode=0o700,
        parents=True,
        exist_ok=True,
    )

    payload = (
        json.dumps(
            state,
            sort_keys=True,
            separators=(",", ":"),
        )
        + "\n"
    ).encode("utf-8")

    temporary_path = None

    try:
        descriptor, temporary_name = tempfile.mkstemp(
            prefix=f".{path.name}.",
            suffix=".tmp",
            dir=parent,
        )

        temporary_path = Path(temporary_name)

        try:
            os.fchmod(descriptor, 0o600)

            with os.fdopen(
                descriptor,
                "wb",
                closefd=True,
            ) as handle:
                handle.write(payload)
                handle.flush()
                os.fsync(handle.fileno())
        except Exception:
            try:
                os.close(descriptor)
            except OSError:
                pass
            raise

        os.replace(
            temporary_path,
            path,
        )

        temporary_path = None

        os.chmod(path, 0o600)

        directory_descriptor = os.open(
            parent,
            os.O_RDONLY,
        )

        try:
            os.fsync(directory_descriptor)
        finally:
            os.close(directory_descriptor)

    finally:
        if temporary_path is not None:
            try:
                temporary_path.unlink()
            except FileNotFoundError:
                pass


def enroll_owner_credentials(
    state_path: Any,
    pin: str,
) -> str:
    """Enroll an Owner PIN and return the recovery credential once."""

    from pathlib import Path

    path = Path(state_path)

    if path.exists():
        raise FileExistsError(
            "Owner credentials are already enrolled."
        )

    recovery = generate_recovery_credential()

    state = {
        "state_version": OWNER_STATE_VERSION,
        "credential_revision": 1,
        "pin": create_secret_record(pin),
        "recovery": create_secret_record(recovery),
    }

    # Refuse a race that creates the target between the initial
    # existence check and persistence.
    if path.exists():
        raise FileExistsError(
            "Owner credentials are already enrolled."
        )

    _write_owner_state(
        path,
        state,
    )

    return recovery


def verify_owner_pin(
    state_path: Any,
    pin: str,
) -> bool:
    """Verify the Owner PIN against persistent credential state."""

    try:
        state = _load_owner_state(state_path)
        return verify_secret(
            pin,
            state["pin"],
        )
    except (
        KeyError,
        TypeError,
        ValueError,
    ):
        return False


def verify_owner_recovery(
    state_path: Any,
    recovery: str,
) -> bool:
    """Verify the offline Owner recovery credential."""

    try:
        state = _load_owner_state(state_path)
        return verify_secret(
            recovery,
            state["recovery"],
        )
    except (
        KeyError,
        TypeError,
        ValueError,
    ):
        return False


def reset_owner_pin_with_recovery(
    state_path: Any,
    recovery: str,
    new_pin: str,
) -> bool:
    """Reset only the Owner PIN after successful recovery verification."""

    try:
        state = _load_owner_state(state_path)

        if not verify_secret(
            recovery,
            state["recovery"],
        ):
            return False

        updated_state = {
            "state_version": OWNER_STATE_VERSION,
            "credential_revision":
                state["credential_revision"] + 1,
            "pin": create_secret_record(new_pin),
            "recovery": state["recovery"],
        }

        _write_owner_state(
            state_path,
            updated_state,
        )

        return True

    except (
        KeyError,
        TypeError,
        ValueError,
    ):
        return False
