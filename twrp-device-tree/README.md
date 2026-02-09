# TWRP Device Tree — LinknLink iSG (Allwinner A133 / ceres_c3)

Auto-generated from the stock recovery image using `twrpdtgen`, then customized and **successfully built**.

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
| Encryption | File-Based Encryption (FBE) — not decrypted by TWRP |

## Build Status

**Successfully built and flashed.** The image fits exactly in the 32 MB recovery partition.

Key build fixes that were needed:
- Device name uses underscore (`ceres_c3`) — dashes break lunch combo parsing
- Product mk renamed from `omni_` to `twrp_` and vendor path changed from `vendor/omni` to `vendor/twrp`
- Kernel base set to `0x00000000` with explicit offsets — the auto-generated base `0x40078000` caused `tags_offset` overflow in mkbootimg
- Crypto, MTP, repack tools, extra languages, logcat disabled to fit in 32 MB (22 MB kernel + 11 MB ramdisk is tight)
- `TW_EXCLUDE_ENCRYPTED_BACKUPS` must NOT be set — TWRP has a bug where setting it includes libopenaes but also prevents it from building

## Build Instructions

```bash
# 1. Initialize TWRP minimal manifest
mkdir twrp && cd twrp
repo init --depth=1 -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b twrp-11
repo sync -j4 --no-clone-bundle --no-tags --current-branch

# 2. Copy this device tree
mkdir -p device/allwinner/ceres_c3
cp -r /path/to/twrp-device-tree/* device/allwinner/ceres_c3/

# 3. Build
export ALLOW_MISSING_DEPENDENCIES=true
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export LC_ALL=C
source build/envsetup.sh
lunch twrp_ceres_c3-eng
make -j$(nproc) recoveryimage

# 4. Output at: out/target/product/ceres_c3/recovery.img (32 MB)
```

Build takes ~33 minutes on 8 cores. The manifest sync downloads ~38 GB.

## Flash Instructions

Since the device is `userdebug` with `adb root`, we can flash via `dd` **without bootloader unlock**:

```bash
# Push TWRP image to device
adb root
adb push recovery.img /data/local/tmp/twrp-recovery.img

# Flash to recovery partition
adb shell dd if=/data/local/tmp/twrp-recovery.img of=/dev/block/by-name/recovery bs=4096
adb shell sync

# Verify
adb shell md5sum /data/local/tmp/twrp-recovery.img
adb shell "dd if=/dev/block/by-name/recovery bs=4096 | md5sum"

# Boot into TWRP
adb reboot recovery

# Clean up
adb shell rm /data/local/tmp/twrp-recovery.img
```

**Note**: TWRP recovery requires a **physical USB cable** for ADB access — WiFi ADB is not available in recovery mode.

## Restore Stock Recovery

```bash
adb root
adb push partitions/recovery.img /data/local/tmp/recovery_stock.img
adb shell dd if=/data/local/tmp/recovery_stock.img of=/dev/block/by-name/recovery bs=4096
adb shell sync
adb reboot
```
