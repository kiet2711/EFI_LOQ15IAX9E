#!/usr/bin/env bash
set -euo pipefail

# One-shot Tahoe Dual GPU + AirDrop + 144Hz installer for Lenovo LOQ 15IAX9E.
# Automatically detects whether RTX 3050 (10DE) is already visible on PCI:
#   - Phase 1 (pre-reboot): installs 144Hz display override, syncs full Tahoe EFI to OPENCORE, optimizes pmset.
#   - Phase 2 (post-reboot): installs NullMoth v3.1 NVIDIA driver offline using ~/Downloads files.
#   - --check: prints live verification for AirDrop, 144Hz display, and Dual GPU.

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DL_DIR="${HOME}/Downloads"
NULLMOTH_TGZ="${DL_DIR}/nullmoth-nvidia-3.1.tar.gz"
NV_RUN="${DL_DIR}/NVIDIA-Linux-x86_64-620.70.06.run"
NV_RUN_SHA="29118e3abd08c07559bcca3d9c76238d039490af0362a2e5bcfcbe7204afd4b1"

MODE="auto"
while [ $# -gt 0 ]; do
    case "$1" in
        --phase1) MODE="phase1" ;;
        --phase2) MODE="phase2" ;;
        --check)  MODE="check" ;;
        -h|--help)
            cat <<'EOF'
Usage: ./setup-tahoe.sh [--phase1 | --phase2 | --check]
  (default)  Auto-detect Phase 1 (144Hz + EFI + pmset) or Phase 2 (NullMoth RTX 3050)
  --phase1   Force Phase 1 (Display 144Hz override + OPENCORE EFI sync + pmset)
  --phase2   Force Phase 2 (Install NullMoth v3.1 RTX 3050 driver offline)
  --check    Verify AirDrop, BOE 144Hz display, and Intel + NVIDIA GPUs
EOF
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

run_checks() {
    echo "=== 1. Displays & GPUs ==="
    system_profiler SPDisplaysDataType || true
    echo
    echo "=== 2. Refresh Rate & Pixel Clock ==="
    /usr/bin/python3 - <<'PY' || true
import ctypes
cg = ctypes.CDLL('/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics')
cg.CGMainDisplayID.restype = ctypes.c_uint32
cg.CGDisplayCopyDisplayMode.argtypes = [ctypes.c_uint32]
cg.CGDisplayCopyDisplayMode.restype = ctypes.c_void_p
cg.CGDisplayModeGetRefreshRate.argtypes = [ctypes.c_void_p]
cg.CGDisplayModeGetRefreshRate.restype = ctypes.c_double
did = cg.CGMainDisplayID()
mode = cg.CGDisplayCopyDisplayMode(did)
print(f"MainDisplayID=0x{did:x} RefreshRate={cg.CGDisplayModeGetRefreshRate(mode)} Hz")
PY
    ioreg -r -c AppleIntelFramebuffer | grep -E "IOFBCurrentPixelClock|IOFBCurrentPixelCount" || true
    echo
    echo "=== 3. Loaded Graphics / AirDrop Kexts ==="
    kmutil showloaded --list-only 2>/dev/null | grep -iE "whatever|amfi|tgl|nullmoth|nvrm|nvaccel|forbidden|btle|bluetool|intelbluetooth|airport" || true
    echo
    if [ -x /Applications/1401.app/Contents/Resources/nullmoth-metal-devices ]; then
        echo "=== 4. NullMoth Metal Devices ==="
        /Applications/1401.app/Contents/Resources/nullmoth-metal-devices || true
        echo
    fi
    echo "=== 5. AirDrop Compatibility ==="
    bash "$REPO_DIR/airdrop/check_compat.sh" || true
    echo
    echo "=== 6. AWDL Interface ==="
    ifconfig awdl0 2>/dev/null || echo "awdl0 not active yet"
}

if [ "$MODE" = "check" ]; then
    run_checks
    exit 0
fi

if [ "$MODE" = "auto" ]; then
    if ioreg -r -c IOPCIDevice -d 1 | grep -q '"vendor-id" = <de100000>'; then
        if kmutil showloaded --list-only 2>/dev/null | grep -q 'com\.nullmoth\.NVRM'; then
            echo "Detected: RTX 3050 is visible and NullMoth is already loaded."
            run_checks
            exit 0
        fi
        MODE="phase2"
    else
        MODE="phase1"
    fi
fi

