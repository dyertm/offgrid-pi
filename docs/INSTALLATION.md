# Offgrid Pi Installation Guide

**Document status:** Development installation, verification, and recovery guide
**Reconciled:** September 25, 2026
**Current installer:** `0.7.6`
**Clean-install acceptance baseline:** Installer `0.7.5` passed pristine clean-install acceptance on a separate Raspberry Pi OS 64-bit Desktop installation. That validation included preflight, one-pass `install-all`, independent verification, reboot persistence, Chromium autostart, local-service recovery, and offline-operation testing.

The current `0.7.6` installer extends that validated foundation with later Offgrid Pi components. Run the current verification suite after installation or upgrade rather than assuming an earlier acceptance result covers later changes.

## 1. Validated development target

* Raspberry Pi 4B, 4 GB RAM
* Raspberry Pi OS 64-bit Desktop based on Debian 13 Trixie
* 64 GB microSD card or larger for the current system-storage baseline
* Raspberry Pi-compatible 5V 3A USB-C power supply
* Cooling suitable for sustained Raspberry Pi 4 operation
* Attached display and local keyboard/mouse or equivalent input
* Network connectivity during initial package installation and content acquisition

Offgrid Pi is offline-first and workstation-first. Internet or another client device must not be required for normal use after the required software and content have been installed.

## 2. Image Raspberry Pi OS

In Raspberry Pi Imager, select:

* Device: Raspberry Pi 4
* Operating system: Raspberry Pi OS 64-bit with Raspberry Pi Desktop
* Hostname: `offgridpi`
* Non-default administrative username
* Wi-Fi and locale as appropriate
* SSH enabled for development if desired

Do not store passwords or Wi-Fi credentials in the repository.

## 3. First boot and operating-system update

```bash
sudo apt update
sudo apt full-upgrade -y
sudo reboot
```

Record:

```bash
cat /etc/os-release
uname -a
hostnamectl
free -h
df -h
ip address
vcgencmd measure_temp
vcgencmd get_throttled
systemctl --failed
```

## 4. Obtain the repository and run preflight

Install the basic tools needed to obtain the project:

```bash
sudo apt install -y git curl wget rsync
```

Clone the repository and enter it:

```bash
git clone https://github.com/dyertm/offgrid-pi.git
cd offgrid-pi
```

Before making system changes, run the installer preflight:

```bash
sudo ./install.sh check
```

The installer validates the supported operating system, architecture, Raspberry Pi model, administrator account, required repository payload, and other prerequisites.

If the administrator account cannot be determined automatically, specify it explicitly with `OFFGRIDPI_ADMIN_USER`.

## 5. Install the current Offgrid Pi platform

For a normal development installation, use:

```bash
sudo ./install.sh install-all
```

`install-all` creates a configuration snapshot and installs the currently supported Offgrid Pi modules, including:

* Kiwix
* Dashboard and Chromium autostart
* Public document library and automatic indexing
* System status and protected management components
* Offline Maps
* Owner Mode foundation
* Required services, directories, permissions, scripts, and local application assets

The installer is designed to be rerunnable and to preserve user content.

Individual modules may also be installed or repaired separately:

```bash
sudo ./install.sh install-management
sudo ./install.sh install-documents
sudo ./install.sh install-maps
sudo ./install.sh install-owner
sudo ./install.sh install-dashboard
sudo ./install.sh install-kiwix
```

Use the modular commands primarily for development, troubleshooting, or targeted repair. A normal clean installation should use `install-all`.

## 6. Kiwix installation behavior

Kiwix is installed automatically by `install-all`. To install or repair only the Kiwix module, use:

```bash
sudo ./install.sh install-kiwix
```

The installer:

* Installs `kiwix-tools`, `zim-tools`, and required supporting packages
* Creates and secures `/srv/offgridpi/content/kiwix`
* Installs `/opt/offgridpi/scripts/start-kiwix.sh`
* Installs `kiwix-serve.service`
* Discovers `.zim` files recursively while excluding rejected content
* Verifies that discovered ZIM files are readable by the restricted `offgridpi` service account
* Enables and starts Kiwix on TCP port `8080` when approved ZIM files are available
* Leaves the Kiwix service disabled when no ZIM files are present rather than treating an empty library as an installation failure

