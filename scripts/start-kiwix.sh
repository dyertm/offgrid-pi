#!/usr/bin/env bash
set -Eeuo pipefail

KIWIX_ROOT="${KIWIX_ROOT:-/srv/offgridpi/content/kiwix}"
KIWIX_PORT="${KIWIX_PORT:-8080}"

declare -a ZIM_FILES=()

discover_zims() {
  [[ -d "$KIWIX_ROOT" ]] || {
    echo "ERROR: Kiwix content directory is missing: $KIWIX_ROOT" >&2
    exit 1
  }

  mapfile -d '' -t ZIM_FILES < <(
    find "$KIWIX_ROOT" \
      -type d -name rejected -prune -o \
      -type f \
      -name '*.zim' \
      -print0 |
      sort -z
  )

  if [[ "${#ZIM_FILES[@]}" -eq 0 ]]; then
    echo "ERROR: No ZIM files were found under $KIWIX_ROOT" >&2
    exit 1
  fi

  local zim

  for zim in "${ZIM_FILES[@]}"; do
    if [[ ! -r "$zim" ]]; then
      echo "ERROR: ZIM file is not readable: $zim" >&2
      exit 1
    fi
  done
}

discover_zims

if [[ "${1:-}" == "--check" ]]; then
  echo "Kiwix root: $KIWIX_ROOT"
  echo "ZIM count: ${#ZIM_FILES[@]}"

  for zim in "${ZIM_FILES[@]}"; do
    echo "  $zim"
  done

  exit 0
fi

[[ -x /usr/bin/kiwix-serve ]] || {
  echo "ERROR: /usr/bin/kiwix-serve is unavailable." >&2
  exit 1
}

exec /usr/bin/kiwix-serve \
  --port="$KIWIX_PORT" \
  "${ZIM_FILES[@]}"
