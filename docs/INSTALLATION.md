Offgrid Pi Installation Guide
Document status

Status: Initial draft
Validation status: Not yet tested on the development Raspberry Pi

This guide describes the planned installation process. Commands and package names must be validated during the first build before this document is treated as a release-ready procedure.

1. Installation goal

At the end of the installation, the Raspberry Pi should:

Boot into Raspberry Pi OS
Connect to the local network
Run the Offgrid Pi services automatically
Serve at least one Kiwix library
Display the Offgrid Pi dashboard locally
Allow browser access from other devices on the same network
Continue providing installed content without internet access
Optionally launch Kodi and play locally stored media without internet access
2. Required hardware
Raspberry Pi 4B
Raspberry Pi-compatible 5V 3A USB-C power supply
Fan-cooled Raspberry Pi case
MicroSD card
MicroSD card reader
HDMI display
Micro-HDMI-to-HDMI cable
USB keyboard
USB mouse
Ethernet or Wi-Fi connection
Windows, macOS, or Linux computer for imaging the microSD card
Optional USB storage device for media-module testing
3. Recommended microSD card

For development:

32 GB minimum
64 GB or 128 GB recommended
Class 10 or better
A card that may be completely erased

Back up any existing files before beginning.

4. Download Raspberry Pi Imager

Install Raspberry Pi Imager on the computer that will be used to prepare the microSD card.

Record the following information in BUILD_LOG.md:

Imager version
Installation computer
MicroSD-card brand
MicroSD-card capacity
Card reader used
5. Select the operating system

In Raspberry Pi Imager, select:

Device: Raspberry Pi 4
Operating system: Raspberry Pi OS 64-bit with Desktop
Storage: Selected development microSD card

Do not continue until the correct storage device has been confirmed. The selected device will be erased.

6. Configure imaging options

The following values should be selected and documented.

Hostname

Recommended development hostname:

offgridpi

The expected local hostname may become:

offgridpi.local

Hostname resolution depends on the client device and local network.

Username

Use a non-default administrative username.

Do not publish the password in GitHub, screenshots, documentation, or logs.

Password

Use a unique development password.

The password may be changed before public demonstrations or release testing.

Wireless network

Wi-Fi may be configured in Raspberry Pi Imager for development convenience.

Record:

Whether Wi-Fi was configured
Wireless country
Network type
Whether Ethernet will also be used

Do not record the Wi-Fi password in the repository.

Locale

Configure:

Time zone
Keyboard layout
Language
Wireless country
SSH

SSH may be enabled for development.

Password authentication may be used during initial setup, but SSH keys should be considered for later development.

Document whether SSH is enabled.

7. Write the image

Begin the imaging process.

Allow Raspberry Pi Imager to:

Erase the card
Write the operating-system image
Verify the written data

Record the result in BUILD_LOG.md.

Do not remove the card until Raspberry Pi Imager reports that the operation is complete.

8. Assemble the development system

With power disconnected:

Insert the microSD card.
Connect the cooling fan if not already connected.
Connect the monitor.
Connect the keyboard.
Connect the mouse.
Connect Ethernet if being used.
Confirm that all components are secure.
Connect the power supply last.
9. Complete the first boot

Confirm:

The Raspberry Pi powers on.
The fan operates.
The monitor displays the boot process.
The desktop loads.
The keyboard works.
The mouse works.
The display resolution is usable.
The network connection is active.
The configured hostname is correct.

Record any errors or warnings in BUILD_LOG.md.

10. Update Raspberry Pi OS

Open a terminal and run:

sudo apt update
sudo apt full-upgrade -y
sudo reboot

After the reboot, confirm that the desktop loads successfully.

Record the operating-system information:

cat /etc/os-release
uname -a
hostnamectl

Record storage and memory information:

free -h
df -h

Record network information:

ip address

Do not publish public IP addresses, passwords, or other sensitive network details.

11. Install foundational tools

The exact package list will be validated during development.

The expected foundational packages include:

sudo apt install -y git curl wget rsync

Additional packages will be added only as required.

12. Obtain the Offgrid Pi repository

The final command will resemble:

git clone https://github.com/REPLACE-WITH-OWNER/offgrid-pi.git
cd offgrid-pi

During early development, the repository may be created locally before it is cloned from GitHub.

13. Create the directory structure

The installer will eventually create these directories automatically.

Proposed application directories:

sudo mkdir -p /opt/offgridpi/dashboard
sudo mkdir -p /opt/offgridpi/scripts
sudo mkdir -p /opt/offgridpi/config
sudo mkdir -p /opt/offgridpi/tools

Proposed content directories:

sudo mkdir -p /srv/offgridpi/content/kiwix
sudo mkdir -p /srv/offgridpi/content/documents
sudo mkdir -p /srv/offgridpi/content/maps
sudo mkdir -p /srv/offgridpi/content/media/movies
sudo mkdir -p /srv/offgridpi/content/media/television
sudo mkdir -p /srv/offgridpi/content/media/family
sudo mkdir -p /srv/offgridpi/content/media/kids
sudo mkdir -p /srv/offgridpi/content/media/music
sudo mkdir -p /srv/offgridpi/content/media/audiobooks
sudo mkdir -p /srv/offgridpi/indexes
sudo mkdir -p /srv/offgridpi/logs
sudo mkdir -p /srv/offgridpi/backups

Ownership and permissions will be determined during the first build.

Do not apply broad write permissions such as chmod 777.

14. Install Kiwix

The exact installation method must be validated.

Possible methods include:

Raspberry Pi OS package repository
Official Kiwix binary
A project-maintained installation script

The selected method must:

