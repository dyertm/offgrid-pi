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

## Local Management Authorization Boundary

**Date:** August 3, 2026
**Status:** Approved for implementation

### Decision

Offgrid Pi management features will use a separate localhost-only web service.

The management service will:

- Bind only to `127.0.0.1`.
- Use TCP port `8083`.
- Run as the restricted `offgridpi` service account and group.
- Read protected management data from `/var/lib/offgridpi/management`.
- Provide read-only functionality during the initial implementation.
- Reject unsupported HTTP methods and unknown routes.
- Include restrictive browser security headers.
- Perform no privileged system actions.
- Remain separate from the public dashboard, Kiwix, and document services.

### Local access

The browser running directly on the Offgrid Pi may access:

`http://127.0.0.1:8083/`

Physical access to the device is treated as the authorization boundary for this
local management view.

### Development-computer access

Remote access will use SSH port forwarding:

    ssh -L 8083:127.0.0.1:8083 piadmin@offgridpi.local

The development computer may then open:

`http://127.0.0.1:8083/`

SSH authentication provides the remote authorization boundary.

### Rejected alternatives

The following approaches are not approved:

- Publishing protected logs through the public dashboard on port 8081.
- Publishing protected logs through the document service on port 8082.
- Binding the management service to `0.0.0.0`.
- Sending management passwords over unencrypted LAN HTTP.
- Adding privileged browser actions before a separate authorization and
  request-validation design is completed.

### Future privileged actions

Any future restart, reboot, power-off, reindex, or configuration action must use
a separate privileged execution boundary. Read access to the management viewer
must not automatically grant permission to perform system changes.

## Decision 026 — Generate Offline Legal and Software Notices

**Date:** August 5, 2026
**Status:** Accepted

Offgrid Pi will generate a public, read-only Legal & Notices page from an
approved machine-readable register and the packages installed on the device.

### Decision

The notice system will:

- Record the Offgrid Pi project license as MIT.
- Record exact installed versions of approved direct Debian packages.
- Copy installed Debian copyright records into locally served text files.
- Generate notices during dashboard installation.
- Use no JavaScript or remote presentation assets.
- Validate package names and copyright paths against an approved policy.
- Clearly distinguish missing packages during partial installations.
- Remain separate from protected management information.

### Scope limitation

The initial register covers direct packages intentionally installed by Offgrid
Pi. It is not a complete transitive dependency inventory or release SBOM.

Content licenses remain item-specific and continue to be recorded through
content-pack manifests. A ZIM file is a container and does not provide one
universal license for everything stored within it.

### Distribution consequence

Publishing license notices does not by itself satisfy every source-distribution
obligation. Corresponding-source availability, written offers, trademarks, and
content redistribution rights must be reviewed before distributing a release
image or commercial product.

## Decision 027 — Add a Shared Owner Mode Security Boundary

**Date:** August 23, 2026
**Status:** Approved for implementation

Offgrid Pi will provide a shared Owner Mode authorization layer for protected
owner data and configuration. Saved map waypoints will be the first feature to
use this boundary, but Owner Mode is intended to support additional protected
features without creating separate passwords or authorization systems for each
module.

### Service separation

The existing localhost management viewer remains unchanged:

- TCP port `8083`
- Bound only to `127.0.0.1`
- Read-only protected diagnostics
- Remote access through authenticated SSH port forwarding

A separate Owner Mode service will use TCP port `8085`.

The Owner Mode service may support access from the directly attached browser
and authorized devices connected to the Offgrid Pi local network or hotspot.
It must remain separate from the public dashboard, document server, Kiwix, and
read-only map reader.

### Owner authentication

Owner Mode will use an owner-created PIN or equivalent local recovery
credential.

The implementation must:

- Never store the Owner PIN in plaintext.
- Never transmit the Owner PIN or authenticated owner session over
  unencrypted LAN HTTP.
- Use an authenticated and encrypted transport for network-connected owner
  devices.
- Rate-limit failed authentication attempts.
- Use expiring browser sessions that can be explicitly locked.
- Invalidate protected sessions when appropriate during reboot, credential
  changes, or security-sensitive recovery operations.
- Avoid exposing authentication secrets in logs, URLs, public web roots, or
  content exports.

The exact encrypted local transport and credential-verification mechanism will
be selected after focused security and usability testing.

### Access model

Public and owner access are distinct capabilities.

Unauthenticated users may access intentionally public offline resources such as
maps and approved shared content.

Authenticated Owner Mode may provide access to features including:

- Private map waypoints, markers, and notes.
- Map-pack import and management.
- Personal content management.
- Content backup and export.
- Network and hotspot configuration.
- Other owner-specific settings added in future phases.

Owner Mode access does not automatically grant permission to perform privileged
operating-system actions.

Restart, reboot, power-off, recovery, factory reset, service control, and other
privileged operations must retain a separate privileged execution and
confirmation boundary.

### Private map data

Installed map packs remain read-only and separate from private user-generated
map data.

Private map information will be stored under:

`/srv/offgridpi/content/maps/user-data`

The public map reader on TCP port `8084` must not expose private waypoint data
by default.

An authenticated owner may intentionally view private map data from another
connected device. Future sharing controls may allow selected waypoint
information to be exposed read-only to other local users without granting
Owner Mode access.

### Resilience requirement

Owner Mode must support emergency access from another authorized local device
when the Offgrid Pi computer remains operational but its directly attached
display, keyboard, or other local interface is unavailable.

This redundancy requirement is part of the Owner Mode design rather than an
optional convenience feature.

## Decision 028 — Owner Credential Enrollment and Non-Destructive Recovery

