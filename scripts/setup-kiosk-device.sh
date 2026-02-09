#!/bin/bash
#
# LinknLink iSG — Full kiosk setup script
# Run from host via: bash setup-kiosk-device.sh [device-ip] [kiosk-url]
#
# This script:
#   1. Connects via ADB
#   2. Installs the kiosk browser APK
#   3. Disables bloatware (safe list — won't break boot)
#   4. Applies performance optimizations
#   5. Stops and cleans up Termux
#   6. Installs WebView overlay (Chromium 74 → modern)
#   7. Installs custom boot animation
#   8. Sets kiosk as default home launcher
#

set -euo pipefail

DEVICE_IP="${1:-192.168.86.112}"
DEVICE="$DEVICE_IP:5555"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APK_PATH="$REPO_DIR/kiosk-browser/app/build/outputs/apk/debug/app-debug.apk"
OVERLAY_APK="$REPO_DIR/webview-overlay/WebViewConfigOverlay.apk"
BOOTANIM_ZIP="$REPO_DIR/boot-animation/bootanimation.zip"
KIOSK_URL="${2:-http://192.168.86.10/kiosk.html}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }

adb_sh() { adb -s "$DEVICE" shell "$1" 2>/dev/null; }

# ─── Connect ──────────────────────────────────────────────────────────────────

log "Connecting to $DEVICE..."
adb connect "$DEVICE" 2>&1 | grep -q "connected" || { err "Cannot connect to $DEVICE"; exit 1; }
sleep 1
log "Connected!"

# ─── Enable persistent wireless ADB ──────────────────────────────────────────

log "Enabling persistent wireless ADB..."
adb_sh "settings put global adb_enabled 1"
adb_sh "setprop persist.adb.tcp.port 5555"

# ─── Install kiosk browser ───────────────────────────────────────────────────

if [ -f "$APK_PATH" ]; then
    log "Installing kiosk browser APK..."
    adb -s "$DEVICE" install -r "$APK_PATH" 2>&1
else
    warn "APK not found at $APK_PATH — skipping install"
fi

# ─── Disable bloatware (SAFE list — tested, won't break boot) ────────────────

log "Disabling bloatware..."

# These are SAFE to disable — device boots fine without them
SAFE_TO_DISABLE=(
    # Vendor bloat
    com.yhk.qeota                          # OTA updates
    com.yhk.rabbit.yhkages                 # Vendor management

    # LinknLink / Termux (we don't need the smart home stack)
    com.linknlink.app.device.isg           # LinknLink launcher
    com.termux                             # Termux terminal

    # Telephony / SMS (no SIM in a wall tablet)
    com.android.mms.service                # MMS
    com.android.simappdialog               # SIM dialog
    com.android.smspush                    # SMS push

    # Unused providers
    com.android.providers.calendar         # Calendar
    com.android.providers.contacts         # Contacts
    com.android.providers.blockednumber    # Blocked numbers
    com.android.providers.userdictionary   # User dictionary
    com.android.providers.downloads.ui     # Downloads UI

    # Security/enterprise (not needed on kiosk)
    com.android.se                         # Secure element
    com.android.certinstaller              # Certificate installer
    com.android.managedprovisioning        # Enterprise provisioning
    com.android.companiondevicemanager     # Companion device

    # Network extras
    com.android.vpndialogs                 # VPN
    com.android.hotspot2                   # Hotspot 2.0
    com.android.pacprocessor               # PAC proxy

    # Misc
    com.android.onetimeinitializer         # One-time init
    com.android.provision                  # Provisioning
    com.android.backupconfirm              # Backup confirm
    com.android.sharedstoragebackup        # Shared storage backup
    com.android.localtransport             # Local backup transport
    com.android.statementservice           # App links verification
    com.android.dynsystem                  # Dynamic system updates
    com.android.settings.intelligence      # Settings search
    com.android.bluetoothmidiservice       # Bluetooth MIDI
    com.android.cts.priv.ctsshim           # CTS test shim
    com.android.cts.ctsshim               # CTS test shim
    com.android.captiveportallogin         # Captive portal

    # Files / documents
    com.google.android.documentsui         # Files app
)

# DO NOT DISABLE (will break boot or critical functions):
#   com.android.phone                  — system_server depends on telephony
#   com.google.android.ext.services    — core Android services
#   com.android.systemui               — needed for display
#   com.android.settings               — needed for system
#   com.android.bluetooth              — keep if BT needed
#   com.android.providers.media        — media scanner, system depends on it
#   com.android.providers.settings     — system settings provider
#   com.android.packageinstaller       — needed to install APKs
#   com.android.keychain               — SSL/TLS depends on it
#   com.android.inputmethod.latin      — keyboard for settings UI
#   com.android.location.fused         — some services depend on it

for pkg in "${SAFE_TO_DISABLE[@]}"; do
    result=$(adb_sh "pm disable-user --user 0 $pkg" 2>&1)
    if echo "$result" | grep -q "new state"; then
        log "  Disabled: $pkg"
    else
        warn "  Skipped: $pkg (not found or already disabled)"
    fi
done

# ─── Performance optimizations ────────────────────────────────────────────────

log "Applying performance settings..."

