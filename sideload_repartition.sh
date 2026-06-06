#!/bin/bash
# Helper script to wait for sideload mode and flash the repartition zip

REPARTITION_ZIP="repartition-ogpixel-32gb.zip"

echo "===================================================="
echo "Starting Sideload Monitor..."
echo "Waiting for you to select 'Apply update' -> 'Apply from ADB' on the phone..."
echo "===================================================="

# Loop for up to 3 minutes (90 iterations * 2 seconds)
for i in {1..90}; do
  if adb devices | grep -q -w "sideload"; then
    echo ""
    echo "Detected ADB Sideload mode!"
    echo "Sideloading $REPARTITION_ZIP..."
    adb sideload "$REPARTITION_ZIP"
    
    if [ $? -eq 0 ]; then
      echo ""
      echo "===================================================="
      echo "SUCCESS: Repartition zip has been sideloaded!"
      echo "===================================================="
      echo "Next Steps:"
      echo "1. On the phone, go back to the main menu and select 'Advanced' -> 'Reboot to recovery'."
      echo "   (This is required so the recovery kernel re-reads the resized partition table)."
      echo "2. Once recovery reboots, go to 'Factory reset' -> 'Format data/factory reset' -> 'Format data'."
      echo "   (This is required to format the newly resized userdata partition)."
      echo "3. Go back to the main menu, select 'Apply update' -> 'Apply from ADB' to enter sideload mode again."
      echo "4. Once done, tell me so we can flash the main LineageOS ROM!"
      exit 0
    else
      echo "Error: Sideload failed. Please check the USB connection."
      exit 1
    fi
  fi
  
  # Print a dot every 2 seconds to show progress
  echo -n "."
  sleep 2
done

echo ""
echo "Timeout: Sideload mode not detected. Please select 'Apply from ADB' and try again."
exit 1