Support the Raspberry Pi’s architecture
Support multiple ZIM files
Run without internet access after installation
Be manageable through systemd
Be reproducible through the installer

The validated commands will replace this section.

15. Add a test ZIM file

Download one relatively small ZIM file for the first test.

Place it in:

/srv/offgridpi/content/kiwix

Record:

ZIM title
Source
Filename
File size
Download date
License
Checksum when available

Large Wikipedia files should not be required for the first software test.

16. Test Kiwix manually

Before creating a service, start Kiwix manually and confirm:

The process starts.
The test library appears.
The library opens in the local browser.
Search functions operate.
The service can be reached through the Raspberry Pi’s local IP address.
The content remains available after the internet connection is removed.

The exact command and port will be added after validation.

17. Create the Kiwix service

After manual testing succeeds, create:

/etc/systemd/system/kiwix-serve.service

The service should:

Start after the required file systems and network components
Run under a limited account where practical
Load the configured ZIM files
Restart after recoverable failures
Write useful logs
Start automatically after boot

After creating the service:

sudo systemctl daemon-reload
sudo systemctl enable kiwix-serve.service
sudo systemctl start kiwix-serve.service
sudo systemctl status kiwix-serve.service

The final service definition will be stored in the GitHub repository.

18. Install the dashboard

The dashboard files will be installed under:

/opt/offgridpi/dashboard

The initial dashboard should include:

Project title
Kiwix link
Document-library link
Placeholder map link
Optional offline-entertainment launcher
System-status link
Administration link
Project version

The dashboard should be readable on the 1024 × 600 development display.

19. Install the optional offline media module

Status: Planned and not yet validated

The offline media module is optional. It should be installed only after the Raspberry Pi desktop, storage paths, and dashboard are functioning reliably.

The planned applications are:

Kodi as the primary media-library and playback interface
VLC as a fallback player for individual media files

The exact package names and installation commands must be validated on the selected Raspberry Pi OS release before they are treated as release-ready instructions. Record the package versions and installation results in BUILD_LOG.md.

Media should be stored outside the operating-system microSD card whenever practical. An available USB drive may be used for initial testing, but final drive selection and capacity allocation belong to the storage-architecture phase.

The initial directory structure is:

/srv/offgridpi/content/media/movies
/srv/offgridpi/content/media/television
/srv/offgridpi/content/media/family
/srv/offgridpi/content/media/kids
/srv/offgridpi/content/media/music
/srv/offgridpi/content/media/audiobooks

The installation and configuration process should eventually:

Install Kodi and VLC.
Add the approved media directories as local sources.
Avoid requiring cloud accounts or streaming services.
Retain permitted metadata and artwork locally when practical.
Add a dashboard or desktop launcher for Kodi.
Preserve access to the normal Raspberry Pi desktop.
Return cleanly to the dashboard or desktop when Kodi closes.
Avoid exposing personal media through the local web dashboard by default.

Initial validation should include:

MP4 and MKV containers
H.264 video at 720p and 1080p
AAC stereo audio
SRT subtitles
VLC fallback playback
Operation with internet access disconnected
Restart and automatic-mount behavior
Temperature, undervoltage, drive stability, and playback reliability

Only user-supplied, legally obtained media should be added. Media files, library databases containing private information, and copyrighted artwork must not be committed to the public repository.

20. Configure dashboard hosting

The final hosting method has not yet been selected.

Possible options include:

A small Python web server
Nginx
Lighttpd
Another lightweight local web server

The selected method should be:

Lightweight
Available through standard packages
Easy to configure
Able to start automatically
Suitable for local-network access
Maintainable by the project
21. Configure automatic dashboard launch

After login, the local browser should open the Offgrid Pi dashboard automatically.

The final implementation may use:

Desktop autostart configuration
Kiosk mode
A normal browser window
A project launcher application

The first version should preserve access to the normal desktop for troubleshooting.

22. Verify local access

Test from the Raspberry Pi:

http://localhost

or the final configured dashboard port.

Test the Kiwix service through its configured local address.

23. Verify network access

From another device on the same network, test:

http://offgridpi.local

If that does not resolve, use the Raspberry Pi’s local IP address.

Confirm that:

The dashboard opens.
Kiwix opens.
Installed content can be searched.
Administrative actions are not exposed without appropriate controls.
24. Verify offline operation

Disconnect the Raspberry Pi from the internet while leaving the local system running.

Confirm that:

The dashboard loads.
Kiwix content loads.
Search works.
Local documents open.
Kodi and VLC play local test media when the optional module is installed.
The browser does not depend on remote fonts, scripts, icons, or analytics.
Services restart successfully without internet access.
25. Run the health check

The future health-check script should verify:

Supported operating system
Required directories
Required packages
Required services
Service status
Dashboard availability
Kiwix availability
Installed content
Available storage
File permissions
System temperature
Network addresses
Recent errors
Optional Kodi and VLC package status
Optional media-drive mount status and available space

Planned command:

sudo ./scripts/check-system.sh
26. Installation completion criteria

The installation is considered successful when:

The Raspberry Pi boots normally.
The dashboard opens.
Kiwix starts automatically.
At least one test ZIM file is available.
Local documents can be opened.
Another device can reach the dashboard.
The system works without internet access.
All commands and deviations are recorded.
No passwords or personal information have been committed to GitHub.
When installed, the optional media module plays a local test file without internet access.
27. Uninstallation

An uninstall script will be created after the first working installation.

It should:

Stop and disable Offgrid Pi services
Remove application files
Preserve user content and media by default
Offer an explicit option to remove content
Remove created service definitions
Restore modified autostart settings
Record what was removed

The uninstall process must not delete user content without clear confirmation.
