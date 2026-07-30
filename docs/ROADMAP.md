Offgrid Pi Roadmap
Roadmap purpose

This roadmap organizes development into manageable phases.

The order may change when testing reveals dependencies or technical limitations.

Phase 0 — Project definition

Status: In progress

Objectives
Define project mission
Define intended users
Establish scope
Select initial hardware
Select operating-system baseline
Select initial software architecture
Create the GitHub repository
Create project documentation
Define initial folder structure
Establish the build-record process
Deliverables
PROJECT_BLUEPRINT.md
BUILD_LOG.md
DECISIONS.md
INSTALLATION.md
ROADMAP.md
Initial README.md
Initial repository folders
Initial license selection
Completion criteria
The project scope is clearly documented.
Deferred features are separated from active development.
The repository is ready to receive scripts and code.

Phase 1 — Raspberry Pi foundation

Status: Not started

Objectives
Select development microSD card
Flash Raspberry Pi OS 64-bit with Desktop
Document Raspberry Pi Imager settings
Complete first boot
Confirm display support
Confirm fan operation
Confirm keyboard and mouse operation
Confirm Ethernet and Wi-Fi
Update Raspberry Pi OS
Record baseline system information
Install foundational development tools
Deliverables
Documented imaging process
Working Raspberry Pi desktop
Baseline system-information record
Initial configuration notes
Updated installation guide
Completion criteria
Raspberry Pi boots reliably.
Display is usable at 1024 × 600.
Network access works.
Operating system is updated.
SSH access works if enabled.
Build steps have been documented.

Phase 2 — Kiwix proof of concept

Status: Not started

Objectives
Select a Kiwix installation method
Install Kiwix
Create the content directory
Download a small test ZIM
Serve the test ZIM
Test browser access locally
Test browser access from another device
Test without internet access
Create a Kiwix systemd service
Record logs and troubleshooting procedures
Deliverables
install-kiwix.sh
kiwix-serve.service
Kiwix configuration file
Small test-content manifest
Kiwix troubleshooting section
Successful offline test record
Completion criteria
Kiwix starts automatically.
At least one ZIM library is available.
Search works offline.
The service survives a reboot.
The installation can be repeated from documentation.

Phase 3 — Dashboard prototype

Status: Not started

Objectives
Define the Offgrid Pi visual identity
Create the dashboard layout
Add category navigation
Add a Kiwix link
Add a document-library link
Add an optional offline-entertainment launcher or placeholder
Add system-status placeholders
Optimize for 1024 × 600
Host all assets locally
Configure automatic browser launch
Preserve normal desktop access
Deliverables
Dashboard HTML
Dashboard CSS
Dashboard JavaScript
Local icons and assets
Dashboard configuration file
Dashboard service
Autostart configuration
Responsive-display test results
Completion criteria
Dashboard loads without internet access.
Dashboard is readable on the GeeekPi display.
All initial navigation links function.
No required assets are loaded from the internet.
Dashboard launches automatically after boot.

Phase 4 — Local document library

Status: Not started

Objectives
Define supported document types
Create document categories
Create an indexing method
Generate browser-accessible indexes
Add metadata where possible
Add search or filtering
Ensure personal files remain private
Define document naming standards
Document how users add files
Deliverables
index-documents.py
Document-directory template
Document metadata format
Content-management guide
Sample public-domain documents
Document-library dashboard integration
Completion criteria
Users can copy files into documented folders.
The index updates reliably.
Files can be opened through the dashboard.
Personal folders are not exposed by default.
The system works offline.

Phase 5 — Reproducible installer

Status: Not started

Objectives
Combine validated steps into install.sh
Detect supported hardware
Detect supported operating system
Check storage availability
Install dependencies
Create directories
Set safe permissions
Install services
Install dashboard
Configure Kiwix
Run a health check
Log installation results
Add failure handling
Add re-run safety
Deliverables
install.sh
uninstall.sh
verify-installation.sh
Installation log
Error messages
Rollback guidance
Clean-install test report
Completion criteria
A clean Raspberry Pi OS installation can be converted into Offgrid Pi by following the documented process.
The installer does not require undocumented manual changes.
Re-running the installer does not damage the installation.
Failure states provide useful messages.
User content is preserved during upgrades and uninstall operations.

