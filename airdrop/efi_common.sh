#!/usr/bin/env bash
# Shared EFI discovery and mount/unmount helpers for repo AirDrop scripts.

find_opencore_efi() {
    python3 - <<'PY'
import plistlib, subprocess, sys
out = subprocess.check_output(["diskutil", "list", "-plist"])
dl = plistlib.loads(out)
for disk in dl.get("AllDisksAndPartitions", []):
    for part in disk.get("Partitions", []):
        if part.get("VolumeName") == "OPENCORE" and part.get("Content") == "EFI":
            print("/dev/" + part["DeviceIdentifier"])
            sys.exit(0)
sys.exit(1)
PY
}

get_mount_point() {
    python3 - "$1" <<'PY'
import plistlib, subprocess, sys
out = subprocess.check_output(["diskutil", "info", "-plist", sys.argv[1]])
info = plistlib.loads(out)
print(info.get("MountPoint", ""))
PY
}

mount_opencore_efi() {
    EFI_DEV="$(find_opencore_efi || true)"
    if [ -z "$EFI_DEV" ]; then
        echo "ERROR: Could not locate EFI partition named OPENCORE." >&2
        exit 1
    fi
    echo "Found OPENCORE EFI partition: $EFI_DEV"

    WAS_MOUNTED=0
    MNT="$(get_mount_point "$EFI_DEV")"
    cleanup_opencore_efi() {
        if [ "${WAS_MOUNTED:-0}" = "0" ] && [ -n "${MNT:-}" ]; then
            echo "Unmounting $EFI_DEV..."
            sudo diskutil unmount "$EFI_DEV" >/dev/null || true
        fi
    }
    trap cleanup_opencore_efi EXIT

    if [ -n "$MNT" ]; then
        WAS_MOUNTED=1
        echo "Already mounted at: $MNT"
    else
        echo "Mounting $EFI_DEV (sudo password required)..."
        sudo diskutil mount "$EFI_DEV"
        MNT="$(get_mount_point "$EFI_DEV")"
    fi

    OC_DIR="$MNT/EFI/OC"
    KEXT_DIR="$OC_DIR/Kexts"
    if [ -z "$MNT" ] || [ ! -f "$OC_DIR/config.plist" ]; then
        echo "ERROR: $OC_DIR/config.plist not found." >&2
        exit 1
    fi
}
