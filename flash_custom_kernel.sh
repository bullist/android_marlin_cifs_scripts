#!/bin/bash
# Helper script to wait for Fastboot mode and flash the custom boot image

KERNEL_IMG="new-boot.img"

echo "===================================================="
echo "Starting Fastboot Flash Monitor..."
echo "Waiting for you to select 'Advanced' -> 'Reboot to bootloader' on the phone..."
echo "===================================================="

# Loop for up to 3 minutes (90 iterations * 2 seconds)
for i in {1..90}; do
  if fastboot devices | grep -q -w "fastboot"; then
    echo ""
    echo "Detected device in Fastboot mode!"
    echo "Flashing custom kernel boot image ($KERNEL_IMG) to both slots..."
    
    echo "Flashing boot_a..."
    fastboot flash boot_a "$KERNEL_IMG"
    if [ $? -ne 0 ]; then
      echo "Error: Failed to flash boot_a."
      exit 1
    fi
    
    echo "Flashing boot_b..."
    fastboot flash boot_b "$KERNEL_IMG"
    if [ $? -ne 0 ]; then
      echo "Error: Failed to flash boot_b."
      exit 1
    fi
    
    echo "Setting Slot A as active..."
    fastboot set_active a
    if [ $? -ne 0 ]; then
      echo "Error: Failed to set active slot."
      exit 1
    fi
    
    echo ""
    echo "===================================================="
    echo "SUCCESS: Custom kernel with audio bypass & CIFS flashed to both slots!"
    echo "===================================================="
    echo "Rebooting the phone now..."
    fastboot reboot
    
    echo "The phone is rebooting into LineageOS 22.2 (Android 15)!"
    echo "Since audio is completely disabled in the kernel, it will bypass the physical hardware crash and boot up stably."
    exit 0
  fi
  
  # Print a dot every 2 seconds to show progress
  echo -n "."
  sleep 2
done

echo ""
echo "Timeout: Fastboot mode not detected. Please select 'Reboot to bootloader' and try again."
exit 1