Phase 6 — Content-pack system

Status: Not started

Objectives
Define manifest format
Build starter content pack
Build medical pack
Build preparedness pack
Build education pack
Record source and licensing information
Estimate storage requirements
Add optional downloads
Validate checksums
Track content versions
Support removal of optional packs
Deliverables
content-manifest.yml
starter.yml
medical.yml
preparedness.yml
education.yml
Content download tool
Content status page
Licensing documentation
Completion criteria
Users can view available content packs.
Users can install selected packs.
Required storage is shown before downloading.
Sources and licenses are documented.
Installed content is recorded.
Failed downloads can resume or be retried safely.

Phase 7 — System status and administration

Status: Not started

Objectives
Display processor temperature
Display memory usage
Display storage usage
Display installed content
Display service status
Display network address
Add safe restart
Add safe shutdown
Add content reindexing
Add log viewing
Protect administrative actions
Deliverables
System-status page
Administrative tools
Authorization method
Status API or local script
Safe shutdown workflow
Service health reporting
Completion criteria
Users can identify common problems without opening a terminal.
Administrative actions require appropriate authorization.
Shutdown and restart actions do not risk file-system damage.
Status information works without internet access.

Phase 8 — Offline maps

Status: Deferred

Objectives
Evaluate offline map formats
Evaluate PMTiles
Evaluate MapLibre-based display
Evaluate topographic map sources
Define regional map packs
Test map performance on Raspberry Pi 4
Test storage requirements
Add coordinates and search
Add local map import instructions
Potential map packs
Washington State
Pacific Northwest
King County
Eastern Washington
United States overview
Topographic maps
Roads and communities
Trails and recreation
Completion criteria

To be defined after technical evaluation.

Phase 9 — Offline entertainment module

Status: Planned

Dependencies

* Raspberry Pi foundation is stable.
* The dashboard can launch local applications.
* Temporary USB storage is available for testing.
* Final storage allocation will be coordinated with Phase 11.
* Off-grid runtime validation will be completed in Phase 12.

Objectives

* Install Kodi on Raspberry Pi OS.
* Install VLC as a fallback media player.
* Create the approved media-directory structure.
* Test media from an available USB storage device.
* Configure the test drive to mount consistently.
* Add media folders as Kodi library sources.
* Configure Kodi for useful offline operation.
* Retain permitted metadata and artwork locally when practical.
* Disable or avoid unnecessary online services and add-ons.
* Add an Offline Entertainment option to the Offgrid Pi dashboard or desktop launcher.
* Return cleanly to the dashboard or desktop when Kodi closes.
* Test video, audio, and subtitle playback with network access disabled.
* Check for overheating, undervoltage warnings, drive disconnects, and system instability.
* Document media import, naming, library refresh, and removal procedures.
* Document that users must supply legally obtained media.

Initial compatibility tests

* MP4 playback
* MKV playback
* H.264 at 720p
* H.264 at 1080p
* AAC stereo audio
* SRT subtitles
* VLC fallback playback

Deliverables

* Optional Kodi and VLC installation instructions
* Media-directory template
* Dashboard or desktop launcher
* Offline playback test record
* Media-library management instructions
* Known-limitations and troubleshooting notes

Completion criteria

* Kodi launches locally from the documented interface.
* At least one test movie plays without internet access.
* VLC opens at least one media file as a fallback.
* Audio and subtitles work correctly.
* The test media drive mounts after restart.
* Kodi exits without preventing access to the dashboard or desktop.
* Playback does not produce unresolved overheating, undervoltage, drive-disconnect, or stability problems.
* Emergency-reference services remain available and unaffected.

