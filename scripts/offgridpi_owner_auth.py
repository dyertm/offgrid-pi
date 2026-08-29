#!/usr/bin/env python3
"""Runtime authentication and session handling for Offgrid Pi Owner Mode."""

from __future__ import annotations

import math
import secrets
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

import offgridpi_owner_credentials as credentials


SESSION_IDLE_SECONDS = 3600
SESSION_ABSOLUTE_SECONDS = 43200

MAX_FAILED_ATTEMPTS = 5
FAILURE_WINDOW_SECONDS = 300
LOCKOUT_SECONDS = 300

SESSION_TOKEN_BYTES = 32


@dataclass(frozen=True)
class AuthenticationResult:
    status: str
    session_token: str | None = None
    retry_after: int | None = None


@dataclass
class _Session:
    created_at: float
    last_seen_at: float
    credential_revision: int


@dataclass
class _FailureState:
    failures: list[float]
    locked_until: float | None = None


class OwnerAuthenticator:
    """Authenticate Owner credentials and manage runtime-only sessions."""

    def __init__(
        self,
        state_path: str | Path,
        *,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self.state_path = Path(state_path)
        self.clock = clock
        self._sessions: dict[str, _Session] = {}
        self._failures: dict[str, _FailureState] = {}

    def _credential_revision(self) -> int:
        state = credentials._load_owner_state(
            self.state_path
        )
        return int(state["credential_revision"])

    def _prune_failures(
        self,
        state: _FailureState,
        now: float,
    ) -> None:
        cutoff = now - FAILURE_WINDOW_SECONDS
        state.failures[:] = [
            timestamp
            for timestamp in state.failures
            if timestamp > cutoff
        ]

        if (
            state.locked_until is not None
            and now >= state.locked_until
        ):
            state.locked_until = None
            state.failures.clear()

    def _lockout_result(
        self,
        state: _FailureState,
        now: float,
    ) -> AuthenticationResult | None:
        self._prune_failures(state, now)

        if (
            state.locked_until is None
            or now >= state.locked_until
        ):
            return None

        retry_after = max(
            1,
            math.ceil(state.locked_until - now),
        )

        return AuthenticationResult(
            status="locked",
            retry_after=retry_after,
        )

    def authenticate(
        self,
        pin: str,
        *,
        client_key: str,
    ) -> AuthenticationResult:
        """Authenticate a PIN and create a runtime session."""

        if not isinstance(client_key, str) or not client_key:
            raise ValueError(
                "Owner authentication client key is required."
            )

        now = self.clock()

        failure_state = self._failures.setdefault(
            client_key,
            _FailureState(failures=[]),
        )

        lockout = self._lockout_result(
            failure_state,
            now,
        )

        if lockout is not None:
            return lockout

        if not credentials.verify_owner_pin(
            self.state_path,
            pin,
        ):
            failure_state.failures.append(now)
            self._prune_failures(
                failure_state,
                now,
            )

            if (
                len(failure_state.failures)
                >= MAX_FAILED_ATTEMPTS
            ):
                failure_state.locked_until = (
                    now + LOCKOUT_SECONDS
                )

                return AuthenticationResult(
                    status="locked",
                    retry_after=LOCKOUT_SECONDS,
                )

            return AuthenticationResult(
                status="invalid",
            )

        failure_state.failures.clear()
        failure_state.locked_until = None

        revision = self._credential_revision()

        token = secrets.token_urlsafe(
            SESSION_TOKEN_BYTES
        )

        self._sessions[token] = _Session(
            created_at=now,
            last_seen_at=now,
            credential_revision=revision,
        )

        return AuthenticationResult(
            status="authenticated",
            session_token=token,
        )

    def validate_session(
        self,
        token: str,
    ) -> bool:
        """Validate and refresh an Owner session."""

        if not isinstance(token, str) or not token:
            return False

        session = self._sessions.get(token)

        if session is None:
            return False

        now = self.clock()

        if (
            now - session.created_at
            > SESSION_ABSOLUTE_SECONDS
        ):
            self._sessions.pop(token, None)
            return False

        if (
            now - session.last_seen_at
            > SESSION_IDLE_SECONDS
        ):
            self._sessions.pop(token, None)
            return False

        try:
            revision = self._credential_revision()
        except (
            OSError,
            TypeError,
            ValueError,
        ):
            self._sessions.pop(token, None)
            return False

        if revision != session.credential_revision:
            self._sessions.pop(token, None)
            return False

        session.last_seen_at = now
        return True

    def lock_session(
        self,
        token: str,
    ) -> bool:
        """Explicitly invalidate one Owner session."""

        if not isinstance(token, str) or not token:
            return False

        return self._sessions.pop(
            token,
            None,
        ) is not None
