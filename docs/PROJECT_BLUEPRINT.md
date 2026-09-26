# Offgrid Pi Project Blueprint

**Reconciled:** September 23, 2026

## 1. Project overview

Offgrid Pi is an offline-first, workstation-first resilience and knowledge platform designed to remain directly usable without an active internet connection after software and content have been installed.

The initial supported platform is a Raspberry Pi 4B with an attached display and local input devices. Selected services can also be exposed to other devices on the same local network, but phones, tablets, and network clients are enhancements rather than requirements.

The project emphasizes dependable local access to curated information, simple operation under stress, low power consumption, modest hardware requirements, and repairable/reproducible software.

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

### Workstation-first

The attached display and local input devices are the primary interaction path. Network clients may extend the system, but Offgrid Pi must remain useful when Wi-Fi, routers, phones, or other client devices are unavailable.

### Local control

Users retain control of software, content, storage, networking, updates, backups, and personal documents.

### Simple operation under stress

A user should be able to start the device and reach useful information without opening a terminal or understanding Linux administration. Critical information should require as few steps as practical to locate.

### Curation before volume

Useful organization, trustworthy sources, strong metadata, and fast retrieval matter more than maximizing raw storage volume.

### Reproducible installation

Validated manual steps should be converted into scripts and tested on clean installations.

### Modular design

Kiwix, documents, maps, search, media, administration, Owner Mode, and content packs should remain separable where practical.

### Repairability

The project favors understandable files, native packages, standard paths, and `systemd` services.

### Efficient operation

The initial system should avoid unnecessary background services, cloud dependencies, and resource-heavy abstractions. Core functionality must remain appropriate for Raspberry Pi 4 hardware.

### Privacy by default

Personal content, Owner data, logs, and future private household information should remain local and should not be exposed publicly or transmitted automatically.

### Public/private separation

Public software and documentation must remain separate from personal content, credentials, and private commercialization material.

## 4. Validated development baseline

| Item | Current / validated configuration |
|---|---|
| Device | Raspberry Pi 4B, 4 GB RAM |
| Operating system | Raspberry Pi OS 64-bit Desktop, Debian 13 Trixie |
| Kernel recorded | `6.18.34+rpt-rpi-v8` |
| Boot media | Patriot LX Series 64 GB microSDXC |
| Current development display | 15.6-inch 1920 × 1080 display |
| Earlier display validation | GeeekPi 10.1-inch HDMI, 1024 × 600 |
| Network | Wi-Fi; local hostname `offgridpi.local` |
| Kiwix | `kiwix-tools` 3.7.0 on TCP 8080 |
| Dashboard | Local dashboard on TCP 8081 |
| Documents | Public document library on TCP 8082 with automatic indexing |
| Management viewer | Read-only localhost service on `127.0.0.1:8083` |
| Offline Maps | Read-only local map reader on TCP 8084 |
| Owner Mode foundation | Localhost bootstrap service on `127.0.0.1:8085` |
| Installer | `0.7.6` |
| Privacy boundary | Personal document root is unserved and unindexed |
| Browser behavior | Chromium launches automatically after desktop login |
| Offline validation | Kiwix, dashboard, documents, system-status functions, and Offline Maps have passed offline/local validation |

The 15.6-inch display is the current development display. The earlier 10.1-inch 1024 × 600 display remains part of the project's historical compatibility and Phase 3 validation record.

## 5. Current scope

The active software scope includes:

* Raspberry Pi configuration
* Kiwix and ZIM hosting
* Custom local dashboard
* Automatic startup
* Direct attached-display use
* Local-network access
* Local document library
* Public/private document separation
* Automatic document catalog generation
* Content folder standards
* Versioned content-pack definitions and validation
* Installation automation
* Configuration backup and rollback foundations
* Direct software-component and offline license-notice inventory
* System status and health checks
* Protected localhost management/log viewing
* Offline Maps reader
* PMTiles and PDF/GeoPDF map support
* `.ogmap` package validation and protected import
* Owner Mode foundation and isolated owner/map-user-data paths
* Troubleshooting and recovery documentation
* Clean-install and regression testing

The next major development phase is Unified Offline Search. See `docs/ROADMAP.md` for the current phase sequence and future scope.

