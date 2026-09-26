# Offgrid Pi Roadmap

**Reconciled:** September 23, 2026

## Phase status summary

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

## Phase 0 — Project definition

**Status:** Completed

Completed outcomes:

* Mission, intended users, scope, architecture, and public documentation established
* Raspberry Pi 4B and Raspberry Pi OS Desktop selected
* Native services and scripted-install direction selected
* Public/private documentation boundary established

Remaining administrative item:

* Select and add the project license

## Phase 1 — Raspberry Pi foundation

**Status:** Completed

Validated outcomes:

* Patriot LX Series 64 GB microSDXC imaged and verified
* Raspberry Pi OS 64-bit Desktop installed
* Raspberry Pi 4B, 4 GB RAM confirmed
* Display, fan, keyboard, mouse, Wi-Fi, and hostname verified
* Operating system updated
* Foundational tools installed
* Baseline health checks passed

## Phase 2 — Kiwix proof of concept

**Status:** Completed

Validated outcomes:

* `kiwix-tools` and `zim-tools` installed
* Standard content directory created
* Test ZIM downloaded and checksummed
* Kiwix served content locally and over the local network
* `kiwix-serve.service` enabled and active
* Reboot persistence passed
* Offline operation passed

Known follow-up:

* Retest current ZIM archives with newer validation tools when available

## Phase 3 — Dashboard prototype

**Status:** Completed

Validated outcomes:

* Local dashboard created using only local assets
* Layout passed at 1024 × 600
* Kiwix link works locally and over the local network
* Dashboard service enabled on TCP port `8081`
* Chromium opens automatically after desktop login
* Normal desktop access remains available
* Manual full-screen mode passed
* Reboot and offline tests passed

Resolved follow-up:

* The original Python `http.server` implementation was replaced by the dedicated `offgridpi-dashboard-server.py` service.
* Chromium now launches in kiosk mode for the normal appliance experience while the underlying Raspberry Pi OS desktop remains available for development and troubleshooting.

## Phase 4 — Local document library

**Status:** Completed

Validated outcomes:

* Separate public and personal document roots created with restrictive permissions
* Eleven approved public categories created, including `faith`
* Existing format-test and reference files migrated from the legacy `library` path
* Legacy content backed up and verified before removal of the old path
* Public catalog generated as HTML and JSON
* PDF, text, Markdown, HTML, SVG, and common document/image formats indexed
* Public document service enabled on TCP port `8082`
* Dashboard Local Documents card connected through a dynamic hostname redirect
* Automatic recursive indexing enabled through `inotifywait` and `systemd`
* Add and remove tests passed
* Personal content proved unserved and unindexed
* Local, network, reboot, and offline operation passed

Validated paths and services:

```text
/srv/offgridpi/content/documents/public
/srv/offgridpi/content/documents/personal
/opt/offgridpi/scripts/index-documents.py
/opt/offgridpi/scripts/watch-documents.sh
offgridpi-documents.service
offgridpi-document-indexer.service
```

Known follow-up:

* Windows `.local` hostname resolution may be temporarily unavailable after a reboot even when SSH, Avahi, and networking are healthy. Direct IP access is the documented fallback.

## Phase 5 — Reproducible installer

**Status:** Completed — pristine clean-install validation passed

Objectives:

* Convert validated manual procedures into idempotent scripts
* Detect the supported operating system, architecture, Raspberry Pi model, and administrator account
* Install packages, directories, permissions, scripts, and services safely
* Preserve existing user content during installation and upgrades
* Avoid hardcoded development usernames in public release files
* Add reusable verification and health-check scripts
* Add useful error handling and rerun safety
* Test each module independently before combining the complete installer
* Produce uninstall and rollback procedures
* Validate the finished installer on a clean Raspberry Pi OS installation

First checkpoint:

* Added `install.sh` with `check`, `install-documents`, and `verify` commands
* Added an administrator placeholder to the document-indexer service template
* Packaged the validated indexer, watcher, and document service
* Added `tests/verify-installation.sh` for repeatable platform, service, port, HTTP, catalog, and isolation checks

Completion criteria:

* A clean Raspberry Pi OS installation can be converted into Offgrid Pi without undocumented manual changes
* Re-running the installer does not damage services or user content
* Failures produce actionable messages
* Verification can be run independently after installation or upgrade

Acceptance validation:

