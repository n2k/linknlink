#!/bin/bash
# Build the WebView provider overlay APK.
#
# Prerequisites:
#   - aapt2 (from Android SDK build-tools)
#   - keytool + apksigner (from JDK / Android SDK)
#   - framework-res.apk pulled from device:
#     adb pull /system/framework/framework-res.apk .
#
# Usage:
#   ./build.sh
#
# Output:
#   WebViewConfigOverlay.apk

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

FRAMEWORK_RES="${1:-framework-res.apk}"

if [ ! -f "$FRAMEWORK_RES" ]; then
    echo "Error: $FRAMEWORK_RES not found."
    echo "Pull it from device: adb pull /system/framework/framework-res.apk ."
    exit 1
fi

echo "Compiling resources..."
aapt2 compile --dir res -o compiled.zip

echo "Linking APK..."
aapt2 link \
    -o WebViewConfigOverlay.unsigned.apk \
    -I "$FRAMEWORK_RES" \
    --manifest AndroidManifest.xml \
    compiled.zip

echo "Generating signing key..."
if [ ! -f debug.keystore ]; then
    keytool -genkey -v -keystore debug.keystore \
        -storepass android -alias androiddebugkey -keypass android \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -dname "CN=Debug, OU=Debug, O=Debug, L=Debug, ST=Debug, C=US" 2>/dev/null
fi

echo "Signing APK..."
if command -v apksigner &>/dev/null; then
    cp WebViewConfigOverlay.unsigned.apk WebViewConfigOverlay.apk
    apksigner sign --ks debug.keystore --ks-pass pass:android --key-pass pass:android \
        WebViewConfigOverlay.apk
else
    jarsigner -keystore debug.keystore -storepass android -keypass android \
        -signedjar WebViewConfigOverlay.apk \
        WebViewConfigOverlay.unsigned.apk androiddebugkey
fi

rm -f compiled.zip WebViewConfigOverlay.unsigned.apk
echo "Built: WebViewConfigOverlay.apk ($(wc -c < WebViewConfigOverlay.apk) bytes)"
