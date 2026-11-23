#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_KEXTS="$REPO_DIR/EFI/OC/Kexts"
MODE="beta"

while [ $# -gt 0 ]; do
    case "$1" in
        --beta) MODE="beta" ;;
        --alpha) MODE="alpha" ;;
        --kexts-dir)
            shift
            [ $# -gt 0 ] || { echo "Missing path after --kexts-dir" >&2; exit 2; }
            SRC_KEXTS="$1"
            ;;
        -h|--help)
            cat <<'EOF'
Usage: install-airdrop.sh [--beta | --alpha] [--kexts-dir PATH]
  Installs ForbiddenItlwm.kext + BTLEAdvFixup.kext from the repo EFI/OC/Kexts
  into the live OPENCORE EFI partition while preserving your existing SMBIOS.
  --beta         Use tested boot-args (default, matches bundled 0.6.0-beta.4)
  --alpha        Also append experimental alpha flags (itlawdlsched=1 -btleadvnodupfilter)
  --kexts-dir    Custom directory containing ForbiddenItlwm.kext and BTLEAdvFixup.kext
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 2
            ;;
    esac
    shift
done

if [ ! -d "$SRC_KEXTS/ForbiddenItlwm.kext" ] || [ ! -d "$SRC_KEXTS/BTLEAdvFixup.kext" ]; then
    echo "ERROR: Missing ForbiddenItlwm.kext or BTLEAdvFixup.kext in $SRC_KEXTS" >&2
    exit 1
fi

# shellcheck source=efi_common.sh
source "$SCRIPT_DIR/efi_common.sh"
mount_opencore_efi

if [ ! -f "$OC_DIR/config-no-airdrop-backup.plist" ]; then
    cp "$OC_DIR/config.plist" "$OC_DIR/config-no-airdrop-backup.plist"
    echo "Saved clean backup: $OC_DIR/config-no-airdrop-backup.plist"
fi
SNAP="$OC_DIR/config-backup-$(date +%Y%m%d-%H%M%S).plist"
cp "$OC_DIR/config.plist" "$SNAP"
echo "Saved timestamped snapshot: $SNAP"

rm -rf "$KEXT_DIR/ForbiddenItlwm.kext" "$KEXT_DIR/BTLEAdvFixup.kext"
cp -RX "$SRC_KEXTS/ForbiddenItlwm.kext" "$KEXT_DIR/"
cp -RX "$SRC_KEXTS/BTLEAdvFixup.kext" "$KEXT_DIR/"
echo "Installed kexts from $SRC_KEXTS (kept AirportItlwm.kext and IntelBTPatcher.kext on disk for rollback)."

python3 "$SCRIPT_DIR/patch_opencore.py" apply \
    --mode "$MODE" \
    --input "$OC_DIR/config.plist" \
    --output "$OC_DIR/config.plist" \
    --kext-dir "$KEXT_DIR"

plutil -lint "$OC_DIR/config.plist"

cat <<EOF

DONE! AirDrop ($MODE) installed to $OC_DIR.
Next steps:
  1. Reboot macOS (OpenCore NVRAM->Delete refreshes boot-args automatically; Reset NVRAM only if flags don't appear).
  2. Verify after reboot:
       bash "$SCRIPT_DIR/check_compat.sh"
       ifconfig awdl0
  3. To roll back anytime:
       bash "$SCRIPT_DIR/revert-airdrop.sh"
EOF
