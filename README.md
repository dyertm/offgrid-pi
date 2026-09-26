# Offgrid Pi

Offgrid Pi is a customizable, reproducible offline knowledge system built initially for the Raspberry Pi 4B.

It is designed to provide locally stored reference material when internet access is unavailable, unreliable, or intentionally disconnected. The system can be used directly from an attached display or from another device on the same local network.

## Current development platform

The current development platform provides:

* Raspberry Pi OS 64-bit Desktop based on Debian 13
* Native Kiwix service hosting local ZIM archives
* A custom Offgrid Pi dashboard
* Automatic service startup through `systemd`
* Automatic Chromium launch after desktop login
* Direct workstation use through an attached display and local keyboard/mouse
* Current development display at 1920 × 1080, with the earlier 10.1-inch 1024 × 600 display retained as a validated lower-resolution baseline
* Browser access from another device on the same local network
* Public document library with automatic indexing
* Protected personal-document storage that is neither publicly served nor indexed
* Read-only System Status and localhost management views
* Offline Maps with PMTiles and PDF/GeoPDF support
* Versioned `.ogmap` packages with validation, protected import, integrity checks, and installed-pack discovery
* Local Owner Mode service foundation with isolated owner/map-user data
* Offline Legal & Notices page with local software-license records
* Confirmed reboot persistence and operation with internet connectivity disabled
* Reproducible installer `0.7.6` with installation, verification, configuration snapshots, rollback, content-preserving uninstall, and offline legal-notice generation

The current services use:

* Kiwix: TCP port `8080`
* Dashboard: TCP port `8081`
* Public documents: TCP port `8082`
* Localhost management viewer: TCP port `8083`, bound only to `127.0.0.1`
* Offline Maps: TCP port `8084`
* Owner Mode foundation: TCP port `8085`, bound only to `127.0.0.1`

## Project goals

Offgrid Pi is intended to be:

* Offline-first, with no mandatory cloud dependency
* Workstation-first, so the attached display and local input remain fully functional without another device
* Simple to operate under stressful conditions
* Reproducible from documented configuration and scripts
* Modular rather than overloaded with unnecessary services
* Efficient enough to remain practical on Raspberry Pi 4-class hardware
* Accessible from local-network clients without making them a requirement
* Curated for fast retrieval rather than optimized for raw storage volume
* Privacy-conscious, with no mandatory telemetry or cloud identity
* Expandable through optional content, storage, networking, and hardware capabilities
* Designed for backup, restore, migration, and long-term serviceability
* Shareable as an open public project without exposing personal or private product data

## Planned content

Offgrid Pi content is intended to emphasize practical, legally distributable reference material that remains useful during common outages, emergencies, and connectivity loss.

Priority subject areas include:

* Wikipedia and other appropriately licensed Kiwix/ZIM libraries
* Medical, first-aid, and triage references
* Water storage, treatment, and sanitation
* Food storage, preservation, and practical cooking
* Gardening, seed saving, and food production
* Repair and maintenance manuals
* Power, batteries, generators, and solar reference material
* Shelter, fire safety, and emergency household guidance
* Evacuation, family plans, and checklists
* Weather, hazard, and regional map resources
* Radio and communications references
* Education, books, and family-use material
* Faith and Scripture resources where licensing permits
* Practical household security and privacy guidance
* Carefully curated regional edible-plant references
* User-supplied local documents
* Optional legally owned offline entertainment

The project favors curated, searchable collections over large undifferentiated document archives.

## Current development status

| Phase | Status |
|---|---|
| 0 — Project definition | Completed |
| 1 — Raspberry Pi foundation | Completed |
| 2 — Kiwix proof of concept | Completed |
| 3 — Dashboard prototype | Completed |
| 4 — Local document library | Completed |
| 5 — Reproducible installer | Completed — pristine clean-install validation passed |
| 6 — Content-pack system | Completed — starter workflow validated |
| 7 — System status and administration | Completed — pristine clean-install validation passed |
| 8 — Offline maps | Completed — PMTiles/PDF reader, pack validation, import, and real-world GeoPDF acceptance passed |
| 9 — Unified Offline Search | Planned — next development phase |
| 10 — Offline Entertainment | Planned |
| 11 — Local Networking & Connectivity Resilience | Deferred |
| 12 — Storage & Content Management | Deferred |
| 13 — Power & Platform Resilience | Deferred |
| 14 — Backup, Restore & Private Data | Deferred |
| 15 — Appliance UX & Release Image | Deferred |
| 16 — Hardware Qualification & Physical Protection | Deferred |
| 17 — Release Validation & Community Release | Future |

Installer `0.7.6` packages the current Kiwix, dashboard, Chromium autostart, document-library, management, status, Offline Maps, Owner Mode foundation, and offline legal-notice components.

The completed system has passed clean-install, reboot, offline-operation, protected-administration, map-package, PMTiles, PDF/GeoPDF, and real-world map acceptance testing on Raspberry Pi 4 hardware.

The next development phase is Phase 9 — Unified Offline Search.

## Public and private content boundary

The public repository may contain:

* Source code
* Scripts
* Service definitions
* Configuration templates
* Content manifests
* Documentation
* Public-domain or clearly redistributable sample files

The public repository must not contain:

* Passwords, Wi-Fi credentials, private keys, or personal network details
* Personal documents
* Copyrighted books, media, Bible translations, maps, or ZIM archives without redistribution rights
* Private product, market, pricing, packaging, or commercialization plans

## Repository documentation

See the `docs/` directory for the project blueprint, build log, decision record, roadmap, installation guide, hardware inventory, and content strategy.

## Attribution

Offgrid Pi is an independent project. Kiwix, OpenStreetMap, Raspberry Pi OS, Kodi, VLC, and other third-party projects remain the work of their respective developers and communities.

## License

Offgrid Pi source code is licensed under the MIT License. Third-party software and content retain their own licenses and attribution requirements.