Out of scope for this phase

* Final media-drive purchase or long-term storage recommendation
* Jellyfin or other network media-server deployment
* Video transcoding
* EcoFlow runtime measurement
* Solar recharge testing
* Large-scale redistribution of media files

Phase 10 — Local Wi-Fi hotspot mode

Status: Deferred

Objectives
Allow operation without an existing router
Provide a predictable Wi-Fi network name
Provide local DNS or captive-portal behavior
Maintain direct monitor access
Secure administrative functions
Document client-device connection
Test simultaneous users
Test offline reboot behavior
Completion criteria

To be defined after the base network services are stable.

Phase 11 — Storage architecture

Status: Deferred

Objectives
Inventory existing storage devices
Test microSD endurance considerations
Compare USB HDD and USB SSD performance
Select recommended primary storage
Define mount points
Automate drive detection where practical
Define backup process
Define recovery process
Define content-drive migration
Reserve capacity for knowledge content before entertainment media
Define stable media-library mount paths
Test unexpected drive removal
Test read-only recovery options
Completion criteria

To be defined after the approximate content-library size is known.

Phase 12 — Off-grid power optimization

Status: Deferred

Existing power equipment
EcoFlow RIVER 2
Renogy 200-watt folding solar panel
Voltaic V72 battery
Voltaic Arc 20-watt solar panel
Objectives
Measure idle power use
Measure active-search power use
Measure monitor power use
Measure external-drive power use
Measure Kodi video-playback power use
Test USB and DC powering methods
Compare direct DC operation with AC inverter operation
Define reduced-power mode
Test battery runtime
Test solar recharge
Document safe shutdown thresholds
Completion criteria

To be defined after the software and storage configuration are stable.

Phase 13 — Backup, recovery, and resilience

Status: Deferred

Objectives
Create cloned boot media
Export configuration
Back up user content
Back up content manifests
Restore onto a clean Raspberry Pi OS installation
Detect corrupted or missing content
Document emergency recovery
Create a recovery flash drive
Test restoration without internet access
Completion criteria
A failed boot card can be replaced.
Configuration can be restored.
User content can be recovered.
Recovery instructions are available offline.

Phase 14 — Prebuilt release image

Status: Deferred

Objectives
Create a sanitized Raspberry Pi image
Remove machine-specific credentials
Minimize image size
Support first-boot customization
Publish checksums
Document imaging
Define release versioning
Test on separate hardware
Provide source and license compliance
Completion criteria
A user can flash the image and complete setup without undocumented steps.
No development credentials or personal data are included.
The image corresponds to a tagged repository release.

Phase 15 — Physical protection and long-term storage

Status: Deferred

Objectives
Evaluate environmental storage
Evaluate waterproof storage
Evaluate shock protection
Evaluate cable organization
Evaluate spare-component storage
Revisit Faraday and EMP-protection questions
Separate evidence-based recommendations from marketing claims

This phase will begin only after the software platform, content, storage, and power systems are working.

Phase 16 — Community release

Status: Future

Objectives
Publish a stable GitHub release
Create contributor guidance
Create issue templates
Create feature-request templates
Create security-reporting guidance
Publish screenshots
Publish a demonstration video
Add tested hardware combinations
Add community content-pack submissions
Establish version-support expectations
Initial public-release target

The first public release should provide:

Reproducible installation
Kiwix support
Local dashboard
Local document library
Offline operation
Local-network access
Health check
Documentation
Clean uninstall process
Optional offline media playback when the module is selected

Maps, hotspot mode, extensive content packs, storage recommendations, and downloadable images do not need to be complete for the first public release.

Immediate next actions
Create the five source documents in the repository.
Add an initial README.md.
Select a software license.
Select an erasable development microSD card.
Flash Raspberry Pi OS 64-bit with Desktop.
Complete and document the first boot.
Install system updates.
Record baseline system information.
Install Kiwix.
Serve one small test ZIM file.
