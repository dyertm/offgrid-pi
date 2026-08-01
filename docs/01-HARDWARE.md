# Offgrid Pi Hardware Inventory

**Reconciled:** August 1, 2026

## Confirmed development hardware

| Component | Current hardware | Status |
|---|---|---|
| Single-board computer | Raspberry Pi 4 Model B, 4 GB RAM | Validated |
| Boot storage | Patriot LX Series 64 GB microSDXC, UHS-I, Class 10, U1 | Validated |
| Development power | 5V 3A USB-C Raspberry Pi-compatible supply | Validated |
| Case | Miuzei Raspberry Pi 4 case | Validated |
| Cooling | Integrated fan and heatsinks | Validated |
| Display | GeeekPi 10.1-inch HDMI display | Validated |
| Display resolution | 1024 × 600 | Validated manually |
| Input | USB keyboard and mouse | Validated |
| Network | Wi-Fi | Validated |
| Imaging computer | Windows computer | Used |
| Card reader | HDE All-in-One card reader | Used |

## Current operating baseline

* Raspberry Pi OS 64-bit Desktop
* Debian GNU/Linux 13 Trixie
* ARM64 / `aarch64`
* Kernel recorded during baseline: `6.18.34+rpt-rpi-v8`
* Root storage after update: approximately 46 GB available
* Baseline CPU temperature: approximately 35°C
* Throttle status: `0x0`

## Existing equipment reserved for later testing

| Purpose | Equipment | Current phase |
|---|---|---|
| Primary off-grid battery | EcoFlow RIVER 2 | Deferred |
| Primary solar charging | Renogy 200-watt folding solar panel | Deferred |
| Secondary battery | Voltaic V72 | Deferred |
| Secondary solar charging | Voltaic Arc 20W | Deferred |
| Content storage candidates | USB flash drives and USB hard drives | Inventory/testing pending |

## Planned storage architecture

The operating system and content library should remain logically separate.

### Operating-system storage

Used for:

* Raspberry Pi OS
* Application code
* Service definitions
* Configuration
* Logs and temporary files

### Content storage

Used for:

* Kiwix ZIM files
* Public documents
* Offline maps
* Faith resources
* Equipment manuals
* Personal reference material
* Optional entertainment media

The final content device will likely be external USB storage, but model, capacity, file system, mount path, power draw, and backup strategy remain undecided.

## Storage priorities

1. Core knowledge and medical material
2. Preparedness, repair, communications, agriculture, and maps
3. Education, books, and faith resources
4. User personal material
5. Optional entertainment
6. Reserved free space for updates and future growth

## Remaining hardware information

* External storage model, capacity, health, and file system
* Stable mount behavior
* Storage power requirements
* Runtime with display and external storage
* Whether a powered USB hub is needed
* Battery runtime and solar recharge performance
* Final recommended hardware combinations for community use

## Public-documentation boundary

This inventory records reproducible technical hardware information. Product pricing, package tiers, branded cases, retail kit concepts, and commercialization plans are maintained separately as private source material.
