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

### Outstanding Tasks

* Select an erasable development microSD card.
* Record card brand and capacity.
* Install Raspberry Pi Imager on the Windows development computer if needed.
* Flash Raspberry Pi OS 64-bit with Desktop.
* Record every Raspberry Pi Imager setting.
* Boot the Raspberry Pi.
* Record the initial hostname and user configuration.
* Update the operating system.
* Record the display behavior at 1024 × 600.
* Confirm fan operation.
* Confirm keyboard and mouse operation.
* Confirm Ethernet and Wi-Fi operation.
* Install Git.
* Clone or initialize the repository.
* Install Kiwix.
* Download a small test ZIM file.
* Configure Kiwix to serve the test file.
* Test local browser access.
* Test access from another network device.
* Record all commands and results below.

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
* **Hostname reachable:** Locally confirmed as `offgridpi`; remote SSH test from the development computer remains pending
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
* **Network address:** Recorded locally and excluded from the public repository
* **SSH enabled:** Yes
* **SSH authentication:** Password authentication
* **SSH connectivity from development computer:** Pending confirmation
* **Raspberry Pi Connect:** Disabled

### Baseline Assessment

The Raspberry Pi passed its initial operating-system, memory, storage, temperature, throttling, display, and service-health checks. No failed services, undervoltage conditions, thermal throttling, or storage concerns were detected.

---

## Kiwix Test Installation

**Date:** Not started
**Status:** Planned

### Objectives

* Install a supported Kiwix server package or binary.
* Create the Kiwix content directory.
* Download one small test ZIM file.
* Serve the ZIM file locally.
* Confirm browser access.
* Record the final command and service configuration.

### Planned Content Directory

```text
/srv/offgridpi/content/kiwix
```

### Installation Commands

> To be documented after the installation method is validated.

### Test Results

* **Kiwix installed:**
* **Kiwix version:**
* **Test ZIM:**
* **ZIM size:**
* **Listening port:**
* **Local browser test:**
* **Network browser test:**
* **Offline restart test:**
* **Errors:**
* **Notes:**

---

## Dashboard Prototype

**Date:** Not started
**Status:** Planned

### Objectives

* Create a local landing page.
* Confirm that it displays correctly at 1024 × 600.
* Add a link to the Kiwix service.
* Add placeholder content categories.
* Add basic system-status information.
* Configure automatic browser launch.

### Planned Dashboard Path

```text
/opt/offgridpi/dashboard
```

### Test Results

> To be completed during development.

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

---

## Lessons Learned

* Commands that query the graphical display may fail when run through SSH or outside the active desktop session even though the physical display is operating normally.
* Manual verification should be recorded when an automated check cannot access the graphical session.
* Baseline temperature, throttling, storage, memory, and failed-service checks provide a useful health snapshot before installing application services.

---

## Next Action

Confirm SSH access from the Windows development computer using `piadmin@offgridpi.local`. After SSH connectivity is verified, clone the Offgrid Pi GitHub repository onto the Raspberry Pi, update this build log in `docs/BUILD_LOG.md`, and begin the Kiwix proof-of-concept phase.
