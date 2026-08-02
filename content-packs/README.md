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
```