## 6. Current architecture

### Operating-system layer

Raspberry Pi OS provides hardware support, desktop access, networking, package management, user management, and service supervision.

### Kiwix layer

Kiwix serves ZIM-format content through a local web service on TCP port `8080`.

### Dashboard layer

The dashboard is stored under `/opt/offgridpi/dashboard` and is served locally on TCP port `8081`.

The dashboard includes a generated, read-only Legal & Notices page containing the MIT project license, direct software-component versions, and locally available Debian copyright records.

The dashboard is served by the dedicated `offgridpi-dashboard-server.py` service, which replaces the earlier prototype use of Python's built-in static HTTP server.

### Document-library layer

The validated browser-accessible document root is:

```text
/srv/offgridpi/content/documents/public
```

The private document root is:

```text
/srv/offgridpi/content/documents/personal
```

The private root must not be served or included in generated indexes.

Document indexing currently produces browsable catalog data. Phase 9 will add a separate full-text Unified Offline Search index rather than replacing the document-storage model.

### Offline Maps layer

The map-reader application is installed under `/opt/offgridpi/maps`.

Map content is stored under `/srv/offgridpi/content/maps`.

The read-only map service listens on TCP port `8084`.

The validated map architecture supports versioned `.ogmap` packages, PMTiles vector maps, PDF and GeoPDF documents, local-only reader assets, package metadata and hash verification, protected import, PMTiles range requests, and PDF navigation/zoom/rotation/fullscreen behavior.

User-friendly universal map import, private waypoints, map notes, and optional GNSS integration are later enhancements rather than unfinished Phase 8 requirements.

### System-status and management layer

System-status data is published for local read-only use.

Protected diagnostic and log information is exposed through a separate localhost-only management viewer on `127.0.0.1:8083`.

Privileged administrative actions remain outside the public browser interface.

### Owner Mode foundation

The Owner Mode bootstrap service binds only to `127.0.0.1:8085`.

Owner state is stored separately under `/var/lib/offgridpi/owner`.

Owner map-user data is separated from published map packs under `/srv/offgridpi/content/maps/user-data`.

The existing Owner service establishes the security and storage foundation. Full graphical Owner workflows remain later appliance-UX work.

### Media layer

Kodi and VLC remain a planned later module under Phase 10 — Offline Entertainment.

Kodi is the intended primary local media-library interface, with VLC available as a direct-playback fallback. Media may include movies, television, music, audiobooks, and family media stored on attached local storage.

Classic-game emulation such as NES and SNES may also be supported. Copyrighted commercial ROMs must be user-supplied and are not distributed with Offgrid Pi.

Entertainment storage must not displace reserved knowledge-library capacity.

### Service layer

The current installed and managed service set includes:

```text
kiwix-serve.service
offgridpi-dashboard.service
offgridpi-documents.service
offgridpi-document-indexer.service
offgridpi-status-publisher.service
offgridpi-status-publisher.timer
offgridpi-log-publisher.service
offgridpi-log-publisher.timer
offgridpi-management.service
offgridpi-maps.service
offgridpi-owner.service
```

The document-indexing services maintain the browsable public catalog. Status and log publishers generate sanitized local state for their approved interfaces. Maps, management, and Owner services use separate security boundaries appropriate to their roles.

## 7. File-system structure

```text
/opt/offgridpi/
├── dashboard/
├── maps/
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
│   │   ├── packs/
│   │   ├── incoming/
│   │   ├── rejected/
│   │   └── user-data/
│   └── media/
├── indexes/
├── logs/
└── backups/

/var/lib/offgridpi/
├── management/
└── owner/
```

Bulk-content storage is expected to move to external USB SSD storage in a later phase, while these logical paths remain stable and the system-storage layer remains separate.

## 8. Dashboard surfaces

The dashboard is intentionally kept simple and appliance-oriented rather than exposing every content category as a separate top-level card.

Current and planned top-level surfaces include:

* Knowledge Library
* Local Documents
* Offline Maps
* Offline Entertainment
* System Status
* Legal & Notices
* Administration / Owner functions

