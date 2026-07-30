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
| Device             | Raspberry Pi 4B                            |
| Case               | Miuzei case with cooling fan and heatsinks |
| Display            | GeeekPi 10.1-inch HDMI display             |
| Display resolution | 1024 × 600                                 |
| Development power  | 5V 3A USB-C power supply                   |
| Input              | USB keyboard and mouse                     |
| Network            | To be documented during initial setup      |
| Boot media         | To be selected                             |
| Operating system   | Raspberry Pi OS 64-bit with Desktop        |
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

**Date:** Not started
**Status:** Planned

### MicroSD Card

* **Brand:**
* **Model:**
* **Capacity:**
* **Speed rating:**
* **Previous contents backed up:**
* **Card erased:**
* **Imaging computer:**
* **Card reader:**

### Raspberry Pi Imager Version

* **Version:**
* **Download source:**
* **Verification performed:**

### Image Selected

* **Operating system:**
* **Architecture:**
* **Release date:**
* **Image filename:**

### Imager Customization

* **Hostname:**
* **Username:**
* **Password configured:**
* **Wi-Fi configured:**
* **Wi-Fi country:**
* **Time zone:**
* **Keyboard layout:**
* **SSH enabled:**
* **SSH authentication method:**
* **Telemetry setting:**
* **Other settings:**

### Imaging Result

* **Imaging started:**
* **Imaging completed:**
* **Verification completed:**
* **Errors:**
* **Notes:**

---

## First Boot

**Date:** Not started
**Status:** Planned

### Hardware Connected

* **Raspberry Pi:**
* **MicroSD card:**
* **Display:**
* **HDMI connection:**
* **Keyboard:**
* **Mouse:**
* **Ethernet:**
* **Wi-Fi:**
* **Power supply:**

### Boot Results

* **Power LED:**
* **Activity LED:**
* **Video output:**
* **Desktop loaded:**
* **Display resolution:**
* **Keyboard detected:**
* **Mouse detected:**
* **Fan operating:**
* **Network connected:**
* **Hostname reachable:**
* **Errors or warnings:**
* **Notes:**

> To be completed during the first boot.

---

## Operating-System Update

**Date:** Not started
**Status:** Planned

### Commands

```bash
sudo apt update
sudo apt full-upgrade -y
sudo reboot
```

### Results

* **Packages updated:**
* **Errors:**
* **Reboot successful:**
* **Kernel version:**
* **Operating-system version:**
* **Available disk space after update:**

---

## Initial System Information

**Date:** Not started
**Status:** Planned

### Commands

```bash
cat /etc/os-release
uname -a
hostnamectl
free -h
df -h
ip address
```

### Recorded Results

> To be added after the initial build.

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

No technical issues have been recorded yet.

---

## Lessons Learned

No build lessons have been recorded yet.

---

## Next Action

Select the development microSD card and perform the documented Raspberry Pi OS imaging process.
