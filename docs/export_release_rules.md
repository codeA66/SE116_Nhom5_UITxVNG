# Quy tắc bản export release — BẮT BUỘC đọc trước khi sửa script, `@tool` hay export

Tài liệu này dành cho mọi người và mọi AI làm việc trong dự án. Đọc hết trước khi:
- viết hoặc sửa script có `@tool`, hoặc gọi hàm của Node liên quan tới editor;
- sửa cấu hình export (`export_presets.cfg`);
- sửa lỗi kiểu "chạy trong editor được nhưng bản export bị hỏng".

## 1. Lỗi đã gặp (13/11/2026)

**Triệu chứng.** Bản export **release** (bỏ tích *Export With Debug*) không nhặt được chìa khoá ở đền trung tâm.
Bản chạy trong editor (F5) và bản export **debug** thì bình thường. Log bản release
(`%APPDATA%\Godot\app_userdata\SE116\logs\godot.log`) ghi:

```
SCRIPT ERROR: Parse Error: Could not resolve class "Pickup".
   at: GDScript::reload (res://objects/core/pickups/key/key_pickup.gd:2)
```

**Nguyên nhân thật** (đọc được khi tự export bản release và nạp thử từng script):

```
SCRIPT ERROR: Parse Error: Function "_get_configuration_warnings()" not found in base self.
   at: res://objects/core/pickups/pickup.gd:21
```

`pickup.gd` gọi `_get_configuration_warnings()` lúc chạy game. Hàm này là hàm ảo của Node **chỉ có trong
editor và bản debug**; template release không có. Vì vậy `pickup.gd` không biên dịch được, kéo theo mọi lớp con
(`KeyPickup`, `CharmPickup`, `AbilityPickup`, `WeaponPickup`, `ItemPickup`…) mất script. Thông báo
"Could not resolve class Pickup" ở lớp con chỉ là **hệ quả**, không phải gốc lỗi.

**Cách sửa.** `Pickup` tự khai báo `func _get_configuration_warnings() -> PackedStringArray: return PackedStringArray()`
để hàm luôn tồn tại ở mọi bản build; lớp con ghi đè như cũ.

**Hai cách sửa đã thử và SAI** (đừng lặp lại):
- Đổi `extends Pickup` thành `extends "res://.../pickup.gd"`: vẫn lỗi, vì gốc lỗi nằm trong `pickup.gd`.
- Đổi *GDScript Export Mode* sang *Text*: vẫn lỗi, không liên quan cách nén script.

## 2. Quy tắc khi viết code

1. **Không gọi hàm chỉ có trong editor lúc chạy game**, trừ khi chính script đó (hoặc lớp cha của nó) tự khai báo
   hàm ấy. Các hàm, class hay gặp:
   - `_get_configuration_warnings()`: chỉ gọi được nếu script tự khai báo;
   - các class `Editor*` (`EditorInterface`, `EditorPlugin`, `EditorScenePostImport`…);
   - mọi thứ trong thư mục `addons/` dành cho editor.
2. Phần chỉ dành cho editor phải bọc trong `if Engine.is_editor_hint():` **và** không được làm hỏng biên dịch
   ở bản release (bọc `if` không cứu được lỗi biên dịch: hàm vẫn phải tồn tại).
3. Script import model (`*_import.gd`, kế thừa `EditorScenePostImport`) chỉ chạy trong editor. Bản release báo
   chúng không biên dịch được là bình thường, miễn là game không nạp chúng lúc chạy.

## 3. Cách kiểm tra — CẤM ĐOÁN

Lỗi "editor được, export hỏng" **phải tái hiện trên bản release thật** rồi mới sửa. Không đưa cách sửa khi chưa
thấy lỗi gốc trong log.

1. **Không chạy Godot nền (headless, export) trên thư mục dự án khi editor đang mở**: đã từng làm editor văng.
   Chép dự án ra chỗ khác (bỏ `.git`), ví dụ `robocopy <dự án> D:\FoxyRepro\project /MIR /XD .git`.
2. Trong bản chép, thêm một cảnh test làm đúng thao tác bị lỗi (ví dụ vào đền trung tâm, đứng cạnh chìa, bấm F)
   và `print` kết quả. Đặt cảnh đó làm `run/main_scene` **chỉ trong bản chép**.
   - Nên cho cảnh test `load()` lần lượt mọi script và in ra script nào `can_instantiate() == false`.
     Bản export đổi `.gd` thành `.gd.remap` / `.gdc`, nên khi duyệt thư mục phải tính cả `.gd.remap`.
3. Export release từ bản chép:
   `Godot --headless --path <bản chép> --export-release "Windows Desktop" <đường dẫn>.exe`
   (đặt `APPDATA` trỏ tới thư mục có `Godot/export_templates/4.7.2.stable`).
4. Chạy `.exe` với `APPDATA` / `LOCALAPPDATA` riêng (không đụng save thật), rồi đọc
   `<APPDATA>\Godot\app_userdata\SE116\logs\godot.log`.
5. Sửa trong dự án thật, chép file đã sửa sang bản chép, export và chạy lại. **Chỉ báo "đã sửa" khi log và kết quả
   thao tác đều đúng.**

Template export của máy nhóm trưởng nằm ở `D:\GodotData\export_templates` (liên kết từ
`%APPDATA%\Godot\export_templates`).
