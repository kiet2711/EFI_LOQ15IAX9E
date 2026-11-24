# OpenCore EFI — Lenovo LOQ 15IAX9E (83LK)

Cấu hình **OpenCore (`DBG-109-2026-10-23`)** đã thử nghiệm và hoạt động trên **macOS Sequoia 15.8.1 (24H32)** với tăng tốc đồ họa **Intel UHD Graphics (`0x468B`, Metal 2, 1536 MB VRAM)** qua **WhateverXe** bản vá cho Alder Lake-HX và đầy đủ **Bluetooth Intel (`2.5.0`)**.

---

## 1. Thông số phần cứng đã kiểm tra

| Thành phần | Phần cứng | Trạng thái | Ghi chú |
| --- | --- | --- | --- |
| **Máy** | Lenovo LOQ 15IAX9E (`83LK`) | Hoạt động | SMBIOS `MacBookPro16,2` |
| **CPU** | Intel Core i5-12450HX (12th Gen) | Hoạt động | `CpuTopologyRebuild` + `CpuTscSync` |
| **iGPU** | Intel UHD Graphics (`8086:468B`, rev `0x0C`) | Hoạt động | `WhateverXe 0.8.3` (patched), Metal 2, 1536 MB, chỉnh sáng `AppleBacklightDisplay` |
| **dGPU** | NVIDIA RTX (tắt bằng SSDT) | Đã vô hiệu hóa | `SSDT-Disable_GPU_PEG1.aml` |
| **Màn hình** | Internal eDP `BOE NE156FHM-NX9` (`1920x1080`) | Hoạt động | Hỗ trợ `60 / 120 / 144 Hz` (qua [`display-144hz/`](display-144hz/)), PWM backlight & eDP 4 lane |
| **Wi-Fi** | Intel CNVi (`8086:7AF0` / `8086:0274`) | Hoạt động | `AirportItlwm 2.4.0` (Sequoia `24.2.0`–`24.99.99`) |
| **Bluetooth** | Intel Wireless Bluetooth (`8087:0026`) | Hoạt động | `IntelBluetoothFirmware 2.5.0` + `IntelBTPatcher 2.5.0` + `BlueToolFixup 2.7.3` |
| **Âm thanh** | Intel Audio (`8086:7AE0` / `AppleALC`, `layout-id = 18`) | Hoạt động | Loa ngoài, tai nghe, mic tích hợp |
| **Mạng dây** | Realtek RTL8168H/8111H Gigabit Ethernet | Hoạt động | `RealtekRTL8111 3.0.0` |
| **Touchpad / Phím** | I2C HID (`Magic Trackpad 2`) + PS/2 Keyboard | Hoạt động | `VoodooI2C 2.9.1` + `VoodooI2CHID 1.0` + `VoodooPS2Controller 2.3.8` |
| **NVMe** | `SAMSUNG MZAMX512HCLV-00BL2` (`512 GB`) | Hoạt động | `NVMeFix 1.1.4` |
| **Pin / SMC** | VirtualSMC + YogaSMC | Hoạt động | `VirtualSMC 1.3.9` + `SMCBatteryManager` + `YogaSMC 1.5.3` |

> **Lưu ý tính năng Apple:** Card mạng/Bluetooth Intel hỗ trợ mạng Wi-Fi và ghép nối tai nghe/chuột/phím Bluetooth bình thường, nhưng **AirDrop / Handoff / Continuity** không hoạt động như card Broadcom gốc.

---

## 2. Danh sách những thứ cần tải & Công cụ hỗ trợ

### A. Driver đồ họa rời & Bộ cài macOS (Bắt buộc khi cài mới)

