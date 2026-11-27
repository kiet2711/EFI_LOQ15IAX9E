#!/usr/bin/env python3
"""Patch or revert OpenCore config.plist for ForbiddenItlwm AirDrop support."""

from __future__ import annotations

import argparse
import copy
import os
import platform
import plistlib
import sys
from typing import Any

NVRAM_APPLE_GUID = "7C436110-AB2A-4BBB-A880-FE41995C9F82"

# Legacy tested boot-args required for ForbiddenItlwm <= 0.7.0-alpha.1 (0.6.0-beta.4).
# From 0.7.0-alpha.2+, all Wi-Fi AWDL flags are enabled by default and only -btleadv is needed.
TESTED_BOOT_ARGS = [
    "-btleadv",
    "-itlawdlcoexprobe",
    "-itlawdliface",
    "-itlawdlnativeup",
    "-itlawdlcoexrx",
    "-itlawdlcoextx",
    "-itlawdlcoexmulti",
    "-itlawdlcoexdata",
    "-itlawdlmitx",
    "-itlawdlelicit",
    "-itlawdlcaps",
    "-itlawdlsvcmerge",
    "-itlawdlawsync",
    "itlawdlintcoal=4",
    "-itlawdlcoexbatx",
    "-itlawdlcoexpeerpause",
    "-itlawdlcoexbatrace",
    "itlawdltxqueue=4096",
]

ALPHA_EXPERIMENTAL_ARGS = [
    "itlawdlsched=1",
    "-btleadvnodupfilter",
]

AIRDROP_MANAGED_KEXTS = {"BTLEAdvFixup.kext", "ForbiddenItlwm.kext"}

KERNEL_BOUNDS = {
    "tahoe": ("25.0.0", "25.99.99", "Tahoe"),
    "sequoia": ("24.0.0", "24.99.99", "Sequoia"),
    "sonoma": ("23.4.0", "23.99.99", "Sonoma"),
}


def _detect_target(target: str) -> str:
    if target != "auto":
        return target
    if sys.platform == "darwin":
        major = int(platform.release().split(".")[0])
        if major >= 25:
            return "tahoe"
        if major == 24:
            return "sequoia"
        if major == 23:
            return "sonoma"
    return "tahoe"


def _detect_forbidden_version(kext_dir: str | None) -> tuple[int, ...]:
    if not kext_dir:
        return (0, 7, 0)
    plist_path = os.path.join(kext_dir, "ForbiddenItlwm.kext", "Contents", "Info.plist")
    if not os.path.isfile(plist_path):
        return (0, 7, 0)
    with open(plist_path, "rb") as fh:
        info = plistlib.load(fh)
    ver = str(info.get("CFBundleShortVersionString", "0.7.0")).split("-")[0]
    parts = []
    for p in ver.split("."):
        digits = "".join(ch for ch in p if ch.isdigit())
        parts.append(int(digits) if digits else 0)
    return tuple(parts)


def _is_airdrop_token(token: str) -> bool:
    return (
        token in {"-btleadv", "-btleadvnodupfilter"}
        or token.startswith(("itlawdl", "-itlawdl", "itlsched", "-itlsched"))
    )


def _update_boot_args(raw: str, mode: str | None, kext_dir: str | None = None) -> str:
    tokens = [t for t in raw.split() if not _is_airdrop_token(t)]
    if mode == "beta":
        if _detect_forbidden_version(kext_dir) >= (0, 7, 0):
            tokens.append("-btleadv")
        else:
            tokens.extend(TESTED_BOOT_ARGS)
    elif mode == "alpha":
        if _detect_forbidden_version(kext_dir) >= (0, 7, 0):
            tokens.append("-btleadv")
        else:
            tokens.extend(TESTED_BOOT_ARGS)
        tokens.extend(ALPHA_EXPERIMENTAL_ARGS)
    updated = " ".join(tokens)
    if len(updated) >= 1024:
        raise ValueError(
            f"boot-args length {len(updated)} reaches macOS 1024-char limit"
        )
    return updated


