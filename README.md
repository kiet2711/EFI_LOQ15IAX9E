# OpenCore EFI — Lenovo LOQ 15IAX9E (83LK) · macOS Tahoe Dual GPU (`Intel UHD` + `NVIDIA RTX 3050`)

Cấu hình **OpenCore (`DBG-109-2026-10-23`)** cho **macOS Tahoe `26.7.3 (25G342)`** (và tương thích Sequoia `15.8.x`), kết hợp đầy đủ:
- **Dual GPU song song:**
  - **iGPU Intel UHD Graphics (`0x468B`, Metal 2, 1536 MB VRAM)** qua **WhateverXe 0.8.3** (bản vá cho Alder Lake-HX) + `WhateverXe-Graphics 0.4.4`, phụ trách màn hình laptop `BOE NE156FHM-NX9` (`60 / 120 / 144 Hz`) và chỉnh sáng `AppleBacklightDisplay`.
  - **dGPU NVIDIA GeForce RTX 3050 6GB Laptop GPU (`10DE:25AC`, Metal 3, 6 GB VRAM)** qua **NullMoth (`v3.1` / `1401.app`)** + `SSDT-PEG1-KeepPower.aml` nhận thẳng lúc boot, phụ trách tăng tốc Metal 3 / tính toán và xuất màn hình ngoài qua **HDMI**.
- **AirDrop / AWDL gốc trên Intel Wi-Fi:** `ForbiddenItlwm 0.7.0-alpha.4 (Tahoe)` + `BTLEAdvFixup 0.9.8 (Tahoe)` *(giữ sẵn `AirportItlwm 2.4.0 Tahoe` làm dự phòng)*.

> **Lưu ý các nhánh trong repo:**
> - `main`: Chỉ dùng Intel UHD (`SSDT-Disable_GPU_PEG1.aml`) cho Sequoia.
> - `airdrop`: Intel-only + AirDrop cho Sequoia + map USB.
> - `dual-gpu-rtx3050`: Dual GPU (`Intel UHD` + `RTX 3050`) + AirDrop + 144 Hz cho Sequoia `15.8.1`.
> - `tahoe` *(nhánh này)*: Full tính năng (**Dual GPU + AirDrop + 144 Hz**) cho **macOS Tahoe `26.7.3 (25G342)`** (`MacBookPro16,1`).

---

## 1. Thông số phần cứng & trạng thái trên macOS Tahoe

| Thành phần | Phần cứng | Trạng thái | Ghi chú |
| --- | --- | --- | --- |
| **Máy** | Lenovo LOQ 15IAX9E (`83LK`) | Hoạt động | SMBIOS `MacBookPro16,1` (được macOS 26 Tahoe hỗ trợ gốc) |
| **CPU** | Intel Core i5-12450HX (12th Gen) | Hoạt động | `CpuTopologyRebuild 2.0.2` + `CpuTscSync 1.1.2` |
| **iGPU** | Intel UHD Graphics (`8086:468B`, rev `0x0C`) | Hoạt động | `WhateverXe 0.8.3` (patched) + `WhateverXe-Graphics 0.4.4`, Metal 2, 1536 MB, chỉnh sáng `AppleBacklightDisplay` |
| **dGPU** | NVIDIA GeForce RTX 3050 6GB Laptop GPU (`10DE:25AC`, sub `17AA:3DA0`) | Hoạt động song song | `SSDT-PEG1-KeepPower.aml` + `AMFIPass 1.4.1` + `NullMoth v3.1` (`NVRM`/`NVAccel`/`NVRMFB`/`NVRMAGDC`), Metal 3, 6 GB VRAM, xuất HDMI |
| **Màn hình** | Internal eDP `BOE NE156FHM-NX9` (`1920x1080`) + HDMI ngoài | Hoạt động | Màn trong `60 / 120 / 144 Hz` (qua [`display-144hz/`](display-144hz/)) trên Intel UHD; HDMI ngoài trên RTX 3050 |
| **Wi-Fi** | Intel CNVi (`8086:7AF0` / `8086:0274`) | Hoạt động | `ForbiddenItlwm 0.7.0-alpha.4 (Tahoe)` (`MinKernel = 25.0.0`, `MaxKernel = 25.99.99`), kèm dự phòng `AirportItlwm 2.4.0` (`laobamac` Tahoe) |
| **Bluetooth** | Intel Wireless Bluetooth (`8087:0026`) | Hoạt động | `IntelBluetoothFirmware 2.5.0` + `BlueToolFixup 2.7.3` + `BTLEAdvFixup 0.9.8 (Tahoe)` *(tắt `IntelBTPatcher` để tránh xung đột hook)* |
| **Âm thanh** | Intel Audio (`8086:7AE0` / `AppleALC`, `layout-id = 18`) | Hoạt động | Loa ngoài, tai nghe, mic tích hợp |
| **Mạng dây** | Realtek RTL8168H/8111H Gigabit Ethernet | Hoạt động | `RealtekRTL8111 3.0.4` |
| **Touchpad / Phím** | I2C HID (`Magic Trackpad 2`) + PS/2 Keyboard | Hoạt động | `VoodooI2C 2.9.1` + `VoodooI2CHID 1.0` + `VoodooPS2Controller 2.3.8` |
| **NVMe** | `SAMSUNG MZAMX512HCLV-00BL2` (`512 GB`) | Hoạt động | `NVMeFix 1.1.4` |
| **Pin / SMC** | VirtualSMC + YogaSMC | Hoạt động | `VirtualSMC 1.3.9` + `SMCBatteryManager` + `YogaSMC 1.5.3` |

