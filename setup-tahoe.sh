#!/usr/bin/env bash
set -euo pipefail

# One-shot Tahoe Dual GPU + AirDrop + 144Hz installer for Lenovo LOQ 15IAX9E.
# Automatically detects whether RTX 3050 (10DE) is already visible on PCI:
#   - Phase 1 (pre-reboot): installs 144Hz display override, syncs full Tahoe EFI to OPENCORE, optimizes pmset.
#   - Phase 2 (post-reboot): installs NullMoth v3.1 NVIDIA driver offline using ~/Downloads files.
#   - --upgrade-wex: updates WhateverXe.kext (0.8.6 patched) + WhateverXe-Graphics (0.4.5) + safe pmset.
#   - --install-audio: syncs SimpleHDA.kext + nmxaudio=2 configs to OPENCORE and installs SimpleHDA-HAL.
#   - --check: prints live verification for AirDrop, 144Hz display, Audio/Mic, and Dual GPU.

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DL_DIR="${HOME}/Downloads"
NULLMOTH_TGZ="${DL_DIR}/nullmoth-nvidia-3.1.tar.gz"
NV_RUN="${DL_DIR}/NVIDIA-Linux-x86_64-620.70.06.run"
NV_RUN_SHA="29118e3abd08c07559bcca3d9c76238d039490af0362a2e5bcfcbe7204afd4b1"
WEX_PKG="${DL_DIR}/WhateverXe-0.4.5/WhateverXe-Graphics-0.4.5.pkg"
WEX_PKG_URL="https://github.com/b00t0x/WhateverXe-Graphics/releases/download/v0.4.5/WhateverXe-Graphics-0.4.5.pkg"
WEX_PKG_SHA="f6ec2bdcc4d826d9b5be4858da5f4c1b79cc5872ee93ab0ba9abfc3609e9aa37"
SHDA_ZIP="${DL_DIR}/SimpleHDA-Tahoe-v1.0.2-RELEASE.zip"
SHDA_URL="https://github.com/laobamac/SimpleHDA/releases/download/v1.0.2/SimpleHDA-Tahoe-v1.0.2-RELEASE.zip"
SHDA_SHA="4e24a54ea58bc8196c517bd415b263313512832b6e28c455b97e18490a6230f0"

MODE="auto"
while [ $# -gt 0 ]; do
    case "$1" in
        --phase1) MODE="phase1" ;;
        --phase2) MODE="phase2" ;;
        --upgrade-wex) MODE="upgrade-wex" ;;
        --install-audio) MODE="install-audio" ;;
        --check)  MODE="check" ;;
        -h|--help)
            cat <<'EOF'
Usage: ./setup-tahoe.sh [--phase1 | --phase2 | --upgrade-wex | --install-audio | --check]
  (default)        Auto-detect Phase 1 (144Hz + EFI + pmset) or Phase 2 (NullMoth RTX 3050)
  --phase1         Force Phase 1 (Display 144Hz override + OPENCORE EFI sync + SimpleHDA HAL + pmset)
  --phase2         Force Phase 2 (Install NullMoth v3.1 RTX 3050 driver offline)
  --upgrade-wex    Sync patched WhateverXe 0.8.6 to OPENCORE, install WhateverXe-Graphics 0.4.5, apply safe pmset
  --install-audio  Sync SimpleHDA.kext + nmxaudio=2 configs to OPENCORE and install SimpleHDA-HAL 1.0.2
  --check          Verify AirDrop, BOE 144Hz display, Audio/Mic, and Intel + NVIDIA GPUs
EOF
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

apply_tahoe_pmset() {
    echo "Optimizing power management (disabling Hibernate/DarkWake; Battery 5m/10m, AC 20m/30m)..."
    sudo pmset -a hibernatemode 0 standby 0 autopoweroff 0 powernap 0 tcpkeepalive 0 womp 0 proximitywake 0 ttyskeepawake 0
    sudo pmset -b displaysleep 5 sleep 10
    sudo pmset -c displaysleep 20 sleep 30
}

