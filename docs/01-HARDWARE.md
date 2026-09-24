# Offgrid Pi Hardware Inventory

**Reconciled:** September 24, 2026

## Confirmed development hardware

| Component | Current hardware | Status |
|---|---|---|
| Single-board computer | Raspberry Pi 4 Model B, 4 GB RAM | Validated |
| Boot storage | Patriot LX Series 64 GB microSDXC, UHS-I, Class 10, U1 | Validated |
| Development power | 5V 3A USB-C Raspberry Pi-compatible supply | Validated |
| Case | Miuzei Raspberry Pi 4 case | Validated |
| Cooling | Integrated fan and heatsinks | Validated |
| Current development display | 15.6-inch HDMI display | In active development use |
| Current display resolution | 1920 × 1080 | Validated in active use |
| Historical baseline display | GeeekPi 10.1-inch HDMI display | Validated |
| Historical baseline resolution | 1024 × 600 | Validated manually |
| Input | USB keyboard and mouse | Validated |
| Network | Wi-Fi | Validated |
| Imaging computer | Windows computer | Used |
| Card reader | HDE All-in-One card reader | Used |

## Hardware qualification candidates

| Component | Candidate | Status |
|---|---|---|
| Core enclosure | Flirc Raspberry Pi 4 Case with Pi 4 Security Cover | Leading candidate — qualification pending |

The Flirc enclosure is being considered because it provides passive aluminum cooling, no fan or other moving parts, a clean appliance-style appearance, and reduced casual access to the microSD card.

It is not yet considered production-validated. Final approval depends on Offgrid Pi-specific thermal, endurance, storage, cable-routing, and deployment testing.

## Current operating baseline

* Raspberry Pi OS 64-bit Desktop
* Debian GNU/Linux 13 Trixie
* ARM64 / `aarch64`
* Kernel recorded during baseline: `6.18.34+rpt-rpi-v8`
* Root storage after update: approximately 46 GB available
* Baseline CPU temperature: approximately 35°C
* Throttle status: `0x0`

## Existing equipment reserved for later testing

| Purpose | Equipment | Current role |
|---|---|---|
| Portable power | Anker SOLIX C1000 | Runtime and outage-use testing |
| Portable power | EcoFlow RIVER 2 | Runtime and outage-use testing |
| Portable power | Voltaic V72 | Low-power runtime testing |
| Solar charging | Renogy 200-watt folding solar panel | Recharge testing |
| Solar charging | Voltaic Arc 20W | Low-power recharge testing |
| Content storage candidates | USB flash drives, USB hard drives, and USB SSDs | Qualification/testing pending |

Portable batteries and solar panels are useful for development and resilience testing, but they are not currently required components of the Offgrid Pi Core hardware platform.

## Planned storage architecture

Offgrid Pi should keep system/boot storage logically separate from the bulk content library.

### System and boot storage

Used for:

* Raspberry Pi OS
* Application code
* Service definitions
* Configuration
* Logs and temporary files
* Recovery and system-management components

The current development system boots from microSD. Final production media and endurance requirements remain subject to qualification.

### Bulk content storage

Used for:

* Kiwix ZIM files
* Public documents
* Offline maps
* Faith and Scripture resources
* Equipment manuals
* User-added reference material
* Optional entertainment media

External USB SSD storage is the preferred direction for the main bulk-content library.

Phase 12 will finalize:

* Capacity and approved device models
* File system and stable mount paths
* Power requirements
* Cable retention and strain relief
* Migration between storage devices
* Content backup and recovery behavior
* Preservation of user-added content through system rebuilds

RAID, NAS, and cloud storage are not required for the Core platform.

## Storage priorities

1. Core knowledge and medical material
2. Preparedness, repair, communications, agriculture, and maps
3. Education, books, and faith resources
4. User personal material
5. Optional entertainment
6. Reserved free space for updates and future growth

## Remaining hardware qualification work

Before hardware recommendations are considered release-ready, the project still needs to establish:

* Approved external USB SSD models, capacities, health requirements, and file systems
* Stable storage mounting and migration behavior
* Storage-device power requirements
* SSD and cable retention / strain-relief requirements
* Runtime with the Raspberry Pi, display, and external storage
* Whether any supported configurations require a powered USB hub
* Thermal and throttling performance in the final enclosure
* Extended endurance and burn-in behavior
* Flirc Raspberry Pi 4 Case and Security Cover qualification
* Approved keyboard, pointing-device, display, and other Core peripheral combinations
* Repeated shutdown, restart, and unexpected-power-loss behavior
* Battery runtime and solar-recharge measurements for optional power configurations
* Evaluation of a low-cost battery-backed RTC
* Final supported hardware combinations for community and release use

## Public-documentation boundary

This inventory records reproducible technical hardware information. Product pricing, package tiers, commercial branding, retail kit concepts, and commercialization plans are maintained separately as private source material.
