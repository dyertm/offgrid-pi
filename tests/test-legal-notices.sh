#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GENERATOR="$ROOT/scripts/generate-legal-notices.py"
REGISTER="$ROOT/compliance/software-components.json"
VALIDATOR="$ROOT/compliance/validate-software-components.py"
STYLESHEET="$ROOT/dashboard/legal/legal.css"
LICENSE_FILE="$ROOT/LICENSE"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEMP_ROOT"' EXIT

SYSTEM_ROOT="$TEMP_ROOT/system"
OUTPUT_ROOT="$TEMP_ROOT/output"
FAKE_DPKG="$TEMP_ROOT/dpkg-query"
REGISTER_FIXTURE="$TEMP_ROOT/software-components.json"

cp "$REGISTER" "$REGISTER_FIXTURE"

packages=(
  python3
  inotify-tools
  curl
  rsync
  chromium
  kiwix-tools
  zim-tools
)

for package in "${packages[@]}"; do
  directory="$SYSTEM_ROOT/usr/share/doc/$package"
  mkdir -p "$directory"

  printf '%s\n' \
    "Copyright notice for $package" \
    "Characters requiring safe handling: < > &" \
    > "$directory/copyright"
done

cat > "$FAKE_DPKG" <<'DPKG'
#!/usr/bin/env bash
set -euo pipefail

package="${!#}"

if [[ "${OFFGRIDPI_TEST_MISSING_PACKAGE:-}" == "$package" ]]; then
  exit 1
fi

case "$package" in
  python3)       version="3.13-test" ;;
  inotify-tools) version="4.23-test" ;;
  curl)          version="8.14-test" ;;
  rsync)         version="3.4-test" ;;
  chromium)      version="150.0-test" ;;
  kiwix-tools)   version="3.7-test" ;;
  zim-tools)     version="3.5-test" ;;
  *) exit 1 ;;
esac

printf '%s' "$version"
DPKG

chmod +x "$FAKE_DPKG"

python3 -m py_compile "$GENERATOR"

"$GENERATOR" \
  --register "$REGISTER_FIXTURE" \
  --license "$LICENSE_FILE" \
  --stylesheet "$STYLESHEET" \
  --validator "$VALIDATOR" \
  --system-root "$SYSTEM_ROOT" \
  --dpkg-query "$FAKE_DPKG" \
  --output-root "$OUTPUT_ROOT"

pass "Generator completed against the isolated test system."

for path in \
  "$OUTPUT_ROOT/index.html" \
  "$OUTPUT_ROOT/legal.css" \
  "$OUTPUT_ROOT/notices/offgrid-pi-license.txt"
do
  [[ -s "$path" ]] ||
    fail "Generated file is missing or empty: $path"
done

for package in "${packages[@]}"; do
  [[ -s "$OUTPUT_ROOT/notices/$package.txt" ]] ||
    fail "Package notice is missing: $package"
done

pass "Project and package notice files were generated."

python3 - "$OUTPUT_ROOT/index.html" <<'PY'
import sys
from html.parser import HTMLParser
from pathlib import Path

page = Path(sys.argv[1])


class Inspector(HTMLParser):
    def __init__(self):
        super().__init__()
        self.component_count = 0
        self.links = []
        self.scripts = []
        self.stylesheets = []

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        classes = set(values.get("class", "").split())

        if tag == "article" and "component" in classes:
            self.component_count += 1

        if tag == "a" and values.get("href"):
            self.links.append(values["href"])

        if tag == "script":
            self.scripts.append(values.get("src"))

        if (
            tag == "link"
            and values.get("rel") == "stylesheet"
            and values.get("href")
        ):
            self.stylesheets.append(values["href"])


text = page.read_text(encoding="utf-8")
inspector = Inspector()
inspector.feed(text)

if inspector.component_count != 7:
    raise SystemExit(
        f"Expected 7 component cards; found "
        f"{inspector.component_count}."
    )

required_styles = {
    "../css/styles.css",
    "legal.css",
}

if not required_styles.issubset(inspector.stylesheets):
    raise SystemExit("Generated stylesheet references are incomplete.")

