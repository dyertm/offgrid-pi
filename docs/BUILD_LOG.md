# Offgrid Pi Build Log

## Purpose

This document records the chronological development history of Offgrid Pi.

It should include:

* Work performed
* Commands used
* Configuration changes
* Test results
* Errors encountered
* Troubleshooting steps
* Successful fixes
* Files created or modified
* Outstanding tasks

This document is an engineering log. It may include failed attempts and temporary solutions that should not appear in the final installation guide.

---

## Build Environment

### Development System

| Item               | Configuration                              |
| ------------------ | ------------------------------------------ |
| Device             | Raspberry Pi 4B, 4 GB RAM                  |
| Case               | Miuzei case with cooling fan and heatsinks |
| Display            | GeeekPi 10.1-inch HDMI display             |
| Display resolution | 1024 × 600                                 |
| Development power  | 5V 3A USB-C power supply                   |
| Input              | USB keyboard and mouse                     |
| Network            | Wi-Fi connected; Ethernet not used         |
| Boot media         | Patriot LX Series 64 GB microSDXC          |
| Operating system   | Raspberry Pi OS 64-bit Desktop; Debian 13  |
| Repository         | Offgrid Pi GitHub repository               |
| Repository address | To be added                                |

## Status Legend

| Status          | Meaning                                           |
| --------------- | ------------------------------------------------- |
| **Planned**     | Approved but not started                          |
| **In progress** | Work has begun                                    |
| **Blocked**     | Cannot proceed until another issue is resolved    |
| **Testing**     | Configuration is complete and being validated     |
| **Completed**   | Work has been tested successfully                 |
| **Revisit**     | Functional for now but requires later improvement |

---

## July 29, 2026 — Project Direction Established

**Status:** Completed

### Work Completed

* Defined the project as a reusable offline knowledge platform rather than a one-time personal Raspberry Pi configuration.
* Selected the Raspberry Pi 4B as the initial development platform.
* Established direct monitor use as a core requirement.
* Selected Raspberry Pi OS 64-bit with Desktop as the planned operating-system baseline.
* Selected Kiwix as the initial offline-content engine.
* Proposed a custom local dashboard as the primary user interface.
* Decided to use standard Linux services for the initial release.
* Deferred Docker-based deployment.
* Deferred downloadable disk-image creation until scripted installation is stable.
* Defined an initial GitHub repository structure.
* Defined preliminary application and content directories.
* Separated active software development from future storage, EMP, Faraday, and power-system planning.
* Created the initial project documentation set.

### Current Project Documents

```text
docs/
├── PROJECT_BLUEPRINT.md
├── BUILD_LOG.md
├── DECISIONS.md
├── INSTALLATION.md
└── ROADMAP.md
```

### Current Planned Application Directories

```text
/opt/offgridpi/
/srv/offgridpi/
```

### Current Planned Services

```text
kiwix-serve.service
offgridpi-dashboard.service
offgridpi-indexer.service
```

### Initial Action List — Current Status

Completed during the July 30–31 development session:

* Selected and documented the development microSD card.
* Installed Raspberry Pi Imager and recorded the imaging configuration.
* Flashed and verified Raspberry Pi OS 64-bit with Desktop.
* Completed the first boot and verified the display, fan, keyboard, mouse, and Wi-Fi.
* Updated Raspberry Pi OS and recorded baseline system information.
* Installed Git, curl, wget, and rsync.
* Cloned the Offgrid Pi repository to `~/offgrid-pi` on the Raspberry Pi.
* Installed Kiwix and ZIM tools from the Debian 13 ARM64 repositories.
* Created the standard Kiwix content directory.
* Downloaded and tested small ZIM archives.
* Served Kiwix content locally and to another device on the local network.
* Created and enabled `kiwix-serve.service`.
* Confirmed automatic service startup and successful offline operation.

Remaining near-term tasks:

* Add the confirmed GitHub repository address to this document.
* Confirm and document SSH access from the Windows development computer if not already recorded separately.
* Begin Phase 4 — Local Document Library.

