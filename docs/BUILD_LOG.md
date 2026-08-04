# Offgrid Pi Build Log

**Reconciled:** August 3, 2026

## Build environment

| Item | Configuration |
|---|---|
| Device | Raspberry Pi 4B, 4 GB RAM |
| Case | Miuzei case with cooling fan and heatsinks |
| Display | GeeekPi 10.1-inch HDMI, 1024 × 600 |
| Development power | 5V 3A USB-C supply |
| Input | USB keyboard and mouse |
| Network | Wi-Fi; Ethernet not used |
| Boot media | Patriot LX Series 64 GB microSDXC |
| Operating system | Raspberry Pi OS 64-bit Desktop; Debian 13 Trixie |
| Hostname | `offgridpi` |
| Repository path | `~/offgrid-pi` |

## July 29, 2026 — Project direction established

**Status:** Completed

* Defined Offgrid Pi as a reusable public project.
* Selected Raspberry Pi 4B and Raspberry Pi OS 64-bit Desktop.
* Selected Kiwix, a custom dashboard, native packages, and `systemd`.
* Deferred containers, release images, final storage, EMP planning, and power testing.
* Established `/opt/offgridpi` and `/srv/offgridpi` as standard roots.

## July 30, 2026 — Optional media module approved

**Status:** Planned module

* Selected Kodi as the planned primary media interface.
* Selected VLC as the fallback player.
* Kept media separate from core knowledge content.
* Deferred storage allocation, playback testing, and power measurements.

## July 30, 2026 — Initial imaging session

**Status:** Completed

* Card: Patriot LX Series 64 GB microSDXC, UHS-I, Class 10, U1
* Imager: Raspberry Pi Imager 2.0.10
* Image: Raspberry Pi OS 64-bit Desktop, Debian Trixie, June 18, 2026 release
* Hostname: `offgridpi`
* Username: `piadmin`
* Wi-Fi: configured
* SSH: enabled with password authentication
* Raspberry Pi Connect: disabled
* Image write and verification: passed

## July 31, 2026 — First boot and baseline

**Status:** Completed

Validated:

* Raspberry Pi 4B with 4 GB RAM
* Display, keyboard, mouse, fan, and Wi-Fi
* Desktop startup
* Local hostname access
* Operating-system update and reboot
* Foundational tools: Git, curl, wget, and rsync

Recorded baseline:

* Debian GNU/Linux 13 Trixie
* Kernel `6.18.34+rpt-rpi-v8`
* Architecture `aarch64`
* 3.7 GiB usable memory
* 2.0 GiB swap, unused during baseline
* Approximately 46 GB root storage available
* CPU temperature approximately 35°C
* Throttle status `0x0`
* Failed services: none

Known observation:

`xrandr` returned `Can't open display` outside the graphical session. The attached display was manually verified and remained usable at 1024 × 600.

## July 31, 2026 — Kiwix proof of concept

**Status:** Completed

Installed:

```bash
sudo apt install -y kiwix-tools zim-tools
```

Recorded versions:

* `kiwix-tools` 3.7.0
* `libkiwix` 14.0.0
* `libzim` used by Kiwix 9.2.3
* `zim-tools` 3.5.0

Created:

```text
/srv/offgridpi/content/kiwix
```

Test archives:

* `openzim_en_all_maxi_2026-05.zim`
  * SHA-256: `b87ba04033c170134c2069b1bc079e95d436dfd6ac19251374a32d58aec0df4c`
  * `zimcheck` reported a title-index structural error
* `alpinelinux_en_all_maxi_2026-07.zim`
  * SHA-256: `2d191a9da8bfde47ae505164d076a187513070bf92298fe0eaabdfbaa981ddf1`
  * The same validator error occurred
  * Functional Kiwix serving, navigation, and search passed

Successful manual command:

```bash
cd /srv/offgridpi/content/kiwix
kiwix-serve --port=8080 alpinelinux_en_all_maxi_2026-07.zim
```

The attempted `--address=0.0.0.0` option was not supported by the installed version and was removed.

Created restricted service account:

```bash
sudo useradd --system --home-dir /nonexistent --shell /usr/sbin/nologin offgridpi
```

Created and enabled:

```text
/etc/systemd/system/kiwix-serve.service
```

Validation results:

* Service enabled: passed
* Service active: passed
* TCP 8080 listening: passed
* Local browser access: passed
* Development-computer access through `offgridpi.local`: passed
* Reboot persistence: passed
* Offline search and navigation: passed
* Post-test temperature: 34.5°C
* Throttle status: `0x0`

Known issue:

