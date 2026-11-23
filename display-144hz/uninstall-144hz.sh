#!/bin/bash
set -euo pipefail

TARGET_DIR="/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-9e5"
sudo rm -rf "$TARGET_DIR"
echo "Da go Display Override ($TARGET_DIR). Hay Restart may de tro ve EDID 60 Hz mac dinh."
