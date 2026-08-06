# Offgrid Pi

Offgrid Pi is a customizable, reproducible offline knowledge system built initially for the Raspberry Pi 4B.

It is designed to provide locally stored reference material when internet access is unavailable, unreliable, or intentionally disconnected. The system can be used directly from an attached display or from another device on the same local network.

## Current prototype

The development prototype currently provides:

* Raspberry Pi OS 64-bit Desktop based on Debian 13
* Native Kiwix service hosting a local ZIM archive
* A custom Offgrid Pi dashboard
* Automatic Kiwix and dashboard startup through `systemd`
* Automatic Chromium launch after desktop login
* Local access through the attached 1024 × 600 display
* Browser access from another device on the local network
* Public document library with automatic indexing on TCP port `8082`
* Protected personal-document storage that is neither served nor indexed
* Read-only System Status and localhost management views
* Offline Legal & Notices page with local software-license records
* Confirmed reboot persistence and operation with internet connectivity disabled
* Reproducible installer `0.7.4` with unified installation, verification, configuration snapshots, rollback, content-preserving uninstall, and offline legal-notice generation

The current services use:

* Kiwix: TCP port `8080`
* Dashboard: TCP port `8081`
* Public documents: TCP port `8082`
* Localhost management viewer: TCP port `8083`, bound only to `127.0.0.1`

## Project goals

Offgrid Pi is intended to be:

* Offline-first
* Easy to operate after installation
* Reproducible from documented configuration and scripts
* Modular rather than overloaded with unnecessary services
* Accessible through an attached display and a local network
* Expandable through optional content profiles
* Easy to back up, restore, and migrate to larger storage
* Shareable as an open public project without exposing personal data

## Planned content

Potential content includes:

* Wikipedia and other Kiwix libraries
* Medical and first-aid references
* Emergency-preparedness information
* Water, food, gardening, and preservation references
* Repair and maintenance manuals
* Radio and communications material
* Books and literature
* Education resources
* Faith and Scripture resources
* Regional offline maps
* User-supplied local documents
* Optional legally owned offline entertainment

## Current development status

| Phase | Status |
|---|---|
| Project definition | Completed |
| Raspberry Pi foundation | Completed |
| Kiwix proof of concept | Completed |
| Dashboard prototype | Completed |
| Local document library | Completed |
| Reproducible installer | In progress — clean-install validation remaining |
| Content-pack system | Completed |
| System status and administration | In progress — clean-install validation remaining |

Installer `0.7.4` packages the Kiwix, dashboard, Chromium autostart, document-library, management, status, and offline legal-notice components. It supports `install-all`, independent verification, configuration snapshots, rollback, and content-preserving uninstall. Validation on a separate clean Raspberry Pi OS installation remains required.

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
