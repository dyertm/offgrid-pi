# Offgrid Pi Project Blueprint

## 1. Project overview

**Offgrid Pi** is a Raspberry Pi-based offline knowledge system designed to provide access to useful information without requiring an active internet connection.

The system is intended to operate locally through an attached monitor, keyboard, and mouse. It may also provide browser-based access to other devices connected to the same local network.

The project will combine established offline-content tools with a simplified, customized interface that nontechnical users can understand and operate.

The initial goal is not merely to configure one personal Raspberry Pi. The goal is to create a repeatable open project that other people can install, customize, document, and maintain.

## 2. Project mission

Create a dependable, approachable, and reproducible offline knowledge platform that can be used for:

* General reference
* Emergency preparedness
* Medical and first-aid reference
* Repair and maintenance
* Food production and preservation
* Education
* Books and literature
* Radio and communications
* Equipment documentation
* Regional maps and geographic information
* User-supplied documents

The system should remain useful during internet outages, remote travel, grid failures, natural disasters, or other situations where normal online resources are unavailable.

## 3. Intended users

Offgrid Pi is intended for:

* Individuals building an emergency knowledge library
* Families preparing for extended internet or power outages
* Rural or remote users with unreliable internet access
* Amateur radio operators
* Campers, overlanders, and remote travelers
* Homesteaders
* Community preparedness groups
* Schools or organizations that need offline reference materials
* Raspberry Pi users who want a structured offline-content platform

The system should be usable by people with limited Linux experience after the initial installation is complete.

## 4. Core design principles

### 4.1 Offline-first

The system must remain functional without internet access after content and software have been installed.

Internet access may be required during initial setup, software updates, and content downloads.

### 4.2 Local control

Users should retain control over:

* Installed software
* Downloaded content
* Storage location
* Network configuration
* Personal documents
* Updates
* Backups

The project should not depend on a cloud account for normal operation.

### 4.3 Simple operation

A user should be able to start the Raspberry Pi and access the primary dashboard without opening a terminal.

The local interface should use clear categories, large controls, and plain language.

### 4.4 Reproducible installation

The installation process should be documented and automated wherever practical.

Another user should be able to begin with a supported Raspberry Pi and a clean Raspberry Pi OS installation, follow the documented procedure, and produce a comparable system.

### 4.5 Modular design

Major functions should be divided into modules so that users can choose what they need.

Potential modules include:

* Kiwix knowledge library
* Local document library
* Offline maps
* Emergency reference pack
* Medical reference pack
* Education pack
* Radio reference pack
* Local Wi-Fi access point
* Backup and recovery tools

### 4.6 Repairability

The project should favor components that can be understood, replaced, or repaired without requiring a complete rebuild.

Configuration files, scripts, service definitions, and documentation should be stored in the GitHub repository.

### 4.7 Efficient operation

The system should minimize unnecessary processor, memory, and power usage.

The initial version should avoid unnecessary background services and overly complex dependencies.

## 5. Current project scope

The current development phase focuses on building and documenting the software platform.

The active scope includes:

* Raspberry Pi OS installation
* Raspberry Pi configuration
* Kiwix installation
* Local ZIM-file hosting
* Local document hosting
* A customized Offgrid Pi dashboard
* Automatic service startup
* Automatic dashboard launch
* Local hostname access
* Local-network browser access
* Content folder standards
* Content-pack definitions
* Installation scripts
* Health-check scripts
* Troubleshooting documentation
* GitHub repository structure
* Clean installation testing

* ## Offline Entertainment Module (7-30-27)

The Offgrid Pi will include an optional offline entertainment module for use during extended power outages, emergencies, travel, camping, or other periods without reliable internet access.

The module will provide local playback of legally owned movies, television programs, music, audiobooks, and other media stored on attached USB storage.

Kodi will serve as the primary media-library interface. VLC will be installed as a lightweight fallback player for individual files and media formats that do not work correctly in Kodi.

The entertainment module must remain separate from the system’s emergency-reference content. Entertainment files must not reduce the reliability, accessibility, or available storage required for maps, medical information, repair manuals, communications references, Kiwix libraries, and other essential resources.

### Primary Functions

* Browse and play movies and television programs without internet access.
* Play locally stored music and audiobooks.
* Maintain separate family, children’s, and general media folders.
* Retain media metadata and artwork locally when practical.
* Launch the media center from the main Offgrid Pi interface.
* Return to the main Offgrid Pi interface after exiting Kodi.
* Allow direct file playback through VLC if Kodi is unavailable.

### Design Priorities

* Fully functional without internet access.
* Simple enough for nontechnical users.
* Compatible with Raspberry Pi 4 hardware.
* Low power consumption during playback.
* No dependence on cloud accounts or streaming services.
* Media stored separately from the operating-system SD card.
* Emergency information receives priority over entertainment content.

## 6. Deferred scope

