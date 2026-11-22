# OpenCore EFI — Lenovo LOQ 15IAX9E (83LK)

Cấu hình **OpenCore (`DBG-109-2026-10-23`)** đã thử nghiệm và hoạt động trên **macOS Sequoia 15.8.1 (24H32)** với tăng tốc đồ họa **Intel UHD Graphics (`0x468B`, Metal 2, 1536 MB VRAM)** qua **WhateverXe** bản vá cho Alder Lake-HX và đầy đủ **Bluetooth Intel (`2.5.0`)**.

---

## Thông số phần cứng đã kiểm tra

| Thành phần | Phần cứng | Trạng thái | Ghi chú |
| --- | --- | --- | --- |
| **Máy** | Lenovo LOQ 15IAX9E (`83LK`) | Hoạt động | SMBIOS `MacBookPro16,2` |
| **CPU** | Intel Core i5-12450HX (12th Gen) | Hoạt động | `CpuTopologyRebuild` + `CpuTscSync` |
| **iGPU** | Intel UHD Graphics (`8086:468B`, rev `0x0C`) | Hoạt động | `WhateverXe 0.8.3` (patched), Metal 2, 1536 MB, chỉnh sáng `AppleBacklightDisplay` |
| **dGPU** | NVIDIA RTX (tắt bằng SSDT) | Đã vô hiệu hóa | `SSDT-Disable_GPU_PEG1.aml` |
| **Màn hình** | Internal eDP `BOE NE156FHM-NX9` (`1920x1080`) | Hoạt động | Hỗ trợ PWM backlight & chế độ eDP nội bộ |
| **Wi-Fi** | Intel CNVi (`8086:7AF0` / `8086:0274`) | Hoạt động | `AirportItlwm 2.4.0` (Sequoia `24.2.0`–`24.99.99`) |
| **Bluetooth** | Intel Wireless Bluetooth (`8087:0026`) | Hoạt động | `IntelBluetoothFirmware 2.5.0` + `IntelBTPatcher 2.5.0` + `BlueToolFixup 2.7.3` |
| **Âm thanh** | Intel Audio (`8086:7AE0` / `AppleALC`, `layout-id = 18`) | Hoạt động | Loa ngoài, tai nghe, mic tích hợp |
| **Mạng dây** | Realtek RTL8168H/8111H Gigabit Ethernet | Hoạt động | `RealtekRTL8111 3.0.0` |
| **Touchpad / Phím** | I2C HID (`Magic Trackpad 2`) + PS/2 Keyboard | Hoạt động | `VoodooI2C 2.9.1` + `VoodooI2CHID 1.0` + `VoodooPS2Controller 2.3.8` |
| **NVMe** | `SAMSUNG MZAMX512HCLV-00BL2` (`512 GB`) | Hoạt động | `NVMeFix 1.1.4` |
| **Pin / SMC** | VirtualSMC + YogaSMC | Hoạt động | `VirtualSMC 1.3.9` + `SMCBatteryManager` + `YogaSMC 1.5.3` |

> **Lưu ý tính năng Apple:** Card mạng/Bluetooth Intel hỗ trợ mạng Wi-Fi và ghép nối tai nghe/chuột/phím Bluetooth bình thường, nhưng **AirDrop / Handoff / Continuity** không hoạt động như card Broadcom gốc.

---

## Điểm khác biệt & bản vá quan trọng trong repo này

1. **Bản vá `WhateverXe 0.8.3` cho Lenovo LOQ 12th/13th Gen HX (`0x468B` / `0x4688`):**
   - Xem file nguồn patch tại [`patches/WhateverXe-0.8.3-LOQ-ADL-HX.patch`](patches/WhateverXe-0.8.3-LOQ-ADL-HX.patch).
   - Bỏ kiểm tra bit fuse `0x42000 & 0x01000000` (luôn bằng `0` trên dòng HX dù PG1 `0x45404 & 1` và mạch PWM vẫn hoạt động), tránh lỗi đen màn `0xe00002d8` (`LightUpEDP` / `DDI0`).
   - Thêm `wrapADLSCDClockProbe` để lập trình lại CDCLK hợp lệ (`disableCDClock` + `setCDClockFrequency`) khi UEFI GOP để tần số ngoài bảng Apple.
   - Thêm `wrapADLSSetMode` để đảm bảo nguồn panel (`hwSetPanelPower(2)`), CDCLK PLL, DBUF (`0x45008`/`0x44FE8`) và `AUX A` (`0x45444`) được bật trước `hwSetMode`.
   - Thêm boot-arg `-nodisplaysleepDC6` trong `config.plist` (`-allow3d -disablegfxfirmware -igfxdvmt -nodisplaysleepDC6 keepsyms=1`).

