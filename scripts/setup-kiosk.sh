#!/bin/bash
# =============================================================================
# LinknLink iSG Kiosk Browser Setup (run from host via ADB)
#
# Purpose: Configure the iSG as a kiosk device displaying a single URL.
#          Run this AFTER cleanup-adb.sh.
#
# Usage:   bash setup-kiosk.sh <device-ip> <kiosk-url> [--browser <apk-path>]
#
# Examples:
#   bash setup-kiosk.sh 192.168.1.100 https://dashboard.example.com
#   bash setup-kiosk.sh 192.168.1.100 http://192.168.1.50:8123 --browser fully-kiosk.apk
#
# Browser options:
#   1. Fully Kiosk Browser (recommended, commercial license ~$7/device)
#      - Download from: https://www.fully-kiosk.com/
#      - Best kiosk features: remote admin, auto-restart, screensaver
#
#   2. Hermit (free, lightweight)
#      - Turns any website into a lite app
#
#   3. Custom WebView APK (build your own, see webview-kiosk/ directory)
# =============================================================================

set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: $0 <device-ip> <kiosk-url> [--browser <apk-path>]"
    exit 1
fi

DEVICE_IP="$1"
KIOSK_URL="$2"
BROWSER_APK=""

shift 2
while [ $# -gt 0 ]; do
    case "$1" in
        --browser) BROWSER_APK="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

ADB="adb -s $DEVICE_IP:5555"

log() { echo "[$(date '+%F %T')] $*"; }

# Connect
log "Connecting to $DEVICE_IP..."
adb connect "$DEVICE_IP:5555" 2>&1 || true
sleep 2

# =============================================================================
# Step 1: Install kiosk browser if provided
# =============================================================================
if [ -n "$BROWSER_APK" ]; then
    if [ -f "$BROWSER_APK" ]; then
        log "Installing kiosk browser: $BROWSER_APK"
        $ADB install -r "$BROWSER_APK"
    else
        log "ERROR: APK not found: $BROWSER_APK"
        exit 1
    fi
fi

# =============================================================================
# Step 2: Display settings for wall-mounted screen
# =============================================================================
log "Configuring display for wall-mount kiosk..."

# Keep screen on permanently (plugged in)
$ADB shell settings put global stay_on_while_plugged_in 7
$ADB shell settings put system screen_off_timeout 2147483647

# Disable lock screen
$ADB shell settings put secure lockscreen.disabled 1 2>/dev/null || true

# Disable navigation bar hints
$ADB shell settings put global policy_control "immersive.full=*" 2>/dev/null || true

# Disable all animations
$ADB shell settings put global window_animation_scale 0
$ADB shell settings put global transition_animation_scale 0
$ADB shell settings put global animator_duration_scale 0

# =============================================================================
# Step 3: Create a boot script to launch the kiosk URL
# =============================================================================
log "Setting up auto-launch for: $KIOSK_URL"

# Launch URL in default browser (or Fully Kiosk if installed)
$ADB shell "am start -a android.intent.action.VIEW -d '$KIOSK_URL'" 2>/dev/null || true

log ""
log "=== Kiosk Setup Complete ==="
log ""
log "The device will open: $KIOSK_URL"
log ""
log "For a production kiosk setup, consider:"
log "  1. Install Fully Kiosk Browser for auto-restart, remote admin, screensaver"
log "  2. Set the kiosk browser as the default launcher"
log "  3. Use 'adb shell dpm set-device-owner' for full lockdown (factory reset required)"
log ""
log "To verify: adb -s $DEVICE_IP:5555 shell dumpsys window | grep mCurrentFocus"
