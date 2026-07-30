# Offgrid Pi

Offgrid Pi is a customizable, reproducible offline knowledge server built for the Raspberry Pi.

The goal is to create a practical local information repository that remains useful when internet access is unavailable, unreliable, or intentionally disconnected.

The project will use Internet-in-a-Box and other open-source tools to provide offline access to resources such as:

* Wikipedia and other Kiwix libraries
* Offline maps and navigation resources
* Medical and first-aid references
* Emergency-preparedness information
* Gardening and food-preservation guides
* Repair and maintenance manuals
* Local PDF documents and personal reference material
* Optional family education resources
* Optional offline movies, music, and audiobooks

## Project Goals

Offgrid Pi is intended to be:

* Customizable instead of overloaded with unnecessary services
* Reproducible from documented configuration files
* Accessible through a directly connected monitor
* Available to nearby devices over a local network
* Easy to back up and restore
* Expandable through optional content profiles
* Shareable with others through GitHub

## Planned Hardware

The initial build is planned around:

* Raspberry Pi 4
* Raspberry Pi OS 64-bit with Desktop
* MicroSD card for the operating system
* USB 3 SSD for offline content
* Monitor, keyboard, and mouse
* Optional local Wi-Fi access point
* Optional backup power supply

## Planned Software

The initial software stack may include:

* Internet-in-a-Box
* Kiwix
* Offline OpenStreetMap resources
* Calibre-Web or another local document library
* A customized local home page
* Backup, restore, and system health scripts
* Kodi for optional offline media-library playback
* VLC as a fallback player for individual media files

The final software selection will remain intentionally small. Additional applications will be added only when they provide a clear off-grid or emergency-use benefit.

## Content Profiles

The project may eventually offer several optional configurations:

### Core

General reference material, essential maps, medical references, and local documents.

### Preparedness

First aid, water treatment, food preservation, gardening, communications, and repair information.

### Pacific Northwest

Washington, Oregon, and Idaho maps, public-land information, regional hazards, trails, and local emergency resources.

### Family Education

Selected mathematics, science, history, reading, and practical-skills resources.

### Offline Entertainment

User-supplied, legally owned movies, television programs, music, and audiobooks. This profile will remain optional and will use storage separate from the operating-system drive. Emergency and reference content will receive storage priority.

## Project Status

This project is currently in the initial planning and build stage.

The first version will focus on:

1. Preparing the Raspberry Pi and external SSD
2. Installing a minimal Internet-in-a-Box configuration
3. Adding a curated Kiwix library
4. Installing regional offline maps
5. Creating a simple local home screen
6. Documenting backup and recovery procedures
7. Testing whether the system can be rebuilt from this repository
8. Prototyping an optional Kodi and VLC offline-media module after the core platform is stable

## Important Content Note

This repository will contain configuration files, scripts, manifests, and documentation.

It will not directly contain large Wikipedia archives, map databases, copyrighted books or media, personal documents, passwords, private keys, or other sensitive information. Content manifests will identify authorized download sources whenever possible.

## Attribution

Offgrid Pi is an independent community project and is not the official Internet-in-a-Box project.

Internet-in-a-Box, Kiwix, OpenStreetMap, and other included projects remain the work of their respective developers and communities.

## License

A project license will be selected after the initial configuration and scripts have been created.
