# 📱 Pixel 1 (Sailfish/Marlin) NAS Photo Frame: Full Setup Guide

This guide will walk you through turning a legacy Google Pixel 1 into an automated, root-integrated photo frame backed directly by a standard SMB/CIFS network share. 

By the end of this guide, your Pixel will:
1. Bypass the notorious Pixel 1 "Audio IC" hardware crash / bootloop.
2. Trick Android 15 into natively seeing a 10TB+ network share as local storage.
3. Automatically scan new network photos into Google Photos / Immich.
4. Protect against battery swelling by hard-limiting the charge cycle to 60-70%.

---

## 🛑 Prerequisites

* **Hardware**: Google Pixel 1 (Sailfish) or Pixel 1 XL (Marlin)
* **OS**: A Linux PC (Ubuntu/Debian recommended) for compiling the kernel.
* **Storage Server**: A NAS or SMB share on your local network.
* **Pre-installed on Phone**: 
  1. Unlocked Bootloader
  2. LineageOS 22.2 (Android 15) flashed
  3. Magisk installed (for Root access)

---

## 🛠 Phase 1: SMB Server Setup

Before touching the phone, ensure your storage server is ready to accept connections.
1. Create a dedicated user on your SMB server (e.g., `pixel_sync`).
2. Create an SMB share pointing to your photo library (e.g., `dockerdata/immich/data/library`).
3. Ensure the `pixel_sync` user has **Read/Write** permissions to this dataset.

---

## 🧠 Phase 2: Compiling the Custom Hardware-Bypass Kernel

The Google Pixel 1 suffers from a severe manufacturing defect where the motherboard solder cracks near the Audio IC. When the stock kernel tries to initialize the audio drivers, the phone instantly crashes or bootloops. 

We bypass this by compiling a custom kernel that explicitly **disables the audio subsystems** and **enables SMB/CIFS network storage support**.

1. **Clone the Tooling Repository**
   On your Linux PC, clone this script repository:
   ```bash
   git clone https://github.com/bullist/android_marlin_cifs_scripts.git
   cd android_marlin_cifs_scripts
   ```

2. **Clone the Custom Kernel**
   ```bash
   git clone https://github.com/bullist/android_kernel_google_marlin_cifs.git kernel_4.4
   cd kernel_4.4
   git checkout lineage-22.2-audio-bypass
   cd ..
   ```

3. **Compile the Kernel**
   Run the automated compiler script. It will automatically download the necessary ARM toolchains and compile the custom kernel.
   ```bash
   ./compile_kernel_4.4.sh
   ```
   *If successful, this will output a raw kernel file: `kernel_4.4/out/arch/arm64/boot/Image.lz4-dtb`.*

---

## 📦 Phase 3: Repacking and Flashing

Android phones boot from a `boot.img` file, which contains both the kernel and a Ramdisk. We need to inject our custom kernel into your existing LineageOS boot image.

1. **Extract your ROM's Boot Image**
   Extract the `boot.img` from the LineageOS 22.2 installation ZIP you used to flash the phone, and place it in the `android_marlin_cifs_scripts` folder.

2. **Repack the Boot Image**
   Run the repacker script:
   ```bash
   ./repack_boot.sh boot.img
   ```
   *This uses Magisk tools to swap the kernel and outputs `new-boot.img`.*

3. **Flash to the Phone**
   Reboot your phone into Fastboot mode (Hold Power + Volume Down) and connect it via USB.
   ```bash
   ./flash_custom_kernel.sh
   ```
   *Your phone will flash the custom kernel to both slots and reboot. It should now boot successfully without Audio IC kernel panics!*

---

## 🔗 Phase 4: Setting up the CIFS Mount Daemon

Now that the phone supports CIFS, we need to mount the network share. Android 11+ completely overhauled storage using "FUSE Pass-through" namespaces. If you mount a share normally via Root, Android's `MediaProvider` (and Google Photos) won't see the files. 

Our custom script bypasses this by calculating the `MediaProvider` PID and injecting the mount directly into its private namespace.

1. **Configure your Credentials**
   On your PC, open `device/mount_smb.sh` in a text editor.
   Find the configuration block at the top and enter your SMB server details:
   ```bash
   SERVER_IP="192.168.1.10"
   SHARE_NAME="your/share/name"
   USER="pixel_sync"
   PASS="your_password"
   MOUNT_POINT="DCIM/Camera"
   ```

2. **Push the Script to the Phone**
   With the phone booted and connected via USB (with USB Debugging enabled):
   ```bash
   adb push device/mount_smb.sh /data/local/tmp/mount_smb.sh
   adb shell "su -c 'cp /data/local/tmp/mount_smb.sh /data/adb/service.d/mount_smb.sh'"
   adb shell "su -c 'chmod 755 /data/adb/service.d/mount_smb.sh'"
   adb shell "su -c 'rm /data/local/tmp/mount_smb.sh'"
   ```
   *(We push to `/data/adb/service.d/` so Magisk runs it automatically on every boot).*

---

## 🔄 Phase 5: Media Scanner & Battery Configuration

The mount script you just installed runs a background daemon that does two critical things:
1. **Battery Swell Prevention**: It communicates directly with the kernel to completely cut off charging power when the battery hits 70%, and resumes at 60%. Once a week, it does a conditioning charge to 70%.
2. **Network Media Scanner**: SMB shares do not send file-system change notifications (`inotify`) over the network. If you drop a photo onto your SMB share from your PC, the phone won't know it's there. The daemon solves this by scanning the directory in the background.

**Configuring the Scanner:**
You can configure the background media scanner directly from ADB without editing the script.

* Change how often it scans for new network photos (Default is 300 seconds / 5 mins):
  ```bash
  adb shell "su -c 'setprop persist.cifs.scan_interval 60'"
  ```
* Change the directory it looks at:
  ```bash
  adb shell "su -c 'setprop persist.cifs.scan_dir /storage/emulated/0/DCIM/Camera'"
  ```

### 🎉 You're Done!
Reboot the phone one last time. Once you unlock the screen, the daemon will wait for Android's storage to decrypt, connect to your network share, inject the mount into Google Photos, and gracefully manage the battery!
