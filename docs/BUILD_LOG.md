# Offgrid Pi Build Log

**Reconciled:** August 2, 2026

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

## Current known issues

* `zimcheck` 3.5.0 disagrees with functional Kiwix behavior on the tested archives.
* Dashboard HTTP serving uses a prototype Python server.
* SSH success from the Windows development computer should be explicitly recorded if not already documented elsewhere.
* Repository address remains to be added.

## Next action

Validate the Phase 5 starter package on the development Pi:

1. Copy the starter files into the Git repository.
2. Run `sudo ./install.sh check`.
3. Run `./tests/verify-installation.sh` against the existing prototype.
4. Compare the script results with the manually validated baseline.
5. Add Kiwix, dashboard, browser-autostart, and full foundation installation modules.
6. Test the completed installer on a clean Raspberry Pi OS card.