def _kext_entry(
    *,
    bundle: str,
    executable: str,
    arch: str,
    min_kernel: str,
    max_kernel: str,
    comment: str,
) -> dict[str, Any]:
    return {
        "Arch": arch,
        "BundlePath": bundle,
        "Comment": comment,
        "Enabled": True,
        "ExecutablePath": executable,
        "MaxKernel": max_kernel,
        "MinKernel": min_kernel,
        "PlistPath": "Contents/Info.plist",
    }


def _validate_kext_dir(entries: list[dict[str, Any]], kext_dir: str) -> None:
    missing: list[str] = []
    for entry in entries:
        if not entry.get("Enabled"):
            continue
        bundle_path = os.path.join(kext_dir, entry["BundlePath"])
        plist_path = os.path.join(bundle_path, entry["PlistPath"])
        if not os.path.isdir(bundle_path) or not os.path.isfile(plist_path):
            missing.append(f"{entry['BundlePath']} (Info.plist missing)")
            continue
        exe_rel = entry.get("ExecutablePath") or ""
        if exe_rel:
            exe_path = os.path.join(bundle_path, exe_rel)
            if not os.path.isfile(exe_path):
                missing.append(f"{entry['BundlePath']}/{exe_rel} (binary missing)")
    if missing:
        raise FileNotFoundError(
            f"Missing enabled kext files in {kext_dir}: " + ", ".join(missing)
        )


def _validate_airdrop_config(cfg: dict[str, Any], kext_dir: str | None) -> None:
    add_list = cfg["Kernel"]["Add"]
    index_by_bundle = {e["BundlePath"]: i for i, e in enumerate(add_list)}

    for required in (
        "Lilu.kext",
        "IntelBluetoothFirmware.kext",
        "BlueToolFixup.kext",
        "BTLEAdvFixup.kext",
        "ForbiddenItlwm.kext",
    ):
        if required not in index_by_bundle or not add_list[index_by_bundle[required]].get("Enabled"):
            raise ValueError(f"Required kext missing or disabled: {required}")

    if index_by_bundle["Lilu.kext"] >= index_by_bundle["BlueToolFixup.kext"]:
        raise ValueError("Lilu.kext must precede BlueToolFixup.kext")
    if index_by_bundle["BlueToolFixup.kext"] >= index_by_bundle["BTLEAdvFixup.kext"]:
        raise ValueError("BTLEAdvFixup.kext must load strictly after BlueToolFixup.kext")

    for conflict in ("IntelBTPatcher.kext", "AirportItlwm.kext"):
        idx = index_by_bundle.get(conflict)
        if idx is not None and add_list[idx].get("Enabled"):
            raise ValueError(f"Conflicting kext must be disabled: {conflict}")

    boot_args = cfg["NVRAM"]["Add"][NVRAM_APPLE_GUID].get("boot-args", "")
    if len(boot_args) >= 1024:
        raise ValueError(f"boot-args too long ({len(boot_args)} chars)")

    delete_keys = cfg["NVRAM"]["Delete"].get(NVRAM_APPLE_GUID, [])
    if "boot-args" not in delete_keys:
        raise ValueError("NVRAM -> Delete missing 'boot-args'")

    if kext_dir:
        _validate_kext_dir(add_list, kext_dir)