install_wex_graphics() {
    if [ ! -f "$WEX_PKG" ]; then
        echo "Downloading WhateverXe-Graphics-0.4.5.pkg..."
        mkdir -p "$(dirname "$WEX_PKG")"
        curl -fsSL -o "$WEX_PKG" "$WEX_PKG_URL"
    fi
    echo "Verifying WhateverXe-Graphics-0.4.5.pkg SHA-256..."
    ACTUAL_WEX_SHA="$(shasum -a 256 "$WEX_PKG" | awk '{print $1}')"
    if [ "$ACTUAL_WEX_SHA" != "$WEX_PKG_SHA" ]; then
        echo "ERROR: SHA-256 mismatch on $WEX_PKG ($ACTUAL_WEX_SHA != $WEX_PKG_SHA)" >&2
        exit 1
    fi
    echo "Installing WhateverXe-Graphics-0.4.5.pkg (sudo password required; rebuilds AuxKC)..."
    sudo installer -pkg "$WEX_PKG" -target /
}

install_simplehda_hal() {
    if [ ! -f "$SHDA_ZIP" ]; then
        echo "Downloading SimpleHDA-Tahoe-v1.0.2-RELEASE.zip..."
        mkdir -p "$(dirname "$SHDA_ZIP")"
        curl -fsSL -o "$SHDA_ZIP" "$SHDA_URL"
    fi
    echo "Verifying SimpleHDA-Tahoe-v1.0.2-RELEASE.zip SHA-256..."
    ACTUAL_SHDA_SHA="$(shasum -a 256 "$SHDA_ZIP" | awk '{print $1}')"
    if [ "$ACTUAL_SHDA_SHA" != "$SHDA_SHA" ]; then
        echo "ERROR: SHA-256 mismatch on $SHDA_ZIP ($ACTUAL_SHDA_SHA != $SHDA_SHA)" >&2
        exit 1
    fi
    TMP_SHDA="$(mktemp -d /tmp/simplehda-hal.XXXXXX)"
    ditto -xk "$SHDA_ZIP" "$TMP_SHDA"
    HAL_PKG="$(find "$TMP_SHDA" -name 'SimpleHDA-HAL-*.pkg' | head -n 1)"
    if [ -z "$HAL_PKG" ] || [ ! -f "$HAL_PKG" ]; then
        rm -rf "$TMP_SHDA"
        echo "ERROR: SimpleHDA-HAL-*.pkg not found inside $SHDA_ZIP" >&2
        exit 1
    fi
    echo "Installing $(basename "$HAL_PKG") into /Library/Audio/Plug-Ins/SimpleHDA..."
    sudo installer -pkg "$HAL_PKG" -target /
    rm -rf "$TMP_SHDA"
}

sync_oc_configs_preserving_smbios() {
    SNAP="$OC_DIR/config-backup-$(date +%Y%m%d-%H%M%S).plist"
    cp "$OC_DIR/config.plist" "$SNAP"
    echo "Saved live EFI backup: $SNAP"

    cp -f "$REPO_DIR/EFI/OC/config-no-airdrop.plist" "$OC_DIR/config-no-airdrop.plist"
    cp -f "$REPO_DIR/EFI/OC/config-safe-7mb.plist" "$OC_DIR/config-safe-7mb.plist"

    echo "Writing updated config.plist while preserving live SMBIOS..."
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
}

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
    echo "=== 3. Loaded Graphics / AirDrop / Audio Kexts ==="
    kmutil showloaded --list-only 2>/dev/null | grep -iE "whatever|amfi|tgl|nullmoth|nvrm|nvaccel|nmxaudio|simplehda|applealc|applehda|forbidden|btle|bluetool|intelbluetooth|airport" || true
    pkgutil --pkg-info org.b00t0x.WhateverXe.Tahoe 2>/dev/null | grep -E '^(package-id|version):' || true
    pkgutil --pkg-info cn.laobamac.SimpleHDA.HAL 2>/dev/null | grep -E '^(package-id|version):' || true
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
    echo
    echo "=== 7. Audio Devices (Input / Output) ==="
    system_profiler SPAudioDataType || true
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

if [ "$MODE" = "upgrade-wex" ]; then
    echo "============================================================"
    echo " Upgrading WhateverXe (0.8.6 LOQ Patch) + Graphics (0.4.5)"
    echo "============================================================"
    echo
    [ -d "$REPO_DIR/EFI/OC/Kexts/WhateverXe.kext" ] || { echo "ERROR: Missing EFI/OC/Kexts/WhateverXe.kext" >&2; exit 1; }

    echo "[1/3] Mounting OPENCORE EFI partition and updating WhateverXe.kext..."
    # shellcheck source=airdrop/efi_common.sh
    source "$REPO_DIR/airdrop/efi_common.sh"
    mount_opencore_efi
    rm -rf "${KEXT_DIR:?}/WhateverXe.kext"
    cp -RX "$REPO_DIR/EFI/OC/Kexts/WhateverXe.kext" "$KEXT_DIR/"
    echo "Updated $KEXT_DIR/WhateverXe.kext -> $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$KEXT_DIR/WhateverXe.kext/Contents/Info.plist")"

    echo
    echo "[2/3] Upgrading WhateverXe-Graphics to 0.4.5..."
    install_wex_graphics

    echo
    echo "[3/3] Applying Tahoe pmset settings (keep Windows default untouched)..."
    apply_tahoe_pmset

    cat <<'EOF'