* Completed pristine clean-install testing on a separately imaged Raspberry Pi OS 64-bit Desktop microSD card
* Confirmed installer `0.7.5` preflight passed before installation
* Confirmed one-pass `install-all` completed successfully from a fresh GitHub clone
* Confirmed independent verification passed after reboot with zero failures and zero review items
* Confirmed Chromium autostart opened the dashboard after reboot
* Confirmed dashboard, document library, System Status, and Legal & Notices remained functional with internet access blocked
* Confirmed normal network access was restored after offline validation

## Phase 6 — Content-pack system

**Status:** Completed — starter workflow validated

Completed outcomes:

* Added a versioned JSON manifest format and formal JSON Schema
* Added manifest validation for required fields, identifiers, checksums, licenses, duplicate item IDs, and safe destinations
* Added automated validator tests
* Added a draft starter content-pack manifest
* Added a read-only pack-status command
* Added a read-only installation planner
* Added checks for metadata completeness, HTTPS sources, destination conflicts, available storage, and required missing content
* Confirmed unrelated temporary Kiwix test content is ignored by pack status and planning
* Added automated status and planner tests
* Added verified download staging with exact size and SHA-256 enforcement
* Added protected installation with atomic copying and no silent overwrites
* Added installed-content verification and service refresh handling
* Added automated staging, installation, and refresh safety tests
* Separated deliberately incomplete test fixtures from production manifests
* Recorded authoritative metadata for the first starter-pack archive
* Downloaded, verified, installed, and served the Wikipedia English Top Articles Mini archive
* Confirmed the complete manifest-to-service workflow is safe and repeatable
* Retired and permanently removed the temporary Alpine Linux validation archive

Remaining content expansion:

* Medical, preparedness, agriculture, repair, radio, education, Pacific Northwest, and faith manifests remain to be created
* Additional regional map packs remain to be curated and validated
* Additional content sources require individual licensing and checksum review

Completion validation:

* Every published item records its source, size, version, license, destination, and checksum
* Downloads are staged and verified before installation
* Existing files are never silently overwritten
* Content installation can be rerun safely
* Kiwix and document indexes refresh only after successful verification
* The first production starter pack passed the complete workflow

## Phase 7 — System status and administration

**Status:** Completed — pristine clean-install validation passed

Completed outcomes:

* Added a read-only system-status command with human-readable and JSON output
* Added service, TCP listener, HTTP, storage, temperature, throttling, content, catalog, backup, and failed-unit reporting
* Added a protected administration command that defaults to preview-only behavior
* Added explicitly confirmed service restarts with post-restart validation
* Added protected public-document reindexing with generated-catalog validation
* Added protected reboot and power-off requests requiring root and the exact `OFFGRIDPI` confirmation phrase
* Added fake service-manager and indexer tests so destructive paths can be exercised without live system changes
* Added a read-only System Status dashboard page and automatic status publishing
* Visually validated the System Status page at 1024 × 600 and from the development computer
* Added protected publication of sanitized logs from five approved services
* Kept protected log data outside the public dashboard and document web roots
* Defined the management authorization boundary around physical access or authenticated SSH forwarding
* Added a separate read-only management viewer bound only to `127.0.0.1:8083`
* Added restrictive browser security headers, disabled caching, rejected write methods, and withheld raw JSON access
* Kept browser-based privileged administration disabled
* Added installer `0.7.3` support for the status tools, protected log publisher, and localhost management viewer
* Added an offline Legal & Notices module with an approved direct-package register, exact installed versions, local copyright notices, MIT project license, installer integration, and installed-system verification
* Added automated server, service, installer, listener, route, permissions, and installed-system verification
* Deployed the management viewer successfully on the development Raspberry Pi
* Confirmed the complete Phase 7 suite and installed-system verifier passed with zero failures and zero review items
* Completed controlled live reboot acceptance testing
* Confirmed the protected administration command requested the reboot through systemd
* Confirmed the boot ID changed and all required services, listeners, and HTTP endpoints recovered automatically
* Confirmed post-reboot verification passed with zero failures and zero review items
* Completed controlled live power-off acceptance testing
* Confirmed systemd accepted the protected power-off request and terminated the active SSH session
* Confirmed a new boot ID after power restoration
* Confirmed all required services, listeners, and HTTP endpoints recovered automatically
* Confirmed post-power-off verification passed with zero failures and zero review items