# Animations OFF
adb_sh "settings put global window_animation_scale 0"
adb_sh "settings put global transition_animation_scale 0"
adb_sh "settings put global animator_duration_scale 0"

# GPU rendering
adb_sh "settings put global force_gpu 1"

# Screen always on, max brightness
adb_sh "settings put global stay_on_while_plugged_in 7"
adb_sh "settings put system screen_off_timeout 2147483647"
adb_sh "settings put system screen_brightness_mode 0"
adb_sh "settings put system screen_brightness 255"

# Disable notifications
adb_sh "settings put global heads_up_notifications_enabled 0"

# Disable auto-updates
adb_sh "settings put global package_verifier_enable 0"
adb_sh "settings put secure install_non_market_apps 1"

# Disable lockscreen
adb_sh "settings put secure lockscreen.disabled 1"

# Minimize background processes
adb_sh "settings put global always_finish_activities 1"
adb_sh "settings put global background_process_limit 2"

# Disable power saving
adb_sh "settings put global low_power 0"
adb_sh "settings put global app_standby_enabled 0"
adb_sh "settings put global adaptive_battery_management_enabled 0"

# Disable usage stats overhead
adb_sh "settings put global netstats_enabled 0"

log "Performance settings applied."

# ─── Stop Termux services ────────────────────────────────────────────────────

log "Stopping Termux services..."
adb_sh "am force-stop com.termux"

# ─── Set kiosk as default home ────────────────────────────────────────────────

log "Setting kiosk browser as default home launcher..."
adb_sh "cmd package set-home-activity com.linknlink.kiosk/.KioskActivity"

# ─── Launch kiosk ─────────────────────────────────────────────────────────────

log "Launching kiosk browser with URL: $KIOSK_URL"
adb_sh "am start -n com.linknlink.kiosk/.KioskActivity --es url '$KIOSK_URL'"

# ─── Install WebView overlay (requires root) ────────────────────────────────

log "Upgrading WebView provider configuration..."
adb -s "$DEVICE" root 2>&1 | grep -q "root" && {
    sleep 2

    if [ -f "$OVERLAY_APK" ]; then
        log "  Pushing WebView overlay..."
        adb -s "$DEVICE" shell "mount -o remount,rw /product" 2>/dev/null
        adb -s "$DEVICE" push "$OVERLAY_APK" /product/overlay/WebViewConfigOverlay.apk 2>&1
        adb -s "$DEVICE" shell "chmod 644 /product/overlay/WebViewConfigOverlay.apk"
        log "  WebView overlay installed (adds com.google.android.webview.dev as provider)"
        warn "  After reboot, install WebView Dev via AuroraStore to complete upgrade"
    else
        warn "  WebView overlay not found at $OVERLAY_APK — run webview-overlay/build.sh first"
    fi
} || warn "Root not available — skipping WebView overlay"

# ─── Install custom boot animation (requires root) ──────────────────────────

if [ -f "$BOOTANIM_ZIP" ]; then
    log "Installing custom boot animation..."
    adb -s "$DEVICE" shell "mount -o remount,rw /product 2>/dev/null; mkdir -p /product/media"
    adb -s "$DEVICE" push "$BOOTANIM_ZIP" /product/media/bootanimation.zip 2>&1
    adb -s "$DEVICE" shell "chmod 644 /product/media/bootanimation.zip"
    # Also push to /data/local as fallback (higher priority on some builds)
    adb -s "$DEVICE" push "$BOOTANIM_ZIP" /data/local/bootanimation.zip 2>&1
    adb -s "$DEVICE" shell "chmod 644 /data/local/bootanimation.zip"
    log "  Boot animation installed"
else
    warn "  Boot animation not found at $BOOTANIM_ZIP — run: cd boot-animation && python3 generate.py"
fi

# ─── Enable unknown sources (for AuroraStore) ───────────────────────────────

adb_sh "settings put secure install_non_market_apps 1"
adb_sh "settings put global install_non_market_apps 1"

# ─── Trim caches ─────────────────────────────────────────────────────────────

adb_sh "pm trim-caches 999999999999"

# ─── Summary ──────────────────────────────────────────────────────────────────

echo ""
log "═══════════════════════════════════════════"
log "  Setup complete!"
log "═══════════════════════════════════════════"
echo ""
log "Memory:"
adb_sh "cat /proc/meminfo | head -3"
echo ""
log "Disk:"
adb_sh "df -h /data"
echo ""
log "WebView status:"
adb_sh "dumpsys webviewupdate | grep 'Current WebView package'"
echo ""
log "To change the kiosk URL:"
echo "  adb -s $DEVICE shell am start -n com.linknlink.kiosk/.KioskActivity --es url \"http://your-url\""
echo ""
log "To open settings on device:"
echo "  Tap top-right corner 5 times quickly"
echo ""
log "To complete WebView upgrade (if overlay was just installed):"
echo "  1. Reboot: adb -s $DEVICE reboot"
echo "  2. Install AuroraStore, then install 'Android System WebView Dev'"
echo "  3. Grant install permission: adb -s $DEVICE shell appops set com.aurora.store.nightly REQUEST_INSTALL_PACKAGES allow"
echo ""