============================================================
 UPGRADE COMPLETE!
============================================================
Next steps:
  1. Restart macOS once so WhateverXe 0.8.6 + WhateverXe-Graphics 0.4.5 load cleanly.
  2. After rebooting, verify with:
       ./setup-tahoe.sh --check
EOF
    exit 0
fi

if [ "$MODE" = "install-audio" ]; then
    echo "============================================================"
    echo " Installing SimpleHDA 1.0.2 + nmxaudio=2 (ALC257 Mic/Audio)"
    echo "============================================================"
    echo
    [ -d "$REPO_DIR/EFI/OC/Kexts/SimpleHDA.kext" ] || { echo "ERROR: Missing EFI/OC/Kexts/SimpleHDA.kext" >&2; exit 1; }

    echo "[1/3] Mounting OPENCORE EFI partition and syncing SimpleHDA + configs..."
    # shellcheck source=airdrop/efi_common.sh
    source "$REPO_DIR/airdrop/efi_common.sh"
    mount_opencore_efi
    mkdir -p "$KEXT_DIR"
    rm -rf "${KEXT_DIR:?}/SimpleHDA.kext"
    cp -RX "$REPO_DIR/EFI/OC/Kexts/SimpleHDA.kext" "$KEXT_DIR/"
    sync_oc_configs_preserving_smbios

    echo
    echo "[2/3] Installing SimpleHDA-HAL 1.0.2 (/Library/Audio/Plug-Ins/SimpleHDA)..."
    install_simplehda_hal

    echo
    echo "[3/3] Summary"
    echo "SimpleHDA.kext + nmxaudio=2 + SimpleHDA-HAL 1.0.2 installed."
    cat <<'EOF'

============================================================
 AUDIO SETUP COMPLETE!
============================================================
Next steps:
  1. Restart macOS once so SimpleHDA + AppleALC load with nmxaudio=2.
  2. After rebooting, check Mic/Speakers in System Settings -> Sound or run:
       ./setup-tahoe.sh --check
EOF
    exit 0
fi

if [ "$MODE" = "phase1" ]; then
    echo "============================================================"
    echo " Phase 1: Display 144Hz + Full Tahoe EFI (Dual GPU + AirDrop)"
    echo "============================================================"
    echo
    echo "[1/5] Installing BOE NE156FHM-NX9 Display Override (60/120/144 Hz)..."
    chmod +x "$REPO_DIR/display-144hz/"*.sh "$REPO_DIR/airdrop/"*.sh "$REPO_DIR/airdrop/"*.py
    bash "$REPO_DIR/display-144hz/install-144hz.sh"

    echo
    echo "[2/5] Installing SimpleHDA-HAL 1.0.2..."
    install_simplehda_hal

    echo
    echo "[3/5] Mounting OPENCORE EFI partition and syncing repo EFI..."
    # shellcheck source=airdrop/efi_common.sh
    source "$REPO_DIR/airdrop/efi_common.sh"
    mount_opencore_efi

    mkdir -p "$OC_DIR/ACPI" "$OC_DIR/Kexts" "$OC_DIR/Tools"
    cp -f "$REPO_DIR"/EFI/OC/ACPI/*.aml "$OC_DIR/ACPI/"
    cp -f "$REPO_DIR/EFI/OC/Tools/NullMothSafe.efi" "$OC_DIR/Tools/"

    for kext in "$REPO_DIR"/EFI/OC/Kexts/*.kext; do
        kname="$(basename "$kext")"
        rm -rf "${KEXT_DIR:?}/$kname"
        cp -RX "$kext" "$KEXT_DIR/"
    done

    echo
    echo "[4/5] Syncing OpenCore configs while preserving live SMBIOS..."
    sync_oc_configs_preserving_smbios

    echo
    echo "[5/5] Optimizing power management..."
    apply_tahoe_pmset

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