def apply_airdrop(
    cfg: dict[str, Any],
    mode: str,
    kext_dir: str | None,
    target: str = "auto",
) -> dict[str, Any]:
    out = copy.deepcopy(cfg)
    resolved_target = _detect_target(target)
    min_k, max_k, os_label = KERNEL_BOUNDS[resolved_target]

    nvram_add = out["NVRAM"]["Add"][NVRAM_APPLE_GUID]
    nvram_add["boot-args"] = _update_boot_args(
        nvram_add.get("boot-args", ""), mode, kext_dir
    )

    nvram_del = out["NVRAM"]["Delete"].setdefault(NVRAM_APPLE_GUID, [])
    if "boot-args" not in nvram_del:
        nvram_del.append("boot-args")

    if resolved_target == "tahoe":
        out["Kernel"]["Quirks"]["PowerTimeoutKernelPanic"] = False

    new_add: list[dict[str, Any]] = []
    inserted_btle = False
    for entry in out["Kernel"]["Add"]:
        bp = entry.get("BundlePath", "")
        if bp in AIRDROP_MANAGED_KEXTS:
            continue
        if bp in {"IntelBTPatcher.kext", "AirportItlwm.kext"}:
            entry["Enabled"] = False
        new_add.append(entry)
        if bp == "BlueToolFixup.kext":
            entry["Enabled"] = True
            if not entry.get("MinKernel"):
                entry["MinKernel"] = "21.0.0"
            new_add.append(
                _kext_entry(
                    bundle="BTLEAdvFixup.kext",
                    executable="Contents/MacOS/BTLEAdvFixup",
                    arch="Any",
                    min_kernel=min_k,
                    max_kernel=max_k,
                    comment=f"BTLEAdvFixup ({os_label}) for AirDrop BLE advertising",
                )
            )
            inserted_btle = True

    if not inserted_btle:
        raise ValueError("BlueToolFixup.kext not found in Kernel -> Add")

    new_add.append(
        _kext_entry(
            bundle="ForbiddenItlwm.kext",
            executable="Contents/MacOS/ForbiddenItlwm",
            arch="x86_64",
            min_kernel=min_k,
            max_kernel=max_k,
            comment=f"ForbiddenItlwm ({mode}, {os_label}) for AirDrop/AWDL",
        )
    )
    out["Kernel"]["Add"] = new_add
    _validate_airdrop_config(out, kext_dir)
    return out


def revert_airdrop(cfg: dict[str, Any], kext_dir: str | None) -> dict[str, Any]:
    out = copy.deepcopy(cfg)
    nvram_add = out["NVRAM"]["Add"][NVRAM_APPLE_GUID]
    nvram_add["boot-args"] = _update_boot_args(nvram_add.get("boot-args", ""), None)

    reverted_add: list[dict[str, Any]] = []
    for entry in out["Kernel"]["Add"]:
        bp = entry.get("BundlePath", "")
        if bp in AIRDROP_MANAGED_KEXTS:
            continue
        if bp in {"IntelBTPatcher.kext", "AirportItlwm.kext"}:
            entry["Enabled"] = True
        reverted_add.append(entry)
    out["Kernel"]["Add"] = reverted_add

    if kext_dir:
        _validate_kext_dir(reverted_add, kext_dir)
    return out


def _atomic_write_plist(path: str, data: dict[str, Any]) -> None:
    tmp = f"{path}.tmp.{os.getpid()}"
    with open(tmp, "wb") as fh:
        plistlib.dump(data, fh, sort_keys=False)
    os.replace(tmp, path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_apply = sub.add_parser("apply", help="Enable ForbiddenItlwm AirDrop config")
    p_apply.add_argument("--mode", choices=("beta", "alpha"), default="beta")
    p_apply.add_argument(
        "--target", choices=("auto", "tahoe", "sequoia", "sonoma"), default="auto"
    )
    p_apply.add_argument("--input", required=True)
    p_apply.add_argument("--output", required=True)
    p_apply.add_argument("--kext-dir", default=None)

    p_revert = sub.add_parser("revert", help="Restore pre-AirDrop config")
    p_revert.add_argument("--input", required=True)
    p_revert.add_argument("--output", required=True)
    p_revert.add_argument("--kext-dir", default=None)

    args = parser.parse_args()
    with open(args.input, "rb") as fh:
        cfg = plistlib.load(fh)

    if args.cmd == "apply":
        result = apply_airdrop(cfg, args.mode, args.kext_dir, args.target)
    else:
        result = revert_airdrop(cfg, args.kext_dir)

    _atomic_write_plist(args.output, result)
    print(f"OK: {args.cmd} -> {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
