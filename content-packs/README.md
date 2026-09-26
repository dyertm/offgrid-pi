# Offgrid Pi Content Packs

**Reconciled:** September 25, 2026

Offgrid Pi uses validated content-pack workflows to install project-managed offline resources without treating the public source repository as a bulk-content archive.

The project currently has two related but distinct packaging systems:

### General content packs

General content packs use versioned JSON manifests to describe resources such as Kiwix ZIM archives and public documents.

The current manifest records information including:

* Pack and item identifiers
* Source and source version
* Content type
* License and redistribution status
* Expected download and installed size
* SHA-256 checksum
* Final Offgrid Pi destination
* Required or optional status

Content files themselves are normally downloaded, verified, staged, and installed separately rather than committed to the repository.

### Offline map packs

Offline Maps use validated `.ogmap` archives with their own schemas, validator, inspector, and protected importer.

Map packs may contain supported PMTiles or PDF/GeoPDF content plus declared metadata, licensing information, attribution, checksums, and other required package files.

Map-pack presentation is owned by the Offgrid Pi reader. A map pack supplies validated content and metadata rather than executable HTML, JavaScript, CSS, or other presentation code.

See `docs/MAPS.md` for the complete Offline Maps architecture and security model.

The remainder of the first part of this document describes the general content-pack workflow.

## General content-pack governance

General content packs are intended for project-managed resources that Offgrid Pi can identify, verify, and install reproducibly.

A manifest entry does not by itself establish that content may legally be redistributed. Source and license information must be reviewed separately before project-distributed content is treated as publishable.

For project-managed content:

* Prefer authoritative or otherwise well-vetted sources.
* Record the original source page and source version or date.
* Record the applicable license and redistribution status.
* Require exact size and SHA-256 metadata before automated staging and installation.
* Keep project-managed public documents inside the approved public document tree.
* Never use the general content-pack workflow to install files into the private document tree.
* Distinguish intentionally historical material from information that is merely stale.
* Review time-sensitive material periodically and replace or deprecate it when appropriate.
* Preserve older versions when they remain intentionally useful rather than silently presenting them as current guidance.

The current schema records source-version and licensing information but does not yet provide the complete future content-freshness governance model described in `docs/CONTENT_STRATEGY.md`.

User-supplied content is a separate case. A user adding a file for personal use does not imply that Offgrid Pi has redistribution rights to that material.

## Validate a manifest

```bash
content-packs/validate-manifest.py content-packs/manifests/starter.json
```

## Check pack status

The status command is read-only. It does not download, install, remove, or modify content.

```bash
content-packs/content-pack-status.py content-packs/manifests/starter.json
```

A pack is READY only when all required items are installed and each item has complete size and checksum metadata.

## Run tests

```bash
content-packs/test-validator.sh
content-packs/test-status.sh
content-packs/test-plan.sh
content-packs/test-stage.sh
content-packs/test-install.sh
content-packs/test-refresh.sh
```

## Plan a content-pack installation

The planner performs read-only checks for metadata completeness, HTTPS sources, destination conflicts, and available storage.

```bash
content-packs/content-pack-plan.py content-packs/manifests/starter.json
```

A BLOCKED result prevents installation planning from proceeding when required metadata or safety checks are incomplete.

## Stage content safely

The staging command downloads content into a separate staging area and verifies its exact size and SHA-256 checksum before it can be considered for installation.

Preview staging without downloading content:

```bash
content-packs/content-pack-stage.py content-packs/manifests/starter.json --dry-run
```

Download and verify the content after reviewing the preview:

```bash
content-packs/content-pack-stage.py content-packs/manifests/starter.json
```

Verified content is staged under `/srv/offgridpi/staging/content-packs` and is never written directly into the live content directories.

The command refuses incomplete metadata, non-HTTPS sources, conflicting paths, corrupted staged files, and mismatched checksums.

## Install verified staged content

The installation command verifies staged content again and refuses to overwrite existing files.

Preview an installation:

```bash
content-packs/content-pack-install.py content-packs/manifests/starter.json
```

Install after reviewing the preview:

```bash
sudo content-packs/content-pack-install.py content-packs/manifests/starter.json --confirm
```

Live installation requires root privileges. Files are copied atomically, verified after installation, and assigned mode `0640`.

## Refresh services after installation

The refresh command verifies every installed pack item before restarting any affected service.

Preview the required refresh actions:

```bash
content-packs/content-pack-refresh.py content-packs/manifests/starter.json
```

Perform the refresh after reviewing the preview:

```bash
sudo content-packs/content-pack-refresh.py content-packs/manifests/starter.json --confirm
```

Verified ZIM content causes Kiwix to restart and rediscover approved archives. Verified document content causes the document indexer to restart and rebuild the public catalog.

No refresh action is performed if required content is missing, metadata is incomplete, or any installed file fails size or checksum verification.

## Offline map-pack workflow

Offline map packs use their own validation and import path and are not installed through the general content-pack manifest scripts above.

The repository currently supports map-pack schema versions 1 and 2. Version 2 adds viewer-specific packaging for supported PMTiles and PDF/GeoPDF content while retaining validation of declared files, sources, licensing metadata, dates, sizes, and SHA-256 hashes.

Validate a standalone map-pack manifest:

```bash
content-packs/validate-map-pack.py path/to/manifest.json
```

Inspect and validate a complete `.ogmap` archive without installing it:

```bash
content-packs/inspect-map-pack.py path/to/example.ogmap
```

Preview an import:

```bash
content-packs/import-map-pack.py path/to/example.ogmap
```

Import after reviewing the preview:

```bash
sudo content-packs/import-map-pack.py path/to/example.ogmap --confirm
```

The importer validates the archive before installation, checks available storage, rejects unsafe paths and symbolic-link traversal, verifies declared file sizes and SHA-256 hashes, and installs without silently replacing an existing map-pack destination.

For reader behavior, supported package structures, security rules, and current format limitations, see `docs/MAPS.md`.