2. **Bluetooth Intel trên macOS Sequoia (`24.x`):**
   - Dùng `IntelBluetoothFirmware.kext` và `IntelBTPatcher.kext` phiên bản **`2.5.0`** (build từ nhánh `master` của `OpenIntelWireless/IntelBluetoothFirmware`, hỗ trợ Sequoia `24.x` và `descriptor->prepare(kIODirectionOut)`), đi kèm `BlueToolFixup.kext` **`2.7.3`**.
   - Thứ tự kext trong `Kernel -> Add`: `Lilu` -> `IntelBluetoothFirmware` -> `IntelBTPatcher` -> `BlueToolFixup`.
   - NVRAM đã khai báo sẵn `bluetoothExternalDongleFailed` và `bluetoothInternalControllerInfo` (trong cả `Add` và `Delete`).

---

## Yêu cầu bắt buộc khi cài mới với WhateverXe

Bản `EFI` này dùng `WhateverXe` + `AMFIAnchor` (tăng tốc iGPU Intel Gen 12 trên Sequoia) nên **cần thêm gói driver graphics của WhateverXe**:

1. **Bước 1 (Tạo SMBIOS riêng):**
   - Các trường `MLB`, `SystemSerialNumber`, `SystemUUID`, `ROM` trong `EFI/OC/config.plist` và `EFI/OC/config-safe-7mb.plist` đã được ẩn bằng giá trị mẫu để bảo mật.
   - Hãy dùng **[GenSMBIOS](https://github.com/corpnewt/GenSMBIOS)** tạo bộ SMBIOS **`MacBookPro16,2`** mới và điền vào `PlatformInfo -> Generic` trước khi đăng nhập Apple ID / iCloud.
2. **Bước 2 (Lần boot đầu nếu chưa cài WhateverXe Graphics pkg):**
   - Trong `EFI/OC/` có sẵn **`config-safe-7mb.plist`** (chế độ VESA 7MB an toàn, vẫn giữ Bluetooth `2.5.0`). Nếu máy chưa cài `WhateverXe-Graphics-0.4.4.pkg` trong `/Library/Extensions`, hãy boot tạm bằng `config-safe-7mb.plist` trước.
   - Cài **`WhateverXe-Graphics-0.4.4.pkg`** (payload gồm `AppleIntelTGLCompat.kext`, `AppleIntelTGLGraphics.kext`, `AppleIntelTGLGraphicsFramebuffer.kext` và `/Library/GPUBundles`), cho phép System Extension / xây dựng lại AuxKC theo hướng dẫn của WhateverXe.
3. **Bước 3 (Boot với WhateverXe):**
   - Đảm bảo `EFI/OC/config.plist` đang là bản WhateverXe chính.
   - Tại menu OpenCore, chọn **Reset NVRAM** 1 lần rồi boot vào macOS.

---

## Danh sách Kext chính đang bật

- **Core & Graphics:** `Lilu 1.7.3`, `AMFIAnchor 0.1.2`, `AMFIAnchorInjector 1.0.0`, `WhateverXe 0.8.3` *(patched)*, `BrightnessKeys 1.0.4`
- **CPU / Power / NVMe:** `CpuTscSync 1.1.2`, `CpuTopologyRebuild 2.0.2`, `VirtualSMC 1.3.9` (`SMCBatteryManager`, `SMCLightSensor`, `SMCProcessor`, `SMCSuperIO`), `YogaSMC 1.5.3`, `NVMeFix 1.1.4`, `RestrictEvents 1.1.7`
- **Network & Bluetooth:** `AirportItlwm 2.4.0`, `RealtekRTL8111 3.0.0`, `IntelBluetoothFirmware 2.5.0`, `IntelBTPatcher 2.5.0`, `BlueToolFixup 2.7.3`
- **Audio & Input / USB:** `AppleALC 1.9.9` (`layout-id = 18`), `VoodooI2C 2.9.1` + `VoodooI2CHID 1.0`, `VoodooPS2Controller 2.3.8`, `USBToolBox 1.2.0` + `UTBMap 1.1`, `XHCI-unsupported 0.9.2`

*(Kext dự phòng khi dùng `config-safe-7mb.plist`: `WhateverGreen`)*

---

## Mẹo tối ưu Sleep & Chuột ngoài

- **Tắt Hibernate để Sleep/Wake ổn định hơn trên macOS:**
  ```zsh
  sudo pmset -a hibernatemode 0 standby 0 autopoweroff 0 powernap 0
  ```
- **Chuột ngoài cuộn ngược:** Vào **System Settings -> Mouse** tắt **Natural scrolling** (hoặc dùng **Mos** / **LinearMouse** để tách riêng hướng cuộn của chuột và touchpad).

---

## Tác giả

- **Tên:** Kiệt
- **Email:** kiet2711207@gmail.com
