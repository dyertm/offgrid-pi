# Offgrid Pi Roadmap

**Reconciled:** August 3, 2026

## Phase status summary

| Phase | Status |
|---|---|
| 0 — Project definition | Completed |
| 1 — Raspberry Pi foundation | Completed |
| 2 — Kiwix proof of concept | Completed |
| 3 — Dashboard prototype | Completed |
| 4 — Local document library | Completed |
| 5 — Reproducible installer | In progress — clean-install validation remaining |
| 6 — Content-pack system | Completed — starter workflow validated |
| 7 — System status and administration | Not started |
| 8 — Offline maps | Deferred |
| 9 — Offline entertainment | Planned |
| 10 — Local Wi-Fi hotspot | Deferred |
| 11 — Storage architecture | Deferred |
| 12 — Off-grid power optimization | Deferred |
| 13 — Backup and recovery | Deferred |
| 14 — Prebuilt release image | Deferred |
| 15 — Physical protection | Deferred |
| 16 — Community release | Future |

## Phase 0 — Project definition

**Status:** Completed

Completed outcomes:

* Mission, intended users, scope, architecture, and public documentation established
* Raspberry Pi 4B and Raspberry Pi OS Desktop selected
* Native services and scripted-install direction selected
* Public/private documentation boundary established

Remaining administrative item:

* Select and add the project license

## Phase 1 — Raspberry Pi foundation

**Status:** Completed

Validated outcomes:

* Patriot LX Series 64 GB microSDXC imaged and verified
* Raspberry Pi OS 64-bit Desktop installed
* Raspberry Pi 4B, 4 GB RAM confirmed
* Display, fan, keyboard, mouse, Wi-Fi, and hostname verified
* Operating system updated
* Foundational tools installed
* Baseline health checks passed

## Phase 2 — Kiwix proof of concept

**Status:** Completed

Validated outcomes:

* `kiwix-tools` and `zim-tools` installed
* Standard content directory created
* Test ZIM downloaded and checksummed
* Kiwix served content locally and over the local network
* `kiwix-serve.service` enabled and active
* Reboot persistence passed
* Offline operation passed

Known follow-up:

* Retest current ZIM archives with newer validation tools when available

## Phase 3 — Dashboard prototype

**Status:** Completed

Validated outcomes:

* Local dashboard created using only local assets
* Layout passed at 1024 × 600
* Kiwix link works locally and over the local network
* Dashboard service enabled on TCP port `8081`
* Chromium opens automatically after desktop login
* Normal desktop access remains available
* Manual full-screen mode passed
* Reboot and offline tests passed

Known follow-up:

* Reassess the Python prototype server before stable release
* Decide whether kiosk mode should be configurable

## Phase 4 — Local document library

**Status:** Completed

Validated outcomes:

* Separate public and personal document roots created with restrictive permissions
* Eleven approved public categories created, including `faith`
* Existing format-test and reference files migrated from the legacy `library` path
* Legacy content backed up and verified before removal of the old path
* Public catalog generated as HTML and JSON
* PDF, text, Markdown, HTML, SVG, and common document/image formats indexed
* Public document service enabled on TCP port `8082`
* Dashboard Local Documents card connected through a dynamic hostname redirect
* Automatic recursive indexing enabled through `inotifywait` and `systemd`
* Add and remove tests passed
* Personal content proved unserved and unindexed
* Local, network, reboot, and offline operation passed

Validated paths and services:

```text
/srv/offgridpi/content/documents/public
/srv/offgridpi/content/documents/personal
/opt/offgridpi/scripts/index-documents.py
/opt/offgridpi/scripts/watch-documents.sh
offgridpi-documents.service
offgridpi-document-indexer.service
```

Known follow-up:

* Windows `.local` hostname resolution may be temporarily unavailable after a reboot even when SSH, Avahi, and networking are healthy. Direct IP access is the documented fallback.

## Phase 5 — Reproducible installer

**Status:** In progress — clean-install validation remaining

Objectives:

* Convert validated manual procedures into idempotent scripts
* Detect the supported operating system, architecture, Raspberry Pi model, and administrator account
* Install packages, directories, permissions, scripts, and services safely
* Preserve existing user content during installation and upgrades
* Avoid hardcoded development usernames in public release files
* Add reusable verification and health-check scripts
* Add useful error handling and rerun safety
* Test each module independently before combining the complete installer
* Produce uninstall and rollback procedures
* Validate the finished installer on a clean Raspberry Pi OS installation

