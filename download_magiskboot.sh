#!/bin/bash

# ==============================================================================
# Magiskboot Downloader and Extractor for Linux x86_64
# ==============================================================================

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$WORKSPACE_DIR/bin"
MAGISKBOOT_PATH="$BIN_DIR/magiskboot"

echo "===================================================="
echo "Downloading and Extracting official magiskboot..."
echo "===================================================="

if [ -f "$MAGISKBOOT_PATH" ]; then
    echo "magiskboot already exists at $MAGISKBOOT_PATH."
    echo "Skipping download."
    exit 0
fi

mkdir -p "$BIN_DIR"

# Download the latest Magisk APK using curl from github release
echo "Fetching latest Magisk release metadata..."
LATEST_TAG=$(curl -s https://api.github.com/repos/topjohnwu/Magisk/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_TAG" ]; then
    echo "Failed to fetch latest tag name, falling back to Magisk v27.0..."
    LATEST_TAG="v27.0"
fi

APK_URL="https://github.com/topjohnwu/Magisk/releases/download/${LATEST_TAG}/Magisk-${LATEST_TAG}.apk"

echo "Downloading Magisk APK from: $APK_URL"
curl -L -o "$BIN_DIR/magisk.apk" "$APK_URL"

if [ $? -ne 0 ] || [ ! -f "$BIN_DIR/magisk.apk" ]; then
    echo "Error: Failed to download Magisk APK."
    exit 1
fi

echo "Extracting libmagiskboot.so from APK..."
unzip -p "$BIN_DIR/magisk.apk" "lib/x86_64/libmagiskboot.so" > "$MAGISKBOOT_PATH"

if [ $? -eq 0 ] && [ -f "$MAGISKBOOT_PATH" ] && [ -s "$MAGISKBOOT_PATH" ]; then
    chmod +x "$MAGISKBOOT_PATH"
    rm -f "$BIN_DIR/magisk.apk"
    echo "===================================================="
    echo "Successfully installed magiskboot to:"
    echo "$MAGISKBOOT_PATH"
    echo "===================================================="
else
    echo "Error: Extraction failed."
    rm -f "$BIN_DIR/magisk.apk"
    exit 1
fi
