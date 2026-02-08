# LinknLink iSG Research

Research into the LinknLink iSG (Android tablet/wall-mounted smart screen) system image, with the goal of creating a minimal kiosk browser setup.

## Contents of This Repo

- `README.md` — Findings and analysis

## Source Files (not committed)

| File | Size | Description |
|------|------|-------------|
| `image_20251212_143315_*.tar.gz` | ~2.5 GB | iSG system image (Termux userland snapshot) |
| `20167_global_1224.apk` | ~243 MB | iSG homescreen/launcher app |

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

### Option A: Stay on Android (Recommended — Simplest)

- Skip this entire Termux image
- Replace the homescreen APK with a kiosk browser (e.g., Fully Kiosk Browser, or a custom Android WebView app)
- Use ADB to lock down the device (hide nav bar, set as device owner, auto-start on boot)
- **Pro**: No bootloader/kernel risks, touchscreen/display guaranteed to work
- **Con**: Still running Android overhead

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

## TODO

- [ ] Get ADB/SSH access to a live iSG device
- [ ] Identify the SoC/chipset (`getprop ro.board.platform`, `/proc/cpuinfo`)
- [ ] Determine display resolution and touch controller
- [ ] Test Option A with Fully Kiosk Browser or custom WebView APK
- [ ] Investigate bootloader unlock possibility for Option C
- [ ] Analyze the homescreen APK (`20167_global_1224.apk`)
