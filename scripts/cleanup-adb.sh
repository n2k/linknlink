#!/bin/bash
# =============================================================================
# LinknLink iSG Android Cleanup Script (run from host via ADB)
#
# Purpose: Disable unnecessary Android packages and optimize the device
#          for kiosk browser use. Run this from your computer with ADB.
#
# Usage:   Connect to the iSG via ADB, then run:
#          bash cleanup-adb.sh <device-ip> [--dry-run]
#
# Prerequisites:
#   - ADB installed on your computer
#   - ADB debugging enabled on the iSG
#   - Device IP address known
#
# WARNING: Disabling system packages can cause issues. Back up first!
#          Packages are disabled (not uninstalled) and can be re-enabled.
# =============================================================================

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <device-ip> [--dry-run]"
    echo "Example: $0 192.168.1.100"
    exit 1
fi

DEVICE_IP="$1"
DRY_RUN=false
[ "${2:-}" = "--dry-run" ] && DRY_RUN=true

ADB="adb -s $DEVICE_IP:5555"

log() { echo "[$(date '+%F %T')] $*"; }
run_adb() {
    if $DRY_RUN; then
        log "[DRY-RUN] adb shell $*"
    else
        log "[EXEC] adb shell $*"
        $ADB shell "$@"
    fi
}

# =============================================================================
# Step 0: Connect to device
# =============================================================================
log "=== Connecting to $DEVICE_IP ==="
adb connect "$DEVICE_IP:5555" 2>&1 || true
sleep 2

# Verify connection
if ! $ADB get-state &>/dev/null; then
    log "ERROR: Cannot connect to device at $DEVICE_IP"
    log "Make sure ADB debugging is enabled and the device is reachable"
    exit 1
fi

# =============================================================================
# Step 1: Gather device info
# =============================================================================
log ""
log "=== Device Information ==="
log "Model:    $($ADB shell getprop ro.product.model)"
log "Android:  $($ADB shell getprop ro.build.version.release)"
log "SDK:      $($ADB shell getprop ro.build.version.sdk)"
log "SoC:      $($ADB shell getprop ro.board.platform)"
log "CPU:      $($ADB shell getprop ro.product.cpu.abi)"
log "RAM:      $($ADB shell cat /proc/meminfo | head -1)"
log "Build:    $($ADB shell getprop ro.build.display.id)"
log "Serial:   $($ADB shell getprop ro.serialno)"

# Save full prop list for reference
log ""
log "Saving full property list to device_props.txt..."
$ADB shell getprop > device_props.txt 2>/dev/null || true

# =============================================================================
# Step 2: List all installed packages
# =============================================================================
log ""
log "=== Installed Packages ==="
$ADB shell pm list packages -f > installed_packages.txt 2>/dev/null || true
TOTAL=$($ADB shell pm list packages | wc -l)
log "Total packages: $TOTAL"
log "Package list saved to installed_packages.txt"

# =============================================================================
# Step 3: Disable bloatware
# =============================================================================
log ""
log "=== Disabling Bloatware ==="

# Common Android bloatware safe to disable on a kiosk device.
# These are DISABLED (not uninstalled) and can be re-enabled with:
#   adb shell pm enable <package>
PACKAGES_TO_DISABLE=(
    # Google apps (not needed for kiosk)
    com.google.android.youtube
    com.google.android.music
    com.google.android.videos
    com.google.android.apps.photos
    com.google.android.apps.maps
    com.google.android.apps.docs
    com.google.android.apps.books
    com.google.android.apps.magazines
    com.google.android.apps.plus
    com.google.android.apps.tachyon      # Google Duo
    com.google.android.apps.nbu.files    # Files by Google
    com.google.android.apps.wellbeing    # Digital Wellbeing
    com.google.android.apps.messaging    # Google Messages
    com.google.android.gm               # Gmail
    com.google.android.calendar
    com.google.android.contacts
    com.google.android.dialer
    com.google.android.talk              # Hangouts
    com.google.android.feedback
    com.google.android.printservice.recommendation
    com.google.android.googlequicksearchbox
    com.google.android.marvin.talkback   # Accessibility TalkBack
    com.google.android.inputmethod.latin # Gboard (if not needed)

    # Samsung bloatware (in case it's Samsung-based)
    com.samsung.android.app.notes
    com.samsung.android.calendar
    com.samsung.android.email.provider
    com.samsung.android.game.gamehome
    com.samsung.android.game.gametools

    # Common OEM bloatware
    com.android.browser
    com.android.calculator2
    com.android.calendar
    com.android.contacts
    com.android.deskclock
    com.android.documentsui
    com.android.email
    com.android.gallery3d
    com.android.music
    com.android.musicfx
    com.android.quicksearchbox
    com.android.soundrecorder
    com.android.stk                      # SIM Toolkit
    com.android.dreams.basic             # Screensaver
    com.android.dreams.phototable
    com.android.printspooler
    com.android.wallpaper.livepicker
    com.android.bookmarkprovider
    com.android.cellbroadcastreceiver
    com.android.managedprovisioning
    com.android.providers.partnerbookmarks
)

