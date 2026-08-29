#!/usr/bin/env bash
set -Eeuo pipefail

BACKUP_ROOT="${OFFGRIDPI_BACKUP_ROOT:-/srv/offgridpi/backups/configuration}"

SERVICES=(
  kiwix-serve.service
  offgridpi-dashboard.service
  offgridpi-documents.service
  offgridpi-document-indexer.service
  offgridpi-maps.service
  offgridpi-owner.service
)

MANAGED_PATHS=()
LAST_SNAPSHOT=""

log() {
  printf '[offgridpi-management] %s\n' "$*"
}

die() {
  printf '[offgridpi-management] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Offgrid Pi installation management

Usage:
  sudo ./scripts/manage-installation.sh backup
  sudo ./scripts/manage-installation.sh list
  sudo ./scripts/manage-installation.sh rollback SNAPSHOT --confirm
  sudo ./scripts/manage-installation.sh uninstall --dry-run
  sudo ./scripts/manage-installation.sh uninstall --confirm

Commands:
  backup    Create a configuration snapshot without copying user content.
  list      List available configuration snapshots.
  rollback  Restore configuration and service state from a snapshot.
  uninstall Remove installed components while preserving all user content.

Use "latest" as the snapshot name to restore the newest snapshot:

  sudo ./scripts/manage-installation.sh rollback latest --confirm

Preserved during uninstall:

  /srv/offgridpi/content
  /srv/offgridpi/backups
  The source repository
  Installed operating-system packages
  The offgridpi service account
USAGE
}

require_root() {
  [[ "$EUID" -eq 0 ]] || die "Run this command with sudo."
}

resolve_admin_user() {
  local candidate="${OFFGRIDPI_ADMIN_USER:-${SUDO_USER:-}}"

  [[ -n "$candidate" && "$candidate" != "root" ]] \
    || die \
      "Unable to determine the administrator. " \
      "Use OFFGRIDPI_ADMIN_USER=username."

  id "$candidate" >/dev/null 2>&1 \
    || die "Administrator account does not exist: $candidate"

  printf '%s\n' "$candidate"
}

resolve_admin_home() {
  local account="$1"
  local home_directory

  home_directory="$(
    getent passwd "$account" |
      cut -d: -f6
  )"

  [[ -n "$home_directory" && -d "$home_directory" ]] \
    || die "Unable to determine the home directory for $account."

  printf '%s\n' "$home_directory"
}

build_managed_paths() {
  local admin_home="$1"

  MANAGED_PATHS=(
    /etc/systemd/system/kiwix-serve.service
    /etc/systemd/system/offgridpi-dashboard.service
    /etc/systemd/system/offgridpi-documents.service
    /etc/systemd/system/offgridpi-document-indexer.service
    /etc/systemd/system/offgridpi-maps.service
    /etc/systemd/system/offgridpi-owner.service
    /opt/offgridpi/dashboard
    /opt/offgridpi/maps
    /opt/offgridpi/content-packs
    /opt/offgridpi/scripts/offgridpi-map-server.py
    /opt/offgridpi/scripts/offgridpi-owner-server.py
    /opt/offgridpi/scripts/offgridpi_owner_credentials.py
    /opt/offgridpi/scripts/offgridpi_owner_auth.py
    /var/lib/offgridpi/owner
    /opt/offgridpi/scripts/start-kiwix.sh
    /opt/offgridpi/scripts/launch-dashboard.sh
    /opt/offgridpi/scripts/index-documents.py
    /opt/offgridpi/scripts/watch-documents.sh
    /opt/offgridpi/scripts/manage-installation.sh
    "$admin_home/.config/autostart/offgridpi-dashboard.desktop"
  )
}

record_service_states() {
  local output_file="$1"
  local service enabled_state active_state

  printf 'service\tenabled\tactive\n' >"$output_file"

  for service in "${SERVICES[@]}"; do
    enabled_state="$(
      systemctl is-enabled "$service" 2>/dev/null ||
        true
    )"

    active_state="$(
      systemctl is-active "$service" 2>/dev/null ||
        true
    )"

    printf '%s\t%s\t%s\n' \
      "$service" \
      "${enabled_state:-unknown}" \
      "${active_state:-unknown}" \
      >>"$output_file"
  done
}