Current access model:

* Kiwix library: TCP port `8080`
* Public dashboard: TCP port `8081`
* Public document library: TCP port `8082`
* Protected read-only log viewer: `127.0.0.1:8083`
* Offline Maps: TCP port `8084`
* Administrative actions: protected command line only
* Remote protected-log access: authenticated SSH port forwarding

Future consideration:

* Decide whether privileged browser administration belongs in a future phase; the currently approved browser interface remains read-only

Completion criteria:

* Common service, storage, content, and hardware problems can be identified without internet access
* System status is available through the local dashboard
* Protected logs are available only through the localhost authorization boundary
* Administrative actions require root access and explicit confirmation
* Document reindexing validates its generated output
* Shutdown and restart actions use systemd and preserve normal file-system shutdown procedures
* Destructive actions pass controlled live acceptance testing
* Phase 7 components pass clean-install validation on separate boot media

## Phase 8 — Offline maps

**Status:** Completed

Completed outcomes:

* Added a read-only offline map reader and local map service on TCP port `8084`
* Added the `.ogmap` package format, schema validation, import preview, protected installation, and installed-pack discovery
* Added schema v2 capability-aware viewer definitions while retaining compatibility with validated v1 PMTiles packs
* Added interactive PMTiles support with byte-range serving
* Added locally hosted PDF.js support for PDF and GeoPDF map documents
* Added PDF page navigation, zoom, rotation, fullscreen, and Home behavior
* Improved PDF responsiveness by keeping the prior render visible, providing immediate visual zoom feedback, cancelling obsolete render work, and preventing stale-render races
* Preserved original GeoPDF files rather than flattening or converting them
* Added validation for declared files, hashes, sizes, licensing metadata, geographic metadata, safe paths, permitted redistribution, and supported viewer types
* Validated a real U.S. Geological Survey Maple Valley, Washington 1995 GeoPDF through the production package, validator, importer, service, and viewer workflow
* Completed installed-system regression testing for serving, security headers, range requests, manifests, traversal protection, unsupported methods, schemas, and reader behavior
* Confirmed stable live use on the Raspberry Pi 4 development system

Known performance characteristic:

* Large PDF/GeoPDF maps may require several seconds for their initial render on Raspberry Pi 4 hardware. The validated 17 MB USGS test map loaded in approximately six seconds and was accepted as reasonable for the current platform.

Moved to later work rather than reopening Phase 8:

* Graphical universal map import
* Owner-facing map-pack management
* Private waypoints and map notes
* Optional GNSS integration
* Additional map formats and adapters

These items now belong primarily to Phase 12 — Storage & Content Management.

## Phase 9 — Unified Offline Search

**Status:** Planned — next development phase

Build a fast, deterministic search layer for locally stored information without requiring AI or internet access.

Primary scope:

* Use SQLite FTS5 or an equivalently lightweight local full-text index
* Index supported local PDFs, text files, Markdown, HTML, and DOCX content, with additional formats added where practical
* Preserve useful document titles, headings, categories, tags, source metadata, and location information
* Weight titles and headings more strongly than ordinary body text
* Return useful snippets showing why a result matched
* Support page- or section-aware results where the source format allows it
* Deep-link or jump into the appropriate local viewer where technically practical
* Add curated aliases, abbreviations, synonyms, common-language terms, and common misspellings
* Support useful filters by category, source, and content type
* Keep indexing and search responsive on Raspberry Pi 4 hardware
* Keep all search processing and search data local
* Avoid making AI, vector databases, or cloud services a dependency

Design goal:

> A user under stress should be able to type the problem they are facing and reach a useful authoritative source with as few steps as possible.

## Phase 10 — Offline Entertainment

**Status:** Planned

Provide dependable local entertainment and family media without requiring internet connectivity.

Primary scope:

* Kodi as the primary local media-library interface
* VLC as a direct-playback fallback
* Movies, television, music, audiobooks, and family media stored on attached local storage
* Validate common formats including MP4, MKV, H.264, AAC, and SRT
* Validate local metadata and artwork behavior
* Validate attached-storage mounting across reboot
* Test with networking disabled
* Measure heat, power draw, undervoltage behavior, and long-duration playback stability
* Provide a reliable path back to the Offgrid Pi dashboard or normal desktop
* Support classic-game emulation such as NES and SNES
* Require customers/users to supply their own ROMs; copyrighted commercial ROMs are not distributed with Offgrid Pi

