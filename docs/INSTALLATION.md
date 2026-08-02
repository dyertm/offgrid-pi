# Offgrid Pi Installation Guide

**Document status:** Working prototype procedure  
**Validation status:** Raspberry Pi foundation, Kiwix, dashboard, reboot, local-network, and offline tests completed on the development Raspberry Pi. Document-library and full installer steps remain in development.

## 1. Validated development target

* Raspberry Pi 4B, 4 GB RAM
* Raspberry Pi OS 64-bit Desktop based on Debian 13 Trixie
* 64 GB microSD card or larger recommended
* Raspberry Pi-compatible 5V 3A USB-C power supply
* Fan-cooled case
* HDMI display, keyboard, and mouse
* Wi-Fi or Ethernet during installation

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

## 4. Install foundational tools

```bash
sudo apt install -y git curl wget rsync
```

## 5. Create standard directories

```bash
sudo install -d -o piadmin -g piadmin -m 0755 /srv/offgridpi/content/kiwix
sudo install -d -o root -g root -m 0755 /opt/offgridpi/dashboard
sudo install -d -o root -g root -m 0755 /opt/offgridpi/scripts
sudo install -d -o root -g root -m 0755 /opt/offgridpi/config
sudo install -d -o root -g root -m 0755 /opt/offgridpi/tools
sudo install -d -o root -g root -m 0755 /srv/offgridpi/indexes
sudo install -d -o root -g root -m 0755 /srv/offgridpi/logs
sudo install -d -o root -g root -m 0755 /srv/offgridpi/backups
```

The `piadmin` username reflects the development system. The future installer must use the actual configured administrator account rather than hardcoding it.

## 6. Install Kiwix

```bash
sudo apt update
sudo apt install -y kiwix-tools zim-tools
```

Record versions:

```bash
kiwix-serve --version
zimcheck --version
```

The development prototype recorded:

* `kiwix-tools` 3.7.0
* `zim-tools` 3.5.0

## 7. Add a small test ZIM

Place a small test archive in:

```text
/srv/offgridpi/content/kiwix
```

Record the filename, source, download date, size, license, and checksum.

Example checksum command:

```bash
sha256sum /srv/offgridpi/content/kiwix/example.zim
```

Do not assume that a checksum or validator result alone proves functional compatibility. Test the archive through the installed Kiwix version.

## 8. Test Kiwix manually

```bash
cd /srv/offgridpi/content/kiwix
kiwix-serve --port=8080 example.zim
```

The installed Kiwix 3.7.0 prototype did not accept the initially attempted `--address=0.0.0.0` option. Omitting it allowed Kiwix to listen on the available interfaces.

Test:

* `http://localhost:8080`
* `http://offgridpi.local:8080`

## 9. Create the service account

```bash
sudo useradd \
  --system \
  --home-dir /nonexistent \
  --shell /usr/sbin/nologin \
  offgridpi
```

Skip this command if the account already exists.

## 10. Create `kiwix-serve.service`

Create `/etc/systemd/system/kiwix-serve.service`:

```ini
[Unit]
Description=Offgrid Pi Kiwix Server
After=local-fs.target
RequiresMountsFor=/srv/offgridpi/content/kiwix

[Service]
Type=simple
User=offgridpi
Group=offgridpi
ExecStart=/usr/bin/kiwix-serve --port=8080 /srv/offgridpi/content/kiwix/example.zim
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict

[Install]
WantedBy=multi-user.target
```

Replace `example.zim` with the installed filename.

Validate and enable:

```bash
sudo systemd-analyze verify /etc/systemd/system/kiwix-serve.service
sudo systemctl daemon-reload
sudo systemctl enable --now kiwix-serve.service
sudo systemctl status kiwix-serve.service --no-pager
```

## 11. Install the dashboard files

Copy the project dashboard into:

```text
/opt/offgridpi/dashboard
```

Expected prototype structure:

```text
/opt/offgridpi/dashboard/
├── index.html
├── css/
│   └── styles.css
└── js/
    └── app.js
```

All required assets must be local.

## 12. Create `offgridpi-dashboard.service`

Create `/etc/systemd/system/offgridpi-dashboard.service`:

```ini
[Unit]
Description=Offgrid Pi Dashboard
After=local-fs.target
ConditionPathExists=/opt/offgridpi/dashboard/index.html

[Service]
Type=simple
User=offgridpi
Group=offgridpi
WorkingDirectory=/opt/offgridpi/dashboard
ExecStart=/usr/bin/python3 -m http.server 8081 --directory /opt/offgridpi/dashboard
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadOnlyPaths=/opt/offgridpi/dashboard

[Install]
WantedBy=multi-user.target
```

Enable it:

```bash
sudo systemd-analyze verify /etc/systemd/system/offgridpi-dashboard.service
sudo systemctl daemon-reload
sudo systemctl enable --now offgridpi-dashboard.service
sudo systemctl status offgridpi-dashboard.service --no-pager
```

## 13. Configure Chromium automatic launch

The validated prototype uses:

```text
/opt/offgridpi/scripts/launch-dashboard.sh
/home/piadmin/.config/autostart/offgridpi-dashboard.desktop
```

The launcher should:

* Wait until `http://127.0.0.1:8081/` answers
* Avoid duplicate dashboard windows
* Open Chromium maximized
* Disable first-run and default-browser prompts
* Preserve normal desktop access

Manual full-screen mode may be used during development. Kiosk mode remains a later configurable option.

## 14. Verify services

```bash
systemctl is-enabled kiwix-serve.service
systemctl is-active kiwix-serve.service
systemctl is-enabled offgridpi-dashboard.service
systemctl is-active offgridpi-dashboard.service
ss -ltn | grep -E ':8080|:8081'
```

## 15. Verify offline operation

From the attached Raspberry Pi session:

```bash
sudo nmcli networking off
```

Confirm:

* Dashboard loads at `http://127.0.0.1:8081`
* Kiwix loads at `http://localhost:8080`
* Search and navigation work
* No required dashboard assets depend on the internet

Restore networking:

```bash
sudo nmcli networking on
nmcli general status
```

## 16. Install the public document library

The validated document model uses:

```text
/srv/offgridpi/content/documents/public
/srv/offgridpi/content/documents/personal
```

The public root is indexed and served. The personal root must never be used as an index source or web root.

Approved public categories:

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

The Phase 5 installer checkpoint can install this module from the repository root:

```bash
sudo ./install.sh check
sudo ./install.sh install-documents
```

The installer:

* Detects the administrator account rather than hardcoding the development username
* Creates the protected public and personal roots
* Installs the document indexer and watcher
* Renders the indexer service template with the selected administrator account
* Generates the initial catalog
* Enables `offgridpi-document-indexer.service`
* Enables `offgridpi-documents.service` on TCP port `8082`
* Preserves existing user documents

Manual service verification:

```bash
systemctl is-enabled offgridpi-document-indexer.service
systemctl is-active offgridpi-document-indexer.service
systemctl is-enabled offgridpi-documents.service
systemctl is-active offgridpi-documents.service
ss -ltn | grep ':8082'
curl -I http://localhost:8082/
```

The Local Documents dashboard route uses the current browser hostname and redirects to the same host on port `8082`. This supports `localhost`, `offgridpi.local`, and direct IP access without hardcoding one address.

## 17. Run the reusable verification script

From the repository root:

```bash
./tests/verify-installation.sh
```

Or through the installer entry point:

```bash
sudo ./install.sh verify
```

The verifier checks:

* Required files and directories
* Enabled and active services
* TCP ports `8080`, `8081`, and `8082`
* Local HTTP responses
* Document catalog integrity
* Public/private isolation
* Dynamic dashboard document routing
* Failed systemd units
* Chromium presence when a graphical session is active
* Raspberry Pi temperature and throttle state when `vcgencmd` is available

## 18. Verify offline operation

Keep the local router or Wi-Fi network running while disconnecting its internet/WAN connection. Confirm that the following remain available:

```text
http://localhost:8080
http://localhost:8081
http://localhost:8082
```

From another device, use either `offgridpi.local` or the Pi's local IP address. Direct IP access is the fallback when Windows temporarily fails to resolve the `.local` hostname.

## 19. Known prototype limitations

* The dashboard and document library use Python's built-in server and require later release review.
* The current Kiwix service points to a specific ZIM filename rather than a generated library definition.
* `zimcheck` 3.5.0 reported a structural error on tested official archives even though functional Kiwix tests passed.
* The Phase 5 installer currently packages the document module first; Kiwix, dashboard, browser autostart, upgrade, and uninstall modules are still being added.
* Clean-install testing is still required before a release is considered reproducible.
