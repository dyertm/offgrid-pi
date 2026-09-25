# Offgrid Pi Content Strategy

**Created:** August 1, 2026
**Reconciled:** September 24, 2026

## 1. Purpose

The value of Offgrid Pi depends more on useful, trustworthy, legally distributable content than on the quantity of files installed.

This document defines content priorities and selection rules. Exact filenames, sizes, release dates, and download locations must be verified when manifests are created because available archives change over time.

## 2. Selection principles

Offgrid Pi should prioritize curated usefulness over raw storage volume. A smaller collection of trustworthy, well-organized material is more valuable during an emergency than hundreds of gigabytes of poorly selected files.

Content should be:

* Useful without internet access
* Relevant to realistic household disruptions and resilience needs
* Understandable by non-specialists
* Organized for fast retrieval under stress
* Searchable through current Offgrid Pi indexing and designed for future unified-search integration
* Clearly categorized when full-text search is not available
* Stored in formats the Raspberry Pi can open reliably
* Sourced from authoritative or otherwise well-vetted publishers when safety or accuracy matters
* Accompanied by source, date, edition, license, and checksum information when distributed as part of an Offgrid Pi content set
* Clearly distinguishable as historical material when it is no longer current
* Replaceable or updateable without rebuilding the operating system
* Tested on the actual Offgrid Pi platform before being relied upon

Bundled or project-distributed content must have verified redistribution rights.

User-supplied content does not need redistribution permission from the Offgrid Pi project, but users remain responsible for the legality and appropriateness of material they add to their own systems.

## 3. Priority tiers

### Tier 1 — Essential household reference

* General encyclopedia and broad reference
* Medical, first aid, and basic triage
* Water safety, treatment, and sanitation
* Emergency preparedness and household response
* Food safety, storage, and preservation
* Shelter, cooking, sanitation, and fire safety
* Basic repair and maintenance
* Power, batteries, generators, and solar guidance
* Radio and emergency communications
* Evacuation, family plans, and practical checklists
* Local and regional maps
* Weather and natural-hazard references

### Tier 2 — Long-term resilience

* Gardening and agriculture
* Seed saving and food-production sustainability
* Regional edible and useful plants
* Construction and tool use
* Electrical, mechanical, and plumbing references
* Equipment manuals
* Household security and privacy
* Homesteading and other practical self-reliance skills

### Tier 3 — Education and morale

* Mathematics, science, history, and reading
* Project Gutenberg and other lawful book collections
* Faith and Scripture resources
* Children and family learning material
* Music, audiobooks, and legally owned media

## 4. Kiwix strategy

Offgrid Pi should use a curated set of Kiwix ZIM archives rather than attempting to mirror every available collection.

Candidate categories include:

* Wikipedia in an edition appropriate to available storage
* Wiktionary
* Wikibooks
* WikiMed or other reputable medical collections
* Project Gutenberg collections
* Repair or practical-skills collections when an appropriate ZIM exists
* Education collections suitable for the intended users

Project-managed ZIM archives should be described through the Offgrid Pi content-pack system rather than copied into place without provenance or integrity records.

For every approved ZIM, retain:

* Display title
* Exact filename
* Source URL
* Download or acquisition date
* Archive date or version
* Language
* Size
* License and redistribution status
* SHA-256 checksum
* Validation result
* Functional Kiwix serving result

Content-pack workflows should validate metadata, available storage, source and destination safety, file size, and checksum before installation.

Downloaded material should be staged separately from the live library and verified before it is installed.

A validator warning or failure and a successful functional Kiwix serving test are separate facts. Both should be retained when they disagree rather than silently discarding either result.

ZIM archives should also be reviewed periodically for freshness. An older archive may remain useful, but its archive date must remain visible so historical content is not mistaken for current information.

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

Offline Maps is now an implemented Core capability supporting PMTiles and PDF/GeoPDF map packs. Regional map acquisition and curation should use the established map-pack workflow.

## 8. Source quality and freshness

Medical, safety, legal, technical, and emergency material should favor authoritative primary sources, recognized institutions, standards bodies, government agencies, established publishers, or other sources appropriate to the subject.

Every project-managed content item should retain enough metadata to determine:

* Who produced it
* Where it came from
* When it was published or revised
* When Offgrid Pi acquired or reviewed it
* Which edition or version is installed
* What license or redistribution terms apply
* Whether a newer edition is known to exist

The date a file was downloaded is not the same as the date its information was published.

Older material may remain valuable, especially manuals, historical references, literature, and stable technical information. It should be clearly identified as historical or older-edition material when users could otherwise mistake it for current guidance.

Time-sensitive content should be reviewed periodically. Examples include:

* Medical and first-aid guidance
* Water-treatment recommendations
* Emergency procedures
* Regulatory or legal references
* Communications rules and frequency information
* Hazard and evacuation information
* Product manuals for equipment still in active use

Content should not be removed solely because it is old. The goal is to prevent stale information from being presented as current while preserving useful historical material when appropriate.

## 9. Storage planning

Offgrid Pi should separate operating-system and application storage from larger bulk-content storage where practical.

The current direction is:

* microSD or equivalent local system storage for Raspberry Pi OS, Offgrid Pi software, configuration, and recovery-critical files
* external USB SSD storage preferred for larger document, map, Kiwix, and media collections
* content paths and manifests designed so bulk content can be replaced or expanded without rebuilding the operating system
* no Core dependency on RAID, NAS, cloud storage, or an internet connection

Content manifests may still group optional collections by approximate storage profile, such as:

* Minimal starter
* Standard preparedness
* Expanded family
* Regional specialist
* Full library

These profiles are planning aids rather than a goal to fill available capacity.

Knowledge and emergency-reference content receives storage priority over entertainment media. Storage should be allocated according to usefulness, retrieval quality, licensing, freshness, and actual household needs rather than raw file count or total gigabytes.

## 10. Content not stored in GitHub

The Offgrid Pi repository should primarily contain software, manifests, schemas, metadata, documentation, configuration examples, and tooling rather than large operational content libraries.

Small public-domain or openly licensed sample files may be included when they are useful for testing, documentation, or examples and their redistribution status is clear.

The repository should not contain:

* Personal or private user documents
* Passwords, private keys, credentials, or other secrets
* Unauthorized copyrighted books or reference material
* Copyrighted Bible translations or study material without redistribution permission
* Large ZIM archives
* Large production map datasets or GeoPDF collections
* Movies, television, music, audiobooks, ROMs, or other commercial media without explicit redistribution rights
* User-specific content libraries
* Private waypoints, notes, or other personal map data

Project-managed content should instead be represented by manifests and provenance metadata where practical, with the actual files acquired, staged, verified, and installed through the appropriate Offgrid Pi content workflow.

User-supplied lawful content may be stored on an individual Offgrid Pi system without being part of the public project repository or redistribution package.
