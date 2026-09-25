# Offgrid Pi Content Management Guide

**Reconciled:** September 24, 2026

## Purpose

This guide explains how locally stored documents are organized, added, indexed, accessed, and removed from Offgrid Pi.

The document system maintains a deliberate boundary between shared reference material and private user content.

Public documents are intended for household-accessible reference material such as emergency guides, medical information, equipment manuals, books, educational resources, faith materials, and locally created documents.

Private documents are stored separately and are not served through the public document library or included in its catalog.

Content files are stored outside the GitHub repository.

## Document library locations

Public documents are stored under:

```text
/srv/offgridpi/content/documents/public
```

Private documents are stored under:

```text
/srv/offgridpi/content/documents/personal
```

The public document library is served directly on TCP port `8082`.

From another device on the local network:

```text
http://offgridpi.local:8082/
```

On the Raspberry Pi itself:

```text
http://localhost:8082/
```

The Local Documents card on the Offgrid Pi dashboard routes users to this document service.

The private document directory is intentionally excluded from both the public HTTP service and the public document index.

## Standard Categories

```text
public/
├── emergency/
├── first-aid/
├── food/
├── gardening/
├── communications/
├── radio/
├── repair/
├── equipment-manuals/
├── education/
├── books/
└── faith/
    ├── bibles/
    ├── devotionals/
    ├── study/
    └── theology/
```

The current public index uses these defined top-level categories. Additional subfolders may be created within them when useful.

Files placed in unsupported top-level folders are not currently included in the generated public catalog.

## Adding Documents

Copy a document into the most appropriate category.

Example:

```bash
cp water-purification-guide.pdf \
  /srv/offgridpi/content/documents/public/emergency/
```

Files may also be copied using the Raspberry Pi desktop file manager, SFTP, SCP, a USB storage device, or another approved local transfer method.

Set normal readable permissions when necessary:

```bash
chmod 0644 \
  /srv/offgridpi/content/documents/public/emergency/water-purification-guide.pdf
```

## Index Updates

The public document catalog is maintained automatically by:

```text
offgridpi-document-indexer.service
```

The service watches `/srv/offgridpi/content/documents/public` for local file changes using `inotify`.

When the watcher starts, it rebuilds the catalog immediately. After files are created, changed, moved, deleted, or have relevant attributes changed, it waits briefly for the operation to settle and then rebuilds the catalog.

The generated files are:

```text
/srv/offgridpi/content/documents/public/index.html
/srv/offgridpi/content/documents/public/catalog.json
```

To force an immediate rebuild, restart the watcher service:

```bash
sudo systemctl restart offgridpi-document-indexer.service
```

Check its current state with:

```bash
systemctl is-active offgridpi-document-indexer.service
```

Review recent indexing activity with:

```bash
sudo journalctl -u offgridpi-document-indexer.service -n 50 --no-pager
```

The public document service itself is:

```text
offgridpi-documents.service
```

It serves the generated public library read-only on TCP port `8082`.

## Supported File Types

The current indexer catalogs regular files found within the defined public document categories rather than enforcing a strict extension allowlist.

It provides friendly type labels for:

* PDF
* TXT
* Markdown
* HTML and HTM
* EPUB
* JPG and JPEG
* PNG
* GIF
* WebP
* SVG
* DOC and DOCX
* ODT

Other file extensions may still appear in the catalog, but they are identified by their extension rather than a specialized document type.

Catalog visibility does not guarantee that Chromium can display a file directly.

## Browser Behavior

Formats commonly viewable directly in Chromium include:

* PDF
* Plain text
* HTML
* JPG and JPEG
* PNG
* GIF
* WebP
* SVG

Markdown files normally open as plain text rather than rendered Markdown.

EPUB, Microsoft Office, OpenDocument, and other formats may download or require an installed local application rather than opening directly in Chromium.

A file being indexed therefore means that Offgrid Pi can catalog and serve it; it does not necessarily mean that the browser can render it.

Content intended for emergency use should be tested on the actual Offgrid Pi system before being relied upon.

## Naming Standards

Use clear, descriptive filenames.

Recommended format:

```text
topic-description-version-or-date.ext
```

Examples:

```text
water-purification-guide-2026.pdf
first-aid-field-manual.pdf
raspberry-pi-4-service-notes.txt
kjv-bible.pdf
web-bible-2025.epub
```

