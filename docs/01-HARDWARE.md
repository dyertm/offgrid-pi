# Hardware Inventory

This document records the hardware used for the initial Offgrid Pi build.

Keeping an accurate inventory will make the build easier to reproduce, troubleshoot, upgrade, and share with others.

## Core Hardware

| Component                | Current Hardware       | Status                      |
| ------------------------ | ---------------------- | --------------------------- |
| Single-board computer    | Raspberry Pi 4 Model B | Available                   |
| Installed memory         | To be confirmed        | Check before installation   |
| Operating-system storage | To be selected         | Needed                      |
| Offline-content storage  | To be selected         | Needed                      |
| Power supply             | To be confirmed        | Check wattage and condition |
| Case                     | To be confirmed        | Available or needed         |
| Cooling                  | To be confirmed        | Recommended                 |
| Monitor                  | Existing monitor       | Available                   |
| Keyboard                 | To be confirmed        | Available or needed         |
| Mouse                    | To be confirmed        | Available or needed         |
| Network cable            | To be confirmed        | Recommended during setup    |

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
* Videos
* Personal reference material

Planned device:

* USB 3 external SSD
* Initial target capacity: 1–2 TB
* Final size to be determined after creating the content plan

## Power Requirements

The build should use a reliable Raspberry Pi-compatible power supply.

The final build may also include:

* Uninterruptible power supply
* Raspberry Pi UPS HAT
* Portable power station
* 12-volt vehicle power adapter
* Solar charging equipment

Backup-power equipment is optional for the first build but should be evaluated before relying on Offgrid Pi during an emergency.

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
* Available backup-power equipment

## Hardware Inventory Notes

Use this section to record model numbers, serial numbers, purchase dates, or other useful details.

### Raspberry Pi

* Model: Raspberry Pi 4 Model B
* RAM:
* Serial number:
* Case:
* Cooling:

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

### Power Supply

* Manufacturer:
* Model:
* Rated output:
* Connector:
* Condition:

### Display and Peripherals

* Monitor:
* Video cable or adapter:
* Keyboard:
* Mouse:

## Revision History

| Date          | Change                             |
| ------------- | ---------------------------------- |
| July 29, 2026 | Created initial hardware inventory |
