# Offgrid Pi Content Strategy

**Created:** August 1, 2026

## 1. Purpose

The value of Offgrid Pi depends more on useful, trustworthy, legally distributable content than on the quantity of files installed.

This document defines content priorities and selection rules. Exact filenames, sizes, release dates, and download locations must be verified when manifests are created because available archives change over time.

## 2. Selection principles

Content should be:

* Useful without internet access
* Understandable by non-specialists
* Searchable or clearly categorized
* Appropriate for long-term outages and remote use
* Stored in formats the Raspberry Pi can open reliably
* Accompanied by source, date, edition, license, and checksum information
* Replaceable or updateable without rebuilding the operating system

## 3. Priority tiers

### Tier 1 — Essential reference

* General encyclopedia
* Medical and first aid
* Water safety and sanitation
* Emergency preparedness
* Food safety and preservation
* Basic repair and maintenance
* Radio and emergency communications
* Local and regional maps

### Tier 2 — Long-term resilience

* Gardening and agriculture
* Construction and tool use
* Electrical, mechanical, and plumbing references
* Equipment manuals
* Weather and natural-hazard references
* Homesteading and practical skills

### Tier 3 — Education and morale

* Mathematics, science, history, and reading
* Project Gutenberg and other lawful book collections
* Faith and Scripture resources
* Music, audiobooks, and legally owned media

## 4. Kiwix strategy

The project should prefer a curated set of ZIM archives over downloading every available archive.

Candidate categories include:

* Wikipedia in an edition appropriate to available storage
* Wiktionary
* Wikibooks
* WikiMed or other reputable medical collections
* Project Gutenberg collections
* Repair or practical-skills collections when an appropriate ZIM exists
* Education collections suitable for the intended users

For every ZIM, record:

* Display title
* Exact filename
* Source URL
* Download date
* Archive date or version
* Language
* Size
* License
* SHA-256 checksum
* Validation result
* Functional Kiwix test result

A failed validator result and a successful serving result must both be documented rather than silently choosing one result.

## 5. Document-library categories

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
```

Personal material belongs only in:

```text
/srv/offgridpi/content/documents/personal
```

The personal directory must not be served, indexed, packaged, or committed.

## 6. Faith and Scripture profile

The `faith` category may contain:

* Multiple Bible translations
* Study notes
* Devotionals
* Hymnals or songbooks when legally obtained
* Historical Christian texts
* User-selected denominational or ministry resources

Each Bible edition should be stored in its own clearly named subdirectory and should record:

* Translation name
* Edition or revision
* Publisher or source
* Publication date when known
* File format
* License or copyright status
* Whether redistribution is permitted

Public-domain or openly licensed translations are preferred for public manifests and examples. Users may add legally obtained copyrighted editions to their own systems, but the repository must not redistribute them without permission.

## 7. Regional profile

The initial regional profile should focus on Washington, Oregon, and Idaho, with particular attention to:

* Roads and communities
* Topography
* Public lands
* Water sources where reliable data is available
* Wildfire, earthquake, volcanic, flood, and severe-weather references
* Regional plants, agriculture, and hazards

Map implementation remains deferred until the map technology is selected.

## 8. Source quality

Medical, safety, legal, technical, and emergency material should favor authoritative sources. Every content item should retain enough metadata to determine who produced it and when.

Outdated material should not be represented as current merely because the file was downloaded recently.

## 9. Storage planning

Content manifests should group items by approximate storage profile:

* Minimal starter
* Standard preparedness
* Expanded family
* Regional specialist
* Full library

Knowledge content receives storage priority over entertainment media.

## 10. Content not stored in GitHub

The repository should generally contain manifests and instructions rather than large content files. It must not contain unauthorized copyrighted books, Bible translations, maps, movies, music, personal documents, or private data.