| Thành phần | Mục đích | Link tải chính thức |
| --- | --- | --- |
| **WhateverXe Graphics (`0.4.4+`)** | Gói `.pkg` cài `AppleIntelTGLCompat`, `AppleIntelTGLGraphics*` vào `/Library/Extensions` & `/Library/GPUBundles` (kèm script gỡ `uninstall.sh`) | [b00t0x/WhateverXe-Graphics Releases](https://github.com/b00t0x/WhateverXe-Graphics/releases) |
| **gibMacOS** | Tải trực tiếp `InstallAssistant.pkg` / bản Recovery macOS từ Windows hoặc macOS | [corpnewt/gibMacOS](https://github.com/corpnewt/gibMacOS) |
| **Mist** *(trên macOS)* | Tải bộ cài macOS (`InstallAssistant.pkg` / `.app`) dễ dùng trên macOS | [ninxsoft/Mist Releases](https://github.com/ninxsoft/Mist/releases) |
| **UnPlugged** | Tạo bộ cài macOS offline không cần mạng từ `InstallAssistant.pkg` trên USB/SSD cài đặt | [corpnewt/UnPlugged](https://github.com/corpnewt/UnPlugged) |

### B. Công cụ chỉnh sửa EFI, SMBIOS, Phân vùng & USB

| Công cụ | Mục đích | Link tải chính thức |
| --- | --- | --- |
| **OpenCorePkg** | Nâng cấp OpenCore, dùng `macrecovery` tải recovery và `ocvalidate` kiểm tra lỗi `config.plist` | [acidanthera/OpenCorePkg Releases](https://github.com/acidanthera/OpenCorePkg/releases) |
| **GenSMBIOS** | Tạo `SystemSerialNumber`, `MLB`, `SystemUUID` mới cho `MacBookPro16,2` | [corpnewt/GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) |
| **ProperTree** | Chỉnh sửa `config.plist` trên Windows/macOS, snapshot kext chuẩn xác | [corpnewt/ProperTree](https://github.com/corpnewt/ProperTree) |
| **OC Auxiliary Tools (OCAT)** | *(Tùy chọn)* Chỉnh `config.plist` bằng giao diện trực quan & kiểm tra validation | [ic005k/OCAuxiliaryTools Releases](https://github.com/ic005k/OCAuxiliaryTools/releases) |
| **MountEFI** | Mount nhanh phân vùng EFI trên macOS để chép EFI | [corpnewt/MountEFI](https://github.com/corpnewt/MountEFI) |
| **DiskGenius** *(trên Windows)* | Chia phân vùng ESP `FAT32`, phân vùng cài đặt & chép EFI từ Windows | [DiskGenius Download](https://www.diskgenius.com/download.php) |
| **USBToolBox** *(Windows)* | Map lại cổng USB nếu đổi sang máy/cấu hình khác | [USBToolBox/tool Releases](https://github.com/USBToolBox/tool/releases) |
| **OpenCore Install Guide** | Tài liệu chuẩn của Dortania để tra cứu thêm khi cần | [dortania/OpenCore-Install-Guide](https://github.com/dortania/OpenCore-Install-Guide) |

### C. Công cụ chẩn đoán & Tiện ích nên cài sau khi vào macOS

| Ứng dụng / Công cụ | Mục đích | Link tải chính thức |
| --- | --- | --- |
| **Hackintool** | Kiểm tra PCI ID, iGPU/Metal, USB port, kext đang nạp, NVRAM | [benbaker76/Hackintool Releases](https://github.com/benbaker76/Hackintool/releases) |
| **IORegistryExplorer** | Xem cây IORegistry (`IORegistryClone`) để debug phần cứng/backlight | [khronokernel/IORegistryClone](https://github.com/khronokernel/IORegistryClone) |
| **MaciASL** | Xem, sửa & biên dịch file ACPI `.dsl` / `.aml` | [acidanthera/MaciASL Releases](https://github.com/acidanthera/MaciASL/releases) |
| **Mos** | Đảo riêng hướng cuộn chuột ngoài (giữ nguyên Touchpad) và làm mượt cuộn | [Caldis/Mos Releases](https://github.com/Caldis/Mos/releases) |
| **LinearMouse** | *(Thay thế Mos)* Tùy chỉnh hướng cuộn, tốc độ & bỏ gia tốc chuột ngoài | [linearmouse/linearmouse Releases](https://github.com/linearmouse/linearmouse/releases) |
| **LocalSend** | Gửi/nhận file qua Wi-Fi/LAN giữa macOS, Windows, iOS/Android thay thế AirDrop | [localsend/localsend Releases](https://github.com/localsend/localsend/releases) |
| **OpenKey (`2.0.5+`)** | Bộ gõ Tiếng Việt ổn định thay cho bộ gõ mặc định Apple (kèm script [`keyboard-vn/`](keyboard-vn/)) | [tuyenvm/OpenKey Releases](https://github.com/tuyenvm/OpenKey/releases) |

### D. Nguồn gốc các Kext đang dùng trong EFI *(dùng khi muốn cập nhật phiên bản mới)*

- **Core & Đồ họa:**
  - `Lilu 1.7.3`: https://github.com/acidanthera/Lilu/releases
  - `AMFIAnchor 0.1.2` + `AMFIAnchorInjector 1.0.0`: https://github.com/b00t0x/AMFIAnchor/releases
  - `WhateverXe 0.8.3` *(repo này dùng bản tự build có patch cho Lenovo LOQ ADL-HX)*: https://github.com/b00t0x/WhateverXe/releases
  - `WhateverGreen` *(dùng cho file dự phòng `config-safe-7mb.plist`)*: https://github.com/acidanthera/WhateverGreen/releases
  - `BrightnessKeys 1.0.4`: https://github.com/acidanthera/BrightnessKeys/releases
- **CPU / Nguồn / NVMe / SMC:**
  - `VirtualSMC 1.3.9` (`SMCBatteryManager`, `SMCLightSensor`, `SMCProcessor`, `SMCSuperIO`): https://github.com/acidanthera/VirtualSMC/releases
  - `YogaSMC 1.5.3`: https://github.com/zhen-zen/YogaSMC/releases
  - `CpuTscSync 1.1.2`: https://github.com/acidanthera/CpuTscSync/releases
  - `CpuTopologyRebuild 2.0.2`: https://github.com/b00t0x/CpuTopologyRebuild/releases
  - `NVMeFix 1.1.4`: https://github.com/acidanthera/NVMeFix/releases
  - `RestrictEvents 1.1.7`: https://github.com/acidanthera/RestrictEvents/releases
- **Mạng & Bluetooth:**
  - `AirportItlwm 2.4.0` *(bản Sequoia `24.2.0`+ của laobamac)*: https://github.com/laobamac/itlwm/releases *(repo gốc: https://github.com/OpenIntelWireless/itlwm/releases)*
  - `IntelBluetoothFirmware 2.5.0` & `IntelBTPatcher 2.5.0` *(build từ nhánh `master` cho Sequoia `24.x`)*: https://github.com/OpenIntelWireless/IntelBluetoothFirmware/releases
  - `BrcmPatchRAM` (`BlueToolFixup 2.7.3`): https://github.com/acidanthera/BrcmPatchRAM/releases
  - `RealtekRTL8111 3.0.0`: https://github.com/Mieze/RTL8111_driver_for_OS_X/releases
- **Âm thanh, Bàn phím, Touchpad & USB:**
  - `AppleALC 1.9.9` (`layout-id = 18`): https://github.com/acidanthera/AppleALC/releases
  - `VoodooI2C 2.9.1` (`VoodooI2C`, `VoodooI2CHID`, `VoodooGPIO`, `VoodooI2CServices`, `VoodooInput`): https://github.com/VoodooI2C/VoodooI2C/releases
  - `VoodooPS2Controller 2.3.8`: https://github.com/acidanthera/VoodooPS2/releases
  - `USBToolBox 1.2.0` + `UTBMap 1.1`: https://github.com/USBToolBox/kext/releases

---

## 3. Điểm khác biệt & bản vá quan trọng trong repo này

1. **Bản vá `WhateverXe 0.8.3` cho Lenovo LOQ 12th/13th Gen HX (`0x468B` / `0x4688`):**
   - Xem file patch nguồn tại [`patches/WhateverXe-0.8.3-LOQ-ADL-HX.patch`](patches/WhateverXe-0.8.3-LOQ-ADL-HX.patch).
   - Bỏ kiểm tra bit fuse `0x42000 & 0x01000000` (luôn bằng `0` trên dòng HX dù PG1 `0x45404 & 1` và mạch PWM vẫn hoạt động), tránh lỗi đen màn `0xe00002d8` (`LightUpEDP` / `DDI0`).
   - Thêm `wrapADLSCDClockProbe` để lập trình lại CDCLK hợp lệ (`disableCDClock` + `setCDClockFrequency`) khi UEFI GOP để tần số ngoài bảng Apple.
   - Thêm `wrapADLSSetMode` để đảm bảo nguồn panel (`hwSetPanelPower(2)`), CDCLK PLL, DBUF (`0x45008`/`0x44FE8`) và `AUX A` (`0x45444`) được bật trước `hwSetMode`.
   - Thêm boot-arg `-nodisplaysleepDC6` trong `config.plist` (`-allow3d -disablegfxfirmware -igfxdvmt -nodisplaysleepDC6 keepsyms=1`).

2. **Bluetooth Intel trên macOS Sequoia (`24.x`):**
   - Dùng `IntelBluetoothFirmware.kext` và `IntelBTPatcher.kext` phiên bản **`2.5.0`** (build từ nhánh `master` của `OpenIntelWireless/IntelBluetoothFirmware`, hỗ trợ Sequoia `24.x` và `descriptor->prepare(kIODirectionOut)`), đi kèm `BlueToolFixup.kext` **`2.7.3`**.
   - Thứ tự kext trong `Kernel -> Add`: `Lilu` -> `IntelBluetoothFirmware` -> `IntelBTPatcher` -> `BlueToolFixup`.
   - NVRAM đã khai báo sẵn `bluetoothExternalDongleFailed` và `bluetoothInternalControllerInfo` (trong cả `Add` và `Delete`).

---

## 4. Hướng dẫn cài mới từ đầu từng bước

1. **Tạo SMBIOS riêng:**
   - Các trường `MLB`, `SystemSerialNumber`, `SystemUUID`, `ROM` trong `EFI/OC/config.plist` và `EFI/OC/config-safe-7mb.plist` đã được ẩn bằng giá trị mẫu để bảo mật.
   - Dùng **GenSMBIOS** chọn kiểu máy **`MacBookPro16,2`**, mở file `.plist` bằng **ProperTree** và điền vào `PlatformInfo -> Generic` (nên đặt `ROM` là địa chỉ MAC cổng Ethernet thật dạng 6 byte hex nếu cần iServices).
2. **Chuẩn bị phân vùng boot EFI (`FAT32`):**
   - Chép toàn bộ thư mục `EFI` vào gốc phân vùng ESP `FAT32` (dùng **DiskGenius** trên Windows hoặc **MountEFI** / `diskutil` trên macOS).
3. **Cài đặt macOS lần đầu (dùng chế độ an toàn 7MB trước):**
   - Trong `EFI/OC/` có sẵn **`config-safe-7mb.plist`** (boot VESA 7MB an toàn, vẫn có Wi-Fi & Bluetooth `2.5.0`).
   - Nếu ổ đích macOS chưa cài `WhateverXe-Graphics-0.4.4.pkg`, hãy tạm đổi tên `config.plist` -> `config-wex.plist` và copy `config-safe-7mb.plist` -> `config.plist` để cài xong macOS và vào được màn hình chính.
4. **Cài gói Graphics & bật WhateverXe:**
   - Khi đã vào macOS, cài `WhateverXe-Graphics-0.4.4.pkg`:
     ```zsh
     sudo installer -pkg WhateverXe-Graphics-0.4.4.pkg -target /
     ```
     *(Nếu macOS yêu cầu xác nhận System Extension trong Privacy & Security / xây lại kernel cache, làm theo hướng dẫn hiện trên màn hình).*
   - Đổi lại file **`config.plist`** về bản WhateverXe chính (`config-wex.plist` -> `config.plist`).
   - Khởi động lại, tại menu OpenCore chọn **Reset NVRAM** 1 lần rồi boot vào macOS -> kiểm tra **About This Mac** báo `Intel UHD Graphics 1536 MB` là hoàn tất.
5. **Bật tần số quét 144 Hz / 120 Hz cho màn hình nội bộ (nếu cần):**
   - Chạy script có sẵn trong repo rồi Restart (chi tiết xem [Mục 5](#5-kích-hoạt-màn-hình-144-hz--120-hz-boe-ne156fhm-nx9)):
     ```zsh
     ./display-144hz/install-144hz.sh
     ```

---

## 5. Kích hoạt màn hình 144 Hz / 120 Hz (`BOE NE156FHM-NX9`)

- **Nguyên nhân mặc định chỉ hiện 60 Hz:** Panel `BOE NE156FHM-NX9` (`DisplayVendorID=0x09e5`, `DisplayProductID=0x0c29`) đặt timing `60.00 Hz` (`144.52 MHz`) ở Base Block `DTD #0`, còn timing `144.00 Hz` (`346.85 MHz`) nằm trong block mở rộng `0x70` (DisplayID `2.0`, tag `0x22`) nên `CoreDisplay` trên macOS bỏ qua.
- **Cách khắc phục trong repo ([`display-144hz/`](display-144hz/)):**
  - [`display-144hz/DisplayProductID-c29`](display-144hz/DisplayProductID-c29): File Display Override chứa EDID `128 byte` hợp lệ (giữ nguyên ID BOE `9e5:c29`, đặt **`60.00 Hz` ở `DTD #0`** để luôn boot an toàn, thêm **`144.00 Hz` ở `DTD #1`** (`346.85 MHz`) và **`120.00 Hz` ở `DTD #2`** (`289.04 MHz`), cùng dải tần gốc `48–144 Hz`).
  - Driver `AppleIntelTGLGraphicsFramebuffer` + `WhateverXe` tự nâng kết nối eDP từ `2 lane` lên **`4 lane HBR (2.7 Gbps/lane)`** (`24 bpp / 8 bpc`) khi chuyển sang `144 Hz`.
- **Cài đặt (chỉ sửa `/Library/Displays/...` trên phân vùng Data, không sửa EFI):**
  ```zsh
  chmod +x display-144hz/*.sh
  ./display-144hz/install-144hz.sh
  ```
  Sau đó **Restart**, vào **System Settings -> Displays** và chọn **144 Hz** (nếu màn hình đen bất thường, giữ nguyên 15 giây macOS sẽ tự quay về 60 Hz).
- **Kiểm tra 144 Hz thật ở mức phần cứng:**
  ```zsh
  swift -e 'import AppKit; print("MaxFPS:", NSScreen.main?.maximumFramesPerSecond ?? 0)'
  ioreg -r -c AppleIntelFramebuffer | grep -E "IOFBCurrentPixelClock|IOFBCurrentPixelCount"
  ```
  *(Đạt chuẩn khi `MaxFPS: 144` và `IOFBCurrentPixelClock = 346850000`.)*
- **Lưu ý khi cập nhật / cài lại macOS & cách gỡ:**
  - Cập nhật macOS OTA thông thường **thường giữ nguyên** file trong `/Library/Displays/Contents/Resources/Overrides/` (nằm trên phân vùng Data `/System/Volumes/Data`).
  - Nếu **cài trắng lại macOS** (xóa phân vùng Data), chạy lại `./display-144hz/install-144hz.sh` sau khi cài xong.
  - Nếu muốn **gỡ bỏ**, chạy `./display-144hz/uninstall-144hz.sh` rồi Restart.

---

## 6. Mẹo tối ưu Sleep & Chuột ngoài

- **Tắt Hibernate để Sleep/Wake ổn định hơn trên macOS:**
  ```zsh
  sudo pmset -a hibernatemode 0 standby 0 autopoweroff 0 powernap 0
  ```
- **Chuột ngoài cuộn ngược:** Vào **System Settings -> Mouse** tắt **Natural scrolling**, hoặc cài **Mos** / **LinearMouse** để tách riêng hướng cuộn của chuột ngoài và touchpad.

---

## 7. Sửa lỗi gõ Tiếng Việt, mất chữ & loạn phím số ([`keyboard-vn/`](keyboard-vn/))

- **Nguyên nhân hay gặp trên macOS:**
  - Nếu để nguồn nhập macOS là **Vietnamese (`Simple Telex`)** chạy chồng với **OpenKey**, hai bộ gõ sẽ đè phím Backspace lên nhau gây mất chữ/sai dấu (như `nhập` -> `nâ`) hoặc kẹt chữ trên trình duyệt Chromium/Electron.
  - Nếu OpenKey bị chuyển nhầm sang kiểu gõ **VNI** (`InputType = 1`) và bảng mã **VNI Windows** (`CodeTable = 2`), việc nhấn phím số `1–9` sau chữ sẽ kích hoạt bỏ dấu/sửa lại cụm chữ trước đó, đồng thời tắt `FixRecommendBrowser` / `vFixChromiumBrowser` làm rơi ký tự trong trình duyệt và IDE.
- **Khắc phục nhanh trong 1 lệnh (không cần Restart máy):**
  1. Cài **OpenKey** ([tuyenvm/OpenKey Releases](https://github.com/tuyenvm/OpenKey/releases)) vào `/Applications/OpenKey.app` và cấp quyền **Accessibility** (`System Settings -> Privacy & Security -> Accessibility`).
  2. Chạy script [`keyboard-vn/fix-keyboard-vn.sh`](keyboard-vn/fix-keyboard-vn.sh):
     ```zsh
     chmod +x keyboard-vn/fix-keyboard-vn.sh
     ./keyboard-vn/fix-keyboard-vn.sh
     ```
     Script sẽ tự động sao lưu cấu hình cũ, chuyển nguồn nhập hệ thống macOS về **`ABC`** (`com.apple.keylayout.ABC`), tắt bộ gõ `VietnameseIM` mặc định của Apple, và cấu hình OpenKey chuẩn **`Telex` + `Unicode` + bật `FixRecommendBrowser` + `vFixChromiumBrowser`**.
  3. *(Tùy chọn)* Nếu một số app vẫn bị sót phím khi gõ nhanh, chạy `./keyboard-vn/fix-keyboard-vn.sh --step-by-step` (`SendKeyStepByStep = 1`); dùng `--check` để xem trạng thái hoặc `--restore` để khôi phục cấu hình cũ.

---

## Tác giả

- **Tên:** Kiệt
- **Email:** kiet2711207@gmail.com