First checkpoint:

* Added `install.sh` with `check`, `install-documents`, and `verify` commands
* Added an administrator placeholder to the document-indexer service template
* Packaged the validated indexer, watcher, and document service
* Added `tests/verify-installation.sh` for repeatable platform, service, port, HTTP, catalog, and isolation checks

Completion criteria:

* A clean Raspberry Pi OS installation can be converted into Offgrid Pi without undocumented manual changes
* Re-running the installer does not damage services or user content
* Failures produce actionable messages
* Verification can be run independently after installation or upgrade

## Phase 6 — Content-pack system

**Status:** Completed — starter workflow validated

Completed outcomes:

* Added a versioned JSON manifest format and formal JSON Schema
* Added manifest validation for required fields, identifiers, checksums, licenses, duplicate item IDs, and safe destinations
* Added automated validator tests
* Added a draft starter content-pack manifest
* Added a read-only pack-status command
* Added a read-only installation planner
* Added checks for metadata completeness, HTTPS sources, destination conflicts, available storage, and required missing content
* Confirmed unrelated temporary Kiwix test content is ignored by pack status and planning
* Added automated status and planner tests
* Added verified download staging with exact size and SHA-256 enforcement
* Added protected installation with atomic copying and no silent overwrites
* Added installed-content verification and service refresh handling
* Added automated staging, installation, and refresh safety tests
* Separated deliberately incomplete test fixtures from production manifests
* Recorded authoritative metadata for the first starter-pack archive
* Downloaded, verified, installed, and served the Wikipedia English Top Articles Mini archive
* Confirmed the complete manifest-to-service workflow is safe and repeatable
* Retired and permanently removed the temporary Alpine Linux validation archive

Remaining content expansion:

* Medical, preparedness, agriculture, repair, radio, education, Pacific Northwest, maps, and faith manifests remain to be created
* Additional content sources require individual licensing and checksum review

Completion validation:

* Every published item records its source, size, version, license, destination, and checksum
* Downloads are staged and verified before installation
* Existing files are never silently overwritten
* Content installation can be rerun safely
* Kiwix and document indexes refresh only after successful verification
* The first production starter pack passed the complete workflow

## Phase 7 — System status and administration

**Status:** Not started

Add local health information, storage usage, service status, content status, safe shutdown, safe restart, reindexing, and protected administrative actions.

## Phase 8 — Offline maps

**Status:** Deferred

Evaluate formats and rendering approaches after the document library and installer are stable.

## Phase 9 — Offline entertainment

**Status:** Planned

Install and validate Kodi and VLC using attached storage. Test direct playback, subtitles, reboot mounts, offline operation, heat, power, undervoltage, and system stability.

## Phase 10 — Local Wi-Fi hotspot

**Status:** Deferred

Provide local access without an existing router after the base networking and security design are stable.

## Phase 11 — Storage architecture

**Status:** Deferred

Select final content storage, stable mount paths, reserved knowledge capacity, backup behavior, and drive-migration procedures.

## Phase 12 — Off-grid power optimization

**Status:** Deferred

Measure runtime and charging behavior with the currently available EcoFlow, Renogy, Voltaic, and Arc equipment after software and storage stabilize.

## Phase 13 — Backup and recovery

**Status:** Deferred

Create boot-media cloning, configuration export, content backup, and offline recovery procedures.

## Phase 14 — Prebuilt release image

**Status:** Deferred

Create only after scripted installation is stable and clean-install testing is repeatable.

## Phase 15 — Physical protection

**Status:** Deferred

Evaluate environmental, shock, water, and long-term storage after the core system is complete.

## Phase 16 — Community release

**Status:** Future

Publish a documented, reproducible, sanitized release with contribution and support guidance.

## Immediate next actions

1. Complete clean-install testing on a separate microSD card when available.
2. Create the medical and first-aid content-pack manifest.
3. Create the emergency-preparedness content-pack manifest.
4. Review additional agriculture, repair, radio, education, faith, and regional resources.
5. Begin Phase 7 system-status and administration design.
6. Select and add the project license.