create_snapshot() {
  require_root

  local admin_user admin_group admin_home timestamp snapshot manifest
  local path relative_path
  local present_count=0
  local missing_count=0

  admin_user="$(resolve_admin_user)"
  admin_group="$(id -gn "$admin_user")"
  admin_home="$(resolve_admin_home "$admin_user")"

  build_managed_paths "$admin_home"

  timestamp="$(date +%Y%m%d-%H%M%S-%N)"
  snapshot="$BACKUP_ROOT/snapshot-$timestamp"
  manifest="$snapshot/manifest.txt"

  install -d \
    -o root \
    -g "$admin_group" \
    -m 0750 \
    "$BACKUP_ROOT" \
    "$snapshot" \
    "$snapshot/rootfs"

  {
    printf 'snapshot_format=1\n'
    printf 'created=%s\n' "$(date --iso-8601=seconds)"
    printf 'hostname=%s\n' "$(hostname)"
    printf 'administrator=%s\n' "$admin_user"
    printf 'content_preserved=/srv/offgridpi/content\n'
    printf 'backup_root=%s\n' "$BACKUP_ROOT"
    printf '\n'
    printf '[managed_paths]\n'
  } >"$manifest"

  for path in "${MANAGED_PATHS[@]}"; do
    if [[ -e "$path" || -L "$path" ]]; then
      relative_path="${path#/}"

      install -d \
        "$snapshot/rootfs/$(dirname "$relative_path")"

      cp -a \
        "$path" \
        "$snapshot/rootfs/$relative_path"

      printf 'PRESENT\t%s\n' "$path" >>"$manifest"
      present_count=$((present_count + 1))
    else
      printf 'MISSING\t%s\n' "$path" >>"$manifest"
      missing_count=$((missing_count + 1))
    fi
  done

  record_service_states "$snapshot/service-states.tsv"

  (
    cd "$snapshot"

    find rootfs \
      -type f \
      -print0 |
      sort -z |
      while IFS= read -r -d '' file; do
        sha256sum "$file"
      done >checksums.sha256
  )

  # Permit the administrator group to inspect snapshot metadata.
  # Never recursively change copied modes because rollback must restore them.
  chown root:"$admin_group" \
    "$BACKUP_ROOT" \
    "$snapshot" \
    "$snapshot/rootfs"

  chmod 0750 \
    "$BACKUP_ROOT" \
    "$snapshot" \
    "$snapshot/rootfs"

  LAST_SNAPSHOT="$snapshot"

  log "Configuration snapshot created."
  log "Snapshot: $snapshot"
  log "Present managed paths: $present_count"
  log "Missing managed paths: $missing_count"
  log "User content was not copied."
  log "Content remains at: /srv/offgridpi/content"
}

list_snapshots() {
  require_root

  if [[ ! -d "$BACKUP_ROOT" ]]; then
    log "No configuration backup directory exists."
    return 0
  fi

  local found=0
  local snapshot

  while IFS= read -r snapshot; do
    found=1
    printf '%s\n' "$snapshot"
  done < <(
    find "$BACKUP_ROOT" \
      -mindepth 1 \
      -maxdepth 1 \
      -type d \
      -name 'snapshot-*' \
      -printf '%f\n' |
      sort
  )

  if [[ "$found" -eq 0 ]]; then
    log "No configuration snapshots were found."
  fi
}

resolve_snapshot() {
  local requested="${1:-latest}"
  local snapshot=""

  [[ -d "$BACKUP_ROOT" ]] \
    || die "No configuration backup directory exists."

  if [[ "$requested" == "latest" ]]; then
    snapshot="$(
      find "$BACKUP_ROOT" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -name 'snapshot-*' \
        -printf '%p\n' |
        sort |
        tail -n 1
    )"
  else
    [[ "$requested" == snapshot-* ]] \
      || die \
        "Snapshot must be a snapshot name or the word latest."

    snapshot="$BACKUP_ROOT/$requested"
  fi

  [[ -n "$snapshot" && -d "$snapshot" ]] \
    || die "Requested configuration snapshot was not found."

  printf '%s\n' "$snapshot"
}

