# LinknLink iSG — Kiosk Conversion

Converting a LinknLink iSG (Android wall-mounted smart screen) from a bloated smart-home hub into a lean, fast kiosk browser.

## What This Repo Contains

```
README.md                           — This file (findings + setup guide)
NATIVE_LINUX.md                     — Research into native Linux on the hardware

kiosk-browser/                      — Custom Android WebView kiosk browser app
  app/src/main/
    AndroidManifest.xml             — Home launcher + boot receiver
    java/.../KioskActivity.java     — Fullscreen WebView with error handling
    java/.../SettingsActivity.java  — URL config (5x tap top-right corner)
    java/.../BootReceiver.java      — Auto-launch on boot

webview-overlay/                    — Framework overlay to enable modern WebView
  AndroidManifest.xml               — Targets android framework
  res/xml/config_webview_packages.xml — Adds modern WebView providers
  build.sh                          — Build the overlay APK

boot-animation/                     — Custom boot animation generator
  generate.py                       — Python script (Pillow) to generate frames

scripts/
  setup-kiosk-device.sh             — Full automated setup (run from host)
  cleanup-adb.sh                    — Android cleanup via ADB
  cleanup-termux.sh                 — Termux cleanup (run on device)
  setup-kiosk.sh                    — Older kiosk setup script
```

## Quick Start

After a **factory reset**, run:

```bash
# 1. Build the kiosk browser APK
cd kiosk-browser && gradle assembleDebug

# 2. Build the WebView overlay
cd webview-overlay
adb pull /system/framework/framework-res.apk .
./build.sh

# 3. Generate the boot animation
cd boot-animation && python3 generate.py

# 4. Run the full setup
cd scripts && bash setup-kiosk-device.sh 192.168.86.112 http://192.168.86.10/kiosk.html

# 5. Reboot, then install WebView Dev via AuroraStore
adb -s 192.168.86.112:5555 reboot
```

---

## Device Hardware

| Property | Value |
|----------|-------|
| Model | CPF1056 |
| SoC | **Allwinner A133** (sun50iw10p1, aka "Ceres") |
| CPU | 4x ARM Cortex-A53 @ 1.6 GHz (ARMv8-A, aarch64) |
| GPU | Imagination PowerVR GE8300 |
| RAM | 3,923 MB (~4 GB) |
| Storage | 30 GB eMMC (20 GB usable /data) |
| Display | 1280x800, 160 DPI, MIPI DSI (landscape, 270° rotated) |
| LCD Driver | `za691_101_qinuo_jhx_9881c` (ILI9881C-based) |
| Touch | Silead GSL680 (I2C bus 0, addr 0x40) |
| WiFi | XR829 (Allwinner/XRadio) |
| Bluetooth | XRadio (xradio_btlpm module) |
| Android | 10 (API 29), `userdebug` build with `test-keys` |
| Manufacturer | Allwinner (OEM: YHK) |
| Build Type | `userdebug` — **root access available via `adb root`** |

---

## What We Did

### 1. Custom Kiosk Browser App

Built a minimal Android WebView-based kiosk browser (`com.linknlink.kiosk`, 2.9 MB):

- **Home launcher** — replaces LinknLink launcher, auto-starts on boot
- **Fullscreen immersive** — no status bar, no navigation, no distractions
- **Error handling** — shows connection error screen with auto-retry (5s)
- **SSL tolerance** — accepts self-signed certs for local services
- **URL persistence** — remembers URL across reboots
- **Settings access** — tap top-right corner 5 times to change URL
- **ADB URL change** — `am start -n com.linknlink.kiosk/.KioskActivity --es url "http://..."`
- **Wake lock** — screen never sleeps
- **Viewport** — renders at native 1280x800 (no mobile viewport scaling)

### 2. WebView Upgrade (Chromium 74 → 146)

The stock firmware ships with **Chromium 74** (from 2019) as the only WebView provider. This doesn't support modern CSS features like `gap` for flexbox (added in Chromium 84).

**Problem**: The framework's `config_webview_packages` only lists `com.android.webview`, and it's OEM-signed (signature `1a492f7d`), so you can't update it with Google's version.

**Solution**: Created a **Runtime Resource Overlay (RRO)** that overrides the framework's allowed WebView provider list:

1. Built an overlay APK targeting `android` that overrides `res/xml/config_webview_packages.xml`
2. Added `com.google.android.webview.dev`, `com.google.android.webview`, and `com.android.chrome` as valid providers
3. Pushed to `/product/overlay/WebViewConfigOverlay.apk`
4. Installed **Android System WebView Dev** via AuroraStore (F-Droid build)
5. System automatically switched to the newer provider

**Result**: WebView went from Chromium 74 (2019) to **Chromium 146** (2025). Full modern CSS/JS support.

