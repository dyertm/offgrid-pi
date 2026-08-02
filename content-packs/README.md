# Offgrid Pi Content Packs

Content packs describe optional offline resources that may be installed into Offgrid Pi.

Each pack will record source, version, license, destination, size, and checksum information.

Content files themselves are not automatically included in the public repository.

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
```

## Plan a content-pack installation

The planner performs read-only checks for metadata completeness, HTTPS sources, destination conflicts, and available storage.

```bash
content-packs/content-pack-plan.py content-packs/manifests/starter.json
```

A BLOCKED result prevents installation planning from proceeding when required metadata or safety checks are incomplete.

## Stage content safely

The staging command downloads content into a separate staging area and verifies its exact size and SHA-256 checksum before it can be considered for installation.

Dry-run example:

```bash
content-packs/content-pack-stage.py content-packs/manifests/starter.json --dry-run
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
