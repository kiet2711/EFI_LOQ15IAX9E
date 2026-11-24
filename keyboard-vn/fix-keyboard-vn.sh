#!/bin/bash
set -euo pipefail

# Khắc phục lỗi gõ tiếng Việt trên macOS (mất chữ, loạn số, xung đột bộ gõ) bằng cách:
# 1) Chuyển nguồn nhập hệ thống macOS sang ABC và tắt bộ gõ Tiếng Việt mặc định của Apple.
# 2) Cấu hình OpenKey sang Telex + Unicode và bật fix cho Chromium/Electron/trình duyệt.

BACKUP_ROOT="${HOME}/Library/Application Support/EFI_LOQ15IAX9E/keyboard-vn-backup"
OPENKEY_DOMAIN="com.tuyenmai.openkey"
OPENKEY_PLIST="${HOME}/Library/Preferences/${OPENKEY_DOMAIN}.plist"
OPENKEY_APP="/Applications/OpenKey.app"
STEP_BY_STEP=0
MODE="apply"

usage() {
  cat <<'EOF'
Usage: ./fix-keyboard-vn.sh [--check | --step-by-step | --restore]
  (default)       Đặt macOS về ABC, tắt Apple VietnameseIM và cấu hình OpenKey (Telex + Unicode + Fix Chromium)
  --step-by-step  Áp dụng kèm SendKeyStepByStep=1 (dùng nếu một số app vẫn sót phím)
  --check         Kiểm tra trạng thái nguồn nhập macOS và OpenKey hiện tại (không sửa gì)
  --restore       Khôi phục cấu hình từ bản sao lưu gần nhất
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE="check" ;;
    --step-by-step) STEP_BY_STEP=1 ;;
    --restore) MODE="restore" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Tuỳ chọn không hợp lệ: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

print_status() {
  echo "=== Nguồn nhập macOS (TIS) ==="
  swift -e '
import Carbon
let list = TISCreateInputSourceList(nil, false).takeRetainedValue() as! [TISInputSource]
for src in list {
    guard let idPtr = TISGetInputSourceProperty(src, kTISPropertyInputSourceID) else { continue }
    let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
    let sel = TISGetInputSourceProperty(src, kTISPropertyInputSourceIsSelected)
        .map { Unmanaged<CFBoolean>.fromOpaque($0).takeUnretainedValue() == kCFBooleanTrue } ?? false
    print("  \(id) (selected=\(sel))")
}
'
  echo "=== Cấu hình OpenKey (${OPENKEY_DOMAIN}) ==="
  if [ -f "$OPENKEY_PLIST" ]; then
    plutil -p "$OPENKEY_PLIST" | grep -E 'InputMethod|InputType|CodeTable|FixRecommendBrowser|vFixChromiumBrowser|SendKeyStepByStep' || true
  else
    echo "  (Chưa có $OPENKEY_PLIST)"
  fi
}

if [ "$MODE" = "check" ]; then
  print_status
  exit 0
fi

if [ "$MODE" = "restore" ]; then
  LATEST="$(ls -1dt "${BACKUP_ROOT}"/* 2>/dev/null | head -n 1 || true)"
  if [ -z "$LATEST" ]; then
    echo "Không tìm thấy bản sao lưu nào trong: $BACKUP_ROOT" >&2
    exit 1
  fi
  echo "Đang khôi phục từ: $LATEST"
  pkill -x OpenKey >/dev/null 2>&1 || true
  sleep 0.3
  if [ -f "$LATEST/hitoolbox.plist" ]; then
    defaults import com.apple.HIToolbox "$LATEST/hitoolbox.plist"
  fi
  if [ -f "$LATEST/openkey.plist" ]; then
    cp "$LATEST/openkey.plist" "$OPENKEY_PLIST"
    defaults read "$OPENKEY_DOMAIN" >/dev/null 2>&1 || true
  fi
  if [ -d "$OPENKEY_APP" ]; then
    open -a "$OPENKEY_APP"
  fi
  echo "Đã khôi phục xong. Nếu biểu tượng bàn phím trên thanh menu chưa đổi, hãy Log out rồi đăng nhập lại."
  exit 0
fi

TS="$(date +%Y%m%d-%H%M%S)"
BAK_DIR="${BACKUP_ROOT}/${TS}"
mkdir -p "$BAK_DIR"
defaults export com.apple.HIToolbox "$BAK_DIR/hitoolbox.plist" 2>/dev/null || true
if [ -f "$OPENKEY_PLIST" ]; then
  cp "$OPENKEY_PLIST" "$BAK_DIR/openkey.plist"
fi
echo "Đã sao lưu cấu hình cũ tại: $BAK_DIR"

echo "1) Đang chuyển nguồn nhập macOS sang ABC và tắt Apple VietnameseIM..."
swift -e '
import Carbon
let list = TISCreateInputSourceList(nil, true).takeRetainedValue() as! [TISInputSource]
var abcSrc: TISInputSource?
var vnModes: [TISInputSource] = []
var vnParents: [TISInputSource] = []
for src in list {
    guard let idPtr = TISGetInputSourceProperty(src, kTISPropertyInputSourceID) else { continue }
    let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
    if id == "com.apple.keylayout.ABC" {
        abcSrc = src
    } else if id.hasPrefix("com.apple.inputmethod.VietnameseIM.") {
        vnModes.append(src)
    } else if id == "com.apple.inputmethod.VietnameseIM" {
        vnParents.append(src)
    }
}
guard let abc = abcSrc else {
    fputs("Không tìm thấy com.apple.keylayout.ABC\n", stderr)
    exit(1)
}
let e1 = TISEnableInputSource(abc)
let e2 = TISSelectInputSource(abc)
if e1 != noErr || e2 != noErr {
    fputs("Lỗi bật/chọn ABC: enable=\(e1) select=\(e2)\n", stderr)
    exit(1)
}
for m in vnModes { _ = TISDisableInputSource(m) }
for p in vnParents { _ = TISDisableInputSource(p) }
print("  ABC đã được bật và chọn làm nguồn nhập mặc định.")
'

echo "2) Đang cấu hình OpenKey (Telex, Unicode, FixRecommendBrowser, vFixChromiumBrowser)..."
if pgrep -x OpenKey >/dev/null 2>&1; then
  pkill -x OpenKey || true
  sleep 0.5
fi

defaults write "$OPENKEY_DOMAIN" InputMethod -int 1
defaults write "$OPENKEY_DOMAIN" InputType -int 0
defaults write "$OPENKEY_DOMAIN" CodeTable -int 0
defaults write "$OPENKEY_DOMAIN" FixRecommendBrowser -int 1
defaults write "$OPENKEY_DOMAIN" vFixChromiumBrowser -int 1
defaults write "$OPENKEY_DOMAIN" SendKeyStepByStep -int "$STEP_BY_STEP"

if [ -d "$OPENKEY_APP" ]; then
  open -a "$OPENKEY_APP"
  sleep 1
  echo "  Đã mở lại OpenKey.app."
else
  echo "  Cảnh báo: Chưa thấy /Applications/OpenKey.app."
  echo "  Hãy tải OpenKey tại https://github.com/tuyenvm/OpenKey/releases và cấp quyền Accessibility trong System Settings."
fi

print_status
echo "Hoàn tất sửa cấu hình bàn phím tiếng Việt!"
