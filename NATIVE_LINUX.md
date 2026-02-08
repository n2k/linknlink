# Native Linux on LinknLink iSG (Option C)

Research into running native Linux on the LinknLink iSG CPF1056 for kiosk browser use.

## Hardware Identification

| Component | Details |
|-----------|---------|
| **SoC** | Allwinner A133 (sun50iw10p1), also known as R818 |
| **CPU** | 4x ARM Cortex-A53 @ 1.6 GHz (ARMv8-A, aarch64) |
| **GPU** | Imagination PowerVR GE8300 |
| **RAM** | 4 GB |
| **Storage** | 30 GB eMMC (mmcblk0) |
| **Display** | 1280x800 MIPI DSI panel, 160 DPI, landscape (270° rotated) |
| **LCD Driver** | `za691_101_qinuo_jhx_9881c` (ILI9881C-based MIPI DSI panel) |
| **Touch** | Silead GSL680 (gslX680new, I2C bus 0, addr 0x40) |
| **WiFi** | XR829 (Allwinner/XRadio) |
| **Bluetooth** | XRadio (xradio_btlpm module) |
| **Accelerometer** | MIR3DA (mir3da module) |
| **Hall Sensor** | MH248 |
| **Light Sensor** | sunxi lightsensor |
| **PMIC** | AXP803/AXP2101 (RSB bus) |
| **Current Kernel** | Linux 4.9.170 (Allwinner BSP, Linaro GCC 5.3) |
| **Build Type** | `userdebug` with `test-keys` |
| **Android** | 10 (API 29) |
| **Board** | `ceres-c3` / `exdroid` |
| **Manufacturer** | Allwinner (OEM: YHK) |

## Partition Layout

```
mmcblk0     30 GB   Full eMMC
├── p1      64 MB   bootloader
├── p2      16 MB   env (U-Boot environment)
├── p3      32 MB   boot (kernel + ramdisk)
├── p4       5 GB   super (dynamic partitions: system, vendor, product)
├── p5      16 MB   misc
├── p6      32 MB   recovery
├── p7     768 MB   cache
├── p8      16 MB   vbmeta
├── p9      16 MB   vbmeta_system
├── p10     16 MB   vbmeta_vendor
├── p11     16 MB   metadata
├── p12     16 MB   private
├── p13    512 KB   frp (factory reset protection)
├── p14     16 MB   empty
├── p15      2 MB   dtbo
├── p16     16 MB   media_data
└── p17     23 GB   UDISK (data partition, ext4)
```

## Kernel Modules Loaded

| Module | Size | Purpose |
|--------|------|---------|
| `gslX680new` | 1.1 MB | Silead touch controller |
| `xr829` | 737 KB | WiFi driver |
| `pvrsrvkm` | 1.9 MB | PowerVR GPU kernel driver |
| `xradio_btlpm` | 29 KB | Bluetooth low-power mode |
| `mir3da` | 37 KB | Accelerometer |

## Bootloader Status

```
ro.boot.flash.locked = 1
ro.boot.verifiedbootstate = green
ro.boot.vbmeta.device_state = locked
ro.boot.secure_os_exist = 1
ro.boot.selinux = enforcing
```

**The bootloader is locked** with verified boot (AVB 2.0). This is the biggest obstacle.

---

## Mainline Linux Support (from linux-sunxi.org)

The A133 has **growing but incomplete** mainline support. Key status from the kernel status matrix:

### What Works in Mainline

| Subsystem | Since | Notes |
|-----------|-------|-------|
| Clocks | 5.10 | Core clock tree |
| Pinctrl | 5.10 | GPIO/pin muxing |
| SD/MMC | 5.12 | eMMC and SD card |
| Thermal | 5.10 | Temperature monitoring |
| SID (eFuse) | 5.10 | Chip ID |
| MIPI DSI | **6.2** | Display output — critical for this device |
| I2C | 6.0 | Bus for touch, sensors |
| IR | 6.0 | Infrared receiver |
| RSB | 6.0 | Reduced Serial Bus (PMIC) |
| USB | 6.1 | USB host + OTG |
| DMA | 6.1 | DMA controller |
| Ethernet | 6.17 | GMAC |
| CPUFreq | 6.10 | CPU frequency scaling |
| Crypto | 6.11 | Hardware crypto |
| SRAM | 6.14 | SRAM controller |
| Watchdog | 6.13 | Hardware watchdog |
| PMU | 6.13 | Performance monitoring |
| SMP | PSCI | Multi-core boot |

### What Does NOT Work / Missing

| Subsystem | Status | Impact |
|-----------|--------|--------|
| **GPU (PowerVR GE8300)** | **NO** | **CRITICAL** — No 3D acceleration for browser |
| WiFi (XR829) | NO | Needs out-of-tree driver |
| Bluetooth (XRadio) | NO | Needs out-of-tree driver |
| NAND | NO | N/A (device uses eMMC) |
| LVDS | WIP | N/A (device uses MIPI DSI) |
| RGB | WIP | N/A |
| PWM | WIP | Needed for backlight control |
| RTC | WIP | Real-time clock |
| IOMMU | NO | Not critical |
| PCIe | N/A | Not present on device |