Record the installed tool versions when validating a build:

```bash
kiwix-serve --version
zimcheck --version
```

The recorded development baseline includes `kiwix-tools` 3.7.0 and `zim-tools` 3.5.0.

## 7. Add approved Kiwix content

Project-managed Kiwix content should normally be installed through the validated content-pack workflow rather than copied directly into the live library.

From the repository root, the starter-pack workflow is:

```bash
content-packs/validate-manifest.py content-packs/manifests/starter.json
content-packs/content-pack-status.py content-packs/manifests/starter.json
content-packs/content-pack-plan.py content-packs/manifests/starter.json
content-packs/content-pack-stage.py content-packs/manifests/starter.json
sudo content-packs/content-pack-install.py content-packs/manifests/starter.json --confirm
sudo content-packs/content-pack-refresh.py content-packs/manifests/starter.json --confirm
```

The content-pack workflow stages downloads separately, verifies expected size and SHA-256 metadata, refuses silent overwrites, verifies installed content, and refreshes affected services only after validation succeeds.

User-supplied ZIM files may also be placed under `/srv/offgridpi/content/kiwix` when appropriate. Record their source, date, license or usage basis, size, and checksum where practical.

After adding ZIM content outside the content-pack workflow, rerun the Kiwix module or otherwise restart Kiwix only after confirming the files are readable and appropriate for use.

## 8. Verify Kiwix

When approved ZIM content is installed, verify the managed Kiwix service rather than starting a second manual server:

```bash
systemctl is-enabled kiwix-serve.service
systemctl is-active kiwix-serve.service
systemctl status kiwix-serve.service --no-pager
curl --silent --fail --output /dev/null http://127.0.0.1:8080/
```

Also confirm the library from the attached browser:

* `http://localhost:8080`
* `http://offgridpi.local:8080` when local hostname resolution is available
* The Pi's local IP address on another approved device

If no approved ZIM files are installed, an inactive or disabled Kiwix service is expected rather than an installation failure.

## 9. Restricted service account

The installer creates the `offgridpi` system account automatically when required.

Core background services use this restricted account rather than the interactive administrator account wherever practical.

The account:

* Has no normal interactive login shell
* Does not own the operating-system installation
* Receives only the file access required by its installed services
* Is reused by Offgrid Pi services that share the same restricted execution boundary

Do not manually recreate or replace the account during a normal installation. Use the installer to repair missing platform components.

## 10. Kiwix service architecture

The installer places the managed Kiwix launcher at:

```text
/opt/offgridpi/scripts/start-kiwix.sh
```

and installs:

```text
/etc/systemd/system/kiwix-serve.service
```

The systemd service runs as the restricted `offgridpi` user and group and delegates ZIM discovery to `start-kiwix.sh` rather than hardcoding individual archive filenames into the service definition.

The service uses `/srv/offgridpi/content/kiwix` as its content root and listens on TCP port `8080` when approved ZIM content is available.

The installed service also applies systemd hardening controls including restricted home access, a read-only Kiwix content path, private temporary/device handling, and protections against unnecessary kernel or privilege changes.

For the repository version of the service and launcher, treat `systemd/kiwix-serve.service` and `scripts/start-kiwix.sh` as authoritative rather than reproducing their contents manually in this guide.

## 11. Dashboard installation

The dashboard is installed automatically by `install-all`. To install or repair only the dashboard module, use:

```bash
sudo ./install.sh install-dashboard
```

The installer places the dashboard application under:

```text
/opt/offgridpi/dashboard
```

and installs supporting components including:

* `/opt/offgridpi/scripts/offgridpi-dashboard-server.py`
* `/opt/offgridpi/scripts/launch-dashboard.sh`
* The Chromium Kiwix-navigation extension
* The generated offline Legal & Notices content
* `offgridpi-dashboard.service`
* The administrator user's desktop autostart entry

Dashboard assets are local and must not depend on internet-hosted CSS, JavaScript, fonts, or other required resources.

## 12. Dashboard service architecture

The dashboard is served on TCP port `8081` by the dedicated Offgrid Pi dashboard server:

