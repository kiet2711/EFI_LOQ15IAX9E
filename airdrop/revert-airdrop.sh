#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=efi_common.sh
source "$SCRIPT_DIR/efi_common.sh"
mount_opencore_efi

cp "$OC_DIR/config.plist" "$OC_DIR/config-airdrop-last.plist"

if [ -f "$OC_DIR/config-no-airdrop-backup.plist" ] && plutil -lint "$OC_DIR/config-no-airdrop-backup.plist" >/dev/null; then
    cp "$OC_DIR/config-no-airdrop-backup.plist" "$OC_DIR/config.plist"
    echo "Restored exact backup: $OC_DIR/config-no-airdrop-backup.plist"
else
    echo "No valid config-no-airdrop-backup.plist found; reverting config.plist algorithmically..."
    python3 "$SCRIPT_DIR/patch_opencore.py" revert \
        --input "$OC_DIR/config.plist" \
        --output "$OC_DIR/config.plist" \
        --kext-dir "$KEXT_DIR"
fi

rm -rf "$KEXT_DIR/ForbiddenItlwm.kext" "$KEXT_DIR/BTLEAdvFixup.kext"
plutil -lint "$OC_DIR/config.plist"
echo "DONE! Reverted OPENCORE EFI back to AirportItlwm + IntelBTPatcher. Reboot to take effect."