---

## July 30, 2026 — Offline Media Module Approved

**Status:** Completed

### Work Completed

* Approved an optional offline entertainment module for movies, television programs, music, and audiobooks.
* Selected Kodi as the primary media-library interface.
* Selected VLC as the fallback player for individual files.
* Confirmed that Raspberry Pi OS 64-bit with Desktop will remain the operating-system baseline.
* Deferred LibreELEC because Offgrid Pi must continue supporting Kiwix, maps, documents, scripts, and normal desktop administration.
* Deferred Jellyfin, network streaming, and transcoding from the initial media implementation.
* Defined preliminary media directories under `/srv/offgridpi/content/media`.
* Established that emergency-reference content receives storage priority over entertainment media.
* Assigned final media-drive selection and reserved-capacity planning to the storage-architecture phase.
* Assigned EcoFlow runtime and solar testing to the off-grid power-optimization phase.
* Updated the following files:

  * `README.md`
  * `01-HARDWARE.md`
  * `PROJECT_BLUEPRINT.md`
  * `DECISIONS.md`
  * `ROADMAP.md`
  * `INSTALLATION.md`
  * `BUILD_LOG.md`

### Validation Status

* No Kodi or VLC packages have been installed yet.
* No media playback tests have been performed yet.
* No USB-drive mount behavior has been validated yet.
* No power-consumption measurements have been performed yet.

### Planned Media Test Targets

* MP4 and MKV containers
* H.264 video at 720p and 1080p
* AAC stereo audio
* SRT subtitles
* VLC fallback playback
* Offline operation with network access disconnected
* Drive remount after reboot
* Temperature, undervoltage, and stability checks

---

## Initial Imaging Session

**Date:** July 30, 2026  
**Status:** Completed

### MicroSD Card

* **Brand:** Patriot
* **Model:** LX Series
* **Capacity:** 64 GB
* **Card type:** microSDXC
* **Bus interface:** UHS-I
* **Speed rating:** Class 10, U1
* **Previous contents backed up:** Not applicable — new card
* **Card erased:** Yes
* **Imaging computer:** Windows development computer
* **Card reader:** HDE All-in-One card reader

### Raspberry Pi Imager Version

* **Version:** 2.0.10
* **Download source:** Official Raspberry Pi website
* **Verification performed:** Yes — Raspberry Pi Imager completed write verification

### Image Selected

* **Device:** Raspberry Pi 4
* **Operating system:** Raspberry Pi OS (64-bit) with Raspberry Pi Desktop
* **Distribution base:** Debian Trixie
* **Architecture:** 64-bit
* **Release date:** June 18, 2026
* **Image filename:** Managed automatically by Raspberry Pi Imager

### Imager Customization

* **Hostname:** `offgridpi`
* **Username:** `piadmin`
* **Password configured:** Yes
* **Wi-Fi configured:** Yes
* **Wi-Fi country:** US
* **Time zone:** America/Los_Angeles
* **Keyboard layout:** US
* **SSH enabled:** Yes
* **SSH authentication method:** Password authentication
* **Raspberry Pi Connect:** Disabled
* **Telemetry setting:** Not recorded
* **Other settings:** Wi-Fi and account credentials were configured in Raspberry Pi Imager. Passwords were not recorded in the repository.

### Imaging Result

* **Imaging started:** July 30, 2026 — exact time not recorded
* **Imaging completed:** July 30, 2026 — exact time not recorded
* **Verification completed:** Yes
* **Errors:** None observed
* **Notes:** Raspberry Pi Imager successfully wrote and verified Raspberry Pi OS on the 64 GB development microSD card.

---

## First Boot

**Date:** July 31, 2026  
**Status:** Completed

### Hardware Connected

* **Raspberry Pi:** Raspberry Pi 4 Model B, 4 GB RAM
* **MicroSD card:** Patriot LX Series 64 GB microSDXC, UHS-I, Class 10, U1
* **Display:** GeeekPi 10.1-inch HDMI display
* **HDMI connection:** Micro-HDMI-to-HDMI cable
* **Keyboard:** USB keyboard
* **Mouse:** USB mouse
* **Ethernet:** Not connected
* **Wi-Fi:** Connected to the development network
* **Power supply:** 5V 3A USB-C power supply