```text
/opt/offgridpi/scripts/offgridpi-dashboard-server.py
```

The corresponding systemd unit is:

```text
/etc/systemd/system/offgridpi-dashboard.service
```

The service runs as the restricted `offgridpi` user and group with `/opt/offgridpi/dashboard` as its working directory.

The dedicated server replaces the earlier prototype use of `python3 -m http.server` and provides explicit cache-control and basic response-security headers while remaining lightweight.

Treat `systemd/offgridpi-dashboard.service` and `scripts/offgridpi-dashboard-server.py` in the repository as authoritative rather than reproducing the service definition manually.

## 13. Chromium kiosk launch

The installer configures the administrator's graphical session to launch:

```text
/opt/offgridpi/scripts/launch-dashboard.sh
```

The launcher:

* Waits for `http://127.0.0.1:8081/` to become available
* Avoids opening a duplicate dashboard window
* Starts Chromium using the Wayland backend
* Uses Chromium kiosk mode for the normal appliance interface
* Disables first-run, default-browser, and session-crash prompts
* Loads the local Kiwix-navigation extension
* Records launch output under the administrator user's local state directory

The underlying Raspberry Pi OS desktop remains available for development and troubleshooting even though the normal Offgrid Pi experience launches into kiosk mode.

## 14. Verify installed services

After installation, run the repository verifier:

```bash
sudo ./install.sh verify
```

For a quick manual service check:

```bash
systemctl is-active offgridpi-dashboard.service
systemctl is-active offgridpi-document-indexer.service
systemctl is-active offgridpi-documents.service
systemctl is-active offgridpi-management.service
systemctl is-active offgridpi-maps.service
systemctl is-active offgridpi-owner.service
ss -ltn | grep -E ':8080|:8081|:8082|:8083|:8084|:8085'
```

Expected service boundaries:

* `8080` — Kiwix, when approved ZIM content is installed
* `8081` — public dashboard
* `8082` — public document library
* `127.0.0.1:8083` — protected read-only management viewer
* `8084` — Offline Maps reader
* `127.0.0.1:8085` — Owner Mode foundation

An inactive or disabled `kiwix-serve.service` is expected when no approved ZIM files are installed.

The management and Owner Mode services must remain bound to localhost rather than listening on all network interfaces.

## 15. Verify direct offline operation

The attached Raspberry Pi must remain useful without network connectivity.

For a controlled direct-use test, disable networking from the attached Pi session:

```bash
sudo nmcli networking off
```

Confirm locally:

* Dashboard loads at `http://127.0.0.1:8081/`
* Public Documents loads at `http://127.0.0.1:8082/`
* Offline Maps loads at `http://127.0.0.1:8084/`
* Installed Kiwix content loads at `http://127.0.0.1:8080/` when approved ZIM files are present
* Navigation between installed local functions does not require internet-hosted assets
* The attached display and local input remain sufficient for normal appliance use

Restore networking after the test:

```bash
sudo nmcli networking on
nmcli general status
```

A separate later check should validate local-network client access while the LAN remains available but its internet/WAN connection is unavailable.

## 16. Public and private document libraries

The document module is installed automatically by `install-all`. To install or repair it separately, use:

```bash
sudo ./install.sh install-documents
```

The validated document-storage model uses:

```text
/srv/offgridpi/content/documents/public
/srv/offgridpi/content/documents/personal
```

The public root is indexed and served on TCP port `8082`. The personal root must remain unserved and excluded from the public catalog.

Current public categories are:

```text
emergency
first-aid
food
gardening
communications
radio
repair
equipment-manuals
education
books
faith
```

The installer:

* Detects the administrator account rather than hardcoding the development username
* Creates the public and personal roots with separate permissions
* Installs the document indexer and recursive inotify watcher
* Generates the initial public catalog
* Enables `offgridpi-document-indexer.service`
* Enables `offgridpi-documents.service` on TCP port `8082`
* Preserves existing user documents during normal reinstall or repair operations

Manual verification:

```bash
systemctl is-enabled offgridpi-document-indexer.service
systemctl is-active offgridpi-document-indexer.service
systemctl is-enabled offgridpi-documents.service
systemctl is-active offgridpi-documents.service
curl -I http://127.0.0.1:8082/
```

