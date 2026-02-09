# TWRP Device Tree — LinknLink iSG (Allwinner A133 / ceres-c3)

Auto-generated with `twrpdtgen` from the stock recovery image, then customized.

## Device Specs

| Field | Value |
|-------|-------|
| SoC | Allwinner A133 (sun50iw10p1) |
| Platform codename | `ceres` |
| Build | `ceres_c3-userdebug 10 QP1A.191105.004` |
| Kernel | 4.9.170 (prebuilt, extracted from stock recovery) |
| Screen | 1280×800, landscape |
| Boot image header | v2 |
| Partitions | Non-A/B, dynamic (super), dedicated recovery |
| Encryption | File-Based Encryption (FBE) |

## Build Instructions

Building TWRP requires syncing the minimal TWRP manifest (~20-50 GB).

```bash
# 1. Initialize TWRP minimal manifest (Android 11 branch for boot header v2)
mkdir twrp && cd twrp
repo init --depth=1 -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b twrp-11
repo sync -j$(nproc)

# 2. Copy this device tree
mkdir -p device/allwinner/ceres-c3
cp -r /path/to/twrp-device-tree/* device/allwinner/ceres-c3/

# 3. Build
export ALLOW_MISSING_DEPENDENCIES=true
source build/envsetup.sh
lunch omni_ceres-c3-eng
make -j$(nproc) recoveryimage

# 4. Output at: out/target/product/ceres-c3/recovery.img
```

## Flash Instructions

**Prerequisites**: Bootloader must be unlocked first.

```bash
# Backup current recovery (already done — see partitions/ folder)
adb shell dd if=/dev/block/by-name/recovery of=/data/local/tmp/recovery_stock.img
adb pull /data/local/tmp/recovery_stock.img

# Flash via fastboot (if available)
fastboot flash recovery recovery.img

# Or flash via dd with root ADB (if fastboot doesn't work on Allwinner)
adb root
adb push recovery.img /data/local/tmp/
adb shell dd if=/data/local/tmp/recovery.img of=/dev/block/by-name/recovery bs=4096
adb shell sync
adb reboot recovery
```

## Restore Stock Recovery

```bash
adb root
adb push partitions/recovery.img /data/local/tmp/
adb shell dd if=/data/local/tmp/recovery.img of=/dev/block/by-name/recovery bs=4096
adb shell sync
adb reboot
```
