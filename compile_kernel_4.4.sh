#!/bin/bash

# ==============================================================================
# Linux 4.4 Kernel Compiler for Pixel 1 (sailfish) Android 15 ROM
# ==============================================================================

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_DIR="$WORKSPACE_DIR/kernel_4.4"
TOOLCHAIN_DIR="$WORKSPACE_DIR/toolchain"
TOOLCHAIN_ARM32_DIR="$WORKSPACE_DIR/toolchain_arm32"
DEFCONFIG_PATCH="$WORKSPACE_DIR/kernel_config/marlin_defconfig"

echo "===================================================="
echo "Preparing Pixel 1 Linux 4.4 Kernel Source Tree..."
echo "===================================================="

# Check if toolchains exist
if [ ! -d "$TOOLCHAIN_DIR" ] || [ ! -d "$TOOLCHAIN_ARM32_DIR" ]; then
    echo "Toolchains missing! Downloading..."
    bash "$WORKSPACE_DIR/download_toolchain.sh"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to fetch toolchains."
        exit 1
    fi
fi

# Clone Kernel 4.4 source if not present
if [ ! -d "$KERNEL_DIR" ]; then
    echo "Cloning LineageOS 22.0 Pixel 1 kernel source..."
    git clone --depth 1 -b lineage-22.0 \
        https://github.com/LineageOS/android_kernel_google_marlin.git "$KERNEL_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to clone kernel repository."
        exit 1
    fi
else
    echo "Kernel 4.4 source directory already exists at $KERNEL_DIR."
fi

echo "===================================================="
echo "Applying CIFS defconfig settings..."
echo "===================================================="

ARCH_DEFCONFIG="$KERNEL_DIR/arch/arm64/configs/m1s1_defconfig"

if [ ! -f "$ARCH_DEFCONFIG" ]; then
    echo "Error: Defconfig not found at $ARCH_DEFCONFIG"
    exit 1
fi

# Backup original defconfig if backup doesn't exist
if [ ! -f "${ARCH_DEFCONFIG}.bak" ]; then
    cp "$ARCH_DEFCONFIG" "${ARCH_DEFCONFIG}.bak"
    echo "Created backup of original defconfig."
fi

# Restore clean defconfig from backup before patching
cp "${ARCH_DEFCONFIG}.bak" "$ARCH_DEFCONFIG"

# Append CIFS config flags
cat "$DEFCONFIG_PATCH" >> "$ARCH_DEFCONFIG"
echo "CIFS options successfully appended to marlin_defconfig!"

echo "===================================================="
echo "Applying GCC 10+ Host Compiler Compatibility Patch..."
echo "===================================================="

# Fix the same yylloc multiple definition linker error in the 4.4 kernel Makefile
MAKEFILE_PATH="$KERNEL_DIR/Makefile"
if [ -f "$MAKEFILE_PATH" ]; then
    sed -i 's/HOSTCFLAGS   = -Wall/HOSTCFLAGS   = -Wall -fcommon/g' "$MAKEFILE_PATH"
    echo "KBUILD_CFLAGS += -w" >> "$MAKEFILE_PATH"
    echo "KBUILD_CPPFLAGS += -w" >> "$MAKEFILE_PATH"
    echo "Patched HOSTCFLAGS and KBUILD_CFLAGS with warning suppression in Makefile."
fi

# Fix potential thermal include error if present
THERMAL_CORE_PATH="$KERNEL_DIR/drivers/thermal/thermal_core.c"
if [ -f "$THERMAL_CORE_PATH" ]; then
    sed -i 's/#include <\.\.\/base\/base\.h>/#include "\.\.\/base\/base\.h"/g' "$THERMAL_CORE_PATH"
    echo "Patched thermal_core.c relative include."
fi

echo "===================================================="
echo "Compiling Linux 4.4 Kernel..."
echo "===================================================="

cd "$KERNEL_DIR" || exit 1

# Export environment variables for arm64 cross-compilation
export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE="$TOOLCHAIN_DIR/bin/aarch64-linux-android-"
export CROSS_COMPILE_ARM32="$TOOLCHAIN_ARM32_DIR/bin/arm-linux-androideabi-"

# Generate config
make m1s1_defconfig

if [ $? -ne 0 ]; then
    echo "Error: 'make m1s1_defconfig' failed."
    exit 1
fi

# Compile the kernel
make -j$(nproc)

if [ $? -eq 0 ]; then
    echo "===================================================="
    echo "SUCCESS: Linux 4.4 Kernel compiled successfully!"
    echo "Compiled Kernel Image: $KERNEL_DIR/arch/arm64/boot/Image.lz4-dtb"
    echo "===================================================="
else
    echo "Error: Kernel build failed."
    exit 1
fi