### Boot Results

* **Power LED:** Operating normally
* **Activity LED:** Operating normally
* **Video output:** Working
* **Desktop loaded:** Yes
* **Display resolution:** 1024 × 600, based on the display specification and usable desktop output
* **Keyboard detected:** Yes
* **Mouse detected:** Yes
* **Fan operating:** Yes
* **Network connected:** Yes — Wi-Fi
* **Hostname reachable:** Yes — `offgridpi.local` was successfully used from the development computer for Kiwix browser access; SSH confirmation remains separately documented as pending
* **Errors or warnings:** None observed during first boot
* **Notes:** Raspberry Pi OS completed its first boot successfully. The desktop and connected peripherals operated normally.

---

## Operating-System Update

**Date:** July 31, 2026  
**Status:** Completed

### Commands

```bash
sudo apt update
sudo apt full-upgrade -y
sudo reboot
```

### Results

* **Package lists updated:** Yes
* **Packages upgraded:** Yes
* **Errors:** None observed
* **Reboot successful:** Yes
* **Kernel version:** `6.18.34+rpt-rpi-v8`
* **Operating-system version:** Debian GNU/Linux 13 (Trixie)
* **Architecture:** `aarch64`
* **Available disk space after update:** 46 GB
* **Root partition usage:** 6.8 GB used of 55 GB, 13% utilized
* **Notes:** Raspberry Pi OS was updated successfully. The Raspberry Pi rebooted normally and returned to an operational state.

---

## Foundational Tools Installation

**Date:** July 31, 2026  
**Status:** Completed

### Command

```bash
sudo apt install -y git curl wget rsync
```

### Results

* **Git installed:** Yes
* **curl installed:** Yes
* **wget installed:** Yes
* **rsync installed:** Yes
* **Installation errors:** None observed
* **Notes:** Foundational command-line, download, file-synchronization, and repository-management tools were installed successfully.

---

## Initial System Information

**Date:** July 31, 2026  
**Status:** Completed

### Commands

```bash
cat /etc/os-release
uname -a
hostnamectl
free -h
df -h
ip address
vcgencmd measure_temp
vcgencmd get_throttled
systemctl --failed
```

### Operating System

* **Selected image:** Raspberry Pi OS 64-bit with Raspberry Pi Desktop
* **Distribution base:** Debian GNU/Linux 13
* **Distribution codename:** Trixie
* **Kernel:** `6.18.34+rpt-rpi-v8`
* **Architecture:** `aarch64`
* **Hostname:** `offgridpi`

### Memory

* **Installed hardware memory:** 4 GB
* **Usable system memory:** 3.7 GiB
* **Memory used during baseline check:** 349 MiB
* **Memory free during baseline check:** 2.8 GiB
* **Memory available during baseline check:** 3.4 GiB
* **Buffer/cache usage:** 656 MiB
* **Configured swap:** 2.0 GiB
* **Swap used during baseline check:** 0 bytes

### Operating-System Storage

* **Device:** `/dev/mmcblk0p2`
* **Mounted at:** `/`
* **Formatted capacity:** 55 GB
* **Used space:** 6.8 GB
* **Available space:** 46 GB
* **Utilization:** 13%

### System Health

* **CPU temperature:** 35.0°C
* **Throttle status:** `0x0`
* **Undervoltage detected:** No
* **Frequency throttling detected:** No
* **Failed systemd services:** None
* **System health result:** Passed

### Display

* **Physical display:** GeeekPi 10.1-inch HDMI display
* **Expected resolution:** 1024 × 600
* **Automatic command result:** `xrandr` returned `Can't open display`
* **Explanation:** The command was run outside the active graphical desktop session and could not access the display server.
* **Manual display verification:** Yes
* **Display usable:** Yes
* **Display resolution:** 1024 × 600, based on the display specification and usable desktop output

