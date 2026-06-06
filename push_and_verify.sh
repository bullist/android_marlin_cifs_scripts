#!/bin/bash

# ==============================================================================
# Phone SMB Script Installer & Verification
# ==============================================================================

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "===================================================="
echo "Waiting for ADB Authorization..."
echo "===================================================="
echo "Please unlock your Google Pixel 1 and check the screen."
echo "If a dialog asks to 'Allow USB debugging', please tap 'Allow' or 'Always allow'."
echo ""

# Wait until the device is authorized and connected
adb wait-for-device

echo "Device authorized!"
echo "===================================================="
echo "Step 1: Verifying Kernel CIFS Support..."
echo "===================================================="

CIFS_SUPPORT=$(adb shell "cat /proc/filesystems | grep cifs")

if [ -n "$CIFS_SUPPORT" ]; then
    echo "SUCCESS: Custom kernel is loaded and supports CIFS/SMB!"
else
    echo "Error: CIFS support was not found in the running kernel."
    echo "Please ensure the device booted the correct new-boot.img."
    exit 1
fi

echo "===================================================="
echo "Step 2: Installing Auto-Mount Script..."
echo "===================================================="

# Ensure Magisk directory exists
adb shell "su -c 'mkdir -p /data/adb/service.d/'"

if [ $? -ne 0 ]; then
    echo "Warning: Failed to create Magisk directory using root."
    echo "Is your device rooted with Magisk, and did you grant root access to Shell in Magisk Manager?"
fi

# Push the mount script to temporary storage first, then move to secure partition using root
adb push "$WORKSPACE_DIR/device/mount_smb.sh" /data/local/tmp/mount_smb.sh
adb shell "su -c 'mv /data/local/tmp/mount_smb.sh /data/adb/service.d/mount_smb.sh'"
adb shell "su -c 'chown root:root /data/adb/service.d/mount_smb.sh && chmod 700 /data/adb/service.d/mount_smb.sh'"

if [ $? -eq 0 ]; then
    echo "SUCCESS: Auto-mount script successfully installed to /data/adb/service.d/mount_smb.sh!"
else
    echo "Error: Failed to install script. Ensure ADB Shell has Root permissions in Magisk."
    exit 1
fi

echo "===================================================="
echo "Step 3: Rebooting Device..."
echo "===================================================="
echo "Rebooting the phone to activate automatic SMB mounting..."
adb reboot
echo "Reboot initiated. Once booted, your SMB share will mount at startup!"
echo "===================================================="