DISABLED_COUNT=0
for pkg in "${PACKAGES_TO_DISABLE[@]}"; do
    if $ADB shell pm list packages | grep -q "^package:$pkg$"; then
        log "Disabling: $pkg"
        run_adb "pm disable-user --user 0 $pkg" 2>/dev/null || true
        ((DISABLED_COUNT++)) || true
    fi
done

log "Disabled $DISABLED_COUNT packages"

# =============================================================================
# Step 4: Performance optimizations
# =============================================================================
log ""
log "=== Performance Optimizations ==="

# Disable animations (makes UI feel snappier)
log "Disabling animations..."
run_adb "settings put global window_animation_scale 0"
run_adb "settings put global transition_animation_scale 0"
run_adb "settings put global animator_duration_scale 0"

# Keep screen always on (kiosk mode)
log "Setting screen to stay on..."
run_adb "settings put global stay_on_while_plugged_in 7"  # USB + AC + Wireless
run_adb "settings put system screen_off_timeout 2147483647"

# Disable screen lock
log "Disabling screen lock..."
run_adb "settings put secure lockscreen.disabled 1" 2>/dev/null || true

# Disable notifications
log "Reducing notification clutter..."
run_adb "settings put global heads_up_notifications_enabled 0"

# Disable auto-update
log "Disabling auto-updates..."
run_adb "settings put global package_verifier_enable 0" 2>/dev/null || true

# Set display to never sleep
log "Disabling display sleep..."
run_adb "settings put system screen_brightness_mode 0"  # Manual brightness
run_adb "settings put system screen_brightness 200"     # High brightness for wall display

# Reduce background process limit
log "Limiting background processes..."
run_adb "settings put global always_finish_activities 1"
run_adb "settings put global background_process_limit 2"

# =============================================================================
# Step 5: Clear unnecessary app data/cache
# =============================================================================
log ""
log "=== Clearing App Caches ==="
run_adb "pm trim-caches 999999999999"

# =============================================================================
# Step 6: Stop Termux services via ADB
# =============================================================================
log ""
log "=== Stopping Heavy Termux Services ==="
log "To clean up Termux internals, SSH into port 8022 and run cleanup-termux.sh"
log ""
log "Quick service stop via ADB:"

# Stop heavy services through Termux's run-command
TERMUX_STOP_CMDS=(
    "sv down /data/data/com.termux/files/usr/var/service/hass"
    "sv down /data/data/com.termux/files/usr/var/service/node-red"
    "sv down /data/data/com.termux/files/usr/var/service/zigbee2mqtt"
    "sv down /data/data/com.termux/files/usr/var/service/zwave-js-ui"
    "sv down /data/data/com.termux/files/usr/var/service/matter-server"
    "sv down /data/data/com.termux/files/usr/var/service/matter-bridge"
    "sv down /data/data/com.termux/files/usr/var/service/frpc"
    "sv down /data/data/com.termux/files/usr/var/service/isgdida"
    "sv down /data/data/com.termux/files/usr/var/service/isgelecstat"
    "sv down /data/data/com.termux/files/usr/var/service/isgdatamanager"
    "sv down /data/data/com.termux/files/usr/var/service/isgspacemanager"
    "sv down /data/data/com.termux/files/usr/var/service/isgdevicemanager"
    "sv down /data/data/com.termux/files/usr/var/service/isgtrigger"
    "sv down /data/data/com.termux/files/usr/var/service/isg-credential-services"
    "sv down /data/data/com.termux/files/usr/var/service/isg-adb-server"
    "sv down /data/data/com.termux/files/usr/var/service/messageproxy"
)

for cmd in "${TERMUX_STOP_CMDS[@]}"; do
    run_adb "run-as com.termux $cmd" 2>/dev/null || true
done

# =============================================================================
# Summary
# =============================================================================
log ""
log "=== Cleanup Complete ==="
log ""
log "Saved files:"
log "  device_props.txt       - Full device property list"
log "  installed_packages.txt - All installed packages"
log ""
log "Next steps:"
log "  1. SSH into the device (ssh root@$DEVICE_IP -p 8022)"
log "  2. Run: bash cleanup-termux.sh --aggressive"
log "  3. Reboot: adb reboot"
log ""
log "To re-enable a disabled package:"
log "  adb -s $DEVICE_IP:5555 shell pm enable <package-name>"
