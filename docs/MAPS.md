# Offgrid Pi Offline Maps

## Product direction

Offgrid Pi will include a complete offline map reader and map-pack tools.
Large regional datasets remain optional so users install only the areas they need.
A small public-domain overview pack may be included for immediate demonstration.

## Service architecture

- Public read-only map reader: TCP port `8084`
- Future localhost-only map-pack manager: TCP port `8085`
- Reader application: `/opt/offgridpi/maps`
- Installed packs: `/srv/offgridpi/content/maps/packs`
- Temporary imports: `/srv/offgridpi/content/maps/incoming`
- Rejected packs: `/srv/offgridpi/content/maps/rejected`
- User markers and notes: `/srv/offgridpi/content/maps/user-data`

The public reader must support HTTP byte-range requests for PMTiles files.
Uploads and pack changes must never be exposed through the public reader.

## Map-pack format

Customer-facing packages use the `.ogmap` extension.

A pack is a ZIP-compatible archive containing:

- `manifest.json`
- `data/basemap.pmtiles`
- Optional files under `overlays/`
- License records under `licenses/`
- `README.txt`

Packs may not contain HTML, JavaScript, CSS, executables, shell scripts,
shared libraries, symbolic links, device files, or undeclared files.
Map presentation uses reader-owned styles and assets.

## Manifest requirements

Each manifest records:

- Pack identity, name, version, and status
- Reader compatibility version
- Region, geographic bounds, center, and zoom limits
- Data publication or extraction date
- Installed storage requirement
- Declared files, sizes, roles, and SHA-256 checksums
- Source datasets and source pages
- Licenses and redistribution status
- Required attribution
- Known limitations and freshness notes

## Import security

The importer must reject:

- Missing or invalid manifests
- Unsupported reader or schema versions
- Absolute paths and parent-directory traversal
- Symbolic links and special files
- Undeclared or unsupported files
- File-size or checksum mismatches
- Excessive archive expansion
- Packs larger than available storage

Imports are validated in temporary storage and moved into place atomically.
A failed update must preserve the previously installed version.

## Initial development scope

1. Map-pack schema and validator
2. Safe archive inspection
3. Range-capable read-only map service
4. Basic reader with a tiny synthetic test pack
5. USB import workflow
6. Localhost-only pack manager
7. Public-domain nationwide overview pack
8. Washington emergency pack
9. OSM-derived Washington comparison pack

## Licensing model

Licensing is evaluated for every pack and every source dataset.
The reader does not grant redistribution rights for map data.
Each pack must preserve its required attribution, notices, versions, and sources.

Planned pack types include public-domain emergency maps, OSM-derived enhanced
street maps, customer-created packs, local open-data overlays, and commercial packs.

## Deferred functions

- Offline turn-by-turn routing
- Unattended internet downloads
- Public-network upload endpoints
- Pack-supplied executable presentation code
- Automatic replacement of installed packs
