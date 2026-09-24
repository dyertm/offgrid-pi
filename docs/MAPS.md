# Offgrid Pi Offline Maps

## Product direction

Offline Maps is a completed core capability of Offgrid Pi.

The system provides a local read-only map reader, versioned map-pack format, validation and protected import tooling, PMTiles support, and PDF/GeoPDF viewing without requiring internet access.

Large regional datasets remain optional so users can install only the areas they need. Map formats retain their useful native capabilities rather than being converted into one universal presentation format.

Phase 8 established the map-reader and package foundation. User-friendly map import, map notes/waypoints, optional GNSS integration, and additional format adapters are later enhancements under Phase 12 — Storage & Content Management.

## Service architecture

Current architecture:

* Public read-only map reader: TCP port `8084`
* Owner Mode foundation: localhost TCP port `8085`
* Reader application: `/opt/offgridpi/maps`
* Installed packs: `/srv/offgridpi/content/maps/packs`
* Temporary imports: `/srv/offgridpi/content/maps/incoming`
* Rejected packs: `/srv/offgridpi/content/maps/rejected`
* Private owner/map-user data: `/srv/offgridpi/content/maps/user-data`

The public reader supports HTTP byte-range requests required for PMTiles files.

Uploads, pack changes, Owner state, and private map-user data are not exposed through the public map-reader service.

The Owner Mode service establishes a localhost-only protected boundary for future graphical map-pack management, private waypoint access, and related owner functions. Network-accessible Owner Mode, if added later, must use the authentication and transport protections defined by the project's Owner Mode security architecture.

## Map-pack format

Offgrid Pi map packages use the `.ogmap` extension.

An `.ogmap` file is a ZIP-compatible archive governed by its `manifest.json`. The current schema is map-pack manifest v2.

Schema v2 supports multiple reader capabilities through the manifest's `viewer` definition:

* `pmtiles-vector` — interactive vector maps stored under `data/`
* `pdf` — PDF or GeoPDF map documents stored under `documents/`

A valid package also includes:

* `manifest.json`
* At least one license record under `licenses/`
* `README.txt`
* Optional declared GeoJSON files under `overlays/`

Every installed file must be declared in the manifest with its role, media type, size, SHA-256 checksum, and required/optional status.

PMTiles packs declare one `basemap` file. PDF packs declare one `document` file. The viewer entrypoint identifies the file the reader should open.

Map presentation code remains reader-owned. Packs may not supply HTML, JavaScript, CSS, executables, shell scripts, shared libraries, symbolic links, device files, or undeclared files.

The validator retains compatibility with the previously validated v1 PMTiles manifest format, but new map packs should use schema v2.

## Manifest requirements

Every schema-v2 manifest records:

* Schema version and package format
* Pack identity, name, version, status, and description
* Minimum compatible reader version
* Region name and applicable geographic metadata
* Data publication or extraction date
* Estimated installed storage requirement
* Viewer type and entrypoint
* Declared files, roles, media types, sizes, and SHA-256 checksums
* Source datasets and source pages
* Source version and data date
* License and redistribution status
* Required attribution and source notes
* Known limitations and freshness information

PMTiles viewer definitions additionally require:

* Geographic bounds
* Default center
* Minimum and maximum zoom
* Reader-owned style identifier
* Supported tile-schema identifier
* Exactly one declared basemap

PDF viewer definitions require exactly one declared PDF document.

Every pack requires exactly one declared `README.txt` and at least one declared license file.

## Import security

The production map importer validates archives before installation.

It rejects or prevents:

* Missing or invalid manifests
* Unsupported schema or reader versions
* Absolute paths and parent-directory traversal
* Backslash-based unsafe paths
* Symbolic links and special files
* Undeclared or unsupported files
* Duplicate declared paths
* File-size or SHA-256 mismatches
* Role/media-type mismatches
* Invalid geographic bounds, centers, or zoom ranges
* Unsupported reader-owned styles or tile schemas
* Published packs without permitted redistribution
* Invalid or non-HTTPS source metadata where required
* Excessive archive expansion
* Packs larger than available storage
* Silent replacement of an existing installed pack

The importer supports a preview mode that performs validation and storage checks without installing the archive.

Successful imports are installed only after manifest, size, checksum, path, source, licensing, and storage validation passes.

Failed validation does not replace an existing installed version.

## Phase 8 completion

Phase 8 established and validated the core Offline Maps platform.

Completed capabilities include:

* Versioned `.ogmap` schema and validator
* Safe archive inspection
* Import preview and protected installation
* Installed-pack discovery through the read-only map API
* Range-capable PMTiles serving
* Interactive PMTiles viewing
* Schema-v2 viewer capability definitions
* PDF and GeoPDF support using locally hosted PDF.js
* PDF page navigation, zoom, rotation, fullscreen, and Home behavior
* Responsive PDF rendering with stale-render cancellation
* Owner Mode service and isolated owner/map-user-data foundation
* Automated validator, server, reader, and security regression tests
* Real-world acceptance using an official USGS Maple Valley, Washington 1995 GeoPDF

The validated USGS GeoPDF was preserved in its original form rather than flattened or converted.

Its approximately 17 MB PDF required about six seconds for initial rendering on the Raspberry Pi 4 development system. That performance was accepted for the current platform after zoom and rerender behavior were optimized.

## Licensing model

Licensing is evaluated separately for every map pack and every source dataset.

The reader and `.ogmap` format do not grant redistribution rights for third-party map data.

Published packs must preserve applicable:

* Source identity and source page
* Source version and data date
* License
* Redistribution status
* Required attribution
* Notices and limitations
* File-integrity metadata

The validator requires published packs to declare permitted redistribution.

User-provided map content may be supported later without implying that Offgrid Pi has redistribution rights to that material.

Potential pack sources include public-domain government maps, appropriately licensed OpenStreetMap-derived data, local open-data sources, and user-supplied material.

## Future map work

The following items are intentionally outside the completed Phase 8 scope and belong to later development:

* Graphical Add Map / universal map-import workflow
* USB-based user-facing import
* Automatic file-type detection and format-specific import adapters
* Owner-facing map-pack management
* Private waypoints and map notes
* Optional GNSS/GPS integration
* Additional raster or geospatial formats
* GeoJSON and other overlay workflows
* Additional curated regional map packs

The intended future import experience is one user-facing workflow that detects the supplied map format and routes it through the appropriate validated backend while preserving useful geospatial capabilities.

## Deferred or non-Core functions

The following are not current Core requirements:

* Offline turn-by-turn routing
* Unattended internet map downloads
* Public-network upload endpoints
* Pack-supplied executable presentation code
* Automatic replacement of installed packs without validation
* Mandatory GNSS/GPS hardware
* Cloud-dependent map services
