#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DASHBOARD="$ROOT/dashboard/index.html"
STATUS_HTML="$ROOT/dashboard/status/index.html"
STATUS_CSS="$ROOT/dashboard/status/status.css"
STATUS_JS="$ROOT/dashboard/status/status.js"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

for FILE in \
  "$DASHBOARD" \
  "$STATUS_HTML" \
  "$STATUS_CSS" \
  "$STATUS_JS"
do
  [[ -s "$FILE" ]] ||
    fail "Required dashboard file is missing or empty: $FILE"
done

pass "Required dashboard status files exist."

python3 - \
  "$DASHBOARD" \
  "$STATUS_HTML" <<'PY'
import sys
from html.parser import HTMLParser
from pathlib import Path

dashboard_path = Path(sys.argv[1])
status_path = Path(sys.argv[2])


class Inspector(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.links = []
        self.scripts = []
        self.stylesheets = []

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)

        if values.get("id"):
            self.ids.add(values["id"])

        if tag == "a" and values.get("href"):
            self.links.append(values["href"])

        if tag == "script" and values.get("src"):
            self.scripts.append(values["src"])

        if (
            tag == "link"
            and values.get("rel") == "stylesheet"
            and values.get("href")
        ):
            self.stylesheets.append(values["href"])


dashboard = Inspector()
dashboard.feed(dashboard_path.read_text(encoding="utf-8"))

if "status/" not in dashboard.links:
    raise SystemExit(
        "Dashboard does not link to the status page."
    )

if "legal/" not in dashboard.links:
    raise SystemExit(
        "Dashboard does not link to the Legal & Notices page."
    )

status = Inspector()
status.feed(status_path.read_text(encoding="utf-8"))

required_ids = {
    "overall-status",
    "status-message",
    "status-summary",
    "service-panel",
    "service-list",
}

missing = sorted(required_ids - status.ids)

if missing:
    raise SystemExit(
        "Status page is missing IDs: " + ", ".join(missing)
    )

required_styles = {
    "../css/styles.css",
    "status.css",
}

if not required_styles.issubset(status.stylesheets):
    raise SystemExit(
        "Status page stylesheet references are incomplete."
    )

if "status.js" not in status.scripts:
    raise SystemExit(
        "Status page does not load status.js."
    )

print("PASS: Dashboard and status-page HTML structure is valid.")
PY

grep -qF '../data/system-status.json' "$STATUS_JS" ||
  fail "Status JavaScript does not use the local JSON report."

grep -qF 'window.setInterval' "$STATUS_JS" ||
  fail "Status JavaScript does not refresh automatically."

grep -qF 'textContent' "$STATUS_JS" ||
  fail "Status JavaScript does not use safe text rendering."

if grep -qF 'innerHTML' "$STATUS_JS"; then
  fail "Status JavaScript must not inject content with innerHTML."
fi

if grep -Eq \
  'https?://|//cdn\.|//fonts\.' \
  "$STATUS_HTML" \
  "$STATUS_CSS" \
  "$STATUS_JS"
then
  fail "Status page contains a remote asset or dependency."
fi

grep -qF '.status-grid' "$STATUS_CSS" ||
  fail "Status summary-grid styling is missing."

grep -qF '@media' "$STATUS_CSS" ||
  fail "Responsive status-page styling is missing."

pass "Status page uses only local, read-only resources."

python3 - "$DASHBOARD" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")

pattern = re.compile(
    r'<div class="card card-disabled"[^>]*>'
    r'.*?<h2>Administration</h2>'
    r'.*?Coming later'
    r'.*?</div>',
    re.DOTALL,
)

if not pattern.search(text):
    raise SystemExit(
        "Administration card is no longer clearly disabled."
    )

print("PASS: Browser-based Administration remains disabled.")
PY

grep -qF   '"$PROJECT_ROOT/dashboard/status/index.html"'   "$ROOT/install.sh" ||
  fail "Installer payload does not include the status page."

grep -qF   '/opt/offgridpi/scripts/publish-system-status.sh'   "$ROOT/install.sh" ||
  fail "Dashboard installation does not republish status data."

pass "Dashboard installer includes status-page safeguards."
pass "Dashboard status-page tests completed."
