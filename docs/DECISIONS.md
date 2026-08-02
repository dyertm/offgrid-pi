# Offgrid Pi Decision Record

**Reconciled:** August 2, 2026

## Decision 001 — Build a reusable public project

**Date:** July 29, 2026  
**Status:** Accepted

Offgrid Pi will be developed as a repeatable project that other users can install and customize.

## Decision 002 — Repository documentation is the source of truth

**Date:** July 29, 2026  
**Status:** Accepted

Conversations may support planning and troubleshooting, but repository documentation is the authoritative project record.

## Decision 003 — Raspberry Pi 4B is the initial target

**Date:** July 29, 2026  
**Status:** Accepted

Initial scripts, testing, and support will focus on the Raspberry Pi 4B.

## Decision 004 — Use Raspberry Pi OS 64-bit with Desktop

**Date:** July 29, 2026  
**Status:** Accepted

The desktop edition supports direct attached-display use and graphical troubleshooting.

## Decision 005 — Use Kiwix as the first offline-content engine

**Date:** July 29, 2026  
**Status:** Accepted

Kiwix will provide browser access to ZIM-format offline content.

## Decision 006 — Build a custom local dashboard

**Date:** July 29, 2026  
**Status:** Accepted

A custom dashboard will provide one consistent entry point for local services and content.

## Decision 007 — Prefer native services over containers initially

**Date:** July 29, 2026  
**Status:** Accepted

Native packages and `systemd` services are preferred for the first release to reduce resource use and simplify troubleshooting.

## Decision 008 — Build a scripted installer before a disk image

**Date:** July 29, 2026  
**Status:** Accepted

The project will first produce a repeatable installation process on top of Raspberry Pi OS.

## Decision 009 — Separate software development from final storage planning

**Date:** July 29, 2026  
**Status:** Accepted

Core software will be completed before final external storage selection and capacity allocation.

## Decision 010 — Defer EMP and Faraday-storage planning

**Date:** July 29, 2026  
**Status:** Accepted

Physical protection does not affect the current software architecture and remains deferred.

## Decision 011 — Defer off-grid power integration testing

**Date:** July 29, 2026  
**Status:** Accepted

Development uses stable wall power. Battery and solar measurements will occur after the software and storage configuration stabilize.

## Decision 012 — Use standardized application and content paths

**Date:** July 29, 2026  
**Status:** Accepted for prototype

Application files use `/opt/offgridpi`. Content and generated data use `/srv/offgridpi`.

## Decision 013 — Add an optional offline media module

**Date:** July 30, 2026  
**Status:** Accepted

Kodi will be the planned primary media interface and VLC the fallback player. This remains a later optional module.

## Decision 014 — Use Debian 13 native Kiwix packages for the prototype

**Date:** July 31, 2026  
**Status:** Accepted for prototype

The prototype uses `kiwix-tools` and `zim-tools` from the Debian 13 ARM64 repositories.

**Consequences:**

* Package versions must be recorded.
* Command-line options must be tested against the installed version.
* The current `zimcheck` discrepancy remains documented as a known issue.

## Decision 015 — Run network-facing services under a restricted account

**Date:** July 31, 2026  
**Status:** Accepted

Kiwix and the dashboard run under the non-login `offgridpi` system account where practical.

## Decision 016 — Use a lightweight Python server for the dashboard prototype

**Date:** July 31, 2026  
**Status:** Accepted for prototype; review required

The dashboard is served on TCP port `8081` using Python's built-in HTTP server.

**Review condition:** Reassess during installer and hardening work.

## Decision 017 — Launch Chromium maximized and preserve desktop access

**Date:** July 31, 2026  
**Status:** Accepted for development

Chromium opens automatically in a maximized window. Manual full-screen mode provides an appliance-like view, while normal desktop access remains available for troubleshooting.

## Decision 018 — Separate public and personal document roots

**Date:** July 31, 2026  
**Status:** Accepted

Browser-accessible files will be stored under:

```text
/srv/offgridpi/content/documents/public
```

Private files will be stored under:

```text
/srv/offgridpi/content/documents/personal
```

The personal path must not be served or indexed.

## Decision 019 — Add a Faith and Scripture category

**Date:** July 31, 2026  
**Status:** Accepted

The public document structure will include a `faith` category. It may contain multiple Bible versions and related resources selected by the user.

**Consequences:**

* Translation name, source, license, and edition must be recorded.
* Copyrighted translations must not be redistributed without permission.
* Public-domain and openly licensed resources are preferred for manifests and examples.

## Decision 020 — Keep commercialization material private

**Date:** August 1, 2026  
**Status:** Accepted

Market analysis, pricing, product tiers, complete-kit concepts, rugged-tablet research, packaging, branding, and sales strategy will be maintained outside the public GitHub repository.

**Reason:** These ideas are useful private source material but are not required to reproduce the open software project.

## Decision 021 — Serve public documents on a separate port

**Date:** August 1, 2026  
**Status:** Accepted for prototype

The public document library is served from `/srv/offgridpi/content/documents/public` on TCP port `8082`.

**Reason:** A separate web root prevents the parent document directory and protected personal directory from being exposed by the dashboard server.

## Decision 022 — Automatically rebuild the document catalog

**Date:** August 1, 2026  
**Status:** Accepted

`offgridpi-document-indexer.service` uses `inotifywait` to monitor only the public document tree and rerun `index-documents.py` after file changes.

**Consequences:**

* Users do not need to run a manual indexing command after routine file additions or removals.
* Generated catalog files are excluded from the watch events to prevent rebuild loops.
* The watcher must remain recursive and restart after directory-tree changes.

## Decision 023 — Use dynamic hostname routing for dashboard services

**Date:** August 1, 2026  
**Status:** Accepted

The dashboard's Local Documents route derives the target hostname from the browser and redirects to port `8082`.

**Reason:** The same dashboard must work through `localhost`, `offgridpi.local`, or a direct IP address.

## Decision 024 — Treat direct IP access as the `.local` fallback

**Date:** August 1, 2026  
**Status:** Accepted

If a client temporarily cannot resolve `offgridpi.local`, the documented fallback is the Pi's local IPv4 address.

**Reason:** One Windows reboot test showed delayed `.local` resolution even though SSH, Avahi, hostname configuration, and network connectivity were healthy.

## Decision 025 — Build the installer incrementally by module

**Date:** August 2, 2026  
**Status:** Accepted

The reproducible installer will first package and verify individual validated modules before combining the complete build. The document module is the first installer checkpoint.

**Reason:** Small idempotent modules are easier to test, rerun, diagnose, and validate on the active prototype without risking unrelated working services.