verify_snapshot() {
  local snapshot="$1"

  [[ -f "$snapshot/manifest.txt" ]] \
    || die "Snapshot manifest is missing."

  [[ -f "$snapshot/service-states.tsv" ]] \
    || die "Snapshot service-state record is missing."

  [[ -d "$snapshot/rootfs" ]] \
    || die "Snapshot root filesystem directory is missing."

  if [[ -s "$snapshot/checksums.sha256" ]]; then
    (
      cd "$snapshot"
      sha256sum --check checksums.sha256
    ) || die "Snapshot checksum validation failed."
  fi

  if find "$snapshot/rootfs" \
      -path '*/srv/offgridpi/content*' \
      -print -quit |
      grep -q .
  then
    die "Snapshot unexpectedly contains user content."
  fi
}

restore_service_states() {
  local state_file="$1"
  local service enabled_state active_state

  while IFS=$'\t' read -r \
    service enabled_state active_state
  do
    [[ "$service" == "service" ]] && continue
    [[ -n "$service" ]] || continue

    case "$enabled_state" in
      enabled)
        systemctl enable "$service" >/dev/null
        ;;
      disabled)
        systemctl disable "$service" >/dev/null 2>&1 || true
        ;;
      masked)
        systemctl mask "$service" >/dev/null
        ;;
    esac

    case "$active_state" in
      active)
        systemctl start "$service"
        ;;
      *)
        systemctl stop "$service" >/dev/null 2>&1 || true
        ;;
    esac
  done <"$state_file"
}

rollback_snapshot() {
  require_root

  local requested="${1:-}"
  local confirmation="${2:-}"
  local snapshot manifest
  local admin_user admin_home
  local state path source
  local restored_count=0
  local removed_count=0

  [[ "$confirmation" == "--confirm" ]] \
    || die \
      "Rollback requires explicit confirmation: " \
      "rollback SNAPSHOT --confirm"

  snapshot="$(resolve_snapshot "${requested:-latest}")"
  manifest="$snapshot/manifest.txt"

  verify_snapshot "$snapshot"

  admin_user="$(
    awk -F= \
      '$1 == "administrator" {print substr($0, index($0, "=") + 1); exit}' \
      "$manifest"
  )"

  [[ -n "$admin_user" ]] \
    || die "Snapshot administrator is missing."

  id "$admin_user" >/dev/null 2>&1 \
    || die "Snapshot administrator no longer exists: $admin_user"

  admin_home="$(resolve_admin_home "$admin_user")"
  build_managed_paths "$admin_home"

  declare -A allowed_paths=()

  for path in "${MANAGED_PATHS[@]}"; do
    allowed_paths["$path"]=1
  done

  log "Creating a safety snapshot before rollback."
  create_snapshot
  log "Rollback safety snapshot: $LAST_SNAPSHOT"
  log "Restoring snapshot: $snapshot"

  for service in "${SERVICES[@]}"; do
    systemctl stop "$service" >/dev/null 2>&1 || true
  done

  while IFS=$'\t' read -r state path; do
    [[ -n "$state" ]] || continue
    [[ -n "$path" ]] || continue

    [[ -n "${allowed_paths[$path]:-}" ]] \
      || die "Snapshot contains an unmanaged path: $path"

    case "$state" in
      PRESENT)
        source="$snapshot/rootfs/${path#/}"

        [[ -e "$source" || -L "$source" ]] \
          || die "Snapshot source is missing: $source"

        rm -rf -- "$path"
        install -d "$(dirname "$path")"
        cp -a -- "$source" "$path"

        restored_count=$((restored_count + 1))
        ;;

      MISSING)
        rm -rf -- "$path"
        removed_count=$((removed_count + 1))
        ;;

      *)
        die "Unknown snapshot path state: $state"
        ;;
    esac
  done < <(
    awk '
      found {print}
      /^\[managed_paths\]$/ {found=1}
    ' "$manifest"
  )

  systemctl daemon-reload
  systemctl reset-failed

  restore_service_states "$snapshot/service-states.tsv"

  log "Configuration rollback completed."
  log "Restored managed paths: $restored_count"
  log "Removed paths absent from snapshot: $removed_count"
  log "User content was preserved."
  log "Content remains at: /srv/offgridpi/content"
}