The following subjects are important but are intentionally deferred until the core software platform is working:

* Long-term storage selection
* Storage redundancy
* External-drive performance testing
* Backup-drive rotation
* EMP protection
* Faraday bags or Faraday enclosures
* Hardened electronics storage
* Solar runtime testing
* Battery runtime testing
* EcoFlow integration
* Voltaic V72 integration
* Renogy solar-panel testing
* Arc solar-panel testing
* Custom carrying cases
* Waterproof storage
* Complete downloadable Raspberry Pi images
* Advanced offline-map implementation
* Automatic Wi-Fi hotspot mode
* Emergency communications hardware integration

These items may be added to later project phases without changing the initial software architecture.

## 7. Hardware baseline

### 7.1 Development hardware

The current development system consists of:

* Raspberry Pi 4B
* Miuzei Raspberry Pi 4 case
* Cooling fan
* Heatsinks
* 5V 3A USB-C power supply
* GeeekPi 10.1-inch HDMI display
* 1024 × 600 display resolution
* Keyboard
* Mouse
* Micro-HDMI-to-HDMI cable
* Network connection
* MicroSD cards
* USB flash drives
* USB hard drives
* Windows computer for imaging and repository work

### 7.2 Minimum supported development configuration

The initial project should target:

* Raspberry Pi 4B
* 4 GB RAM or greater preferred
* 32 GB microSD card minimum
* 64 GB or larger microSD card recommended for development
* Raspberry Pi-compatible power supply
* Ethernet or Wi-Fi during installation
* HDMI display for direct local access

Support for other Raspberry Pi models may be evaluated after the Raspberry Pi 4 build is stable.

## 8. Operating-system baseline

The planned operating system is:

**Raspberry Pi OS 64-bit with Desktop**

The Desktop edition is preferred because the system is intended to support direct use through an attached display.

The initial installation should avoid unnecessary preinstalled applications. Additional packages should be installed only when they support a defined Offgrid Pi function.

## 9. Proposed software architecture

### 9.1 Operating-system layer

Raspberry Pi OS will provide:

* Hardware support
* Desktop environment
* Networking
* Package management
* System services
* User management
* Browser access
* File-system access

### 9.2 Offline-content layer

Kiwix will provide access to ZIM-format content such as:

* Wikipedia
* Wiktionary
* Wikibooks
* WikiMed
* Project Gutenberg collections
* Other compatible offline archives

Kiwix content should be served through a local web service.

### 9.3 Document-library layer

Non-ZIM content will be stored in a separate document library.

Supported content may include:

* PDF files
* Text files
* HTML documents
* Images
* Equipment manuals
* Checklists
* Locally created documentation

### 9.4 Dashboard layer

A custom Offgrid Pi dashboard will act as the system’s primary interface.

The dashboard should link to:

* Kiwix libraries
* Document categories
* Offline maps
* System status
* Storage information
* Administration tools
* Shutdown and restart functions
* Project documentation

### 9.5 Service layer

The project is expected to use standard Linux services managed by `systemd`.

Proposed services include:

```text
kiwix-serve.service
offgridpi-dashboard.service
offgridpi-indexer.service
```

Final service names may change during development.

### 9.6 Network layer

The system should support:

* Access from the Raspberry Pi itself
* Access from devices on the same local network
* Local hostname resolution when practical
* Direct IP-address access as a fallback

A future phase may add automatic Wi-Fi hotspot functionality.

## 10. Proposed file-system structure

The planned application structure is:

```text
/opt/offgridpi/
├── dashboard/
├── scripts/
├── config/
└── tools/
```

The planned content structure is:

```text
/srv/offgridpi/
├── content/
│   ├── kiwix/
│   ├── documents/
│   ├── maps/
│   └── media/
├── indexes/
├── logs/
└── backups/
```

The document library may use the following categories:

```text
documents/
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
└── personal/
```

The `personal` directory must not be included in public releases or committed to GitHub.

## 11. Proposed dashboard categories

The initial dashboard may contain:

* Encyclopedia
* Medical and First Aid
* Emergency Preparedness
* Food and Agriculture
* Repair and Maintenance
* Radio and Communications
* Books and Literature
* Education
* Maps
* Equipment Manuals
* Local Documents
* System Status
* Administration

Categories should be configurable rather than permanently hardcoded.

## 12. Content-pack model

Offgrid Pi should eventually support optional content packs.

A content pack should define:

* Pack name
* Description
* Category
* Source
* Download location
* File type
* Approximate size
* License
* Version or release date
* Installation destination
* Required disk space
* Optional or required status

Possible packs include:

* Starter
* Medical
* Preparedness
* Education
* Agriculture
* Repair
* Radio
* Pacific Northwest
* United States maps

Content files should generally not be stored directly in the GitHub repository because of their size.

The repository should instead contain manifests and download instructions.