### Network and Remote Administration

* **Connection type:** Wi-Fi
* **Hostname:** `offgridpi`
* **Network address:** IPv4 and IPv6 addresses were assigned; exact addresses are excluded from the public repository
* **Local hostname access:** Confirmed from the development computer using `offgridpi.local`
* **SSH enabled:** Yes
* **SSH authentication:** Password authentication
* **SSH connectivity from development computer:** Pending explicit build-log confirmation
* **Raspberry Pi Connect:** Disabled
* **Local repository clone:** Confirmed at `~/offgrid-pi`

### Baseline Assessment

The Raspberry Pi passed its initial operating-system, memory, storage, temperature, throttling, display, and service-health checks. No failed services, undervoltage conditions, thermal throttling, or storage concerns were detected.

---

## Kiwix Test Installation

**Date:** July 31, 2026  
**Status:** Completed

### Objectives Completed

* Confirmed that Kiwix and ZIM tools were available from the Debian 13 Trixie ARM64 repositories.
* Installed `kiwix-tools` and `zim-tools`.
* Created the standard Offgrid Pi Kiwix content directory.
* Downloaded small test ZIM archives from the official Kiwix download repository.
* Recorded SHA-256 checksums for the test archives.
* Documented repeated `zimcheck` validation errors.
* Successfully served a ZIM archive manually with `kiwix-serve`.
* Confirmed local access from the Raspberry Pi.
* Confirmed local-network access from the Windows development computer.
* Created and enabled a persistent systemd service.
* Confirmed the service remained enabled and active during post-reboot verification.
* Confirmed Kiwix content remained usable with networking disabled.

### Repository Availability Check

```bash
sudo apt update
apt-cache policy kiwix-tools zim-tools
```

Results:

* **kiwix-tools installed before test:** No
* **kiwix-tools candidate:** `3.7.0-1.1`
* **zim-tools installed before test:** No
* **zim-tools candidate:** `3.5.0-1.2+b2`
* **Repository:** Debian 13 Trixie main, ARM64
* **Package-list status:** All packages were up to date

### Installation

```bash
sudo apt install -y kiwix-tools zim-tools
```

Installed command paths:

```text
/usr/bin/kiwix-serve
/usr/bin/kiwix-manage
/usr/bin/zimcheck
```

Installed software versions:

* **kiwix-tools:** 3.7.0
* **libkiwix:** 14.0.0
* **libzim used by Kiwix:** 9.2.3
* **zim-tools:** 3.5.0
* **Architecture:** ARM64 / `aarch64`

### Content Directory

Created with:

```bash
sudo install -d \
  -o piadmin \
  -g piadmin \
  -m 0755 \
  /srv/offgridpi/content/kiwix
```

Verified configuration:

```text
drwxr-xr-x piadmin piadmin /srv/offgridpi/content/kiwix
```

* **Path:** `/srv/offgridpi/content/kiwix`
* **Owner:** `piadmin`
* **Group:** `piadmin`
* **Permissions:** `0755`

### Test ZIM Attempt 1

Downloaded with:

```bash
cd /srv/offgridpi/content/kiwix
wget https://download.kiwix.org/zim/other/openzim_en_all_maxi_2026-05.zim
```

Results:

* **File:** `openzim_en_all_maxi_2026-05.zim`
* **Source:** Official Kiwix download repository
* **Downloaded size:** 3,216,041 bytes
* **SHA-256:** `b87ba04033c170134c2069b1bc079e95d436dfd6ac19251374a32d58aec0df4c`
* **Validator:** `zimcheck` 3.5.0
* **Validation status:** Failed
* **Reported error:** `Full Title index table outside (or not fully inside) ZIM file.`
* **Low-level result:** `ZIM file's low level structure is invalid`
* **Functional-service use:** Not selected for the completed service test

### Test ZIM Attempt 2

