#!/system/bin/sh

# ==============================================================================
# SMB Auto-Mount Script for Pixel 1 (sailfish) Custom ROM
# ==============================================================================

# Target Configuration
SERVER_IP="192.168.1.X"             # Replace with your TrueNAS/SMB server IP
SHARE_NAME="your/share/path"       # Replace with your SMB share name (e.g. dockerdata/immich/data/library)
USER="username"                     # Replace with your SMB username
PASS="password"                     # Replace with your SMB password
MOUNT_POINT="DCIM/Camera"

# 1. Wait for boot completion and decrypted storage.
# We check multiple signals to ensure the system is ready:
# - sys.boot_completed property is set to 1
# - /storage/emulated/0/Android directory exists (FUSE is running)
# - Timeout after 120 seconds to prevent getting stuck indefinitely.
BOOT_TIMEOUT=120
BOOT_ELAPSED=0

while [ "$BOOT_ELAPSED" -lt "$BOOT_TIMEOUT" ]; do
    BOOT_PROP=$(getprop sys.boot_completed)
    if [ "$BOOT_PROP" = "1" ] && [ -d "/storage/emulated/0/Android" ]; then
        break
    fi
    sleep 2
    BOOT_ELAPSED=$((BOOT_ELAPSED + 2))
done

# Extra wait to ensure FUSE/vold are fully stabilized
sleep 5

# Disable SELinux enforcement to allow Android apps to read files from the CIFS mount
setenforce 0

# Wait up to 60 seconds for the SMB server to become reachable
for i in $(seq 1 30); do
    if ping -c 1 "$SERVER_IP" >/dev/null 2>&1; then
        break
    fi
    sleep 2
done

# Create mount directories on storage
create_dir() {
    local target_dir="$1"
    mkdir -p "$target_dir"
    chmod 777 "$target_dir"
    chown 1023:1023 "$target_dir"
}

create_dir "/storage/emulated/0/$MOUNT_POINT"
for view in default read write; do
    create_dir "/mnt/runtime/$view/emulated/0/$MOUNT_POINT"
done

# Function to mount to all views in a specific namespace option
mount_views() {
    local ns_opt="$1"
    
    # Mount to /storage/emulated/0/DCIM/Camera
    su $ns_opt -c "mount -t cifs -o \"username=$USER,password=$PASS,vers=3.0,uid=1023,gid=1023,file_mode=0777,dir_mode=0777\" \"//$SERVER_IP/$SHARE_NAME\" \"/storage/emulated/0/$MOUNT_POINT\""
    
    # Mount to runtime views
    for view in default read write; do
        su $ns_opt -c "mount -t cifs -o \"username=$USER,password=$PASS,vers=3.0,uid=1023,gid=1023,file_mode=0777,dir_mode=0777\" \"//$SERVER_IP/$SHARE_NAME\" \"/mnt/runtime/$view/emulated/0/$MOUNT_POINT\""
    done
}

# Get MediaProvider PID robustly
get_mp_pid() {
    local pid=$(ps -ef 2>/dev/null | grep "com.android.providers.media.module" | grep -v grep | awk '{print $2}')
    if [ -z "$pid" ]; then
        pid=$(ps 2>/dev/null | grep "com.android.providers.media.module" | grep -v grep | awk '{print $2}')
    fi
    echo "$pid"
}

# Mount globally and in MediaProvider namespace
do_mount() {
    # 1. Mount globally
    mount_views "-mm"
    
    # 2. Inject mount into MediaProvider's namespace
    local mp_pid=$(get_mp_pid)
    if [ -n "$mp_pid" ]; then
        mount_views "-t $mp_pid"
    fi
}

# Do initial mount
do_mount

