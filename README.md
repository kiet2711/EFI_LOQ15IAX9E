# OpenCore EFI — Lenovo LOQ 15IAX9E (83LK) · Dual GPU (`Intel UHD` + `NVIDIA RTX 3050`)

Cấu hình **OpenCore (`DBG-109-2026-10-23`)** đã thử nghiệm và hoạt động song song **2 GPU cùng lúc** trên **macOS Sequoia 15.8.1 (24H32)**:
- **iGPU Intel UHD Graphics (`0x468B`, Metal 2, 1536 MB VRAM)** qua **WhateverXe 0.8.3** (bản vá cho Alder Lake-HX) phụ trách màn hình laptop (`BOE NE156FHM-NX9`, hỗ trợ `144 Hz`).
- **dGPU NVIDIA GeForce RTX 3050 6GB Laptop GPU (`10DE:25AC`, Metal 3, 6 GB VRAM)** qua **NullMoth (`v3.1` / `1401.app`)** + bản vá ACPI `SSDT-PEG1-KeepPower.aml` nhận thẳng lúc boot, phụ trách tăng tốc Metal 3 / tính toán và xuất màn hình ngoài qua **HDMI**.

> **Lưu ý về các nhánh trong repo:**
> - `main`: Cấu hình chỉ dùng Intel UHD (`SSDT-Disable_GPU_PEG1.aml` tắt dGPU).
> - `airdrop`: Cấu hình Intel-only có AirDrop (`ForbiddenItlwm` + `BTLEAdvFixup`) + map USB.
> - `dual-gpu-rtx3050` *(nhánh này)*: Cấu hình **Dual GPU chạy song song cả Intel UHD và RTX 3050** + AirDrop + 144 Hz.

---

## 1. Thông số phần cứng đã kiểm tra

| Thành phần | Phần cứng | Trạng thái | Ghi chú |
| --- | --- | --- | --- |
| **Máy** | Lenovo LOQ 15IAX9E (`83LK`) | Hoạt động | SMBIOS `MacBookPro16,2` |
| **CPU** | Intel Core i5-12450HX (12th Gen) | Hoạt động | `CpuTopologyRebuild` + `CpuTscSync` |
| **iGPU** | Intel UHD Graphics (`8086:468B`, rev `0x0C`) | Hoạt động | `WhateverXe 0.8.3` (patched), Metal 2, 1536 MB, chỉnh sáng `AppleBacklightDisplay` |
| **dGPU** | NVIDIA GeForce RTX 3050 6GB Laptop GPU (`10DE:25AC`, sub `17AA:3DA0`, PCIe `x8`) | Hoạt động song song | `SSDT-PEG1-KeepPower.aml` + `NullMoth v3.1` (`NVRM`/`NVAccel`/`NVRMFB`/`NVRMAGDC`), Metal 3, 6 GB VRAM, xuất HDMI |
| **Màn hình** | Internal eDP `BOE NE156FHM-NX9` (`1920x1080`) + HDMI ngoài | Hoạt động | Màn trong `60 / 120 / 144 Hz` (qua [`display-144hz/`](display-144hz/)) trên Intel UHD; HDMI ngoài trên RTX 3050 |
| **Wi-Fi** | Intel CNVi (`8086:7AF0` / `8086:0274`) | Hoạt động | `ForbiddenItlwm 0.6.0-beta.4` (bật AirDrop/AWDL trên Sequoia `24.0.0`–`24.99.99`), kèm dự phòng `AirportItlwm 2.4.0` |
| **Bluetooth** | Intel Wireless Bluetooth (`8087:0026`) | Hoạt động | `IntelBluetoothFirmware 2.5.0` + `BlueToolFixup 2.7.3` + `BTLEAdvFixup 0.9.4` *(tắt `IntelBTPatcher` để tránh xung đột)* |
| **Âm thanh** | Intel Audio (`8086:7AE0` / `AppleALC`, `layout-id = 18`) | Hoạt động | Loa ngoài, tai nghe, mic tích hợp (kèm node audio HDMI GPU `10DE:2291`) |
| **Mạng dây** | Realtek RTL8168H/8111H Gigabit Ethernet | Hoạt động | `RealtekRTL8111 3.0.0` |
| **Touchpad / Phím** | I2C HID (`Magic Trackpad 2`) + PS/2 Keyboard | Hoạt động | `VoodooI2C 2.9.1` + `VoodooI2CHID 1.0` + `VoodooPS2Controller 2.3.8` |
| **NVMe** | `SAMSUNG MZAMX512HCLV-00BL2` (`512 GB`) | Hoạt động | `NVMeFix 1.1.4` |
| **Pin / SMC** | VirtualSMC + YogaSMC | Hoạt động | `VirtualSMC 1.3.9` + `SMCBatteryManager` + `YogaSMC 1.5.3` |