assert_safe_uninstall_path() {
  local path="$1"

  [[ "$path" == /* ]] \
    || die "Refusing to remove a non-absolute path: $path"

  case "$path" in
    /srv/offgridpi/content|/srv/offgridpi/content/*)
      die "Refusing to remove user content: $path"
      ;;

    /srv/offgridpi/backups|/srv/offgridpi/backups/*)
      die "Refusing to remove configuration backups: $path"
      ;;

    /|/etc|/opt|/home|/srv|/srv/offgridpi)
      die "Refusing to remove protected system path: $path"
      ;;
  esac
}

show_uninstall_plan() {
  require_root

  local admin_user admin_home
  local service enabled_state active_state
  local path state

  admin_user="$(resolve_admin_user)"
  admin_home="$(resolve_admin_home "$admin_user")"

  build_managed_paths "$admin_home"

  log "Uninstall dry-run only."
  log "No files or services will be changed."

  printf '\nServices that would be disabled and stopped:\n'

  for service in "${SERVICES[@]}"; do
    enabled_state="$(
      systemctl is-enabled "$service" 2>/dev/null ||
        true
    )"

    active_state="$(
      systemctl is-active "$service" 2>/dev/null ||
        true
    )"

    printf '  %-42s enabled=%-12s active=%s\n' \
      "$service" \
      "${enabled_state:-unknown}" \
      "${active_state:-unknown}"
  done

  printf '\nManaged paths that would be removed:\n'

  for path in "${MANAGED_PATHS[@]}"; do
    assert_safe_uninstall_path "$path"

    if [[ -e "$path" || -L "$path" ]]; then
      state="present"
    else
      state="missing"
    fi

    printf '  %-8s %s\n' "$state" "$path"
  done

  printf '\nPreserved paths and resources:\n'
  printf '  /srv/offgridpi/content\n'
  printf '  /srv/offgridpi/backups\n'
  printf '  Source repository and Git history\n'
  printf '  Installed operating-system packages\n'
  printf '  offgridpi service account\n'

  log "Run uninstall --confirm only after reviewing this plan."
}

uninstall_managed_components() {
  require_root

  local mode="${1:-}"
  local admin_user admin_home
  local service path
  local removed_count=0

  case "$mode" in
    ""|--dry-run)
      show_uninstall_plan
      return 0
      ;;

    --confirm)
      ;;

    *)
      die \
        "Uninstall accepts only --dry-run or --confirm."
      ;;
  esac

  admin_user="$(resolve_admin_user)"
  admin_home="$(resolve_admin_home "$admin_user")"

  build_managed_paths "$admin_home"

  log "Creating safety snapshot before uninstall."
  create_snapshot
  log "Uninstall safety snapshot: $LAST_SNAPSHOT"

  for service in "${SERVICES[@]}"; do
    systemctl disable --now "$service" \
      >/dev/null 2>&1 || true
  done

  for path in "${MANAGED_PATHS[@]}"; do
    assert_safe_uninstall_path "$path"

    if [[ -e "$path" || -L "$path" ]]; then
      rm -rf -- "$path"
      removed_count=$((removed_count + 1))
    fi
  done

  systemctl daemon-reload
  systemctl reset-failed

  rmdir /opt/offgridpi/scripts \
    >/dev/null 2>&1 || true

  rmdir /opt/offgridpi \
    >/dev/null 2>&1 || true

  log "Managed Offgrid Pi components were removed."
  log "Removed managed paths: $removed_count"
  log "User content was preserved: /srv/offgridpi/content"
  log "Backups were preserved: /srv/offgridpi/backups"
  log "Packages and service account were preserved."
}

case "${1:-}" in
  backup)
    create_snapshot
    ;;

  list)
    list_snapshots
    ;;

  rollback)
    rollback_snapshot "${2:-latest}" "${3:-}"
    ;;

  uninstall)
    uninstall_managed_components "${2:-}"
    ;;

  -h|--help|help|"")
    usage
    ;;

  *)
    usage >&2
    exit 2
    ;;
esac