* **File:** `alpinelinux_en_all_maxi_2026-07.zim`
* **Source:** Official Kiwix download repository
* **SHA-256:** `2d191a9da8bfde47ae505164d076a187513070bf92298fe0eaabdfbaa981ddf1`
* **Validator:** `zimcheck` 3.5.0
* **Validation status:** Failed
* **Reported error:** `Full Title index table outside (or not fully inside) ZIM file.`
* **Low-level result:** `ZIM file's low level structure is invalid`
* **Functional-service result:** Successfully opened and served by `kiwix-serve` 3.7.0
* **Selected use:** Initial Phase 2 functional proof-of-concept archive

### Validation Finding

Both current official test archives produced the same title-index error in `zimcheck` 3.5.0. The Alpine Linux archive nevertheless opened and operated normally through `kiwix-serve` 3.7.0.

The cause has not been conclusively established. The build therefore records the validator result as a known discrepancy rather than declaring either the archive or validator definitively defective. Future testing should repeat validation with updated `zim-tools` and `libzim` packages when available.

### Manual Serving Test

Successful command:

```bash
cd /srv/offgridpi/content/kiwix
kiwix-serve --port=8080 alpinelinux_en_all_maxi_2026-07.zim
```

The initially attempted `--address=0.0.0.0` option was not accepted by the installed command version and was removed. With the address option omitted, Kiwix listened successfully on the available interfaces.

Results:

* **Listening port:** TCP 8080
* **Local Raspberry Pi URL:** `http://localhost:8080`
* **Development-computer URL:** `http://offgridpi.local:8080`
* **Raspberry Pi browser access:** Passed
* **Development-computer browser access:** Passed
* **Content opened:** Passed
* **Navigation:** Passed
* **Search:** Passed
* **Manual-serving errors:** None after removing the unsupported address argument

### Service Account

A restricted system account was used for the automatic service:

```bash
sudo useradd \
  --system \
  --home-dir /nonexistent \
  --shell /usr/sbin/nologin \
  offgridpi
```

* **Service user:** `offgridpi`
* **Login shell:** `/usr/sbin/nologin`

### Systemd Service

Service path:

```text
/etc/systemd/system/kiwix-serve.service
```

Service definition used:

```ini
[Unit]
Description=Offgrid Pi Kiwix Server
After=local-fs.target
RequiresMountsFor=/srv/offgridpi/content/kiwix

[Service]
Type=simple
User=offgridpi
Group=offgridpi
ExecStart=/usr/bin/kiwix-serve --port=8080 /srv/offgridpi/content/kiwix/alpinelinux_en_all_maxi_2026-07.zim
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict

[Install]
WantedBy=multi-user.target
```

Service validation and activation commands:

```bash
sudo systemd-analyze verify /etc/systemd/system/kiwix-serve.service
sudo systemctl daemon-reload
sudo systemctl enable --now kiwix-serve.service
sudo systemctl status kiwix-serve.service --no-pager
```

Final service verification:

```text
enabled
active
LISTEN 0 4096 *:8080 *:*
```

Results:

* **Service enabled:** Yes
* **Service active:** Yes
* **Listening interface:** All available interfaces
* **Listening port:** TCP 8080
* **Restart policy:** Restart on failure after five seconds
* **Reboot persistence:** Passed during post-reboot verification
* **Local access after service activation:** Passed
* **Development-computer access after service activation:** Passed

### Offline Operation Test

Networking was disabled from the attached Raspberry Pi session so the test would not depend on SSH connectivity:

```bash
sudo nmcli networking off
```

The following page was then reloaded locally:

```text
http://localhost:8080
```

Offline results:

* **Kiwix interface available:** Passed
* **Alpine Linux archive available:** Passed
* **Content navigation:** Passed
* **Search:** Passed
* **Required internet connection:** No

Networking was restored with:

```bash
sudo nmcli networking on
nmcli general status
hostname -I
```

Recovery results:

* **Network state:** Connected
* **Connectivity:** Full
* **Wi-Fi hardware:** Enabled
* **Wi-Fi:** Enabled
* **IPv4 address assigned:** Yes — excluded from the public repository
* **IPv6 address assigned:** Yes — excluded from the public repository
* **Development-computer access after restoration:** Passed