Recommended rules:

* Use lowercase filenames when practical.
* Use hyphens instead of spaces.
* Avoid characters such as `\`, `/`, `:`, `*`, `?`, `"`, `<`, `>`, and `|`.
* Include a year or version when multiple editions may exist.
* Avoid vague names such as `manual.pdf`, `document1.pdf`, or `new-file.pdf`.
* Do not rename a file solely to imply a license or source that has not been verified.

## Bible Translations and Faith Resources

Bible translations, devotionals, study materials, and theology references may be stored under:

```text
/srv/offgridpi/content/documents/public/faith
```

Suggested Bible structure:

```text
faith/bibles/
├── KJV/
├── WEB/
├── ASV/
├── Douay-Rheims/
└── Other/
```

Some Bible translations and study materials are copyrighted.

Users are responsible for confirming that content is legally obtained and used appropriately. Copyrighted files should not be committed to GitHub or redistributed through Offgrid Pi unless redistribution is expressly permitted.

## Removing Documents

Delete the file from the library:

```bash
rm \
  /srv/offgridpi/content/documents/public/category/filename.ext
```

The automatic indexer should detect the deletion and rebuild the catalog.

If an immediate manual rebuild is needed:

```bash
sudo systemctl restart offgridpi-document-indexer.service
```

The removed file should disappear from the document page after the browser is refreshed.

## Local-Network Availability

Files in the public document library are available to devices that can reach Offgrid Pi on the local network through TCP port `8082`.

The public library should therefore contain only material intended to be accessible to household or other authorized local-network users.

Passwords, financial records, private keys, confidential business records, and other sensitive material should not be placed in the public document library.

Private user documents belong under:

`/srv/offgridpi/content/documents/personal`

That directory is not served by `offgridpi-documents.service` and is not included in the public document catalog.

Offgrid Pi does not expose the public document library to the internet by default, but the local network should not automatically be assumed to be trusted.

## Content and GitHub

Large content files should not be committed to the Offgrid Pi GitHub repository.

The repository should contain:

* Scripts
* Service definitions
* Dashboard files
* Content manifests
* Configuration examples
* Documentation
* Public-domain sample files when appropriate

The repository should not contain:

* Personal documents
* Passwords
* Private keys
* Copyrighted books or media without redistribution permission
* Large ZIM archives
* Large map databases
* User-specific content libraries

## Troubleshooting

### A file does not appear

Confirm that the file is located under one of the defined public categories beneath:

```text
/srv/offgridpi/content/documents/public
```

List the current public files with:

```bash
find /srv/offgridpi/content/documents/public \
  -type f \
  -printf '%p\n' \
  | sort
```

Files in unsupported top-level folders are not included in the generated catalog.

Hidden files and symbolic links are intentionally skipped by the current indexer.

Restart the automatic indexer to force an immediate rebuild:

```bash
sudo systemctl restart offgridpi-document-indexer.service
```

Review recent indexing activity:

```bash
sudo journalctl \
  -u offgridpi-document-indexer.service \
  -n 50 \
  --no-pager
```

### A file is listed but will not open

Confirm that the public document service is running:

```bash
systemctl is-active offgridpi-documents.service
```

Check that the `offgridpi` service account can read the file:

```bash
sudo -u offgridpi test -r "/path/to/file" \
  && echo "Readable" \
  || echo "Not readable"
```

Check its permissions:

```bash
ls -l "/path/to/file"
```

Also remember that cataloged files are not guaranteed to render directly in Chromium. Some formats may require another local application or may download instead.

### The index does not update automatically

Check the watcher service:

```bash
systemctl is-enabled offgridpi-document-indexer.service
systemctl is-active offgridpi-document-indexer.service
```

If it is not running, inspect its log:

```bash
sudo journalctl \
  -u offgridpi-document-indexer.service \
  -n 100 \
  --no-pager
```

The watcher depends on `inotifywait`, provided by the `inotify-tools` package.

### The public library is unavailable

Check the document-serving service:

```bash
systemctl is-enabled offgridpi-documents.service
systemctl is-active offgridpi-documents.service
```

Review its log with:

```bash
sudo journalctl \
  -u offgridpi-documents.service \
  -n 50 \
  --no-pager
```
