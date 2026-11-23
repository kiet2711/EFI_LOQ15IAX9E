#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-9e5"
SRC_FILE="$SCRIPT_DIR/DisplayProductID-c29"

if [ ! -f "$SRC_FILE" ]; then
  echo "Khong tim thay file: $SRC_FILE" >&2
  exit 1
fi

sudo mkdir -p "$TARGET_DIR"
sudo cp "$SRC_FILE" "$TARGET_DIR/DisplayProductID-c29"
sudo chown -R root:wheel "$TARGET_DIR"
sudo chmod 755 "$TARGET_DIR"
sudo chmod 644 "$TARGET_DIR/DisplayProductID-c29"

plutil -lint "$TARGET_DIR/DisplayProductID-c29"
ls -la "$TARGET_DIR/DisplayProductID-c29"
echo "Da cai Display Override (60 Hz mac dinh + 120 Hz + 144 Hz)."
echo "Hay Restart may, sau do vao System Settings -> Displays de chon 144 Hz."