---

## 2. Danh sách phần mềm, driver & kext

### A. Driver đồ họa & bộ cài
| Thành phần | Mục đích | Link tải chính thức |
| --- | --- | --- |
| **WhateverXe Graphics (`0.4.4+`)** | Gói `.pkg` cài `AppleIntelTGLCompat`, `AppleIntelTGLGraphics*` cho iGPU Intel vào `/Library/Extensions` & `/Library/GPUBundles` | [b00t0x/WhateverXe-Graphics Releases](https://github.com/b00t0x/WhateverXe-Graphics/releases) |
| **NullMoth NVIDIA Driver + 1401 (`v3.1+`)** | Driver RTX 3050 hỗ trợ macOS 15 & 26 Tahoe (`NVRM`, `NVAccel`, `NVRMFB`, `NVRMAGDC`, `NVMTLDriver`) — `1401-Mac-3.1.zip`, `nullmoth-nvidia-3.1.tar.gz`, `SHA256SUMS.txt` | [nullmoth/nvidia-macos-driver Releases](https://github.com/nullmoth/nvidia-macos-driver/releases) |
| **NVIDIA Linux Runfile (`620.70.06`)** | Cung cấp GSP firmware (`gsp_ga10x.bin`, `ucodes_ga10x.bin`) đúng mã pin của NullMoth `v3.1` | [NVIDIA Linux x86_64 620.70.06](https://us.download.nvidia.com/XFree86/Linux-x86_64/620.70.06/NVIDIA-Linux-x86_64-620.70.06.run) |

### B. Nguồn gốc các Kext chính trên nhánh Tahoe
- **Core & Đồ họa:** `Lilu 1.7.3`, `AMFIAnchor 0.1.2` + `AMFIAnchorInjector 1.0.0`, `AMFIPass 1.4.1`, `WhateverXe 0.8.3` (bản vá [WhateverXe-0.8.3-LOQ-ADL-HX.patch](patches/WhateverXe-0.8.3-LOQ-ADL-HX.patch)), `BrightnessKeys 1.0.4`.
- **Wi-Fi, Bluetooth & AirDrop (Tahoe `25.x`):**
  - `ForbiddenItlwm 0.7.0-alpha.4 (Tahoe)` & `BTLEAdvFixup 0.9.8 (Tahoe)`: https://github.com/retropineaple/ForbiddenItlwm/releases
  - `AirportItlwm 2.4.0 (Tahoe alpha 7204c69)` *(dự phòng khi tắt AirDrop)*: https://github.com/laobamac/itlwm/releases
  - `IntelBluetoothFirmware 2.5.0`, `IntelBTPatcher 2.5.0` *(tắt khi dùng `BTLEAdvFixup`)*, `BlueToolFixup 2.7.3`.

---

## 3. Điểm khác biệt & bản vá quan trọng cho macOS Tahoe

1. **SMBIOS `MacBookPro16,1`:** macOS 26 Tahoe ngừng hỗ trợ `MacBookPro16,2` (Ice Lake), nên chuyển sang `MacBookPro16,1` (đồng thời tương thích cấu hình Dual GPU).
2. **Kích hoạt `PEG1` / `PEGP` (`RTX 3050 10DE:25AC`) + NullMoth `v3.1`:**
   - `SSDT-PEG1-KeepPower.aml` + **6 ACPI Patch** (`PXP_ _OFF->XOFF`, `POFF->XPOF`, `PEGP _OFF->XOFF`, `DL23->XL23`, `PEG1 _STA->XSTA`, `PC00 GC6I->X6CI`), tắt `SSDT-Disable_GPU_PEG1.aml`.
   - `Booter -> Quirks -> ResizeAppleGpuBars = 0` (`64 MB`).
   - `AMFIPass.kext` (`1.4.1`), `csr-active-config = QwoAAA==` (`0x0A43`), `ExposeSensitiveData = 7`, và `NullMothSafe.efi` trong `Misc -> Tools`.
   - `boot-args` đầy đủ: `-allow3d -disablegfxfirmware -igfxdvmt -nodisplaysleepDC6 -autopkgbeta -ibtcompatbeta keepsyms=1 -btleadv nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0`.
3. **AirDrop / AWDL trên Tahoe `26.7.3 (25G342)`:**
   - Dùng `ForbiddenItlwm 0.7.0-alpha.4-Tahoe` + `BTLEAdvFixup 0.9.8-Tahoe` (`MinKernel = 25.0.0`, `MaxKernel = 25.99.99`). Từ `0.7.0-alpha.2+`, chỉ cần cờ `-btleadv` trong `boot-args` và `BTLEAdvFixup 0.9.8` vá thêm lỗi crash `bluetoothd` trên Tahoe `26.7.x`.
   - `Kernel -> Quirks -> PowerTimeoutKernelPanic = False`: Trên Tahoe (`kernel 25.6`), quirk này bật sẽ đổi chuỗi `com.apple` thành `not.apple` làm `pf` tắt `enable_netagent` (`= 0`) khiến AirDrop QUIC bị chậm. *(Nếu máy gặp panic liên quan power timeout khi wake, bật lại `True`).*
4. **Màn hình `BOE NE156FHM-NX9` (`144 Hz / 120 Hz`):**
   - Cài Display Override [`display-144hz/DisplayProductID-c29`](display-144hz/DisplayProductID-c29) vào `/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-9e5/` để macOS nhận đúng tên màn hình `BOE NE156FHM-NX9` và mở khóa tùy chọn `144 Hz` / `120 Hz`.

---

## 4. Hướng dẫn cài nhanh tự động trên máy đã vào macOS Tahoe ([`setup-tahoe.sh`](setup-tahoe.sh))

Script [`setup-tahoe.sh`](setup-tahoe.sh) tự nhận biết máy đang ở Giai đoạn 1 (chưa mở PCI RTX 3050) hay Giai đoạn 2 (đã thấy RTX 3050 sau khi reboot):

1. **Giai đoạn 1** *(cài Display 144Hz + cập nhật EFI Dual GPU & AirDrop vào phân vùng `OPENCORE` giữ nguyên SMBIOS + tối ưu `pmset`)*:
   ```zsh
   chmod +x setup-tahoe.sh
   ./setup-tahoe.sh
   ```
   Sau khi chạy xong, **Restart** máy. Khi vào lại macOS:
   - Vào **System Settings → Displays** chọn **144 Hz** (lúc này màn hình đã nhận `BOE NE156FHM-NX9` và **AirDrop** đã hoạt động).
2. **Giai đoạn 2** *(cài driver NVIDIA NullMoth `v3.1` khi RTX 3050 đã hiện trên PCI)*:
   Đảm bảo `~/Downloads` có `nullmoth-nvidia-3.1.tar.gz` và `NVIDIA-Linux-x86_64-620.70.06.run` (hoặc mở `/Applications/1401.app`), rồi chạy lại:
   ```zsh
   ./setup-tahoe.sh
   ```
   Nếu macOS hiện thông báo phê duyệt System Extension trong **System Settings → Privacy & Security**, bấm **Allow**, sau đó **Restart** thêm 1 lần.
3. **Kiểm tra toàn bộ sau khi hoàn tất:**
   ```zsh
   ./setup-tahoe.sh --check
   ```
   Hoặc kiểm tra thủ công:
   ```zsh
   system_profiler SPDisplaysDataType
   ioreg -r -c AppleIntelFramebuffer | grep -E "IOFBCurrentPixelClock|IOFBCurrentPixelCount"
   /Applications/1401.app/Contents/Resources/nullmoth-metal-devices
   ./airdrop/check_compat.sh
   ifconfig awdl0
   ```

> **Lưu ý khi cập nhật macOS Tahoe (OTA):** Theo khuyến cáo của `ForbiddenItlwm`, trước khi cập nhật macOS qua System Settings hãy boot tạm 1 lần không có `-btleadv` (hoặc dùng `config-no-airdrop.plist`).

---

## 5. Cài từ đầu / Khôi phục & Tiện ích khác

- **Cài trắng macOS lần đầu:** Tạm copy `EFI/OC/config-safe-7mb.plist` → `EFI/OC/config.plist` để cài đặt ở chế độ VESA 7MB, sau đó cài `WhateverXe-Graphics-0.4.4.pkg`, đổi lại `config.plist` chính và Reset NVRAM 1 lần.
- **Tắt AirDrop quay lại `AirportItlwm Tahoe`:** chạy `./airdrop/revert-airdrop.sh` (hoặc đổi sang `EFI/OC/config-no-airdrop.plist`) rồi Restart.
- **Cứu hộ khi lỗi driver NVIDIA:** Tại menu OpenCore chọn **`1401: Start once without NVIDIA driver`** hoặc **`1401: Remove NVIDIA driver`** (`NullMothSafe.efi`).
- **Sửa lỗi gõ Tiếng Việt (`OpenKey` + `ABC`):** Xem [`keyboard-vn/fix-keyboard-vn.sh`](keyboard-vn/fix-keyboard-vn.sh).

---

## Tác giả

- **Tên:** Kiệt
- **Email:** kiet2711207@gmail.com