**Date:** August 25, 2026
**Status:** Approved for implementation

Owner Mode credentials will be designed so loss of an Owner PIN does not cause
loss of saved waypoints, personal content, configuration, or other owner data.

The Owner PIN is an authorization credential. It is not the encryption key for
ordinary Owner Mode data.

### Enrollment

A new Offgrid Pi installation will support Owner Mode enrollment through a
reusable local enrollment workflow.

The enrollment workflow is intended to be called by the future first-run setup
experience, but Owner Mode may also be enrolled later if the owner initially
defers setup.

Enrollment will:

- Require creation and confirmation of an Owner PIN.
- Permit a longer PIN or passphrase where supported by the interface.
- Never store the Owner PIN in plaintext.
- Generate a separate offline recovery credential.
- Display the recovery credential to the owner for external safekeeping.
- Store only the information required to verify the recovery credential, not a
  recoverable plaintext copy of the credential.
- Keep credential state under `/var/lib/offgridpi/owner`.
- Keep credentials separate from user-generated content under
  `/srv/offgridpi/content`.

The same underlying enrollment mechanism must be usable by future graphical
setup interfaces without duplicating credential-generation logic.

### Recovery credential

Owner enrollment will generate a cryptographically random recovery credential.

The recovery credential must:

- Work without internet access.
- Require no vendor account, email account, cloud service, or external server.
- Be suitable for recording on paper or storing on removable media or another
  trusted device.
- Be verified locally by Offgrid Pi.
- Permit the owner to establish a new Owner PIN.
- Never reveal the previous PIN.
- Never delete user content as part of credential recovery.

A future Recovery Card interface may present the recovery credential in a
human-readable format and provide printable or downloadable instructions.

### Non-destructive PIN reset

Resetting or replacing the Owner PIN must modify authentication state only.

A PIN reset must not delete or recreate:

- Saved map waypoints, markers, or notes.
- Installed map packs.
- Personal documents.
- User media.
- Imported content.
- Owner-generated exports or backups.
- Other persistent user content.

Credential changes must invalidate existing authenticated Owner Mode sessions.

### Physical recovery

Offgrid Pi will retain a separate physical/local recovery path for an owner who
has lost both the Owner PIN and the normal recovery credential.

Physical recovery must:

- Require local or physical control of the Offgrid Pi.
- Never be available as an unauthenticated LAN operation.
- Reset Owner authentication independently of user content.
- Invalidate existing Owner Mode sessions.
- Clearly distinguish credential recovery from destructive factory reset.

The exact physical-recovery interaction will be selected during later recovery
and first-run UX development.

### Factory reset separation

Owner credential recovery and factory reset are separate operations.

A credential reset must be non-destructive.

Any future factory-reset operation that can remove private user data must use a
separate workflow, explicit warnings, and deliberate confirmation. Forgetting
an Owner PIN must never force the owner to perform a factory reset.

### Security scope

Because non-destructive physical recovery is required, the default Owner PIN
primarily protects against unauthorized network access and casual unauthorized
local access. It is not intended by itself to provide cryptographic protection
against an attacker with unrestricted physical possession of the device and its
storage.

Optional encrypted private-storage features may be considered later. If added,
their encryption and recovery model must remain separate from the default Owner
PIN and must clearly explain any risk of permanent data loss.

## Decision 029 — Keep the Generic First-Run Experience in Offgrid Pi

**Date:** August 25, 2026
**Status:** Approved for implementation

Offgrid Pi will provide a reusable first-run setup framework as part of the
public open-source core.

The generic first-run experience will configure appliance-level features that
are useful to any Offgrid Pi installation rather than embedding commercial
product assumptions into the core.

### Core first-run responsibilities

The Offgrid Pi first-run framework may provide setup for:

- Device name and basic identity.
- Time zone, locale, and other regional settings.
- Owner Mode enrollment.
- Owner PIN creation and confirmation.
- Offline recovery-credential generation and acknowledgement.
- Network or hotspot configuration when those features are available.
- Storage and content-location validation.
- Other generic appliance configuration added in future phases.
- Persistent completion state so first-run setup does not repeat after normal
  reboot.

The first-run interface must not duplicate security-sensitive implementation
logic.

For example, Owner enrollment will call the shared Owner credential subsystem
rather than implementing PIN hashing, recovery-credential generation, or
credential storage inside the setup wizard itself.

### Reusable backend operations

Security and configuration operations exposed through first-run setup must be
implemented as reusable backend functions or controlled APIs.

The same underlying operations may later be called by:

- First-run setup.
- Owner Mode settings.
- Credential-change workflows.
- Recovery workflows.
- Administrative or maintenance interfaces where appropriate.

This avoids maintaining separate credential or configuration implementations
for setup and normal operation.

### Product overlays

Commercial products built on Offgrid Pi may provide a private first-run
presentation or product overlay without replacing the generic setup framework.

A product overlay may supply:

- Branding, colors, logos, and product-specific language.
- SKU or factory configuration defaults.
- Factory provisioning validation.
- Licensed or curated content-bundle checks.
- Product-specific hardware detection or setup.
- Commercial support and recovery information.

Commercial product assets, provisioning data, and other protected
productization details must remain outside the public Offgrid Pi core.

The public first-run implementation must not require knowledge of a particular
commercial product or brand.

### Open-source usability

A user installing the public Offgrid Pi project should ultimately receive the
same appliance-oriented setup principles as a commercial derivative rather
than being required to manually edit configuration files for normal initial
setup.

Product overlays may improve presentation and provide product-specific
automation, but the generic Offgrid Pi installation must remain independently
usable.