The Local Documents dashboard route uses the current browser hostname and redirects to the same host on port `8082`, supporting localhost, `offgridpi.local`, and direct-IP access without hardcoding one address.

## 17. Run the reusable verification suite

From the repository root:

```bash
./tests/verify-installation.sh
```

Or through the installer entry point:

```bash
sudo ./install.sh verify
```

The current verifier covers:

* Platform compatibility and required installed paths
* Enabled and active Offgrid Pi services
* Expected network listeners across TCP ports `8080` through `8085`, with service-specific binding rules
* Local HTTP responses
* Offline Maps reader behavior and security checks
* Kiwix content and service state
* Public document catalog integrity and public/private isolation
* Dashboard integration
* Legal & Notices generation and installed-component records
* Configuration-backup and installation-management components
* Protected administration preview behavior
* Dashboard system-status publication
* Protected system-log publication
* Localhost-only management viewer behavior
* Owner Mode foundation and localhost-only exposure
* Failed systemd units
* Chromium presence when a graphical session is active
* Raspberry Pi temperature and throttle state when `vcgencmd` is available

A successful verification run should finish with zero required-check failures. Review items should still be investigated rather than ignored automatically.

## 18. Verify local-network operation without internet

Keep the local router or Wi-Fi network running while disconnecting its internet/WAN connection.

From the attached Raspberry Pi, confirm that the normal local services remain available.

From another approved device on the same LAN, confirm:

```text
http://offgridpi.local:8081
http://offgridpi.local:8082
http://offgridpi.local:8084
```

Kiwix should also remain available on port `8080` when approved ZIM content is installed.

If `.local` hostname resolution is unavailable, use the Raspberry Pi's local IP address instead.

The protected management viewer on `127.0.0.1:8083` and Owner Mode foundation on `127.0.0.1:8085` must not become LAN-accessible during this test.

This test confirms that local-network clients can use approved Offgrid Pi services without an upstream internet connection while preserving the workstation-first model.

## 19. Configuration backup, rollback, and uninstall

The installer includes configuration-management tools intended to support development upgrades and recovery without copying or deleting user content.

Create a configuration snapshot:

```bash
sudo ./install.sh backup-config
```

List available snapshots:

```bash
sudo ./install.sh list-backups
```

Restore the newest snapshot:

```bash
sudo ./install.sh rollback-config latest --confirm
```

A specific listed snapshot may be supplied in place of `latest`.

Configuration snapshots are stored under:

```text
/srv/offgridpi/backups/configuration
```

These snapshots preserve managed Offgrid Pi configuration and service state but deliberately do not copy `/srv/offgridpi/content`. They are therefore not a substitute for the broader user-content backup and restore architecture planned for a later phase.

Preview an uninstall before making changes:

```bash
sudo ./install.sh uninstall --dry-run
```

Perform the uninstall only after reviewing the preview:

```bash
sudo ./install.sh uninstall --confirm
```

The current uninstall workflow preserves user content, Offgrid Pi backups, the source repository, installed operating-system packages, and the `offgridpi` service account.

After a rollback, repair, or reinstall, run `sudo ./install.sh verify` before treating the system as healthy.

## 20. Current development limitations and release gaps

* `zimcheck` 3.5.0 reported a structural error on some tested official archives even when functional Kiwix serving tests passed. Functional acceptance should therefore accompany validator results.
* Kiwix remains intentionally disabled when no approved ZIM files are present; content can be added later without reinstalling the platform.
* Installer `0.7.5` is the pristine clean-install acceptance baseline. Installer `0.7.6` extends that foundation with later components and should be validated with the current verification suite after installation or upgrade.
* Unified Offline Search is not yet implemented; it is the next planned development phase.
* The Owner Mode service currently provides the localhost-only security and storage foundation. Full graphical Owner workflows remain later work.
* External USB SSD bulk-content migration and graphical content-management workflows remain planned for a later phase.
* Full user-content backup and restore, encrypted private-data handling, appliance first-run UX, release-image production, final hardware qualification, thermal/endurance testing, and production burn-in remain future release work.
* Clean-install and regression testing demonstrate the current development architecture, but they do not yet constitute final commercial-release qualification.
