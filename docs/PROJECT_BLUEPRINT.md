# Offgrid Pi Project Blueprint

**Reconciled:** August 1, 2026

## 1. Project overview

Offgrid Pi is an offline-first knowledge platform designed to run locally without depending on an active internet connection after software and content have been installed.

The initial supported platform is a Raspberry Pi 4B with an attached display. The system also exposes selected services to other devices on the same local network.

The long-term objective is a repeatable public project rather than a one-time personal build.

## 2. Mission

Create a dependable, approachable, reproducible offline information system for:

* General reference
* Emergency preparedness
* Medical and first-aid reference
* Water, food production, and preservation
* Repair and maintenance
* Education
* Books and literature
* Faith and Scripture
* Radio and communications
* Equipment documentation
* Regional maps and geographic information
* User-supplied local documents
* Optional offline entertainment and morale resources

## 3. Design principles

### Offline-first

Installed services and content must remain functional without internet access.

### Local control

Users retain control of software, content, storage, networking, updates, backups, and personal documents.

### Simple operation

A user should be able to start the device and reach the dashboard without opening a terminal.

### Reproducible installation

Validated manual steps should be converted into scripts and tested on clean installations.

### Modular design

Kiwix, documents, maps, media, administration, and future content packs should remain separable.

### Repairability

The project favors understandable files, native packages, standard paths, and `systemd` services.

### Efficient operation

The initial system should avoid unnecessary background services, cloud dependencies, and resource-heavy abstractions.

### Public/private separation

Public software and documentation must remain separate from personal content, credentials, and private commercialization material.

## 4. Validated development baseline

| Item | Validated configuration |
|---|---|
| Device | Raspberry Pi 4B, 4 GB RAM |
| Operating system | Raspberry Pi OS 64-bit Desktop, Debian 13 Trixie |
| Kernel recorded | `6.18.34+rpt-rpi-v8` |
| Boot media | Patriot LX Series 64 GB microSDXC |
| Display | GeeekPi 10.1-inch HDMI, 1024 × 600 |
| Network | Wi-Fi; local hostname `offgridpi.local` |
| Kiwix | `kiwix-tools` 3.7.0 on TCP 8080 |
| Dashboard | Local static dashboard on TCP 8081 |
| Browser behavior | Chromium launches automatically in a maximized window |
| Offline test | Kiwix and dashboard passed |

## 5. Current scope

The active software scope includes:

* Raspberry Pi configuration
* Kiwix and ZIM hosting
* Custom dashboard
* Automatic startup
* Local-network access
* Local document library
* Public/private document separation
* Content folder standards
* Content-pack definitions
* Installation automation
* Health checks
* Troubleshooting documentation
* Clean-install testing

## 6. Current architecture

### Operating-system layer

Raspberry Pi OS provides hardware support, desktop access, networking, package management, user management, and service supervision.

### Kiwix layer

Kiwix serves ZIM-format content through a local web service on TCP port `8080`.

### Dashboard layer

The dashboard is stored under `/opt/offgridpi/dashboard` and is served locally on TCP port `8081`.

The prototype uses Python's built-in static HTTP server. This is accepted for development and must be reviewed before a stable release.

### Document-library layer

The planned browser-accessible document root is:

```text
/srv/offgridpi/content/documents/public
```

The private document root is:

```text
/srv/offgridpi/content/documents/personal
```

The private root must not be served or included in generated indexes.

### Media layer

Kodi and VLC remain an optional later module. Media must not displace reserved knowledge-library storage.

### Service layer

Validated services:

```text
kiwix-serve.service
offgridpi-dashboard.service
```

Planned service:

```text
offgridpi-documents.service
```

## 7. File-system structure

```text
/opt/offgridpi/
├── dashboard/
├── scripts/
├── config/
└── tools/

/srv/offgridpi/
├── content/
│   ├── kiwix/
│   ├── documents/
│   │   ├── public/
│   │   │   ├── emergency/
│   │   │   ├── first-aid/
│   │   │   ├── food/
│   │   │   ├── gardening/
│   │   │   ├── communications/
│   │   │   ├── radio/
│   │   │   ├── repair/
│   │   │   ├── equipment-manuals/
│   │   │   ├── education/
│   │   │   ├── books/
│   │   │   └── faith/
│   │   └── personal/
│   ├── maps/
│   └── media/
├── indexes/
├── logs/
└── backups/
```

## 8. Dashboard categories

The dashboard should eventually provide configurable entries for:

* Knowledge Library
* Medical and First Aid
* Emergency Preparedness
* Food and Agriculture
* Repair and Maintenance
* Radio and Communications
* Books and Literature
* Education
* Faith and Scripture
* Maps
* Equipment Manuals
* Local Documents
* Offline Entertainment
* System Status
* Administration

## 9. Content profiles

Planned profiles include:

* Core
* Preparedness
* Medical
* Agriculture and Food
* Repair
* Radio and Communications
* Pacific Northwest
* Family Education
* Faith and Scripture
* Offline Entertainment

Every manifest must record source, approximate size, license, version or date, destination, and checksum when available.

## 10. Optional faith content

The document library will include a `faith` category capable of holding multiple Bible translations and other user-selected faith resources.

The project may document how to add such files, but it must not redistribute copyrighted translations unless the license explicitly permits it. Public-domain and openly licensed editions may be referenced through manifests or setup instructions.

## 11. Deferred scope

Deferred work includes:

* Final storage selection and redundancy
* Offline maps implementation
* Local Wi-Fi hotspot mode
* Kodi and VLC integration
* Battery and solar runtime testing
* Backup and recovery automation
* Prebuilt release images
* Physical protection and long-term storage
* Support for additional hardware platforms

Private market, packaging, pricing, brand, rugged-tablet, and commercial product plans are intentionally excluded from this public blueprint.

## 12. Initial public-release criteria

A first public release should:

* Install on a clean supported Raspberry Pi OS system
* Start required services automatically
* Open a usable local dashboard
* Serve at least one Kiwix library
* Serve a local public document library
* Keep personal documents unexposed
* Work without internet access after setup
* Support attached-display and local-network access
* Include installation, troubleshooting, health-check, and uninstall guidance
* Avoid embedding personal data or credentials
* Be reproducible from the repository

## 13. Project workflow

1. Discuss and define the next checkpoint.
2. Record the decision.
3. Perform the configuration.
4. Record commands, results, errors, and fixes.
5. Add or update scripts.
6. Test locally, across the local network, after reboot, and offline.
7. Update public documentation.
8. Commit and synchronize the repository.
