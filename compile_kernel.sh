#!/bin/bash

# ==============================================================================
# Kernel Compiler for Pixel 1 (sailfish) Kernel Build
# ==============================================================================

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_DIR="$WORKSPACE_DIR/kernel"
TOOLCHAIN_DIR="$WORKSPACE_DIR/toolchain"
TOOLCHAIN_ARM32_DIR="$WORKSPACE_DIR/toolchain_arm32"
DEFCONFIG_PATCH="$WORKSPACE_DIR/kernel_config/marlin_defconfig"

echo "===================================================="
echo "Preparing Pixel 1 (sailfish) Kernel Source Tree..."
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

# Clone Kernel source if not present (~3-5 mins)
if [ ! -d "$KERNEL_DIR" ]; then
    echo "Cloning Pixel 1 kernel source (branch android-msm-marlin-3.18-android10)..."
    git clone --depth 1 -b android-msm-marlin-3.18-android10 \
        https://android.googlesource.com/kernel/msm "$KERNEL_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to clone kernel repository."
        exit 1
    fi
else
    echo "Kernel source directory already exists at $KERNEL_DIR."
fi

echo "===================================================="
echo "Applying CIFS defconfig settings..."
echo "===================================================="

ARCH_DEFCONFIG="$KERNEL_DIR/arch/arm64/configs/marlin_defconfig"

if [ ! -f "$ARCH_DEFCONFIG" ]; then
    echo "Error: Defconfig not found at $ARCH_DEFCONFIG"
    exit 1
fi

# Backup original defconfig if backup doesn't exist
if [ ! -f "${ARCH_DEFCONFIG}.bak" ]; then
    cp "$ARCH_DEFCONFIG" "${ARCH_DEFCONFIG}.bak"
    echo "Created backup of original defconfig."
fi

# Restore clean defconfig from backup before patching (ensures idempotency)
cp "${ARCH_DEFCONFIG}.bak" "$ARCH_DEFCONFIG"

# Explicitly disable Audio IC configurations in base defconfig to prevent overrides
echo "Disabling Audio IC configurations in marlin_defconfig..."
for cfg in CONFIG_AMP_TFA9888 CONFIG_WCD9335_CODEC CONFIG_SND_SOC_MSM8996 CONFIG_USE_CODEC_MBHC CONFIG_SND_SOC_WCD9335 CONFIG_SND_SOC_WCD_MBHC CONFIG_SND_SOC_WSA881X CONFIG_SND_SOC_WSA881X_SENSORS CONFIG_BTFM_SLIM CONFIG_BTFM_SLIM_WCN3990; do
    sed -i "s/^${cfg}=.*/# ${cfg} is not set/g" "$ARCH_DEFCONFIG"
done

# Append CIFS config flags
cat "$DEFCONFIG_PATCH" >> "$ARCH_DEFCONFIG"
echo "CIFS options successfully appended to marlin_defconfig!"

# Strip generic SPMI/QCOM configs that conflict on 3.18
echo "Cleaning up generic SPMI/QCOM configs for 3.18 compatibility..."
sed -i '/CONFIG_SPMI=/d' "$ARCH_DEFCONFIG"
sed -i '/CONFIG_MFD_SPMI_PMIC=/d' "$ARCH_DEFCONFIG"
sed -i '/CONFIG_RESET_CONTROLLER=/d' "$ARCH_DEFCONFIG"
sed -i '/CONFIG_ARCH_QCOM=/d' "$ARCH_DEFCONFIG"
sed -i '/CONFIG_QCOM_SCM=/d' "$ARCH_DEFCONFIG"
sed -i '/CONFIG_QCOM_SCM_XPU=/d' "$ARCH_DEFCONFIG"

echo "===================================================="
echo "Compiling Kernel..."
echo "===================================================="

cd "$KERNEL_DIR" || exit 1

# Export environment variables for arm64 cross-compilation
export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE="$TOOLCHAIN_DIR/bin/aarch64-linux-android-"
export CROSS_COMPILE_ARM32="$TOOLCHAIN_ARM32_DIR/bin/arm-linux-androideabi-"

# Generate config
make marlin_defconfig

if [ $? -ne 0 ]; then
    echo "Error: 'make marlin_defconfig' failed."
    exit 1
fi

# Compile the kernel using all available CPU threads
make -j$(nproc)

if [ $? -eq 0 ]; then
    echo "===================================================="
    echo "Kernel successfully compiled!"
    echo "Compiled Kernel Image: $KERNEL_DIR/arch/arm64/boot/Image.lz4-dtb"
    echo "===================================================="
else
    echo "Error: Kernel build failed."
    exit 1
fi