Not currently planned:

* Jellyfin or other always-on streaming-server stacks
* Transcoding-heavy media workflows
* Cloud media services

## Phase 11 — Local Networking & Connectivity Resilience

**Status:** Deferred

Provide useful local connectivity while ensuring networking never becomes a prerequisite for direct use.

Primary scope:

* Offline Wi-Fi hotspot for phones, tablets, and laptops
* Local access to approved Offgrid Pi services without an upstream internet connection
* Network-health monitoring
* Safe self-recovery for stuck `wlan0`, Avahi, and related local-connectivity failures
* Human-readable network status and recovery information
* Preserve full attached-display functionality when networking is unavailable

Optional future consideration:

* Simple local household bulletin/status board

Not required:

* Full local chat platform
* Permanent router or internet-sharing role
* Cloud-dependent networking

## Phase 12 — Storage & Content Management

**Status:** Deferred

Finalize how Offgrid Pi stores, imports, updates, verifies, and preserves large content libraries.

Primary scope:

* Separate system/boot storage from bulk content storage
* Prefer external USB SSD storage for the main content library
* Define stable mount paths and drive-migration procedures
* Preserve user content through OS reinstall and system recovery
* Add graphical user-document import
* Add USB import/export workflows
* Build the universal Offline Maps import workflow
* Detect supported map types and route them through format-specific adapters
* Install validated `.ogmap` packages directly
* Preserve GeoPDF and other geospatial capabilities rather than converting everything to PDF
* Add protected Owner-facing content management
* Add content integrity checks using sizes and hashes where available
* Support independent versioned content updates
* Preserve licensing, source, review-date, and freshness metadata
* Add map waypoints and notes as a high-value follow-on
* Support optional GNSS devices separately from the Core hardware BOM
* Add favorites/bookmarks or critical-information shortcuts where they fit naturally

Not required for Core:

* RAID
* NAS dependency
* Cloud storage dependency
* Arbitrary unsupported USB-device compatibility

## Phase 13 — Power & Platform Resilience

**Status:** Deferred

Optimize the system for dependable low-power operation and recovery from real household outage conditions.

Primary scope:

* Measure Raspberry Pi, display, and storage power consumption
* Optimize unnecessary background resource use
* Add clear safe-shutdown behavior
* Improve tolerance of unexpected power removal
* Test repeated hard-power-loss and restoration cycles
* Surface undervoltage, temperature, storage, and service-health warnings
* Validate automatic restart behavior after restored power where appropriate
* Detect obviously incorrect system time
* Provide offline manual date/time configuration
* Evaluate a low-cost battery-backed RTC for production use
* Keep internet-based NTP synchronization optional rather than required

Optional hardware-specific capability:

* Automatic graceful shutdown from supported UPS/battery telemetry

## Phase 14 — Backup, Restore & Private Data

**Status:** Deferred

Protect user-added information and make system recovery understandable to nontechnical owners.

Primary scope:

* Offline configuration and user-data backup
* Restore onto replacement media or a rebuilt system
* Verify backups before reporting success
* Preserve user-added content during repair or upgrade
* Export important owner content
* Define recovery-media procedures
* Protect genuinely private household information separately from shared emergency content
* Evaluate encrypted private-data storage
* Protect private backups
* Define Owner credential and encryption recovery procedures before encrypted storage is considered production-ready

Design rule:

* Shared emergency information must remain immediately usable after normal boot; protecting private information must not make the entire appliance inaccessible during an emergency.

## Phase 15 — Appliance UX & Release Image

**Status:** Deferred

Turn the validated technical system into a cohesive appliance that does not require Linux knowledge for routine operation.

Primary scope:

* Complete the reusable first-run setup framework
* Complete Owner Mode workflows and offline Owner recovery
* Provide graphical configuration for normal appliance tasks
* Add user-friendly software update workflows
* Support signed/verified offline USB updates
* Support optional online update checks without creating an internet dependency
* Provide rollback or recovery after failed updates
* Add simple system-health and diagnostics views
* Add one-click or similarly simple health checks
* Export privacy-safe support bundles to USB
* Improve keyboard navigation, readable typography, scaling, contrast, focus states, and other accessibility fundamentals
* Evaluate offline text-to-speech as a high-value accessibility feature
* Add print-friendly/exportable emergency references and checklists
* Produce a stable prebuilt release image only after the scripted installation and recovery paths remain reproducible