The `zimcheck` discrepancy remains unresolved. Functional behavior passed, but validation should be repeated with future package versions.

## July 31, 2026 — Dashboard prototype

**Status:** Completed

Created:

```text
/opt/offgridpi/dashboard/
├── index.html
├── css/styles.css
└── js/app.js

/opt/offgridpi/scripts/launch-dashboard.sh
/home/piadmin/.config/autostart/offgridpi-dashboard.desktop
/etc/systemd/system/offgridpi-dashboard.service
```

Prototype service:

```bash
python3 -m http.server 8081 --directory /opt/offgridpi/dashboard
```

Validation results:

* Dashboard service enabled and active: passed
* TCP 8081 listening: passed
* Local HTTP response: passed
* Local-network access: passed
* Knowledge Library link to Kiwix: passed
* 1024 × 600 layout: passed
* Horizontal scrolling: not required
* Remote assets: none required
* Chromium automatic launch: passed
* Maximized window: passed
* Normal desktop access: preserved
* Manual full-screen appearance: passed
* Reboot persistence: passed
* Offline operation: passed

Current decision:

Retain maximized automatic launch during development. Treat manual full-screen as an optional appliance view. Reassess kiosk mode and the Python HTTP server before release.

## July 31, 2026 — Local document-library design started

**Status:** In progress

Accepted paths:

```text
/srv/offgridpi/content/documents/public
/srv/offgridpi/content/documents/personal
```

The personal path will not be served or indexed.

Approved public categories:

```text
emergency
first-aid
food
gardening
communications
radio
repair
equipment-manuals
education
books
faith
```

The `faith` category will support multiple Bible versions and related resources. Translation licensing and redistribution rights must be recorded.

Planned components:

```text
/opt/offgridpi/scripts/index-documents.py
offgridpi-documents.service
```

No document-library service, indexer, or browser validation has yet been recorded.

## August 1, 2026 — Documentation reconciliation

**Status:** Completed

* Updated public project status to reflect completed Phases 1 through 3.
* Added the Phase 4 public/private document model.
* Added the Faith and Scripture category.
* Created a public content-strategy document.
* Updated installation guidance with validated Kiwix and dashboard service definitions.
* Updated hardware records with confirmed device, RAM, card, OS, and baseline results.
* Explicitly separated commercialization and future product-platform notes into private source material.

## August 1, 2026 — Local document library completed

**Status:** Completed

Created protected document roots:

```text
/srv/offgridpi/content/documents/public
/srv/offgridpi/content/documents/personal
```

Public directory permissions were set to allow the administrative account to manage files while the restricted `offgridpi` service account could read them. The personal directory was set to mode `0700` and remained unreadable to the service account.

Created public categories:

```text
emergency
first-aid
food
gardening
communications
radio
repair
equipment-manuals
education
books
faith
```

An older `/srv/offgridpi/content/documents/library` tree was discovered. Before removal:

* A timestamped compressed backup was created under `/srv/offgridpi/backups`
* Existing sample and README files were copied into the new public tree
* All eight legacy files passed byte-for-byte comparison
* The legacy path was removed only after verification

Installed:

```text
/opt/offgridpi/scripts/index-documents.py
/opt/offgridpi/scripts/watch-documents.sh
/etc/systemd/system/offgridpi-documents.service
/etc/systemd/system/offgridpi-document-indexer.service
```

Service allocation:

* Kiwix: TCP `8080`
* Dashboard: TCP `8081`
* Public documents: TCP `8082`

Validation results:

* Initial catalog indexed nine public test/reference files: passed
* Private test file excluded from catalog: passed
* Public HTTP access: passed
* Parent traversal to the personal path returned HTTP 404: passed
* Dashboard Local Documents redirect worked locally: passed
* Dashboard Local Documents redirect worked from another device: passed
* Automatic file-add indexing: passed
* Automatic file-removal indexing: passed
* Reboot persistence for all four core services: passed
* Chromium automatic launch after reboot: passed
* Offline Kiwix, dashboard, and document access: passed

Permanent format-test files were retained for regression testing. Temporary public and private validation files were removed at Phase 4 closeout.

Known observation:

Windows briefly failed to resolve `offgridpi.local` after one reboot even though the Pi hostname, SSH service, Avahi service, and network were healthy. Direct IP access worked and is the recommended fallback when `.local` resolution is delayed.

## August 2, 2026 — Reproducible installer started

**Status:** In progress

Created the first Phase 5 installer checkpoint:

```text
install.sh
scripts/index-documents.py
scripts/watch-documents.sh
systemd/offgridpi-documents.service
systemd/offgridpi-document-indexer.service.in
tests/verify-installation.sh
```

The initial installer supports:

```text
check
install-documents
verify
```

Design choices:

* Installation is modular and idempotent
* The administrative username is detected from `sudo` or supplied through `OFFGRIDPI_ADMIN_USER`
* The public service template does not hardcode `piadmin`
* Existing user documents are preserved
* The document module can be installed and tested independently before the remaining modules are combined

## August 2, 2026 — Installer recovery validation

**Status:** Completed on the development Raspberry Pi

Installer `0.6.1` now supports:

* Modular and unified installation
* Independent verification
* Configuration snapshots
* Checksum-validated rollback
* Content-preserving uninstall
* Complete reinstall from the repository

Rollback restored the dashboard to its exact original checksum while preserving all user content. The uninstall and reinstall drill preserved the Kiwix archive and public documents, rebuilt all four services, restored TCP ports `8080`, `8081`, and `8082`, and finished with zero verification failures and no thermal throttling.

Commits:

* `85fb4dc` — Add configuration backup and rollback
* `8f97f74` — Add content-preserving uninstall

The verifier was also updated to accept an empty approved-ZIM library as a valid clean-install state. In that state, the Kiwix package and discovery service definition remain installed, while the Kiwix service, TCP port 8080, and HTTP endpoint are not required until an approved ZIM is added.

Clean-install validation on a separate Raspberry Pi OS card remains required before Phase 5 is marked complete.

## Current known issues

* `zimcheck` 3.5.0 disagrees with functional Kiwix behavior on the tested archives.
* Dashboard HTTP serving uses a prototype Python server.
* SSH success from the Windows development computer should be explicitly recorded if not already documented elsewhere.
* Repository address remains to be added.

## Next action

Continue Phase 6 by adding a staged download-and-verification workflow. Complete Phase 5 clean-install validation on a separate microSD card when available.

## August 2, 2026 — Content-pack foundation and read-only planning

**Status:** In progress

Added the initial content-pack framework:

```text
content-packs/README.md
content-packs/schema/content-pack.schema.json
content-packs/examples/example-pack.json
content-packs/manifests/starter.json
content-packs/validate-manifest.py
content-packs/content-pack-status.py
content-packs/content-pack-plan.py
content-packs/test-validator.sh
content-packs/test-status.sh
content-packs/test-plan.sh
```

Validated behavior:

* Valid manifests are accepted.
* Unsafe personal-content destinations are rejected.
* Malformed SHA-256 values are rejected.
* Duplicate item identifiers are rejected.
* Starter-pack status is reported without modifying content.
* Installation planning is read-only.
* Planning checks metadata, HTTPS transport, destination conflicts, storage, and required missing items.
* The incomplete starter manifest produces a blocked plan and exit code 1.
* The unrelated Alpine Linux test ZIM is ignored.
* All validator, status, and planner tests passed.

Repository milestones:

* `69684b6` — Add content pack manifest foundation
* `0e23980` — Add starter content pack status tooling
* `b3a9f9d` — Add read-only content pack planner

The Alpine Linux ZIM remains temporary Kiwix validation content and is not part of the starter pack.

## Phase 6 — First production content pack completed

**Date:** August 3, 2026
**Status:** Completed

### Work performed

* Completed the end-to-end content-pack workflow:
  * Manifest validation
  * Installed-content status
  * Read-only installation planning
  * Verified download staging
  * Protected no-overwrite installation
  * Installed-content verification
  * Affected-service refresh
* Added dedicated incomplete test fixtures so production manifests can contain complete metadata.
* Recorded authoritative metadata for the first starter-pack resource.
* Downloaded and staged the Wikipedia English Top Articles Mini ZIM.
* Verified the exact archive size and official SHA-256 checksum before installation.
* Installed the verified archive into the approved Kiwix content directory.
* Refreshed Kiwix only after installed-content verification passed.
* Confirmed Wikipedia loaded successfully through the local Kiwix interface.
* Quarantined the temporary Alpine Linux validation archive.
* Confirmed Kiwix worked with Wikipedia as the only approved archive.
* Permanently removed the retired Alpine validation archive.

### Starter content installed

```text
Title: Wikipedia English Top Articles — Mini
Version: 2026-06
File: wikipedia_en_top_mini_2026-06.zim
Destination: /srv/offgridpi/content/kiwix/wikipedia_en_top_mini_2026-06.zim
Exact size: 331421691 bytes
SHA-256: 2bcb45123f661b26ea6f1b1bf9d6b52caef6d2fb777507a0de3072b0c8df30ee
```

