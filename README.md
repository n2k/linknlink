# LinknLink iSG Research

Research into the LinknLink iSG (Android tablet/wall-mounted smart screen) system image, with the goal of creating a minimal kiosk browser setup.

## Contents of This Repo

```
README.md                       — Findings and analysis
scripts/
  cleanup-adb.sh                — Android-side cleanup via ADB (run from host)
  cleanup-termux.sh             — Termux-side cleanup (run via SSH on device)
  setup-kiosk.sh                — Kiosk browser setup via ADB (run from host)
```

## Source Files (not committed)

| File | Size | Description |
|------|------|-------------|
| `image_20251212_143315_*.tar.gz` | ~2.5 GB | iSG system image (Termux userland snapshot) |
| `20167_global_1224.apk` | ~243 MB | iSG homescreen/launcher app |

---

## Live Device Hardware

| Property | Value |
|----------|-------|
| Model | CPF1056 |
| SoC | **Allwinner Ceres** (sun50iw10p1) |
| CPU | 4x ARM Cortex-A53 (ARMv8, 48 BogoMIPS each) |
| RAM | 3,923 MB (~4 GB) |
| Storage | 20 GB eMMC (mmcblk0), 23 GB /data partition |
| Display | 1280x800, 160 DPI (landscape) |
| Android | 10 (API 29) |
| ADB | Wireless on port 5555 (persisted via `persist.adb.tcp.port`) |

### Allwinner Ceres Notes

