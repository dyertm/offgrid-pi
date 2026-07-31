# Offgrid Pi Content Management Guide

## Purpose

This guide explains how to add, organize, update, and remove locally stored documents from Offgrid Pi.

The document library is intended for user-managed reference material such as emergency guides, medical information, equipment manuals, books, educational resources, faith materials, and locally created documents.

Content files are stored outside the GitHub repository.

## Document Library Location

The document library is stored at:

```text
/srv/offgridpi/content/documents/library
```

Files placed under this directory are available through the local Offgrid Pi dashboard.

The library can be opened at:

```text
http://offgridpi.local:8081/documents/
```

On the Raspberry Pi itself, it can also be opened at:

```text
http://localhost:8081/documents/
```

## Standard Categories

```text
library/
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

Users may create additional categories and subfolders when needed.

The first folder beneath `library` becomes the category displayed in the document index.

## Adding Documents

Copy a document into the most appropriate category.

Example:

```bash
cp water-purification-guide.pdf \
  /srv/offgridpi/content/documents/library/emergency/
```

Files may also be copied using the Raspberry Pi desktop file manager, SFTP, SCP, a USB storage device, or another approved local transfer method.

Set normal readable permissions when necessary:

```bash
chmod 0644 \
  /srv/offgridpi/content/documents/library/emergency/water-purification-guide.pdf
```

## Index Updates

The document index is regenerated automatically by:

```text
offgridpi-document-index.timer
```

The timer normally checks for changes approximately every five minutes.

To regenerate the index immediately, run:

```bash
sudo systemctl start offgridpi-document-index.service
```

Check the most recent indexing result with:

```bash
systemctl show \
  offgridpi-document-index.service \
  --property=Result \
  --property=ExecMainStatus
```

A successful run should report:

```text
Result=success
ExecMainStatus=0
```

## Supported File Types

The current indexer recognizes:

* PDF
* TXT
* Markdown
* HTML
* EPUB
* JPG and JPEG
* PNG
* GIF
* WebP
* SVG
* DOC and DOCX
* XLS and XLSX
* PPT and PPTX
* ODT, ODS, and ODP

## Browser Behavior

The following formats normally open directly in Chromium:

* PDF
* Plain text
* HTML
* JPG and JPEG
* PNG
* GIF
* WebP
* SVG

Markdown files normally open as readable plain text rather than formatted Markdown.

EPUB and office-document formats may download or open through an installed external application rather than displaying directly in Chromium.

Offline behavior depends on the file and the installed local applications. Files should be tested before being relied upon during an emergency.

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
/srv/offgridpi/content/documents/library/faith
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
  /srv/offgridpi/content/documents/library/category/filename.ext
```

Then regenerate the index:

```bash
sudo systemctl start offgridpi-document-index.service
```

The removed file should disappear from the document page after the browser is refreshed.

## Local-Network Availability

Files in the document library are available to devices that can access the Offgrid Pi dashboard on the local network.

Do not place passwords, financial records, private keys, confidential business records, or other sensitive material in the library unless local-network access and exposure are understood and accepted.

Offgrid Pi does not make these documents publicly available on the internet by default, but the local network should not automatically be assumed to be trusted.

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

Confirm that the file is located under:

```text
/srv/offgridpi/content/documents/library
```

Confirm that its extension is supported:

```bash
find /srv/offgridpi/content/documents/library \
  -type f \
  -printf '%p\n' \
  | sort
```

Run the indexer manually:

```bash
sudo systemctl start offgridpi-document-index.service
```

Review the service log:

```bash
sudo journalctl \
  -u offgridpi-document-index.service \
  -n 50 \
  --no-pager
```

### A file is listed but will not open

Check that the dashboard service account can read it:

```bash
sudo -u offgridpi test -r "/path/to/file" \
  && echo "Readable" \
  || echo "Not readable"
```

Check its permissions:

```bash
ls -l "/path/to/file"
```

Normal document permissions are generally:

```text
-rw-r--r--
```

### The index does not update automatically

Check the timer:

```bash
systemctl is-enabled offgridpi-document-index.timer
systemctl is-active offgridpi-document-index.timer
systemctl list-timers offgridpi-document-index.timer --no-pager
```

The timer should be enabled and active.