### Validation results

* Manifest validation passed.
* Planner reported complete metadata and ready status.
* Staging preview made no filesystem changes.
* Downloaded content passed exact-size and SHA-256 verification.
* Repeated staging reused the verified archive without redownloading.
* Installation preview made no live-content changes.
* Confirmed installation copied the archive atomically with mode `0640`.
* Repeated installation was idempotent.
* Existing conflicting files were not overwritten.
* Service refresh was blocked whenever installed-content verification failed.
* Kiwix restarted successfully after verified installation.
* Kiwix remained enabled and active on TCP port `8080`.
* Wikipedia opened successfully through the local browser.
* Rejected and retired archives were excluded from the running Kiwix command.
* The temporary Alpine validation archive was permanently removed.

### Current Phase 6 state

The core Phase 6 content-pack system is complete and validated with its first production starter pack. Future work will add additional curated manifests using the same verified workflow.

## August 3, 2026 — Phase 7 system status and administration checkpoint

**Status:** In progress — core local tools validated

### Components added

```text
scripts/offgridpi-status.py
scripts/offgridpi-admin.py
tests/test-system-status.sh
tests/test-system-admin.sh
tests/test-system-admin-confirm.sh
tests/test-system-admin-reindex.sh
tests/test-system-admin-actions.sh
tests/run-phase7-tests.sh
```

### Implemented behavior

* Added a read-only human-readable and JSON system-health report.
* Added service, listener, HTTP, storage, temperature, throttling, content, document-catalog, backup, and failed-unit reporting.
* Added preview-only administration as the default behavior.
* Added explicitly confirmed service restarts with readiness validation.
* Added protected public-document reindexing and catalog validation.
* Added protected reboot and power-off requests requiring root and the exact `OFFGRIDPI` confirmation phrase.
* Added injected fake dependencies for testing confirmed actions without restarting, rebooting, or powering off the development system.
* Added installer `0.7.0` and the independent `install-management` command.
* Extended the installation verifier to require and test the installed Phase 7 tools.

### Validation results

* Complete Phase 7 automated test suite exit code: `0`
* Installed system-status command exit code: `0`
* Complete installed-system verifier exit code: `0`
* Installed-system overall health: healthy
* Administration preview safeguards: passed
* Invalid confirmation handling: passed
* Simulated accepted and rejected service actions: passed
* Simulated valid, invalid, and failed document reindexing: passed
* Simulated reboot and power-off request handling: passed

No automated Phase 7 test issued a live reboot or power-off request.

### Remaining Phase 7 work

* Add dashboard-based status and administration views.
* Add safe local log viewing.
* Define authorization for browser-exposed administration.
* Perform controlled live reboot and power-off acceptance tests later.
* Validate installation on the separate clean-test microSD card.

## Phase 7 — Read-Only System Status Dashboard

**Date:** August 3, 2026  
**Status:** Completed and validated

Implemented the first browser-accessible Phase 7 management feature as a
read-only local system-status dashboard.

### Work completed

- Added a read-only System Status page to the local dashboard.
- Activated the System Status card on the main dashboard.
- Kept browser-based Administration disabled.
- Added status cards for:
  - hostname
  - uptime
  - Raspberry Pi temperature and throttling
  - storage usage
  - approved Kiwix content
  - indexed documents
  - configuration backups
  - failed systemd units
- Added local service-health rows for Kiwix, dashboard, documents, and the
  document indexer.
- Added automatic browser refresh every 60 seconds.
- Added a status publisher that writes validated JSON atomically.
- Added a systemd timer that refreshes the dashboard report every 60 seconds.
- Configured the publisher so an `ATTENTION` result is treated as a valid
  completed service result rather than a systemd failure.
- Updated the installer to deploy and enable the publisher safely.
- Updated dashboard installation to republish status immediately after
  `rsync --delete`.
- Added regression tests for the publisher, status page, local-only assets,
  safe DOM rendering, installer integration, and disabled Administration.
- Extended the installed-system verifier with dashboard status checks.

### Validation

The page was visually validated on:

- the attached 1024 × 600 Offgrid Pi display
- the development PC browser

The status page and JSON endpoint both returned HTTP 200. The status publisher
timer was enabled and active. The live status report parsed successfully and
reported a valid `HEALTHY` or `ATTENTION` state.

No browser-accessible privileged actions were introduced.

### Remaining Phase 7 work

- Safe local log viewing
- Browser authorization design
- Controlled live reboot and power-off acceptance testing
- Clean-card installation acceptance testing