if "../" not in inspector.links or "← Dashboard" not in text:
    raise SystemExit(
        "Generated legal page lacks standardized Dashboard navigation."
    )

if inspector.scripts:
    raise SystemExit("Generated legal page must not use JavaScript.")

required_notices = {
    "notices/offgrid-pi-license.txt",
    "notices/python3.txt",
    "notices/inotify-tools.txt",
    "notices/curl.txt",
    "notices/rsync.txt",
    "notices/chromium.txt",
    "notices/kiwix-tools.txt",
    "notices/zim-tools.txt",
}

if not required_notices.issubset(inspector.links):
    raise SystemExit("Generated notice links are incomplete.")

for version in (
    "3.13-test",
    "4.23-test",
    "8.14-test",
    "3.4-test",
    "150.0-test",
    "3.7-test",
    "3.5-test",
):
    if version not in text:
        raise SystemExit(
            f"Generated page is missing version {version}."
        )

if "This notice inventory is not" not in text:
    raise SystemExit(
        "Source-fulfilment warning is missing."
    )

print("PASS: Generated Legal & Notices HTML is valid.")
PY

if grep -Eq \
  '<script|src="https?://|href="https?://[^"]+\.(css|js)' \
  "$OUTPUT_ROOT/index.html"
then
  fail "Generated page contains a remote executable asset."
fi

pass "Generated page uses only local presentation assets."

PARTIAL_OUTPUT="$TEMP_ROOT/partial-output"

OFFGRIDPI_TEST_MISSING_PACKAGE="kiwix-tools" \
  "$GENERATOR" \
    --register "$REGISTER_FIXTURE" \
    --license "$LICENSE_FILE" \
    --stylesheet "$STYLESHEET" \
    --validator "$VALIDATOR" \
    --system-root "$SYSTEM_ROOT" \
    --dpkg-query "$FAKE_DPKG" \
    --output-root "$PARTIAL_OUTPUT" \
    --allow-missing

grep -qF "Not installed" "$PARTIAL_OUTPUT/index.html" ||
  fail "Partial page does not identify the missing package."

grep -qF "<code>kiwix-tools</code>"   "$PARTIAL_OUTPUT/index.html" ||
  fail "Partial page omitted the missing package record."

if [[ -e "$PARTIAL_OUTPUT/notices/kiwix-tools.txt" ]]; then
  fail "Partial page created a notice for an uninstalled package."
fi

pass "Partial generation records unavailable packages truthfully."

if OFFGRIDPI_TEST_MISSING_PACKAGE="kiwix-tools" \
    "$GENERATOR" \
      --register "$REGISTER_FIXTURE" \
      --license "$LICENSE_FILE" \
      --stylesheet "$STYLESHEET" \
      --validator "$VALIDATOR" \
      --system-root "$SYSTEM_ROOT" \
      --dpkg-query "$FAKE_DPKG" \
      --output-root "$TEMP_ROOT/strict-missing" \
      >/dev/null 2>&1
then
  fail "Strict generation accepted a missing required package."
fi

pass "Strict generation rejected a missing required package."

touch "$OUTPUT_ROOT/preservation-sentinel"

rm \
  "$SYSTEM_ROOT/usr/share/doc/kiwix-tools/copyright"

if "$GENERATOR" \
    --register "$REGISTER_FIXTURE" \
    --license "$LICENSE_FILE" \
    --stylesheet "$STYLESHEET" \
    --validator "$VALIDATOR" \
    --system-root "$SYSTEM_ROOT" \
    --dpkg-query "$FAKE_DPKG" \
    --output-root "$OUTPUT_ROOT" \
    >/dev/null 2>&1
then
  fail "Generator accepted a missing required copyright notice."
fi

[[ -f "$OUTPUT_ROOT/preservation-sentinel" ]] ||
  fail "Failed generation replaced the previous valid output."

[[ -s "$OUTPUT_ROOT/index.html" ]] ||
  fail "Failed generation removed the previous legal page."

pass "Failed generation preserved the previous valid output."
pass "Legal-notice generator tests completed."