Not required for Core:

* Voice recognition
* Cloud identity
* Full Linux administration through the browser
* Broad printer-driver compatibility

## Phase 16 — Hardware Qualification & Physical Protection

**Status:** Deferred

Qualify the final physical platform under realistic household and emergency use.

Primary scope:

* Finalize the production Raspberry Pi enclosure
* Protect or restrict casual access to the microSD card
* Provide reliable SSD and cable retention/strain relief
* Maintain replaceable/serviceable storage and cables where practical
* Validate approved keyboards, pointing devices, storage, and other supported peripherals
* Perform sustained thermal and throttling tests in the final enclosure
* Perform extended runtime and burn-in testing
* Test operation with maps, Kiwix, documents, search, and media under sustained use
* Document realistic storage and operating limits
* Validate transport and normal household emergency use

Product direction:

* Passive/fanless cooling is preferred where testing proves it reliable
* Weatherproof, military-style, Faraday, and EMP hardening are not Core requirements

## Phase 17 — Release Validation & Community Release

**Status:** Future

Complete the repeatable validation, documentation, licensing, and release work required for a dependable public or commercial-quality build.

Primary scope:

* Automated hardware and software acceptance checks
* Repeatable production QA checklist
* Burn-in under realistic load
* Thermal and throttling validation
* Storage read/write validation
* Installed-content integrity verification
* Cold-boot, reboot, shutdown, unexpected-power-loss, and restoration testing
* Validate display, input devices, USB, networking, and required local services
* Smoke-test installed maps, Kiwix, documents, search, entertainment, and other enabled modules
* Verify backup and recovery procedures
* Record software image, content-pack, and relevant build versions
* Maintain per-unit QA/support traceability where commercial production requires it
* Complete licensing review
* Complete public documentation and contribution/support guidance
* Publish a sanitized and reproducible community release

Release rule:

* A unit or image with known failed required checks is not considered release-ready.

## Continuous content workstream

Curated content development continues alongside the software phases rather than waiting for one dedicated phase.

Highest-priority content areas:

* Medical, first aid, and triage
* Water storage, treatment, filtration, and sourcing
* Household repair, plumbing, electrical, mechanical, and equipment references
* Gardening, seed saving, food preservation, and long-term food production
* Food storage, deep-pantry management, shelf life, and outage food safety
* Shelter, cooking, heating, sanitation, hygiene, and fire safety
* Power stations, batteries, generators, solar, and household load management
* Evacuation planning, family communication plans, checklists, and emergency documents
* Weather, environmental hazards, and regional hazard maps
* Radio and emergency-communications reference material
* Education, homeschool material, public-domain books, and family morale resources
* Practical household security and privacy guidance
* Carefully curated regional edible-plant references

Content principles:

* Curation and fast retrieval matter more than raw storage volume
* Prefer authoritative, legally redistributable, current sources
* Retain source, license, date, version, and integrity metadata
* Distinguish intentionally historical material from content that may be stale
* Time-sensitive content should carry review/freshness information where appropriate
* User-added private content must not be exposed or indexed publicly by default

## Roadmap guardrails

Offgrid Pi remains:

* Offline-first
* Workstation-first and directly usable from its attached display and input devices
* Server-capable without becoming dependent on phones or other client devices
* Designed for mainstream household resilience rather than niche doomsday scenarios
* Focused on low power, modest hardware cost, reliability, and simple use under stress
* Functional without cloud accounts, telemetry, or permanent internet connectivity
* Built around strong curated information retrieval rather than maximum raw content volume

Explicitly outside the Core roadmap unless revisited later:

* Local AI as a Core requirement
* EMP/Faraday-hardened product design
* Full local chat
* Full multi-user profile systems
* Mandatory GNSS, SDR, radio, UPS, or other specialized hardware
* Cloud-dependent services
* RAID or NAS requirements
* Voice recognition
* Broad arbitrary peripheral compatibility

## Immediate next actions

1. Begin Phase 9 Unified Offline Search architecture and implementation.
2. Continue acquiring, validating, licensing, and packaging high-priority curated content in parallel with software development.
3. Preserve the completed Phase 8 baseline while deferring graphical map import, waypoints/notes, optional GNSS, and broader content-management workflows to Phase 12.