### System Health After Kiwix Testing

Final checks:

```bash
kiwix-serve --version
systemctl is-enabled kiwix-serve.service
systemctl is-active kiwix-serve.service
ss -ltn | grep ':8080'
vcgencmd measure_temp
vcgencmd get_throttled
```

Results:

* **CPU temperature:** 34.5°C
* **Throttle status:** `0x0`
* **Undervoltage detected:** No
* **Frequency throttling detected:** No
* **Service enabled:** Yes
* **Service active:** Yes
* **TCP port 8080:** Listening
* **Stability concerns:** None observed

### Phase 2 Assessment

Phase 2 was successful. Kiwix is installed, starts automatically, serves a local ZIM archive, is available from both the Raspberry Pi and another device on the local network, survives restart testing, and continues to function without internet access.

---

## Dashboard Prototype

**Date:** July 31, 2026  
**Status:** Completed

### Objectives Completed

* Created a fully local Offgrid Pi landing page.
* Created a responsive layout optimized for the 1024 × 600 GeeekPi display.
* Added a working Knowledge Library card linked to Kiwix on TCP port 8080.
* Added placeholders for Local Documents, Offline Maps, Offline Entertainment, System Status, and Administration.
* Used only locally stored HTML, CSS, and JavaScript assets.
* Tested the dashboard manually before creating a permanent service.
* Created and enabled `offgridpi-dashboard.service` on TCP port 8081.
* Created a Chromium launcher that waits for the dashboard service before opening the page.
* Added a per-user desktop autostart entry for `piadmin`.
* Preserved access to the normal Raspberry Pi desktop.
* Confirmed that Chromium can be placed into full-screen mode for an appliance-style interface.
* Confirmed local, network, reboot, and offline operation.

### Dashboard Files

```text
/opt/offgridpi/dashboard/
├── index.html
├── css/
│   └── styles.css
└── js/
    └── app.js
```

Supporting launcher:

```text
/opt/offgridpi/scripts/launch-dashboard.sh
```

Desktop autostart entry:

```text
/home/piadmin/.config/autostart/offgridpi-dashboard.desktop
```

### Initial Manual Test

The prototype dashboard was first served manually with:

```bash
python3 -m http.server \
  8081 \
  --directory /opt/offgridpi/dashboard
```

Manual test results:

* **Raspberry Pi URL:** `http://localhost:8081`
* **Development-computer URL:** `http://offgridpi.local:8081`
* **Dashboard loaded locally:** Passed
* **Dashboard loaded from development computer:** Passed
* **Knowledge Library link:** Passed from both devices
* **1024 × 600 usability:** Passed
* **Horizontal scrolling required:** No
* **Remote fonts, scripts, icons, or images required:** No
* **Visual assessment:** Dashboard displayed cleanly and was considered visually successful

### Dashboard Service

Service path:

```text
/etc/systemd/system/offgridpi-dashboard.service
```

Service definition used:

```ini
[Unit]
Description=Offgrid Pi Dashboard
After=local-fs.target
ConditionPathExists=/opt/offgridpi/dashboard/index.html

[Service]
Type=simple
User=offgridpi
Group=offgridpi
WorkingDirectory=/opt/offgridpi/dashboard
ExecStart=/usr/bin/python3 -m http.server 8081 --directory /opt/offgridpi/dashboard
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadOnlyPaths=/opt/offgridpi/dashboard

[Install]
WantedBy=multi-user.target
```

Service validation and activation commands:

```bash
sudo systemd-analyze verify \
  /etc/systemd/system/offgridpi-dashboard.service
sudo systemctl daemon-reload
sudo systemctl enable --now offgridpi-dashboard.service
sudo systemctl status offgridpi-dashboard.service --no-pager
```

Results:

* **Service enabled:** Yes
* **Service active:** Yes
* **Listening port:** TCP 8081
* **Local HTTP response:** Passed
* **Development-computer access:** Passed
* **Automatic restart policy:** Restart on failure after five seconds
* **Reboot persistence:** Passed