## 13. GitHub repository structure

The planned repository structure is:

```text
offgrid-pi/
├── README.md
├── LICENSE
├── CHANGELOG.md
├── install.sh
├── uninstall.sh
├── config/
│   ├── offgridpi.conf
│   └── content-manifest.yml
├── dashboard/
│   ├── index.html
│   ├── css/
│   ├── js/
│   ├── icons/
│   └── templates/
├── scripts/
│   ├── install-kiwix.sh
│   ├── configure-dashboard.sh
│   ├── index-documents.py
│   ├── check-system.sh
│   └── update-content-catalog.sh
├── systemd/
│   ├── kiwix-serve.service
│   ├── offgridpi-dashboard.service
│   └── offgridpi-indexer.service
├── content-packs/
│   ├── starter.yml
│   ├── medical.yml
│   ├── preparedness.yml
│   └── education.yml
├── docs/
│   ├── PROJECT_BLUEPRINT.md
│   ├── BUILD_LOG.md
│   ├── DECISIONS.md
│   ├── INSTALLATION.md
│   ├── ROADMAP.md
│   ├── CUSTOMIZATION.md
│   ├── CONTENT_MANAGEMENT.md
│   └── TROUBLESHOOTING.md
└── tests/
    └── verify-installation.sh
```

This structure is provisional and may change as development progresses.

## 14. Proposed installation experience

The long-term installation goal is:

```bash
git clone https://github.com/REPLACE-WITH-OWNER/offgrid-pi.git
cd offgrid-pi
sudo ./install.sh
```

The installation script should eventually:

1. Confirm that the script is running with appropriate permissions.
2. Detect the operating system.
3. Detect the Raspberry Pi model.
4. Check available disk space.
5. Check network connectivity.
6. Install required packages.
7. Create application directories.
8. Create content directories.
9. Install Kiwix.
10. Configure the Kiwix service.
11. Install the Offgrid Pi dashboard.
12. Configure the local hostname.
13. Enable required services.
14. Offer optional starter content.
15. Run a system health check.
16. Display access instructions.
17. Record installation results in a log.

The first release may use multiple scripts before these functions are combined into one installer.

## 15. Security considerations

The system is intended primarily for local and offline use.

Development should account for:

* Avoiding unnecessary exposed network services
* Restricting administrative functions
* Preventing unauthenticated remote shutdown
* Separating public content from personal content
* Avoiding hardcoded passwords
* Documenting default credentials
* Allowing users to change the hostname
* Allowing users to change service ports
* Keeping administrative logs
* Validating downloaded content where practical

The project should not assume that a local network is automatically trustworthy.

## 16. Licensing considerations

The project must identify:

* The software license for Offgrid Pi
* Licenses for included scripts or code
* Licenses for icons and design assets
* Licenses for content catalogs
* Licenses for recommended third-party content
* Restrictions on redistributing downloaded ZIM, map, PDF, or media files

The GitHub repository should not redistribute third-party content unless redistribution is clearly permitted.

## 17. Initial release criteria

A first usable release should meet the following requirements:

* Installs on a clean Raspberry Pi OS 64-bit Desktop installation
* Runs on the Raspberry Pi 4B
* Starts required services automatically
* Opens a usable local dashboard
* Serves at least one Kiwix library
* Provides access to local documents
* Works without internet access after setup
* Can be accessed from the attached monitor
* Can be accessed from another device on the local network
* Includes installation instructions
* Includes troubleshooting instructions
* Includes an uninstall or rollback procedure
* Includes a health-check script
* Does not expose personal content by default
* Can be reproduced from the public repository

## 18. Project workflow

The project will use the following workflow:

1. Discuss the next task.
2. Document the decision.
3. Perform the configuration.
4. Record commands and results in the build log.
5. Add or update scripts.
6. Test the change.
7. Update user-facing installation instructions.
8. Commit the change to GitHub.
9. Repeat the test on a clean installation when appropriate.

Conversations may be used for planning and troubleshooting, but the repository documentation will remain the official source of truth.

## 19. Current project status

The project is currently in the planning and initial-build stage.

Completed planning decisions include:

* Raspberry Pi 4B selected as the initial platform.
* Raspberry Pi OS 64-bit with Desktop selected as the operating-system baseline.
* Direct monitor use is a core requirement.
* Kiwix selected as the initial offline-content engine.
* A custom browser-based dashboard will be developed.
* Native Linux services are preferred over Docker for the first release.
* Installation scripts will be developed before a downloadable disk image.
* Storage architecture will be finalized after the core software is functional.
* EMP and Faraday-storage planning are deferred.
* Power-system integration is deferred until software development is further along.

## 20. Next milestone

The next milestone is to create a clean development installation of Raspberry Pi OS, document the imaging process, complete the initial operating-system configuration, install Kiwix, and serve one small test ZIM file successfully.
