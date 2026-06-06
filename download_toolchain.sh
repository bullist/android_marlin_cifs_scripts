#!/bin/bash

# ==============================================================================
# Toolchain Downloader for Pixel 1 (sailfish) Kernel Build
# ==============================================================================

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLCHAIN_DIR="$WORKSPACE_DIR/toolchain"
TOOLCHAIN_ARM32_DIR="$WORKSPACE_DIR/toolchain_arm32"
TAG="android-10.0.0_r1"

echo "===================================================="
echo "Downloading GCC 4.9 Toolchains (64-bit & 32-bit)..."
echo "===================================================="

# Helper function to clone a toolchain properly
clone_toolchain() {
    local repo_url="$1"
    local dest_dir="$2"
    local name="$3"

    # If the directory exists but doesn't have the compiler binary, wipe it
    if [ -d "$dest_dir" ]; then
        if [ ! -f "$dest_dir/bin/${name}-gcc" ]; then
            echo "Existing $name directory is invalid or empty. Cleaning up..."
            rm -rf "$dest_dir"
        fi
    fi

    if [ ! -d "$dest_dir" ]; then
        echo "Cloning $name toolchain (tag: $TAG)..."
        git clone --depth 1 -b "$TAG" "$repo_url" "$dest_dir"
        if [ $? -eq 0 ]; then
            echo "Successfully cloned $name."
        else
            echo "Error: Failed to clone $name toolchain."
            return 1
        fi
    else
        echo "$name toolchain is already present."
    fi
    return 0
}

# Clone 64-bit Toolchain
clone_toolchain \
    "https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9" \
    "$TOOLCHAIN_DIR" \
    "aarch64-linux-android"

if [ $? -ne 0 ]; then
    exit 1
fi

# Clone 32-bit Toolchain (Required for compat vDSO)
clone_toolchain \
    "https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9" \
    "$TOOLCHAIN_ARM32_DIR" \
    "arm-linux-androideabi"

if [ $? -ne 0 ]; then
    exit 1
fi

echo "===================================================="
echo "Toolchains successfully downloaded!"
echo "64-bit: $TOOLCHAIN_DIR"
echo "32-bit: $TOOLCHAIN_ARM32_DIR"
echo "===================================================="