> **Lưu ý tính năng Apple:** **AirDrop đã hoạt động** trên `macOS Sequoia 15.8.1` qua `ForbiddenItlwm 0.6.0-beta.4` + `BTLEAdvFixup 0.9.4` (xem [Mục 6](#6-kích-hoạt--gỡ-airdrop-forbiddenitlwm--btleadvfixup)). Các tính năng **Handoff / Continuity / Universal Control** nói chung vẫn chưa đầy đủ như card Broadcom gốc; có thể dùng thêm **LocalSend** khi chuyển file với Windows/Android.

---

## 2. Danh sách những thứ cần tải & Công cụ hỗ trợ

### A. Driver đồ họa (Intel iGPU + NVIDIA dGPU) & Bộ cài macOS

| Thành phần | Mục đích | Link tải chính thức |
| --- | --- | --- |
| **WhateverXe Graphics (`0.4.4+`)** | Gói `.pkg` cài `AppleIntelTGLCompat`, `AppleIntelTGLGraphics*` cho iGPU Intel vào `/Library/Extensions` & `/Library/GPUBundles` | [b00t0x/WhateverXe-Graphics Releases](https://github.com/b00t0x/WhateverXe-Graphics/releases) |
| **NullMoth NVIDIA Driver + 1401 (`v3.1+`)** | Driver RTX 3050 cho macOS (`NVRM`, `NVAccel`, `NVRMFB`, `NVRMAGDC`, `NVMTLDriver`) — tải `1401-Mac-3.1.zip`, `nullmoth-nvidia-3.1.tar.gz`, `SHA256SUMS.txt` | [nullmoth/nvidia-macos-driver Releases](https://github.com/nullmoth/nvidia-macos-driver/releases) |
| **NVIDIA Linux Runfile (`620.70.06`)** | Cung cấp GSP firmware (`gsp_ga10x.bin`, `ucodes_ga10x.bin`) đúng mã pin của NullMoth `v3.1` — đặt cùng thư mục `~/Downloads` với `nullmoth-nvidia-3.1.tar.gz` | [NVIDIA Linux x86_64 620.70.06](https://us.download.nvidia.com/XFree86/Linux-x86_64/620.70.06/NVIDIA-Linux-x86_64-620.70.06.run) |
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
| **IORegistryExplorer** | Xem cây IORegistry (`IORegistryClone`) để debug phần cứng/PCIe/GPU | [khronokernel/IORegistryClone](https://github.com/khronokernel/IORegistryClone) |
| **MaciASL** | Xem, sửa & biên dịch file ACPI `.dsl` / `.aml` | [acidanthera/MaciASL Releases](https://github.com/acidanthera/MaciASL/releases) |
| **Mos** | Đảo riêng hướng cuộn chuột ngoài (giữ nguyên Touchpad) và làm mượt cuộn | [Caldis/Mos Releases](https://github.com/Caldis/Mos/releases) |
| **LinearMouse** | *(Thay thế Mos)* Tùy chỉnh hướng cuộn, tốc độ & bỏ gia tốc chuột ngoài | [linearmouse/linearmouse Releases](https://github.com/linearmouse/linearmouse/releases) |
| **LocalSend** | Gửi/nhận file qua Wi-Fi/LAN giữa macOS, Windows, iOS/Android thay thế AirDrop | [localsend/localsend Releases](https://github.com/localsend/localsend/releases) |
| **OpenKey (`2.0.5+`)** | Bộ gõ Tiếng Việt ổn định thay cho bộ gõ mặc định Apple (kèm script [`keyboard-vn/`](keyboard-vn/)) | [tuyenvm/OpenKey Releases](https://github.com/tuyenvm/OpenKey/releases) |

### D. Nguồn gốc các Kext đang dùng trong EFI

- **Core & Đồ họa:**
  - `Lilu 1.7.3`: https://github.com/acidanthera/Lilu/releases
  - `AMFIAnchor 0.1.2` + `AMFIAnchorInjector 1.0.0`: https://github.com/b00t0x/AMFIAnchor/releases
  - `AMFIPass 1.4.1` *(bắt buộc đi kèm NullMoth)*: https://github.com/dhinakg/AMFIPass/releases
  - `WhateverXe 0.8.3` *(bản tự build có patch cho Lenovo LOQ ADL-HX)*: https://github.com/b00t0x/WhateverXe/releases
  - `WhateverGreen` *(dùng cho file dự phòng `config-safe-7mb.plist`)*: https://github.com/acidanthera/WhateverGreen/releases
  - `BrightnessKeys 1.0.4`: https://github.com/acidanthera/BrightnessKeys/releases
- **CPU / Nguồn / NVMe / SMC:**
  - `VirtualSMC 1.3.9` (`SMCBatteryManager`, `SMCLightSensor`, `SMCProcessor`, `SMCSuperIO`): https://github.com/acidanthera/VirtualSMC/releases
  - `YogaSMC 1.5.3`: https://github.com/zhen-zen/YogaSMC/releases
  - `CpuTscSync 1.1.2`: https://github.com/acidanthera/CpuTscSync/releases
  - `CpuTopologyRebuild 2.0.2`: https://github.com/b00t0x/CpuTopologyRebuild/releases
  - `NVMeFix 1.1.4`: https://github.com/acidanthera/NVMeFix/releases
  - `RestrictEvents 1.1.7`: https://github.com/acidanthera/RestrictEvents/releases
- **Mạng, Bluetooth & AirDrop:**
  - `ForbiddenItlwm 0.6.0-beta.4` *(bật AirDrop/AWDL trên Sequoia `24.0.0`–`24.99.99`)* & `BTLEAdvFixup 0.9.4`: https://github.com/retropineaple/ForbiddenItlwm/releases
  - `AirportItlwm 2.4.0` *(bản dự phòng không AirDrop cho Sequoia `24.2.0`+)*: https://github.com/laobamac/itlwm/releases *(repo gốc: https://github.com/OpenIntelWireless/itlwm/releases)*
  - `IntelBluetoothFirmware 2.5.0` & `IntelBTPatcher 2.5.0`: https://github.com/OpenIntelWireless/IntelBluetoothFirmware/releases
  - `BrcmPatchRAM` (`BlueToolFixup 2.7.3`): https://github.com/acidanthera/BrcmPatchRAM/releases
  - `RealtekRTL8111 3.0.0`: https://github.com/Mieze/RTL8111_driver_for_OS_X/releases
- **Âm thanh, Bàn phím, Touchpad & USB:**
  - `AppleALC 1.9.9` (`layout-id = 18`): https://github.com/acidanthera/AppleALC/releases
  - `VoodooI2C 2.9.1` (`VoodooI2C`, `VoodooI2CHID`, `VoodooGPIO`, `VoodooI2CServices`, `VoodooInput`): https://github.com/VoodooI2C/VoodooI2C/releases
  - `VoodooPS2Controller 2.3.8`: https://github.com/acidanthera/VoodooPS2/releases
  - `USBToolBox 1.2.0` + `UTBMap 1.1`: https://github.com/USBToolBox/kext/releases

---

## 3. Điểm khác biệt & bản vá quan trọng trong nhánh Dual GPU

1. **Kích hoạt `PEG1` / `PEGP` (`RTX 3050 10DE:25AC`) nhận thẳng khi boot (`SSDT-PEG1-KeepPower.aml`):**
   - Trên Lenovo LOQ 15IAX9E, `SSDT-8.aml` gốc của hãng khởi tạo các gói chân GPIO (`RSTG`, `PWRG`, `WAKG`, `P1WK`) bằng lệnh `Store`/`Index` ở cấp module (module-level), khiến `AppleACPIPlatform` báo lỗi `AE_ERROR` và để trống `{0, 0}`, làm `PEG1` bị cắt nguồn ngay lúc boot (`PEGP` chỉ hiện sau khi Sleep/Wake).
   - `EFI/OC/ACPI/SSDT-PEG1-KeepPower.aml` kết hợp **6 ACPI Patch** trong `config.plist` (`PXP_ _OFF->XOFF`, `POFF->XPOF`, `PEGP _OFF->XOFF`, `DL23->XL23`, `PEG1 _STA->XSTA`, `PC00 GC6I->X6CI`) giúp:
     - Nạp lại `RSTG`, `PWRG`, `WAKG`, `P1WK` từ `GNVS` (`P1RE`/`P1RP`/`P1PE`/`P1PP`/`P1WP`) hợp lệ qua `\_SB_.PC00.PEG1.GINI`.
     - Chặn `GC6I` và các hàm `_OFF`/`POFF`/`DL23` tắt nguồn PCIe khi chạy Darwin (`macOS`).
     - Ép mở nguồn khe `PEG1`, đặt `SCB0 = 1` trước khi gọi `L23D()`, bật Bus Master / Memory space (`CMDR = 7`) và chờ `PEGP.NVID == 0x10DE` ngay khi khởi động (`_INI`).
   - `Booter -> Quirks -> ResizeAppleGpuBars = 0` (`64 MB`) để cấp phát BAR cho cả Intel UHD và RTX 3050 cùng lúc.

2. **Chạy song song `WhateverXe` (iGPU) + `NullMoth` (dGPU) & Cứu hộ OpenCore:**
   - Thêm **`AMFIPass.kext` (`1.4.1`)** song song với `AMFIAnchor` + `AMFIAnchorInjector` + `WhateverXe 0.8.3`.
   - Giữ `IONDRVSupport` không bị chặn để màn hình nội bộ (`BOE NE156FHM-NX9`) chạy qua Intel UHD, còn cổng HDMI ngoài xuất qua `NVRMFramebuffer` của RTX 3050.
   - Bổ sung bộ boot-args của NullMoth vào `config.plist`:
     `nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0`.
   - Bổ sung **`EFI/OC/Tools/NullMothSafe.efi`** vào `Misc -> Tools` với 2 tuỳ chọn ngay trên OpenCore Boot Picker:
     - **`1401: Start once without NVIDIA driver`** (boot 1 lần không nạp driver NVIDIA nếu gặp sự cố).
     - **`1401: Remove NVIDIA driver`** (gỡ driver NullMoth từ menu boot nếu macOS không vào được desktop).
   - *(Lưu ý: `Misc -> Debug -> Target` trên repo được đặt về `0` để không sinh log rác lên phân vùng ESP; đổi sang `67` nếu cần debug boot).*

3. **Bản vá `WhateverXe 0.8.3` cho Lenovo LOQ ADL-HX (`0x468B`):**
   - Xem [`patches/WhateverXe-0.8.3-LOQ-ADL-HX.patch`](patches/WhateverXe-0.8.3-LOQ-ADL-HX.patch) (bỏ fuse `0x42000 & 0x01000000`, thêm `wrapADLSCDClockProbe`, `wrapADLSSetMode`, và cờ `-nodisplaysleepDC6`).

4. **AirDrop / AWDL & Bluetooth Intel trên macOS Sequoia (`24.x`):**
   - Dùng `ForbiddenItlwm.kext` (`0.6.0-beta.4`, `MinKernel = 24.0.0`, `MaxKernel = 24.99.99`) + `IntelBluetoothFirmware 2.5.0` + `BlueToolFixup 2.7.3` + `BTLEAdvFixup 0.9.4` *(giữ `IntelBTPatcher` tắt `Enabled = False`)*.

---

## 4. Hướng dẫn cài đặt & kích hoạt Dual GPU từ đầu

> **Cảnh báo SMBIOS:** Nhánh cá nhân này giữ nguyên thông số SMBIOS thực tế trong `config.plist`. Nếu bạn áp dụng cho máy khác hoặc đưa lên repo công khai, hãy dùng **GenSMBIOS** tạo `SystemSerialNumber`, `MLB`, `SystemUUID`, `ROM` mới (`MacBookPro16,2`) trước khi dùng.

### Bước 1: Chuẩn bị BIOS & phân vùng EFI
1. Trong BIOS máy Lenovo LOQ 15IAX9E, để chế độ đồ hoạ là **Switchable Graphics / Dynamic Graphics** (không chọn mode tắt hẳn card rời).
2. Chép toàn bộ thư mục [`EFI/`](EFI/) vào gốc phân vùng ESP `FAT32` (dùng **DiskGenius** trên Windows hoặc **MountEFI** / `diskutil` trên macOS).

### Bước 2: Nếu cài mới macOS lần đầu (chưa cài `WhateverXe-Graphics` và `1401`)
1. Tạm sao lưu `EFI/OC/config.plist` thành `EFI/OC/config-dual-gpu.plist`, rồi copy `EFI/OC/config-safe-7mb.plist` thành `EFI/OC/config.plist` để boot chế độ VESA 7MB cài macOS.
2. Sau khi vào macOS, cài gói iGPU **`WhateverXe-Graphics-0.4.4.pkg`**:
   ```zsh
   sudo installer -pkg WhateverXe-Graphics-0.4.4.pkg -target /
   ```
   *(Xác nhận System Extension trong **System Settings -> Privacy & Security** nếu macOS yêu cầu).*
3. Đổi `EFI/OC/config-dual-gpu.plist` lại thành `EFI/OC/config.plist`, **Restart** và chọn **Reset NVRAM** 1 lần ở menu OpenCore.
4. Khi vào lại macOS, kiểm tra **System Information -> Graphics/Displays** đã thấy đồng thời cả **Intel UHD Graphics (`1536 MB`, Metal 2)** và thiết bị PCIe **NVIDIA (`0x10de:0x25ac`)** trước khi sang Bước 3.

### Bước 3: Cài driver NVIDIA RTX 3050 (`NullMoth v3.1` / `1401.app`)
1. Tải về `~/Downloads` 3 file sau (giữ cùng thư mục để `1401` tự động nhận firmware):
   - `1401-Mac-3.1.zip` -> giải nén và chép `1401.app` vào `/Applications/`
   - `nullmoth-nvidia-3.1.tar.gz` (kèm `SHA256SUMS.txt` nếu kiểm tra thủ công)
   - `NVIDIA-Linux-x86_64-620.70.06.run`
2. Mở **`/Applications/1401.app`**, chọn gói `nullmoth-nvidia-3.1.tar.gz` để cài driver (`NVRM`, `NVAccel`, `NVRMFB`, `NVRMAGDC`, `NVMTLDriver.bundle` và firmware `620.70.06`). *(EFI trên nhánh này đã tích hợp sẵn `SSDT-PEG1-KeepPower.aml`, `AMFIPass.kext`, `ResizeAppleGpuBars=0`, boot-args và `NullMothSafe.efi`).*
3. **Restart** máy. Nếu lần boot đầu macOS hỏi cấp quyền mở rộng kernel trong **System Settings -> Privacy & Security**, bấm **Allow** rồi **Restart** thêm 1 lần nữa.

### Bước 4: Kiểm tra 2 GPU hoạt động song song
Mở Terminal chạy:
```zsh
system_profiler SPDisplaysDataType
kmutil showloaded | grep -iE 'nullmoth|nvrm|whatever|tgl|amfi'
/Applications/1401.app/Contents/Resources/nullmoth-metal-devices
```
Kết quả chuẩn sẽ hiện đầy đủ cả **Intel UHD Graphics (Metal 2)** phụ trách màn laptop `BOE NE156FHM-NX9` lẫn **NVIDIA GeForce RTX 3050 6GB Laptop GPU (Metal 3)** phụ trách màn hình qua `NVRMFramebuffer` / HDMI.

### Bước 5: Mẹo dùng 2 màn hình & xử lý sự cố
- **Chọn GPU mặc định theo màn hình chính:**
  - Màn hình laptop dùng Intel UHD; cổng **HDMI** xuất qua RTX 3050.
  - Nếu muốn màn hình ngoài HDMI làm màn chính (`Main display`) và khiến `MTLCreateSystemDefaultDevice()` ưu tiên RTX 3050 cho toàn hệ thống: vào **System Settings -> Displays** -> chọn màn ngoài -> **Use as: Main display** *(hoặc kéo thanh menu trắng trong **Arrange...** sang màn ngoài)*.
- **Nếu chạy Xcode iOS Simulator bị lỗi hiển thị/nhấp nháy trên RTX 3050:**
  - Trong **Simulator**, chọn **File -> GPU Selection -> Prefer Integrated GPU** rồi tắt hẳn Simulator (`⌘Q`) và mở lại để riêng Simulator chạy trên Intel UHD trong khi các app khác vẫn dùng RTX 3050.
- **Cứu hộ khi không boot vào được desktop:**
  - Chọn **`1401: Start once without NVIDIA driver`** hoặc **`1401: Remove NVIDIA driver`** ngay tại màn hình boot OpenCore (`NullMothSafe.efi`), hoặc chuyển tạm về `config-safe-7mb.plist`.

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

## 6. Kích hoạt & Gỡ AirDrop (`ForbiddenItlwm` + `BTLEAdvFixup`)

- **Cơ chế:** Dùng `ForbiddenItlwm.kext` (`0.6.0-beta.4`) để dựng giao diện `awdl0` cùng `BTLEAdvFixup.kext` (`0.9.4`) để vá Bluetooth LE advertising trên macOS Sequoia (`15.8.1`), thay cho `AirportItlwm 2.4.0` + `IntelBTPatcher 2.5.0`.
- **Nếu cài mới từ repo:** `EFI/OC/config.plist` đã bật sẵn AirDrop. Bản không AirDrop được lưu dự phòng tại `EFI/OC/config-no-airdrop.plist`.
- **Nếu cập nhật lên EFI `OPENCORE` đang chạy (giữ nguyên SMBIOS hiện tại):**
  ```zsh
  chmod +x airdrop/*.sh airdrop/*.py
  ./airdrop/install-airdrop.sh
  ```
  Script [`airdrop/install-airdrop.sh`](airdrop/install-airdrop.sh) tự tìm phân vùng EFI `OPENCORE`, backup `config-no-airdrop-backup.plist`, chép `ForbiddenItlwm.kext` + `BTLEAdvFixup.kext`, tắt `IntelBTPatcher` & `AirportItlwm`, thêm cờ `boot-args` và chạy `plutil -lint`. Sau khi xong hãy **Restart** máy.
- **Kiểm tra sau khi Restart:**
  ```zsh
  ./airdrop/check_compat.sh
  ifconfig awdl0
  ```
- **Gỡ AirDrop & quay lại `AirportItlwm` trong 1 lệnh:**
  ```zsh
  ./airdrop/revert-airdrop.sh
  ```
  Sau đó **Restart** để quay về `AirportItlwm 2.4.0` + `IntelBTPatcher 2.5.0`.

---

## 7. Mẹo tối ưu Sleep & Chuột ngoài

- **Tắt Hibernate để Sleep/Wake ổn định hơn trên macOS:**
  ```zsh
  sudo pmset -a hibernatemode 0 standby 0 autopoweroff 0 powernap 0
  ```
- **Chuột ngoài cuộn ngược:** Vào **System Settings -> Mouse** tắt **Natural scrolling**, hoặc cài **Mos** / **LinearMouse** để tách riêng hướng cuộn của chuột ngoài và touchpad.

---

## 8. Sửa lỗi gõ Tiếng Việt, mất chữ & loạn phím số ([`keyboard-vn/`](keyboard-vn/))

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