if [ "$MODE" = "phase1" ]; then
    echo "============================================================"
    echo " Phase 1: Display 144Hz + Full Tahoe EFI (Dual GPU + AirDrop)"
    echo "============================================================"
    echo
    echo "[1/4] Installing BOE NE156FHM-NX9 Display Override (60/120/144 Hz)..."
    chmod +x "$REPO_DIR/display-144hz/"*.sh "$REPO_DIR/airdrop/"*.sh "$REPO_DIR/airdrop/"*.py
    bash "$REPO_DIR/display-144hz/install-144hz.sh"

    echo
    echo "[2/4] Mounting OPENCORE EFI partition and syncing repo EFI..."
    # shellcheck source=airdrop/efi_common.sh
    source "$REPO_DIR/airdrop/efi_common.sh"
    mount_opencore_efi

    SNAP="$OC_DIR/config-backup-$(date +%Y%m%d-%H%M%S).plist"
    cp "$OC_DIR/config.plist" "$SNAP"
    echo "Saved live EFI backup: $SNAP"

    mkdir -p "$OC_DIR/ACPI" "$OC_DIR/Kexts" "$OC_DIR/Tools"
    cp -f "$REPO_DIR"/EFI/OC/ACPI/*.aml "$OC_DIR/ACPI/"
    cp -f "$REPO_DIR/EFI/OC/Tools/NullMothSafe.efi" "$OC_DIR/Tools/"

    for kext in "$REPO_DIR"/EFI/OC/Kexts/*.kext; do
        kname="$(basename "$kext")"
        rm -rf "${KEXT_DIR:?}/$kname"
        cp -RX "$kext" "$KEXT_DIR/"
    done

    cp -f "$REPO_DIR/EFI/OC/config-no-airdrop.plist" "$OC_DIR/config-no-airdrop.plist"
    cp -f "$REPO_DIR/EFI/OC/config-safe-7mb.plist" "$OC_DIR/config-safe-7mb.plist"

    echo "[3/4] Writing updated config.plist while preserving live SMBIOS..."
    python3 - "$REPO_DIR/EFI/OC/config.plist" "$OC_DIR/config.plist" <<'PY'
import plistlib, sys

src_path, dst_path = sys.argv[1], sys.argv[2]
with open(src_path, "rb") as f:
    src = plistlib.load(f)
with open(dst_path, "rb") as f:
    live = plistlib.load(f)

live_generic = live.get("PlatformInfo", {}).get("Generic")
if isinstance(live_generic, dict) and live_generic.get("SystemProductName"):
    src["PlatformInfo"]["Generic"] = live_generic

with open(dst_path, "wb") as f:
    plistlib.dump(src, f, sort_keys=False)
PY
    plutil -lint "$OC_DIR/config.plist"

    echo
    echo "[4/4] Optimizing power management (disabling Hibernate for sleep/wake)..."
    sudo pmset -a hibernatemode 0 standby 0 autopoweroff 0 powernap 0

    cat <<'EOF'

============================================================
 PHASE 1 COMPLETE!
============================================================
Next steps:
  1. Restart your Mac now (AirDrop Tahoe + BOE 144Hz + RTX 3050 PCI will activate).
     (Optional: choose "Reset NVRAM" once in OpenCore if boot-args don't update.)
  2. After rebooting into macOS:
     - Go to System Settings -> Displays and select 144 Hz.
     - Run this script again to install the NullMoth RTX 3050 driver (Phase 2):
         ./setup-tahoe.sh
       (Or open /Applications/1401.app and click Install.)
EOF
    exit 0
fi

if [ "$MODE" = "phase2" ]; then
    echo "============================================================"
    echo " Phase 2: Installing NullMoth v3.1 RTX 3050 Driver (Offline)"
    echo "============================================================"
    echo
    [ -f "$NULLMOTH_TGZ" ] || { echo "ERROR: Missing $NULLMOTH_TGZ" >&2; exit 1; }
    [ -f "$NV_RUN" ] || { echo "ERROR: Missing $NV_RUN" >&2; exit 1; }

    echo "Verifying NVIDIA-Linux-x86_64-620.70.06.run SHA-256..."
    ACTUAL_SHA="$(shasum -a 256 "$NV_RUN" | awk '{print $1}')"
    if [ "$ACTUAL_SHA" != "$NV_RUN_SHA" ]; then
        echo "ERROR: SHA-256 mismatch on $NV_RUN ($ACTUAL_SHA != $NV_RUN_SHA)" >&2
        exit 1
    fi

    if [ -f "${DL_DIR}/SHA256SUMS.txt" ]; then
        echo "Verifying nullmoth-nvidia-3.1.tar.gz SHA-256..."
        (cd "$DL_DIR" && grep -E ' nullmoth-nvidia-3\.1\.tar\.gz$' SHA256SUMS.txt | shasum -a 256 -c -)
    fi

    TMP_NM="$(mktemp -d /tmp/nullmoth-install.XXXXXX)"
    trap 'rm -rf "$TMP_NM"' EXIT
    tar -xzf "$NULLMOTH_TGZ" -C "$TMP_NM"
    echo "Running NullMoth installer (sudo password required)..."
    (cd "$TMP_NM/pkgroot" && sudo NULLMOTH_FW_RUN="$NV_RUN" ./install.sh)

    cat <<'EOF'

============================================================
 PHASE 2 COMPLETE!
============================================================
Next steps:
  1. If macOS asks in System Settings -> Privacy & Security to Allow
     the NullMoth system extensions, click Allow.
  2. Restart your Mac once more.
  3. After rebooting, verify everything with:
       ./setup-tahoe.sh --check
EOF
fi
