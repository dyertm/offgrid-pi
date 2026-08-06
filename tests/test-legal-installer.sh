#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/install.sh"
VERIFIER="$ROOT/tests/verify-installation.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

required_payload=(
  'dashboard/legal/legal.css'
  'compliance/software-components.json'
  'compliance/schema/software-components.schema.json'
  'compliance/validate-software-components.py'
  'scripts/generate-legal-notices.py'
  'LICENSE'
)

for relative_path in "${required_payload[@]}"; do
  grep -qF \
    "\"\$PROJECT_ROOT/$relative_path\"" \
    "$INSTALLER" ||
    fail "Installer payload omits $relative_path."
done

pass "Installer preflight includes the legal-notice payload."

for destination in \
  '/opt/offgridpi/scripts/generate-legal-notices.py' \
  '/opt/offgridpi/compliance/validate-software-components.py' \
  '/opt/offgridpi/compliance/software-components.json' \
  '/opt/offgridpi/compliance/schema/software-components.schema.json' \
  '/opt/offgridpi/LICENSE'
do
  grep -qF "$destination" "$INSTALLER" ||
    fail "Installer does not install $destination."
done

pass "Installer deploys the legal compliance files."

grep -qF \
  -- '--output-root "$DASHBOARD_ROOT/legal"' \
  "$INSTALLER" ||
  fail "Installer does not generate the Legal & Notices page."

grep -qF \
  -- '--allow-missing' \
  "$INSTALLER" ||
  fail "Standalone dashboard installation lacks partial mode."

pass "Dashboard installation supports truthful partial notices."

rsync_line="$(
  grep -nF '"$PROJECT_ROOT/dashboard/"' "$INSTALLER" |
  head -1 |
  cut -d: -f1
)"

generator_line="$(
  grep -nF \
    '/opt/offgridpi/scripts/generate-legal-notices.py \' \
    "$INSTALLER" |
  head -1 |
  cut -d: -f1
)"

permissions_line="$(
  grep -nF \
    'chown -R root:root "$DASHBOARD_ROOT"' \
    "$INSTALLER" |
  head -1 |
  cut -d: -f1
)"

[[ -n "$rsync_line" ]] ||
  fail "Dashboard rsync line was not found."

[[ -n "$generator_line" ]] ||
  fail "Legal generator invocation was not found."

[[ -n "$permissions_line" ]] ||
  fail "Dashboard permission normalization was not found."

if ! (
  ((
    rsync_line < generator_line
    && generator_line < permissions_line
  ))
); then
  fail "Legal generation is not ordered safely."
fi

pass "Legal generation occurs after rsync and before permissions."

verifier_markers=(
  '/opt/offgridpi/dashboard/legal/index.html'
  '/opt/offgridpi/compliance/software-components.json'
  '=== Legal & Notices ==='
  'http://127.0.0.1:8081/legal/'
  'Legal page lists all seven registered components.'
  'Legal page contains no JavaScript.'
  'Legal page records the installed Kiwix package version.'
)

for verifier_marker in "${verifier_markers[@]}"; do
  grep -qF "$verifier_marker" "$VERIFIER" ||
    fail "Installed verifier omits: $verifier_marker"
done

pass "Installed verifier includes Legal & Notices checks."

grep -qF \
  'INSTALLER_VERSION="0.7.4"' \
  "$INSTALLER" ||
  fail "Installer version was not advanced to 0.7.4."

pass "Legal installer integration tests completed."