---

## The GPU Problem

The **Imagination PowerVR GE8300** is the biggest blocker for a kiosk browser. Unlike ARM Mali GPUs (which have the open-source Panfrost/Lima drivers), PowerVR has:

1. **No mainline Linux driver** — Imagination has been working on open-sourcing their GPU driver, but GE8300 support is not yet available
2. **No Mesa/Gallium3D support** — Modern browsers (Chromium, Firefox) need GPU acceleration for compositing
3. **Imagination's open-source effort** — They started releasing source for newer PowerVR GPUs in 2022, but GE8300 is an older generation and may not be covered

### Workarounds

1. **Software rendering** — Run Chromium with `--disable-gpu`. Works but will be slow for complex pages on a Cortex-A53
2. **Use the vendor GPU driver** — Extract the PowerVR userspace blob from Android and use it with the BSP kernel. Fragile and version-locked
3. **BSP kernel** — Use Allwinner's BSP kernel (4.9 or 5.4) which includes the PowerVR driver. Sacrifice mainline for functionality

---

## Feasibility Assessment

### Approach 1: Mainline Kernel + Software Rendering

```
Mainline kernel (6.14+)
  └── ARM64 defconfig + A133 DT
       ├── MIPI DSI display (mainline driver)
       ├── gslX680 touch (mainline silead driver + firmware)
       ├── eMMC storage (mainline)
       ├── USB (mainline)
       └── WiFi: XR829 out-of-tree module

Alpine Linux / Debian minimal rootfs
  └── Cage (single-window Wayland compositor)
       └── Chromium --kiosk --disable-gpu
```

**Pros**: Clean, maintainable, uses mainline kernel
**Cons**: No GPU = slow browser, WiFi needs out-of-tree driver
**Verdict**: Possible but performance may be unacceptable for modern web content

### Approach 2: Allwinner BSP Kernel + Vendor GPU

```
Allwinner BSP kernel (4.9 or 5.4)
  └── All hardware supported (including PowerVR GPU)

Minimal rootfs (Debian/Alpine)
  └── Weston (Wayland compositor with PowerVR EGL)
       └── Chromium --kiosk --use-gl=egl
```

**Pros**: Full hardware support including GPU acceleration
**Cons**: Old kernel (4.9), security concerns, vendor lock-in, hard to maintain
**Verdict**: Best performance, most effort to set up, least maintainable

### Approach 3: Reference Device (Creality Sonic Pad)

The [Creality Sonic Pad](https://linux-sunxi.org/Creality_Sonic_Pad) uses the same A133 SoC (rebadged as T800). The community has done Linux work on it. This could serve as a reference for:
- Device tree configuration
- Bootloader unlocking procedures
- WiFi driver compilation

### Approach 4: Stay on Android (Current Recommendation)

Given the GPU situation, the most practical approach remains:
- Keep Android 10 as the base OS
- Strip it down (already done — freed 470 MB RAM)
- Use a WebView-based kiosk app or Chrome in kiosk mode
- Manage via ADB

---

## Bootloader Unlocking

The device has a locked bootloader with AVB 2.0. Options:

1. **`fastboot flashing unlock`** — May work since the build is `userdebug` with `test-keys`. Try:
   ```bash
   adb reboot bootloader
   fastboot flashing unlock
   ```
   **Warning**: This will factory reset the device.

2. **Allwinner PhoenixSuit/LiveSuit** — Allwinner devices can often be flashed with vendor tools via USB-OTG in FEL mode. Requires holding a button during boot.

3. **UART console** — The SoC has UART0 exposed. If accessible on the board, provides direct U-Boot console access.

---

## Touch Controller Notes

The Silead GSL680 requires firmware to operate. The mainline `silead` driver supports it, but you need the correct firmware blob. It can potentially be extracted from Android:

```bash
# On the device via ADB
adb pull /system/vendor/firmware/gsl_firmware.bin
# Or extract from the gslX680new.ko module
```

## WiFi Driver Notes

The XR829 is an Allwinner/XRadio WiFi chip. Driver source is available in various BSP leaks and has been packaged for some community kernels:
- [xr829 driver on GitHub](https://github.com/AvaotaSBC/linux-5.15-xr829)
- Needs to be compiled against whatever kernel you run

---

## Next Steps

1. **Try bootloader unlock** — `adb reboot bootloader && fastboot flashing unlock`
2. **Check for FEL mode** — Try booting with USB-OTG connected while holding volume buttons
3. **Look at Creality Sonic Pad community work** — Same SoC, active community
4. **Extract vendor GPU blobs** — If going BSP kernel route
5. **Test software rendering performance** — Install a Termux X11 environment and test Chromium with `--disable-gpu`
6. **Evaluate if WebView kiosk on Android is "good enough"** — May be the pragmatic choice
