#!/bin/bash
# Helper script to wait for sideload mode and flash the main LineageOS ROM

ROM_ZIP="lineage.zip"

echo "===================================================="
echo "Starting ROM Sideload Monitor..."
echo "Waiting for you to reboot recovery, format data, and select 'Apply from ADB'..."
echo "===================================================="

# Loop for up to 5 minutes (150 iterations * 2 seconds)
for i in {1..150}; do
  if adb devices | grep -q -w "sideload"; then
    echo ""
    echo "Detected ADB Sideload mode!"
    echo "Sideloading $ROM_ZIP... (This will take a couple of minutes, please wait)"
    adb sideload "$ROM_ZIP"
    
    if [ $? -eq 0 ]; then
      echo ""
      echo "===================================================="
      echo "SUCCESS: LineageOS ROM has been successfully sideloaded!"
      echo "===================================================="
      echo "Next Steps:"
      echo "1. Do NOT reboot into the system yet! (The stock LineageOS kernel will crash on boot due to the audio IC failure)."
      echo "2. On the phone, go back to the main menu and select 'Advanced' -> 'Reboot to bootloader' to enter Fastboot mode."
      echo "3. Once the phone is in Fastboot mode, tell me so I can flash our custom audio-bypass/CIFS kernel boot images!"
      exit 0
    else
      echo "Error: ROM sideload failed. Please check the USB connection."
      exit 1
    fi
  fi
  
  # Print a dot every 2 seconds to show progress
  echo -n "."
  sleep 2
done

echo ""
echo "Timeout: Sideload mode not detected. Please try again."
exit 1
