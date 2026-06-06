#!/bin/bash

# ==============================================================================
# boot.img Repacker for Pixel 1 (sailfish) Kernel injection
# ==============================================================================

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$WORKSPACE_DIR/bin"
MAGISKBOOT_PATH="$BIN_DIR/magiskboot"

if [ -f "$WORKSPACE_DIR/kernel_4.4/arch/arm64/boot/Image" ]; then
    COMPILED_KERNEL="$WORKSPACE_DIR/kernel_4.4/arch/arm64/boot/Image"
    echo "Selected custom Linux 4.4 kernel."
else
    COMPILED_KERNEL="$WORKSPACE_DIR/kernel/arch/arm64/boot/Image"
    echo "Selected custom Linux 3.18 kernel."
fi

echo "===================================================="
echo "Pixel 1 (sailfish) boot.img Repacker"
echo "===================================================="

# Check if original boot.img is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <path_to_original_boot.img>"
    exit 1
fi

ORIGINAL_BOOT="$(realpath "$1")"

if [ ! -f "$ORIGINAL_BOOT" ]; then
    echo "Error: Original boot image not found at $ORIGINAL_BOOT"
    exit 1
fi

# Ensure magiskboot exists
if [ ! -f "$MAGISKBOOT_PATH" ]; then
    echo "magiskboot not found! Downloading..."
    bash "$WORKSPACE_DIR/download_magiskboot.sh"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to obtain magiskboot."
        exit 1
    fi
fi

# Ensure compiled kernel exists
if [ ! -f "$COMPILED_KERNEL" ]; then
    echo "Error: Compiled kernel not found at $COMPILED_KERNEL"
    echo "Please run compile_kernel.sh first!"
    exit 1
fi

# Create a temporary working directory
TEMP_DIR="$WORKSPACE_DIR/repack_temp"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR" || exit 1

# Copy boot.img and tools
cp "$ORIGINAL_BOOT" "./boot.img"
cp "$MAGISKBOOT_PATH" "./magiskboot"

echo "Unpacking original boot image..."
./magiskboot unpack boot.img

if [ $? -ne 0 ]; then
    echo "Error: Failed to unpack boot.img. Is it a valid boot image?"
    cd "$WORKSPACE_DIR" || exit 1
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Replace the unpacked kernel with our custom one
echo "Injecting custom kernel with SMB/CIFS support..."
if [ -f "kernel" ]; then
    cp "$COMPILED_KERNEL" "kernel"
    echo "Kernel replaced successfully."
    if [ -f "kernel_dtb" ] && [ -f "$WORKSPACE_DIR/custom_pruned_kernel_dtb" ]; then
        cp "$WORKSPACE_DIR/custom_pruned_kernel_dtb" "kernel_dtb"
        echo "Pruned DTB replaced successfully."
    fi
else
    echo "Error: Unpacked boot image does not contain a standard 'kernel' component!"
    cd "$WORKSPACE_DIR" || exit 1
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "Repacking boot image..."
./magiskboot repack boot.img

if [ $? -eq 0 ] && [ -f "new-boot.img" ]; then
    mv "new-boot.img" "$WORKSPACE_DIR/new-boot.img"
    echo "===================================================="
    echo "SUCCESS: Re-packed boot image generated!"
    echo "Flashable Boot Image: $WORKSPACE_DIR/new-boot.img"
    echo "===================================================="
    echo "To test without flashing:"
    echo "  fastboot boot new-boot.img"
    echo ""
    echo "To flash permanently:"
    echo "  fastboot flash boot new-boot.img"
    echo "===================================================="
else
    echo "Error: Failed to repack boot image."
    exit 1
fi

# Cleanup
cd "$WORKSPACE_DIR" || exit 1
rm -rf "$TEMP_DIR"