**Search paths for WebView providers** (from `libbootanimation.so`):
```
1. /apex/com.android.bootanimation/etc/bootanimation.zip
2. com.google.android.webview.dev  (our addition)
3. com.android.webview             (stock, Chromium 74)
4. com.android.chrome              (our addition)
5. com.google.android.webview      (our addition)
```

### 3. Custom Boot Animation

Replaced the LinknLink boot animation with a heat-pump themed one matching the dashboard:

- **Dark navy background** (#0d1117) matching the dashboard
- **Cyan snowflake** with glow effect — fades in during part0
- **"IVT Air X 400 / Heat Pump Dashboard"** text
- **Cyan-to-orange gradient flow line** — represents cold→hot energy flow
- **Animated particles** moving along the flow line in the looping part1
- **"Starting..."** text with animated dots
- **1.9 MB** (down from 12 MB original)
- **12 FPS**, 1280x800, 36 frames per part

**Boot animation search paths** (extracted from `libbootanimation.so`):
```
1. /apex/com.android.bootanimation/etc/bootanimation.zip
2. /data/local/bootanimation.zip        ← we use this (always writable)
3. /product/media/bootanimation.zip     ← and this (backup, persists)
4. /oem/media/bootanimation.zip
5. /system/media/bootanimation.zip      ← stock (read-only, dm-verity)
```

**Note**: `/system` is dm-verity protected and can't be written persistently. We use `/data/local/` (highest priority writable path) and `/product/media/` (writable after `mount -o remount,rw /product`).

### 4. System Cleanup & Optimization

**Android bloatware**: 55 packages disabled via `pm disable` (root) or `pm disable-user`:

| Category | Packages | Examples |
|----------|----------|----------|
| Vendor | 2 | OTA updater, YHK management |
| LinknLink/Termux | 2 | LinknLink launcher, Termux |
| Telephony/SMS | 3 | MMS, SIM dialog, SMS push |
| Unused providers | 5 | Calendar, contacts, blocked numbers |
| Security/enterprise | 4 | Secure element, cert installer, provisioning |
| Network extras | 3 | VPN, hotspot 2.0, PAC proxy |
| Google apps | ~20 | Docs UI, CTS shims, etc. |
| Misc | ~16 | Settings intelligence, Bluetooth MIDI, etc. |

**Critical packages NOT disabled** (will break boot):
- `com.android.phone` — system_server depends on telephony
- `com.google.android.ext.services` — core Android services
- `com.android.systemui` — display management
- `com.android.settings` — system settings
- `com.android.providers.media` — media scanner
- `com.android.providers.settings` — settings provider
- `com.android.packageinstaller` — APK installation
- `com.android.keychain` — SSL/TLS certificates
- `com.android.inputmethod.latin` — keyboard

**Performance tweaks** (via `settings put`):
- All animations disabled (window, transition, animator = 0)
- Screen always on, max brightness, no lockscreen
- Background process limit = 2
- GPU rendering forced
- Notifications disabled
- Auto-updates disabled
- Power saving disabled

**Termux cleanup**: All 19 runit services stopped. Home Assistant, MariaDB, Zigbee2MQTT, Node-RED, Matter — all disabled. proot Ubuntu (85% of image) available for removal.

### 5. Factory Reset Recovery

Documented the full recovery procedure after an over-aggressive cleanup caused a boot loop:

1. Factory reset via recovery mode
2. WiFi reconnection via root shell (`wpa_supplicant.conf` edit)
3. Re-enable wireless ADB
4. Run `setup-kiosk-device.sh` for automated re-setup

**WiFi config** (written to `/data/misc/wifi/wpa_supplicant/wpa_supplicant.conf`):
```
ctrl_interface=/data/vendor/wifi/wpa/sockets
update_config=1
pmf=1
p2p_disabled=1

network={
    ssid="YourSSID"
    psk="YourPassword"
    key_mgmt=WPA-PSK
    priority=1
}
```

---

## Memory & Performance

### Before Cleanup

| Metric | Value |
|--------|-------|
| Memory used | 1,393 MB / 3,923 MB (35.5%) |
| Processes | 39 |
| Top consumers | hass: 334 MB, mysqld: 125 MB, com.termux: 49 MB |

### After Full Cleanup

| Metric | Value |
|--------|-------|
| Memory used | ~900 MB / 3,923 MB (~23%) |
| Processes | ~15 |
| Top consumer | com.linknlink.kiosk (WebView) |

**~500 MB RAM freed** — the device now runs the kiosk browser smoothly with 3 GB free.

---

## Architecture

```
Android 10 (stock, userdebug)
  ├── WebView: Chromium 146 (via overlay + WebView Dev)
  ├── Kiosk Browser (com.linknlink.kiosk) — home launcher
  │     └── WebView → http://192.168.86.10/kiosk.html
  ├── Boot Animation: custom heat-pump themed
  ├── 55 bloatware packages disabled
  ├── Termux: disabled (available if needed)
  └── ADB: wireless on :5555 (persistent)
```

---

## Partition Layout

```
mmcblk0     30 GB   Full eMMC
├── p1      64 MB   bootloader
├── p2      16 MB   env (U-Boot environment)
├── p3      32 MB   boot (kernel + ramdisk)
├── p4       5 GB   super (system, vendor, product — dm-verity protected)
├── p5      16 MB   misc
├── p6      32 MB   recovery
├── p7     768 MB   cache
├── p8–p10  48 MB   vbmeta (verified boot)
├── p11     16 MB   metadata
├── p15      2 MB   dtbo
├── p16     16 MB   media_data
└── p17     23 GB   UDISK (data partition, ext4 — user data, apps)
```

---

## Key Findings

### dm-verity & System Partition
- `/system` is dm-verity protected — writes don't persist across reboot
- `/product` IS writable after `mount -o remount,rw /product` (overlays persist here)
- `/data` is always writable (boot animation, app data, etc.)
- `adb disable-verity` reports "Device is locked" but enables overlayfs for `/vendor`

### Bootloader
- Locked with AVB 2.0 (`ro.boot.flash.locked=1`)
- Build type is `userdebug` with `test-keys` — root via `adb root` works
- `fastboot flashing unlock` may work but will factory reset

### WebView Provider System
- Framework resource `res/xml/config_webview_packages.xml` controls allowed providers
- Stock firmware only allows `com.android.webview` (OEM-signed, Chromium 74)
- Runtime Resource Overlays (RROs) in `/product/overlay/` can override framework resources
- `cmd webviewupdate set-webview-implementation PACKAGE` switches active provider
- System auto-selects the highest-version valid provider after overlay is applied

### Boot Animation Format
- Standard Android `bootanimation.zip` (ZIP_STORED, not compressed)
- `desc.txt` format: `WIDTH HEIGHT FPS\np COUNT PAUSE PART_DIR\n...`
- `p 1 0 part0` = play once, no pause
- `p 0 0 part1` = loop until boot complete
- Frames: numbered JPG/PNG files in part directories

---

## Source Files (not in repo)

| File | Size | Description |
|------|------|-------------|
| `image_*.tar.gz` | ~2.5 GB | iSG Termux userland snapshot |
| `20167_global_1224.apk` | ~243 MB | iSG homescreen/launcher app |
| `AuroraStore-*.apk` | ~8.4 MB | AuroraStore (for installing WebView) |

---

## Original System Image Analysis

The system image is a **Termux userland filesystem snapshot** (not a full Android image) containing 465,519 files:

| Layer | Files | Size | Purpose |
|-------|-------|------|---------|
| proot Ubuntu | 397K (85%) | ~1.5 GB | Runs Home Assistant in a Python venv |
| Node.js modules | 81K | ~500 MB | Node-RED, Zigbee2MQTT, Z-Wave JS, Matter |
| Termux binaries | 854 | ~400 MB | Clang 20, CMake, Python 3.12, MariaDB |
| LinknLink Go services | 15 | ~50 MB | isgaddonmanager, isgdevicemanager, etc. |

### 19 Runit Services (all disabled for kiosk)

| Service | Purpose |
|---------|---------|
| `hass` | Home Assistant (in proot Ubuntu) |
| `mosquitto` | MQTT broker |
| `node-red` | Node-RED automation |
| `zigbee2mqtt` | Zigbee gateway |
| `zwave-js-ui` | Z-Wave gateway |
| `matter-server/bridge` | Matter protocol |
| `frpc` | FRP reverse proxy |
| `mysqld` | MariaDB |
| `sshd` | SSH server (:8022) |
| `isg*` (7 services) | LinknLink proprietary services |

---

## TODO

- [x] Get ADB/SSH access to live device
- [x] Identify SoC/chipset → Allwinner A133
- [x] Determine display resolution → 1280x800 @ 160 DPI
- [x] Run cleanup → 500 MB RAM freed, 55 packages disabled
- [x] Build custom kiosk browser APK
- [x] Upgrade WebView (Chromium 74 → 146 via framework overlay)
- [x] Custom boot animation (heat pump themed)
- [x] Automated setup script
- [x] Research native Linux feasibility (see NATIVE_LINUX.md)
- [ ] Add hard-reload command to kiosk app (clear WebView cache + reload)
- [ ] Investigate bootloader unlock (`fastboot flashing unlock`)
- [ ] Try Allwinner FEL mode for potential firmware backup
- [ ] Evaluate Creality Sonic Pad community work (same A133 SoC)