# 2. Start background daemon (Battery Monitor + Mount self-healing + Media Scanner)
(
    LAST_CHECK_FILE="/data/adb/service.d/last_weekly_charge"
    FORCE_CHARGE=0
    LOOP_COUNT=0

    while true; do
        # --- PART A: Mount Self-Healing (Every 30 seconds) ---
        # If the mount is missing (checked by looking for .immich file), remount it
        if [ ! -f "/storage/emulated/0/$MOUNT_POINT/.immich" ]; then
            # Cleanly unmount views first to avoid duplicate stacked mount loops
            su -mm -c "umount -l /storage/emulated/0/$MOUNT_POINT"
            for view in default read write; do
                su -mm -c "umount -l /mnt/runtime/$view/emulated/0/$MOUNT_POINT"
            done
            do_mount
        fi

        # --- PART B: Battery Health Monitor (Every 10 minutes / 600 seconds) ---
        # We run this check every 20 loops (20 * 30s = 600s)
        if [ $((LOOP_COUNT % 20)) -eq 0 ]; then
            if [ -f "/sys/class/power_supply/battery/capacity" ]; then
                LEVEL=$(cat /sys/class/power_supply/battery/capacity)
                CURRENT_TIME=$(date +%s)

                # Ensure time is valid (NTP synced) before checking weekly interval
                if [ "$CURRENT_TIME" -gt 1735689600 ]; then
                    if [ -f "$LAST_CHECK_FILE" ]; then
                        LAST_TIME=$(cat "$LAST_CHECK_FILE")
                    else
                        LAST_TIME=0
                    fi

                    DIFF=$((CURRENT_TIME - LAST_TIME))
                    if [ "$DIFF" -ge 604800 ] || [ "$LAST_TIME" -eq 0 ]; then
                        FORCE_CHARGE=1
                    fi
                fi

                if [ "$FORCE_CHARGE" -eq 1 ]; then
                    if [ "$LEVEL" -lt 70 ]; then
                        if [ -f "/sys/class/power_supply/battery/charging_enabled" ]; then
                            echo 1 > /sys/class/power_supply/battery/charging_enabled
                        fi
                        if [ -f "/sys/class/power_supply/battery/battery_charging_enabled" ]; then
                            echo 1 > /sys/class/power_supply/battery/battery_charging_enabled
                        fi
                    else
                        FORCE_CHARGE=0
                        echo "$CURRENT_TIME" > "$LAST_CHECK_FILE"
                        if [ -f "/sys/class/power_supply/battery/charging_enabled" ]; then
                            echo 0 > /sys/class/power_supply/battery/charging_enabled
                        fi
                        if [ -f "/sys/class/power_supply/battery/battery_charging_enabled" ]; then
                            echo 0 > /sys/class/power_supply/battery/battery_charging_enabled
                        fi
                    fi
                else
                    if [ "$LEVEL" -lt 60 ]; then
                        if [ -f "/sys/class/power_supply/battery/charging_enabled" ]; then
                            echo 1 > /sys/class/power_supply/battery/charging_enabled
                        fi
                        if [ -f "/sys/class/power_supply/battery/battery_charging_enabled" ]; then
                            echo 1 > /sys/class/power_supply/battery/battery_charging_enabled
                        fi
                    elif [ "$LEVEL" -ge 70 ]; then
                        if [ -f "/sys/class/power_supply/battery/charging_enabled" ]; then
                            echo 0 > /sys/class/power_supply/battery/charging_enabled
                        fi
                        if [ -f "/sys/class/power_supply/battery/battery_charging_enabled" ]; then
                            echo 0 > /sys/class/power_supply/battery/battery_charging_enabled
                        fi
                    fi
                fi
            fi
        fi

        # --- PART C: Media Scanner (Every 5 minutes / 300 seconds) ---
        # We run this check every 10 loops (10 * 30s = 300s)
        # We search only for files modified in the last 6 minutes (-mmin -6) and scan them
        if [ $((LOOP_COUNT % 10)) -eq 0 ]; then
            if [ -f "/storage/emulated/0/$MOUNT_POINT/.immich" ]; then
                find "/storage/emulated/0/$MOUNT_POINT" -type f -mmin -6 2>/dev/null | while read file; do
                    content call --method scan_file --uri content://media --arg "$file" >/dev/null 2>&1
                done
            fi
        fi

        sleep 30
        LOOP_COUNT=$((LOOP_COUNT + 1))
    done
) &