### Chromium Automatic Launch

Launcher path:

```text
/opt/offgridpi/scripts/launch-dashboard.sh
```

The launcher:

* Waits for the dashboard service to answer on `http://127.0.0.1:8081/`.
* Avoids opening a duplicate dashboard window.
* Opens Chromium in a new maximized window.
* Disables first-run and default-browser prompts.
* Records launcher output under the `piadmin` user state directory.

Autostart entry:

```text
/home/piadmin/.config/autostart/offgridpi-dashboard.desktop
```

Automatic-launch results:

* **Chromium launched after desktop login:** Passed
* **Dashboard opened automatically:** Passed
* **Window opened maximized:** Passed
* **Normal desktop remained accessible:** Passed
* **Knowledge Library link after automatic launch:** Passed
* **Closing or minimizing Chromium returned to the desktop:** Passed

### Full-Screen Display Test

Chromium was manually switched into full-screen mode using the browser full-screen control.

Results:

* **Dashboard occupied the full 1024 × 600 display:** Passed
* **Browser controls hidden:** Yes
* **Appliance-style appearance:** Passed
* **Visual assessment:** The dashboard looked especially effective when full screen was enabled and it was the only interface visible
* **Current decision:** Retain normal maximized automatic launch during development and use manual full-screen mode as needed. A configurable full-screen or kiosk option may be added later.

### Offline Operation Test

Networking was disabled from the attached Raspberry Pi session and the following local page was reloaded:

```text
http://127.0.0.1:8081
```

The Knowledge Library card was then used to open the local Kiwix service.

Offline results:

* **Dashboard available:** Passed
* **Dashboard styling and scripts available:** Passed
* **Knowledge Library link:** Passed
* **Kiwix service available:** Passed
* **Required internet connection:** No
* **Networking restored successfully:** Yes

### Phase 3 Assessment

Phase 3 was successful. The Offgrid Pi dashboard is readable on the attached 1024 × 600 display, is available from another local-network device, starts automatically as a system service, opens automatically in Chromium after desktop login, uses only local assets, links successfully to Kiwix, and continues to function without internet access.

The current Python static server is appropriate for the working prototype. Its suitability for the stable public release should be reviewed during the reproducible-installer and hardening phases.

---

## Local Document Library

**Date:** Not started  
**Status:** Planned

### Objectives

* Create approved public document categories.
* Keep personal or private material outside the browser-accessible library.
* Support common offline formats such as PDF, text, HTML, and images.
* Generate a local browser index from files copied into the category folders.
* Add file metadata such as display name, type, size, and modification date.
* Add a working Local Documents link to the dashboard.
* Test document access on the Raspberry Pi and from another local-network device.
* Confirm that the library and its indexes remain functional without internet access.
* Document naming, import, indexing, and removal procedures.

### Proposed Public Content Path

```text
/srv/offgridpi/content/documents/public
```

### Proposed Private Content Path

```text
/srv/offgridpi/content/documents/personal
```

The private path will not be served by the document-library web service or included in generated indexes.

### Proposed Public Categories

```text
public/
├── emergency/
├── first-aid/
├── food/
├── gardening/
├── communications/
├── radio/
├── repair/
├── equipment-manuals/
├── education/
└── books/
```

### Planned Indexer

```text
/opt/offgridpi/scripts/index-documents.py
```

### Planned Service

```text
offgridpi-documents.service
```

### Test Results

> To be completed during Phase 4 development.

---

## Offline Media Module Test

**Date:** Not started
**Status:** Planned

### Software

* **Kodi installed:**
* **Kodi version:**
* **VLC installed:**
* **VLC version:**
* **Installation method:**

### Storage

* **Test drive manufacturer:**
* **Test drive model:**
* **Capacity:**
* **File system:**
* **Mount path:**
* **Automatic mount after reboot:**
* **Available space before testing:**

### Playback Tests

