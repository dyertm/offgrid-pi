#!/usr/bin/env bash
set -Eeuo pipefail

PUBLIC_ROOT="/srv/offgridpi/content/documents/public"
INDEXER="/opt/offgridpi/scripts/index-documents.py"

if [[ ! -d "$PUBLIC_ROOT" ]]; then
  echo "ERROR: Public document directory is missing: $PUBLIC_ROOT" >&2
  exit 1
fi

if [[ ! -x "$INDEXER" ]]; then
  echo "ERROR: Document indexer is missing or not executable: $INDEXER" >&2
  exit 1
fi

if [[ ! -x /usr/bin/inotifywait ]]; then
  echo "ERROR: inotifywait is not installed." >&2
  exit 1
fi

rebuild_catalog() {
  echo "Rebuilding document catalog at $(date --iso-8601=seconds)"
  "$INDEXER"
}

# Ensure the catalog is current whenever the watcher starts.
rebuild_catalog

while true; do
  /usr/bin/inotifywait \
    --quiet \
    --recursive \
    --event close_write,moved_to,moved_from,create,delete,attrib \
    --exclude '(^|/)(index\.html|catalog\.json|\.index\.html\.tmp|\.catalog\.json\.tmp)$' \
    "$PUBLIC_ROOT"

  # Allow multi-file copy and move operations to settle.
  sleep 2
  rebuild_catalog
done