Topical areas such as medical, preparedness, food, repair, radio, education, books, faith, and equipment manuals belong inside the underlying content libraries and Unified Offline Search rather than requiring separate dashboard cards.

The current dashboard layout is considered an approved baseline and should not be expanded casually. New top-level entries should be added only when they represent a distinct appliance function rather than another content category.

## 9. Content organization

Curated content may be grouped into installable profiles or packs, but the library is organized primarily around practical subject areas rather than fixed product bundles.

High-priority content areas include:

* Medical, first aid, and triage
* Water storage, treatment, filtration, and sourcing
* Emergency preparedness and evacuation planning
* Food storage, gardening, seed saving, and preservation
* Household repair, plumbing, electrical, and equipment manuals
* Power, batteries, generators, solar, and load management
* Shelter, sanitation, cooking, heating, and fire safety
* Radio and emergency communications
* Weather, environmental hazards, and regional information
* Education, books, and family reference material
* Practical household security and privacy
* Faith and Scripture
* Regional maps and geographic information

Every published content manifest should record source, size, license, version or date, destination, checksum, and freshness/review metadata where appropriate.

Profiles remain useful as optional installation groupings such as Core, Medical, Preparedness, Repair, Pacific Northwest, Family Education, Faith, or Entertainment, but they should not limit how content is categorized or searched.

## 10. Optional faith content

The document library will include a `faith` category capable of holding multiple Bible translations and other user-selected faith resources.

The project may document how to add such files, but it must not redistribute copyrighted translations unless the license explicitly permits it. Public-domain and openly licensed editions may be referenced through manifests or setup instructions.

## 11. Deferred scope

Major future work is organized in `docs/ROADMAP.md`.

Deferred work currently includes:

* Phase 9 Unified Offline Search
* Kodi/VLC offline entertainment and customer-supplied classic-game ROM support
* Offline Wi-Fi hotspot mode and network self-recovery
* Final external-content storage architecture
* Graphical document and universal map import
* Private map waypoints and notes
* Optional GNSS integration
* Off-grid power optimization and hard-power-loss testing
* RTC/time-resilience evaluation
* Backup, restore, and protected private-data workflows
* Full first-run and Owner Mode appliance UX
* Safe offline software/content update workflows
* Release-image production
* Final enclosure and hardware qualification
* Thermal/endurance testing
* Production QA, burn-in, and release validation
* Support for additional hardware platforms

Offline AI is not a Core requirement. It may be reconsidered later as an experimental or higher-end capability only if hardware cost, power use, reliability, and user benefit justify it.

EMP/Faraday hardening, mandatory radio/SDR/GNSS hardware, full local chat, cloud identity, RAID/NAS dependencies, and similar specialist features are outside the Core roadmap unless explicitly revisited.

Private market, packaging, pricing, brand, and commercial product plans are intentionally excluded from this public blueprint.

## 12. Initial public-release criteria

A first public release should:

* Install reproducibly on a clean supported Raspberry Pi OS system
* Start required services automatically
* Open a usable local dashboard
* Serve at least one Kiwix library
* Serve and index a local public document library
* Provide Unified Offline Search across supported local content
* Provide a validated Offline Maps reader
* Keep personal and private information outside public services and indexes
* Work without internet access after setup
* Remain directly usable from the attached display and local input devices
* Support approved local-network access without making it a dependency
* Provide understandable system-health information
* Provide safe shutdown, recovery, backup, and restore procedures
* Support safe offline software and content maintenance
* Preserve user content through normal upgrade and recovery workflows
* Include installation, troubleshooting, diagnostics, health-check, and uninstall guidance
* Avoid embedding personal data, credentials, telemetry, or mandatory cloud services
* Pass defined thermal, storage, power-loss, reboot, content-integrity, and service acceptance checks
* Be reproducible from the public repository

Commercial production, if pursued separately, requires additional per-unit hardware qualification, burn-in, QA, traceability, packaging, support, and licensing review.

## 13. Project workflow

1. Discuss and define the next checkpoint.
2. Record the decision.
3. Perform the configuration.
4. Record commands, results, errors, and fixes.
5. Add or update scripts.
6. Test locally, across the local network, after reboot, and offline.
7. Update public documentation.
8. Commit and synchronize the repository.