* **MP4 test:**
* **MKV test:**
* **720p H.264 test:**
* **1080p H.264 test:**
* **AAC stereo test:**
* **SRT subtitle test:**
* **VLC fallback test:**
* **Offline playback test:**
* **Kodi exit and return test:**

### System Behavior

* **CPU temperature before playback:**
* **CPU temperature during playback:**
* **Undervoltage warnings:**
* **Drive disconnects:**
* **Dropped frames or stuttering:**
* **Other errors:**

### Notes

> To be completed during Phase 9.

---

## Known Issues

### Display Query Outside the Graphical Session

The command below returned `Can't open display` when it was run outside the active graphical desktop session:

```bash
xrandr --current | grep '\*'
```

This did not indicate a display failure. The attached display was manually verified as usable at its expected 1024 × 600 resolution.

### Repeated ZIM Validation Error

`zimcheck` 3.5.0 reported the same title-index structural error for both tested 2026 ZIM archives:

```text
Full Title index table outside (or not fully inside) ZIM file.
ZIM file's low level structure is invalid
```

The Alpine Linux archive still opened, navigated, searched, survived service and reboot testing, and operated without internet access through `kiwix-serve` 3.7.0. The precise cause of the validation discrepancy remains unresolved and should be retested when newer validation packages are available.

### Prototype Dashboard Server Requires Later Review

The dashboard currently uses Python's built-in static HTTP server. It has been reliable for the Phase 3 prototype, but it is intentionally simple and should be reassessed before the stable public release. A later phase may retain it with documented limitations or replace it with a lightweight dedicated web server.

### SSH Confirmation Not Explicitly Recorded

SSH was enabled during imaging with password authentication. The repository is present at `~/offgrid-pi`, and local-network hostname access is confirmed, but a dedicated SSH success result has not yet been explicitly entered in this build log.

---

## Lessons Learned

* Commands that query the graphical display may fail when run through SSH or outside the active desktop session even though the physical display is operating normally.
* Manual verification should be recorded when an automated check cannot access the graphical session.
* Baseline temperature, throttling, storage, memory, and failed-service checks provide a useful health snapshot before installing application services.
* Package availability should be confirmed before installation on the selected operating-system and architecture baseline.
* ZIM archives should receive both checksum recording and functional testing; a validator result and practical serving result may not always agree.
* Manual service testing should succeed before creating a persistent systemd unit.
* Command-line options must be validated against the installed version. Omitting the unsupported address argument allowed `kiwix-serve` 3.7.0 to listen successfully on all available interfaces.
* Offline testing must be performed deliberately rather than assuming local content is independent of remote assets.
* Keeping the Kiwix service under a restricted account reduces the privileges available to the network-facing process.
* A manual dashboard test should pass before enabling automatic startup.
* Relative dashboard links should derive the current hostname so they work from `localhost`, `offgridpi.local`, and the local IP address.
* Local-only HTML, CSS, and JavaScript prevent the dashboard from breaking when internet access is removed.
* A maximized normal browser window preserves troubleshooting access, while manual full-screen mode provides a clean appliance-style interface.
* Desktop autostart should wait for the local web service rather than assuming it is immediately available after login.

---

## Next Action

Begin **Phase 4 — Local Document Library**.

The first Phase 4 checkpoint is to create separate public and private document paths, build the approved category folders, and verify that the private path cannot be accessed through the browser-facing library.

The initial public library will be created under:

```text
/srv/offgridpi/content/documents/public
```

Private or personal material will be stored separately under:

```text
/srv/offgridpi/content/documents/personal
```

The first implementation should:

* Create the public category structure.
* Add one harmless sample document for testing.
* Create an index-generation script in `/opt/offgridpi/scripts`.
* Serve the generated library on a separate local port.
* Add a working Local Documents card to the existing dashboard.
* Confirm local, network, reboot, and offline access.
* Confirm that the personal directory is not browser accessible.

Before beginning Phase 4 configuration, upload this file to GitHub as `docs/BUILD_LOG.md`, commit it, and synchronize the Raspberry Pi repository with `git pull`.