The Allwinner "Ceres" (sun50iw10p1) is a relatively obscure Allwinner SoC. Allwinner chips generally have decent mainline Linux support through the sunxi community, though this specific variant may require more research. Key resources:
- [linux-sunxi wiki](https://linux-sunxi.org/)
- Kernel support status varies by exact chip variant

---

## Homescreen APK Analysis

| Property | Value |
|----------|-------|
| Package | `com.linknlink.app.device.isg` |
| Version | `20.167.251224_global` (code: 20167) |
| Target SDK | Android 11 (API 30) |
| Min SDK | Android 8.0 (API 26) |
| Architecture | arm64-v8a, armeabi-v7a |
| Base SDK | Broadlink (`cn.com.broadlink.unify.app`) |
| Launcher Activity | `cn.com.broadlink.unify.app.activity.common.LoadingActivity` |

### Hardware Features Used

- `android.hardware.type.television` — Confirms wall-mounted screen form factor
- `android.hardware.screen.landscape` — Landscape-only display
- `android.hardware.bluetooth_le` — BLE for device pairing
- `android.hardware.usb.host` — USB host for Zigbee/Z-Wave dongles
- `android.hardware.camera` — Camera support
- `android.software.leanback` — Android TV interface
- IR transmitter (`TRANSMIT_IR` permission)
- NFC support

### Key Permissions

- `com.termux.permission.RUN_COMMAND` — Direct control of Termux from the app
- `android.permission.FORCE_STOP_PACKAGES` — Can kill other apps
- `android.permission.RECEIVE_BOOT_COMPLETED` — Auto-starts on boot
- `android.permission.SYSTEM_ALERT_WINDOW` — Overlay permissions
- `android.permission.DISABLE_KEYGUARD` — Can dismiss lock screen

---

## System Image Analysis

### What It Is

The system image is **not** a traditional Android system image (no `boot.img`, `system.img`, etc.). It is a **Termux userland filesystem snapshot** — a tarball of the `/data/data/com.termux/files/` directory containing **465,519 files** (~2.5 GB compressed).

### Top-Level Structure

```
files/
├── apps/          # Termux app internals
├── home/          # Home directory (servicemanager scripts, configs)
└── usr/           # Termux prefix (binaries, libs, services, proot Ubuntu)
```

### Architecture Stack

```
Android OS (stock, aarch64)
  └── Termux (terminal emulator app)
       ├── runit (service supervisor)
       ├── proot-distro Ubuntu (full rootfs — 397K of 465K files, ~85% of image)
       │    └── Home Assistant (Python virtualenv)
       ├── Mosquitto (MQTT broker)
       ├── MariaDB (database)
       ├── Zigbee2MQTT / Z-Wave JS UI
       ├── Node-RED
       ├── Matter server + bridge
       ├── ~15 proprietary LinknLink Go binaries
       └── Full C/C++ toolchain (Clang 20, CMake, etc.)
  └── LinknLink Homescreen APK (launcher app)
```

All cloud connectivity goes through `euhome.linklinkiot.com`.

---

## Runit Services (19 active)

| Service | Purpose |
|---------|---------|
| `hass` | Home Assistant (runs inside proot Ubuntu) |
| `mosquitto` | MQTT broker |
| `node-red` | Node-RED automation |
| `zigbee2mqtt` | Zigbee gateway |
| `zwave-js-ui` | Z-Wave gateway |
| `matter-server` | Matter protocol server |
| `matter-bridge` | Matter bridge |
| `frpc` | FRP reverse proxy client (remote access) |
| `isgaddonmanager` | LinknLink addon manager (HTTP :54328) |
| `isgdevicemanager` | LinknLink device manager (HTTP :1688) |
| `isgdatamanager` | Data recording service |
| `isgspacemanager` | Spatial intelligence service |
| `isgtrigger` | Trigger/automation service |
| `isgdida` | Timer service |
| `isgelecstat` | Energy management |
| `isg-credential-services` | Authentication service |
| `isg-adb-server` | ADB server |
| `messageproxy` | Message proxy |
| `ssh-agent` | SSH agent |

Additional services managed by `termuxservice` (outside main runit):
- `mysqld` (MariaDB)
- `sshd` (SSH server, port 8022)
- `isgservicemonitor` (service health monitoring)

---

## Addon System

The iSG has a plugin/addon architecture managed by `isgaddonmanager`. Addons are installed via shell scripts downloaded from the cloud. Known addons:

| Addon | Built-in | Status | Port |
|-------|----------|--------|------|
| Home Assistant Server | Yes | Installed | :8123 |
| MQTT Broker (Mosquitto) | Yes | Running | :1883 |
| Zigbee2MQTT | Yes | Installed | :8080 |
| ZWave-JS-UI | Yes | Installed | :8091 |
| MariaDB | Yes | Running | :3306 |
| System Monitor | Yes | Running | :54328/web |
| Node-RED | No | Available | :1880 |
| ESPHome | No | Available | :6052 |
| CloudFlare Tunnel | No | Available | — |
| HA Web SSH | No | Available | :4200 |
| HACS | No | Installed | — |
| Printer Server (CUPS) | No | Available | :631 |
| SSH Password | Yes | Running | ssh :8022 |
| Serial Port Viewer | No | Running | — |
| Port Redirect | No | Available | — |
| Timer | Yes | Running | — |
| Trigger | Yes | Running | — |
| Spatial Intelligence | Yes | Running | — |
| Data Record | Yes | Running | — |
| Energy Management | Yes | Running | — |
| SmartBNB Service | No | Available | — |
| Mushroom Box | No | Available | — |
| Add-On Management | Yes | Running | — |
| Ctwing Access | No | Available | — |

---

## Software Inventory

### Binaries (`/usr/bin/`) — 854 total

Notable inclusions:
- **Compilers**: Clang 20, GCC (aarch64-linux-android), CMake, Make, Autotools
- **Languages**: Python 3.12, Node.js, npm
- **Databases**: MariaDB (full server + client tools)
- **Networking**: SSH (client + server), Mosquitto, frpc, ADB
- **Dev tools**: Git, Bison, pkg-config, etc.

### Python Packages — 548 total

Mostly Home Assistant and its dependencies (aiohttp, aioesphomeapi, aiohomekit, etc.)

### Node.js Modules — 81,308 files

Includes Node-RED, Zigbee2MQTT, Z-Wave JS UI, Matterbridge.

### proot Ubuntu — 397,082 files (85% of image)

A full Ubuntu rootfs used exclusively to run Home Assistant in a Python virtualenv at `/root/homeassistant/bin/activate`.

---

## Key Configuration

### MQTT (`configuration.yaml`)

```yaml
mqtt:
  host: 127.0.0.1
  port: 1883
  username: admin
  password: admin
```

### Home Assistant Launch

Home Assistant runs inside proot Ubuntu:
```sh
#!/data/data/com.termux/files/usr/bin/sh
exec proot-distro login ubuntu << EOF
source /root/homeassistant/bin/activate
hass
EOF
```

### Service Management

Services are controlled via runit (`runsv`/`runsvdir`). The `isgservicemonitor` watches health, and `isgaddonmanager` handles install/upgrade/status via MQTT topics like `isg/run/{service}/status`.

---

## Process Memory Usage (from snapshot)

| Process | Memory |
|---------|--------|
| `hass` (instance 1) | 47 MB |
| `hass` (instance 2) | 93 MB |
| `com.termux` | 49 MB |
| `isgaddonmanager` | 19 MB |
| `isgservicemonitor` | 17 MB |
| `isgspacemanager` | 14 MB |
| `mysqld` | 12 MB |
| `isgtrigger` | 8 MB |
| `isgelecstat` | 8 MB |
| `sshd` | 5 MB |
| `isgdatamanager` | 5 MB |
| `mosquitto` | 4 MB |
| `isgdida` | 3 MB |
| `adb` | 3 MB |

---

## Goal: Minimal Kiosk Browser

The current image is massively over-provisioned for a kiosk browser use case. ~95%+ of the content is unnecessary.

### Option A: Stay on Android + Clean Up (Recommended — Simplest)

Keep Android but strip it down for kiosk use. This is a two-phase process:

**Phase 1: Android cleanup (from host via ADB)**
```bash
# Connect and clean up Android bloatware, optimize display settings
bash scripts/cleanup-adb.sh 192.168.1.100

# This will also save device_props.txt and installed_packages.txt
# for hardware identification
```

**Phase 2: Termux cleanup (SSH into device)**
```bash
# SSH into the iSG
ssh root@192.168.1.100 -p 8022

# Basic cleanup: stop services, clear caches, remove dev tools
bash cleanup-termux.sh

# Full cleanup: also remove proot Ubuntu, node_modules, Python packages
# Saves ~2+ GB and frees significant RAM
bash cleanup-termux.sh --aggressive
```

**Phase 3: Set up kiosk browser**
```bash
bash scripts/setup-kiosk.sh 192.168.1.100 https://your-dashboard.com
# Optionally provide a kiosk browser APK:
bash scripts/setup-kiosk.sh 192.168.1.100 https://your-dashboard.com --browser fully-kiosk.apk
```

**What gets removed/disabled:**

| Category | Items | Estimated Savings |
|----------|-------|-------------------|
| Termux services | 16 of 19 runit services stopped | ~200 MB RAM |
| proot Ubuntu | Full rootfs + Home Assistant | ~1.5 GB disk |
| Node.js modules | zigbee2mqtt, node-red, zwave, matter | ~500 MB disk |
| Python packages | 548 HA-related packages | ~300 MB disk |
| Dev toolchain | Clang 20, CMake, GCC, autotools | ~400 MB disk |
| MariaDB | Database server + data | ~100 MB disk |
| Caches | pip, npm, temp files, logs | ~100 MB disk |
| Android bloatware | Google apps, OEM apps (disabled) | ~50 MB RAM |

**What stays:**
- Android OS + display/touch drivers
- Termux (minimal, for SSH access)
- SSHD (remote management)
- Kiosk browser app

- **Pro**: No bootloader/kernel risks, touchscreen/display guaranteed to work, reversible
- **Con**: Still running Android overhead (~200 MB baseline)

### Option B: Linux via Termux + proot (No Root Needed)

- Keep Android as the base but strip the Termux image to essentials
- Install a minimal Linux distro via proot-distro (e.g., Alpine)
- Display still goes through an Android app (e.g., Termux:X11 or VNC)
- **Pro**: Safe, reversible, proven to work on this hardware
- **Con**: Still Android underneath, display rendering goes through Android

### Option C: Native Linux (Most Aggressive)

- Requires identifying the exact SoC (check via `getprop ro.board.platform` on the device)
- Flash a mainline or vendor Linux kernel + minimal rootfs
- Example stack: Alpine Linux + Cage (Wayland compositor) + Chromium `--kiosk`
- **Pro**: Minimal, no Android bloat, full OS control
- **Con**: Risk of bricking, touchscreen/display driver support uncertain, likely no community support for this hardware

---

## Cleanup Results (2026-02-08)

### Before Cleanup

| Metric | Value |
|--------|-------|
| Memory used | 1,393 MB / 3,923 MB (35.5%) |
| CPU | 13.1% |
| Disk | 7,006 MB / 20,092 MB (34.9%) |
| Processes | 39 |
| Top consumer | hass: 334 MB, mysqld: 125 MB |

### After Cleanup

| Metric | Value |
|--------|-------|
| Memory used | **923 MB / 3,923 MB (23.5%)** |
| CPU | **12.0%** |
| Disk | 6,852 MB / 20,092 MB (34.1%) |
| Processes | **30** |
| Top consumer | com.termux: 139 MB |

### What Was Done

**Android side (via ADB):**
- Disabled 42 bloatware packages (Google apps, Allwinner test apps, Opera, APKPure, OTA updaters)
- Removed wireless ADB app (no longer needed — ADB persisted natively)
- Disabled all animations
- Set screen always-on, disabled lockscreen
- Limited background processes to 2
- Cleared app caches

**Termux side (via ADB run-as):**
- Stopped 7 services: hass, mysqld, isgdatamanager, isgdida, isgelecstat, isgspacemanager, isgtrigger
- Killed proot (Ubuntu container for HA)
- Enabled SSHD

**Memory freed: ~470 MB (34% reduction)**

### Still Running

| Service | Memory | Purpose | Can Remove? |
|---------|--------|---------|-------------|
| com.termux | 139 MB | Termux base | No (needed for services) |
| isgaddonmanager | 25 MB | Addon manager | Maybe (manages service updates) |
| mosquitto | 7 MB | MQTT broker | Yes if not using MQTT |
| sshd | 4 MB | SSH remote access | No (needed for management) |
| runsv/svlogd (x23) | ~64 MB | Service supervisors | Partially (could remove stopped service dirs) |

---

## TODO

- [x] ~~Get ADB/SSH access to a live iSG device~~
- [x] ~~Identify the SoC/chipset~~ → Allwinner Ceres (sun50iw10p1)
- [x] ~~Determine display resolution~~ → 1280x800 @ 160 DPI
- [x] ~~Run initial cleanup~~ → 470 MB RAM freed
- [ ] Test kiosk browser (Fully Kiosk Browser is already installed: `de.ozerov.fully`)
- [ ] Run aggressive Termux cleanup (remove proot Ubuntu, node_modules, dev tools — saves ~2 GB disk)
- [ ] Evaluate if `isgaddonmanager` can be stopped safely
- [ ] Remove runsv/svlogd instances for permanently disabled services
- [ ] Research Allwinner Ceres mainline Linux support for Option C
- [ ] Investigate bootloader unlock possibility
