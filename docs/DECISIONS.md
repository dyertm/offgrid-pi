Offgrid Pi Decision Record
Purpose

This document records important technical and project decisions.

Each decision should explain:

What was decided
Why it was selected
Alternatives considered
Consequences
Whether the decision is final or subject to review
Decision 001 — Build a reusable public project

Date: July 29, 2026
Status: Accepted

Decision

Offgrid Pi will be developed as a repeatable project that other users can install and customize, rather than as a one-time configuration for a single Raspberry Pi.

Reason

A reusable project provides greater value, encourages community improvement, and requires better documentation, testing, and automation.

Consequences
Configuration changes must be documented.
Scripts should replace undocumented manual steps.
Personal files and credentials must remain outside the public repository.
Clean-install testing will be required.
Licensing and redistribution rules must be considered.
Decision 002 — Maintain repository documentation as the source of truth

Date: July 29, 2026
Status: Accepted

Decision

Project conversations will be used for planning and troubleshooting, but the GitHub repository documentation will be the official source of truth.

Reason

Conversation history is difficult to search, organize, version, and distribute. Repository documents can be reviewed, updated, and tied to specific software versions.

Consequences

The following files will be maintained:

PROJECT_BLUEPRINT.md
BUILD_LOG.md
DECISIONS.md
INSTALLATION.md
ROADMAP.md

Important decisions made during conversations must be transferred into these files.

Decision 003 — Use Raspberry Pi 4B as the initial target

Date: July 29, 2026
Status: Accepted

Decision

The first supported hardware platform will be the Raspberry Pi 4B.

Reason

The development hardware is already available and includes sufficient processing power, memory, networking, USB connectivity, and display support for the planned system.

Alternatives considered
Raspberry Pi 3
Raspberry Pi 5
Mini PC
Laptop-based system
Consequences
Initial scripts and testing will focus on the Raspberry Pi 4B.
Support for other devices will be considered later.
Hardware-specific assumptions must be clearly documented.
Decision 004 — Use Raspberry Pi OS 64-bit with Desktop

Date: July 29, 2026
Status: Accepted

Decision

The initial operating-system baseline will be Raspberry Pi OS 64-bit with Desktop.

Reason

The system is intended to support direct use through an attached monitor, keyboard, and mouse. A desktop environment provides a more approachable experience for nontechnical users.

Alternatives considered
Raspberry Pi OS Lite
Raspberry Pi OS Full
Ubuntu Server
Ubuntu Desktop
DietPi
A preconfigured Internet-in-a-Box image
Consequences
The system will use more storage and memory than a headless Lite installation.
Users will have access to graphical troubleshooting tools.
The dashboard can launch automatically in a local browser.
Unnecessary desktop applications may be removed or ignored.
Decision 005 — Use Kiwix as the first offline-content engine

Date: July 29, 2026
Status: Accepted

Decision

Kiwix will be the initial platform for serving offline encyclopedias, books, medical references, and other ZIM-format content.

Reason

Kiwix is purpose-built for offline content and allows multiple knowledge collections to be served through a browser.

Alternatives considered
A complete Internet-in-a-Box installation
Static HTML collections
A custom document server
Wiki software with imported content
Consequences
ZIM files will become a major supported content format.
The project must provide a manageable way to organize and select ZIM libraries.
Third-party content licenses and file sizes must be documented.
Non-ZIM files will require a separate document-library system.
Decision 006 — Build a custom Offgrid Pi dashboard

Date: July 29, 2026
Status: Accepted

Decision

Offgrid Pi will use a custom local web dashboard as its primary interface.

Reason

A custom dashboard allows Kiwix, documents, maps, system information, and administrative tools to be presented through one consistent interface.

Alternatives considered
Use the Kiwix interface alone
Use the Raspberry Pi desktop as the primary interface
Use a full content-management system
Use Internet-in-a-Box without customization
Consequences
The project must maintain dashboard code and assets.
The dashboard must work offline.
The design must support the 1024 × 600 development display.
Links and categories should be configurable.
Administrative actions must be secured.
Decision 007 — Prefer native services over Docker initially

Date: July 29, 2026
Status: Accepted

Decision

The initial release will use native Linux packages, scripts, and systemd services instead of Docker containers.

Reason

Native services should use fewer resources, provide simpler troubleshooting, and reduce dependency on container images and registries.

Alternatives considered
Docker
Docker Compose
Podman
Kubernetes-based deployment
Consequences
Installation scripts must account for package and service configuration.
Dependency management may require additional work.
A container-based deployment may be added later for advanced users.
Decision 008 — Build scripted installation before a downloadable image

Date: July 29, 2026
Status: Accepted

Decision

The first distribution method will be a documented and scripted installation performed on top of Raspberry Pi OS.

A downloadable preconfigured disk image will be considered later.

Reason

Installation scripts are easier to review, update, test, and maintain during early development.

Alternatives considered
Distribute a complete microSD image immediately
Distribute a virtual-machine image
Require fully manual installation
Consequences
The installer must eventually support repeatable execution.
Clean-install testing is required.
Image-building work is deferred until the configuration is stable.
Decision 009 — Separate software development from storage planning

Date: July 29, 2026
Status: Accepted

Decision

The core software will initially be built and tested without finalizing the long-term storage architecture.

Reason

Existing microSD cards and storage devices are sufficient for early testing. Final drive selection should be based on the actual size, performance, and behavior of the finished software and content library.

Consequences
Initial tests may use limited content.
Content paths must be designed so they can later move to USB storage.
Storage benchmarks and redundancy planning are deferred.
Large content packs will not be required during the first milestone.
Decision 010 — Defer EMP and Faraday-storage planning

Date: July 29, 2026
Status: Accepted

Decision

EMP protection, Faraday bags, hardened storage, and related physical-protection planning are outside the current software-development scope.

Reason

The immediate goal is to produce a functioning and reusable software platform.

Consequences
EMP protection will not influence the initial system architecture.
Physical-protection recommendations may be developed in a later project phase.
Existing Faraday bags are not part of the current build inventory.
Decision 011 — Defer off-grid power integration testing

Date: July 29, 2026
Status: Accepted

Decision

The EcoFlow RIVER 2, Renogy 200-watt folding panel, Voltaic V72, and Arc 20-watt panel will not be required for initial software development.

Reason

Stable wall power is more appropriate during imaging, installation, package updates, and repeated testing.

Consequences
Development will use the Raspberry Pi’s standard 5V 3A power supply.
Power consumption and runtime will be measured later.
The final project may include separate power-optimization and off-grid-operation documentation.
Decision 012 — Use standardized application and content paths

Date: July 29, 2026
Status: Proposed

Decision

Application files will be stored under:

/opt/offgridpi

Content and generated data will be stored under:

/srv/offgridpi
Reason

Separating application code from content will make upgrades, backups, storage migration, and troubleshooting easier.

Consequences
Installation scripts must create and permission these directories.
Personal content must be separated from public project files.
Future external drives can be mounted under or linked to the content structure.
Review condition

Confirm during the first working prototype that the directory design supports Kiwix, document indexing, and future map storage.
