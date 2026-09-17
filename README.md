# Google Pixel 1 (sailfish) Custom Kernel & Auto-Mount Integration

This project configures a custom kernel and a user-space daemon stack for a rooted Google Pixel 1 (sailfish) running **LineageOS 22.2 (Android 15)**. It serves as an automated gateway to bridge network storage with local Android applications (like Google Photos/Immich) while handling specific hardware faults and battery safety configurations.

---

## 📖 Context & Purpose

> **🚀 NEW TO THIS PROJECT?**  
> **Read the [Full Step-by-Step Setup Guide](FULL_SETUP_GUIDE.md)** for a complete tutorial on how to configure your phone, compile the kernel, and integrate your network share from scratch!

The goal of this project is to repurpose a legacy Google Pixel 1 device to act as an automated photo syncing/display device hooked up directly to a **SMB network library share**. It resolves two distinct challenges:

1. **Network SMB Mount & App Integration**: The custom kernel enables `CONFIG_CIFS` (SMB/CIFS support) to mount the remote library. A custom daemon handles mounting the share directly into the emulated storage directory (`DCIM/Camera`), injecting the mount into the isolated `MediaProvider` mount namespace so standard user applications can access the photos seamlessly.
2. **Battery Swell Prevention**: Since the device is plugged into power continuously, a battery care daemon manages charging. It keeps the battery level strictly between 60% and 70%, with a weekly conditioning charge to 70%, to prevent battery swelling.

---

## 🛠 Key Features

### 1. Custom Linux 4.4 Kernel
* Forked from upstream LineageOS: [bullist/android_kernel_google_marlin_cifs](https://github.com/bullist/android_kernel_google_marlin_cifs) on the `lineage-22.0` branch.
* Patched `arch/arm64/configs/m1s1_defconfig` to:
  * Enable `CONFIG_CIFS`, `CONFIG_CIFS_SMB2`, `CONFIG_CRYPTO_ARC4`, `CONFIG_CRYPTO_MD4` for SMB 3.0 protocol support.
  * Set compiler compatibility flags (`-fcommon`) for modern GCC 10+ compilation.

### 2. Boot Auto-Mount & Namespace Injection (`mount_smb.sh`)
Located in Magisk service directory (`/data/adb/service.d/mount_smb.sh`):
* **FBE Decryption Check**: Waits up to 120 seconds for storage decryption (`sys.boot_completed=1` and `/storage/emulated/0/Android` exists).
* **Network Wait**: Pings the target SMB server (`192.168.1.10`) until reachable before attempting to mount.
* **Namespace Injection**: To bypass Android's mount namespace isolation, the script finds the running `MediaProvider` module's PID (`com.android.providers.media.module`) and injects the mount using `su -t <PID>` for all virtual runtime views (`default`, `read`, `write`).
* **Self-Healing Loop**: Every 30 seconds, a background daemon checks for the existence of a sentinel file (`.immich`) on the mount. If missing, it unmounts and remounts all views automatically.

### 3. MediaStore Sync Daemon
* Since Android's `MediaProvider` uses a java-based recursive walker that crashes at FUSE mount boundaries, a localized sync script runs in the background.
* It scans the mount for files modified slightly longer than the interval and triggers standard media indexation on the individual paths:
  ```bash
  content call --method scan_file --uri content://media --arg "$file"
  ```
* **Configuration**: You can configure this daemon without editing the script by setting standard Android system properties via ADB (they persist across reboots):
  * `adb shell "su -c 'setprop persist.cifs.scan_interval 60'"` (Default: 300 seconds / 5 mins)
  * `adb shell "su -c 'setprop persist.cifs.scan_dir /storage/emulated/0/DCIM/Camera'"` (Default: your mount point)
  * `adb shell "su -c 'setprop persist.cifs.enable_scan 0'"` (Default: 1)

### 4. Battery Care Daemon
* Keeps the phone charging in a safe 60%–70% range.
* Uses the kernel interface:
  ```bash
  echo 0 > /sys/class/power_supply/battery/charging_enabled # Disable
  echo 1 > /sys/class/power_supply/battery/charging_enabled # Enable
  ```
* Weekly conditioning logic forces a full charge cycle up to 70% once every 7 days (based on epoch timestamps stored in `/data/adb/service.d/last_weekly_charge`).

---

## 📁 Repository Structure

* [compile_kernel_4.4.sh](file:///home/bullist/.gemini/antigravity/scratch/sailfish_smb_rom/compile_kernel_4.4.sh): Core build script that downloads GCC compiler toolchains, patches configurations, compiles the kernel source tree, and generates `Image.lz4-dtb`.
* [repack_boot.sh](file:///home/bullist/.gemini/antigravity/scratch/sailfish_smb_rom/repack_boot.sh): Uses `magiskboot` to extract a base `boot.img`, injects the newly compiled kernel, and repacks it into `new-boot.img`.
* [flash_custom_kernel.sh](file:///home/bullist/.gemini/antigravity/scratch/sailfish_smb_rom/flash_custom_kernel.sh): Monitors fastboot connection, flashes `new-boot.img` to both slots (`boot_a`/`boot_b`), sets slot A active, and reboots.
* [device/mount_smb.sh](file:///home/bullist/.gemini/antigravity/scratch/sailfish_smb_rom/device/mount_smb.sh): The target shell script containing the mounting logic, self-healing loop, battery control, and MediaStore scanning.
* [kernel_config/marlin_defconfig](file:///home/bullist/.gemini/antigravity/scratch/sailfish_smb_rom/kernel_config/marlin_defconfig): Defconfig diff patch containing CIFS enablement flags.

---

## 🚀 How to Build and Deploy

### Step 1: Compiling the Kernel
Run the compilation script in your local workspace:
```bash
./compile_kernel_4.4.sh
```
This fetches the cross-compilation toolchains (`aarch64-linux-android-` and `arm-linux-androideabi-`) if they are missing, links them, compiles the kernel source in `kernel_4.4/`, and outputs `Image`.

### Step 2: Repacking the Boot Image
Provide a base LineageOS 22.2 stock/patched `boot.img` to the repacker:
```bash
./repack_boot.sh <path_to_original_boot.img>
```
This produces a repacked flashable boot image at `./new-boot.img`.

### Step 3: Flashing the Kernel
Put the phone into Bootloader mode and run the flashing monitor:
```bash
./flash_custom_kernel.sh
```
This script will detect the device, flash the boot image to both slots, and reboot the system.

### Step 4: Installing the Mount Script
Push the mount script to Magisk's startup folder:
```bash
adb push device/mount_smb.sh /data/adb/service.d/mount_smb.sh
adb shell chmod 755 /data/adb/service.d/mount_smb.sh
```
Upon the next reboot, unlocking the device will decrypt storage and trigger the auto-mount sequence.
