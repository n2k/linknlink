#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# LinknLink iSG Termux Cleanup Script
# 
# Purpose: Strip down the Termux environment for kiosk browser use.
#          Stops unnecessary services, removes bloat, frees RAM and storage.
#
# Usage:   SSH into the iSG (port 8022), then run:
#          bash cleanup-termux.sh [--dry-run] [--aggressive]
#
# Flags:
#   --dry-run      Show what would be done without making changes
#   --aggressive   Also remove proot Ubuntu, compilers, and dev tools
#
# WARNING: This is destructive. Back up first!
#          The iSG addon manager can re-download most things if needed.
# =============================================================================

set -euo pipefail

DRY_RUN=false
AGGRESSIVE=false
PREFIX="/data/data/com.termux/files/usr"
HOME_DIR="/data/data/com.termux/files/home"

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --aggressive) AGGRESSIVE=true ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

log() { echo "[$(date '+%F %T')] $*"; }
run() {
    if $DRY_RUN; then
        log "[DRY-RUN] $*"
    else
        log "[EXEC] $*"
        eval "$@"
    fi
}

disk_usage() {
    du -sh "$PREFIX" 2>/dev/null | awk '{print $1}'
}

# =============================================================================
# Phase 1: Stop unnecessary services
# =============================================================================
log "=== Phase 1: Stopping unnecessary services ==="

# Services to KEEP (essential for basic device operation):
#   - sshd (remote access)
#   - mosquitto (only if you need MQTT)
#
# Services to STOP:
SERVICES_TO_STOP=(
    hass
    node-red
    zigbee2mqtt
    zwave-js-ui
    matter-server
    matter-bridge
    frpc
    isgdida
    isgelecstat
    isgdatamanager
    isgspacemanager
    isgdevicemanager
    isgtrigger
    isg-credential-services
    isg-adb-server
    messageproxy
)

for svc in "${SERVICES_TO_STOP[@]}"; do
    SVC_DIR="$PREFIX/var/service/$svc"
    if [ -d "$SVC_DIR" ]; then
        log "Stopping and disabling: $svc"
        run "sv down '$SVC_DIR' 2>/dev/null || true"
        run "touch '$SVC_DIR/down'"
    fi
done

# Stop termuxservice-managed services
TERMUX_SERVICES_TO_STOP=(
    mysqld
    isgservicemonitor
)

for svc in "${TERMUX_SERVICES_TO_STOP[@]}"; do
    SVC_DIR="$PREFIX/var/termuxservice/$svc"
    if [ -d "$SVC_DIR" ]; then
        log "Stopping and disabling: $svc (termuxservice)"
        run "sv down '$SVC_DIR' 2>/dev/null || true"
        run "touch '$SVC_DIR/down'"
    fi
done

log ""
log "=== Phase 2: Clearing caches and temp files ==="

# pip cache
run "rm -rf '$HOME_DIR/.cache/pip'"

# npm cache
run "rm -rf '$HOME_DIR/.npm' '$PREFIX/tmp/npm-*'"

# General temp files
run "rm -rf '$PREFIX/tmp/*'"

# Log files
run "find '$PREFIX/var/log' -name '*.log' -o -name 'current' | xargs truncate -s 0 2>/dev/null || true"

# Service monitor logs
run "find '$PREFIX/var/service' -path '*/monitor/*.log' -exec truncate -s 0 {} \; 2>/dev/null || true"

log ""
log "=== Phase 3: Removing unnecessary packages ==="

# Remove dev tools that are never needed on a kiosk device
PACKAGES_TO_REMOVE=(
    # C/C++ toolchain
    clang
    lld
    llvm
    cmake
    make
    autoconf
    automake
    bison

    # Development libraries (headers/static libs)
    libandroid-stub
    libc++

    # Build tools
    pkg-config
    m4
    libtool

    # Not needed for kiosk
    proot-distro
    gawk
    screen
)

for pkg in "${PACKAGES_TO_REMOVE[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        log "Removing package: $pkg"
        run "apt-get remove -y --purge '$pkg' 2>/dev/null || true"
    fi
done

run "apt-get autoremove -y 2>/dev/null || true"
run "apt-get clean 2>/dev/null || true"

if $AGGRESSIVE; then
    log ""
    log "=== Phase 4 (Aggressive): Removing proot Ubuntu ==="
    
    # This is the big one - 85% of the image
    PROOT_DIR="$PREFIX/var/lib/proot-distro"
    if [ -d "$PROOT_DIR" ]; then
        PROOT_SIZE=$(du -sh "$PROOT_DIR" 2>/dev/null | awk '{print $1}')
        log "Removing proot Ubuntu rootfs ($PROOT_SIZE)"
        run "rm -rf '$PROOT_DIR'"
    fi

    log ""
    log "=== Phase 5 (Aggressive): Removing unused service binaries ==="

    # Remove service-specific binaries and data
    DIRS_TO_REMOVE=(
        # Node.js apps (zigbee2mqtt, node-red, zwave-js-ui, matterbridge)
        "$PREFIX/lib/node_modules"
        "$HOME_DIR/.z2m"
        "$HOME_DIR/.node-red"
        "$HOME_DIR/.zwave-js-ui"

        # Python site-packages (HA dependencies)
        "$PREFIX/lib/python3.12/site-packages"

        # MariaDB data
        "$PREFIX/var/lib/mysql"

        # Service manager scripts
        "$HOME_DIR/servicemanager/hass"
        "$HOME_DIR/servicemanager/node-red"
        "$HOME_DIR/servicemanager/zigbee2mqtt"
        "$HOME_DIR/servicemanager/zwave-js-ui"
        "$HOME_DIR/servicemanager/matter-server"
        "$HOME_DIR/servicemanager/matter-bridge"
        "$HOME_DIR/servicemanager/cloudflared"
        "$HOME_DIR/servicemanager/webssh"
        "$HOME_DIR/servicemanager/frpc"

        # ISG proprietary service binaries
        "$PREFIX/var/service/isgdida/isgdida"
        "$PREFIX/var/service/isgtrigger/isgtrigger"
        "$PREFIX/var/service/isgelecstat/isgelecstat"
        "$PREFIX/var/service/isgdatamanager/isgdatamanager"
        "$PREFIX/var/service/isgspacemanager/isgspacemanager"
        "$PREFIX/var/service/isgdevicemanager/isgdevicemanager"
        "$PREFIX/var/service/messageproxy/messageproxy"
        "$PREFIX/var/service/isg-credential-services"
        "$PREFIX/var/service/isg-adb-server"

        # Compiler/dev related libs
        "$PREFIX/lib/clang"
        "$PREFIX/lib/cmake"
        "$PREFIX/include"
        "$PREFIX/share/man"
        "$PREFIX/share/doc"
        "$PREFIX/share/info"
        "$PREFIX/share/locale"

        # pkgconfig files
        "$PREFIX/lib/pkgconfig"
    )

    for dir in "${DIRS_TO_REMOVE[@]}"; do
        if [ -e "$dir" ]; then
            SIZE=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
            log "Removing: $dir ($SIZE)"
            run "rm -rf '$dir'"
        fi
    done
fi

log ""
log "=== Cleanup Complete ==="
log "Termux prefix size: $(disk_usage)"
log ""
log "To see running services: sv status $PREFIX/var/service/*"
log "To see memory usage:     ps aux --sort=-%mem | head -20"
log ""
if ! $AGGRESSIVE; then
    log "TIP: Run with --aggressive to also remove proot Ubuntu, compilers,"
    log "     node_modules, and Python packages (saves ~2+ GB)"
fi
