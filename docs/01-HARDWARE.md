# Hardware Inventory

This document records the hardware used for the initial Offgrid Pi build.

Keeping an accurate inventory will make the build easier to reproduce, troubleshoot, upgrade, and share with others.

## Core Hardware

| Component                | Current Hardware                              | Status                                  |
| ------------------------ | --------------------------------------------- | --------------------------------------- |
| Single-board computer    | Raspberry Pi 4 Model B                        | Available                               |
| Installed memory         | To be confirmed                               | Check before installation               |
| Operating-system storage | Multiple microSD cards                        | Select an erasable development card     |
| Offline-content storage  | USB flash drives and USB hard drives          | Inventory capacity and condition        |
| Development power supply | 5V 3A USB-C power supply                      | Available                               |
| Primary off-grid power   | EcoFlow RIVER 2                               | Available; integration testing deferred |
| Primary solar charging   | Renogy 200-watt folding solar panel           | Available; integration testing deferred |
| Backup power             | Voltaic V72                                   | Available; integration testing deferred |
| Backup solar charging    | Voltaic Arc 20W solar panel                   | Available; integration testing deferred |
| Case                     | Miuzei Raspberry Pi 4 case                    | Available                               |
| Cooling                  | Integrated fan and heatsinks                  | Available                               |
| Monitor                  | GeeekPi 10.1-inch HDMI display, 1024 × 600    | Available                               |
| Keyboard and mouse       | USB keyboard and mouse                        | Available                               |
| Network cable            | To be confirmed                               | Recommended during setup                |

## Recommended Storage Layout

The planned storage design separates the operating system from the offline content library.

### Operating-System Drive

Used for:

* Raspberry Pi OS
* Internet-in-a-Box applications
* System configuration
* Startup scripts
* Logs
* Temporary files

Planned device:

* 32–64 GB high-quality microSD card, or
* USB SSD if the entire system will boot from external storage

### Content Drive

Used for:

* Kiwix ZIM files
* Wikipedia
* Offline maps
* Medical references
* Emergency-preparedness documents
* Repair manuals
* E-books
* User-supplied movies, television programs, music, and audiobooks
* Personal reference material

Planned device:

* USB 3 external SSD
* Initial target capacity: 1–2 TB
* Final size to be determined after creating the content plan

### Planned Content-Drive Structure

```text
/srv/offgridpi/content/
├── kiwix/
├── documents/
├── maps/
└── media/
    ├── movies/
    ├── television/
    ├── family/
    ├── kids/
    ├── music/
    └── audiobooks/
```

The final external drive may be mounted elsewhere and linked or mounted into `/srv/offgridpi/content`. Emergency-reference content must retain priority over entertainment media. The project should document reserved capacity for knowledge content before a large media library is added.

### Media-Playback Storage Requirements

The storage device selected for media playback should be tested for:

* Reliable USB 3 connectivity
* Automatic mounting after restart
* Sustained playback without disconnects
* Adequate free space for future knowledge-library growth
* Compatibility with Kodi and VLC
* Acceptable power draw when used with the Raspberry Pi, display, and cooling fan

Initial media testing may use an available USB drive. Final media-drive selection will be completed during the storage-architecture phase.

## Power Requirements

The build should use a reliable Raspberry Pi-compatible power supply.

The final build may also include:

* Uninterruptible power supply
* Raspberry Pi UPS HAT
* Portable power station
* 12-volt vehicle power adapter
* Solar charging equipment

The following backup-power equipment is already available for later testing:

* EcoFlow RIVER 2 as the primary off-grid power source
* Renogy 200-watt folding solar panel for charging the EcoFlow
* Voltaic V72 as the secondary backup battery
* Voltaic Arc 20W solar panel for charging the V72

Development, imaging, package installation, and early media testing will use stable wall power. Runtime, solar charging, and reduced-power testing remain deferred until the software and storage configuration are stable.

## Cooling

Because the Raspberry Pi may run for extended periods while serving content or indexing files, active or passive cooling should be installed.

Possible options include:

* Case with integrated fan
* Large passive heatsink case
* Standard heatsinks with a small fan

The selected cooling system should remain serviceable and should not require internet access to manage.

## Network Design

The initial build will support:

* Direct use through an attached monitor, keyboard, and mouse
* Wired Ethernet during installation and content downloads
* Local access from computers, tablets, and phones
* Optional Wi-Fi access point for use without a router or internet connection

Internet access will be used during the initial installation and content-download process. The completed system should remain usable without an internet connection.

## Initial Build Target

The initial prototype will use:

* Raspberry Pi 4
* Raspberry Pi OS 64-bit with Desktop
* Separate operating-system and content storage
* USB 3 SSD for the offline library
* Directly attached monitor
* Ethernet during initial setup
* Optional local Wi-Fi access after core functionality is tested

## Information Still Needed

Before installing the operating system, confirm:

* Raspberry Pi memory capacity
* Available microSD cards
* Available USB SSDs or hard drives
* Power-supply specifications
* Case and cooling configuration
* Monitor connection type
* Whether Wi-Fi hotspot capability is required
* Desired content-storage capacity
* USB-drive model, capacity, file system, and power requirements

## Hardware Inventory Notes

Use this section to record model numbers, serial numbers, purchase dates, or other useful details.

### Raspberry Pi

* Model: Raspberry Pi 4 Model B
* RAM:
* Serial number:
* Case: Miuzei Raspberry Pi 4 case
* Cooling: Integrated fan and heatsinks

### Operating-System Storage

* Manufacturer:
* Model:
* Capacity:
* Type:
* Condition:

### Content Storage

* Manufacturer:
* Model:
* Capacity:
* Connection type:
* File system:
* Condition:

### Development Power Supply

* Manufacturer:
* Model:
* Rated output: 5V 3A
* Connector: USB-C
* Condition:

### Off-Grid Power Equipment

* Primary battery: EcoFlow RIVER 2
* Primary solar panel: Renogy 200-watt folding panel
* Secondary battery: Voltaic V72
* Secondary solar panel: Voltaic Arc 20W
* Integration-test status: Deferred

### Display and Peripherals

* Monitor: GeeekPi 10.1-inch HDMI display
* Resolution: 1024 × 600
* Video cable or adapter: Micro-HDMI-to-HDMI cable
* Keyboard: USB keyboard
* Mouse: USB mouse

## Revision History

| Date          | Change                             |
| ------------- | ---------------------------------- |
| July 29, 2026 | Created initial hardware inventory |
| July 30, 2026 | Added confirmed hardware, off-grid power equipment, and media-storage requirements |
