# Level 1 (Map Gió): bố cục sau khi đưa quái vào

## Luồng chơi
1. **Khu 1–4:** đi, nhảy, đá bước, cao nguyên (có checkpoint).
2. **Khu 5:** gió xuôi.
3. **Khu 6 (mới, làn gió nhịp):** đi thẳng xuống sân gió đẩy lên.
   - Thay cho đoạn vòng sang đông (gió ngược + gió ngang + gió nhịp cũ), vì đoạn đó dài khoảng 60 m mà chỉ dạy lặp lại.
4. **Khu 9:** gió đẩy lên, rồi lên tầng trên.
5. **Khu 10–11:** cầu → sân kiếm.
   - **Trận 1:** nhặt kiếm xong thì quái 1 (lướt chém) chặn lối đi tiếp.
6. **Khu 12:** nhặt dash, vượt khe.
7. **Khu 13:** bến thuyền.
   - **Trận 2:** lính khiên. Phải lướt hoặc nhảy né sóng chấn, rồi đánh vòng ra sau lưng.
8. **Khu 14:** nhánh đông lên cao nguyên sách.
   - **Trận 3:** nhặt sách gió thì pháp sư hiện ra. Dùng E phản cầu ngay (học theo Zelda: có đồ mới là dùng liền).
   - Hình nộm tập đã bỏ.
9. **Khu 15:** nhảy mép xuống bến (đường tắt một chiều) → thuyền → bờ xa.
   - **Trận cuối:** cả 3 loại quái. Thắng thì hiện lối ra.

## Encounter (`objects/encounter/encounter.tscn`)
- Quái đặt làm con của node `Enemies` trong scene. Quái được gỡ khỏi cây cho tới khi player bước vào `Trigger`.
- Thông số:
  - `persistent_id`: cờ được lưu khi đã thắng trận. Lần sau vào khu sẽ không gặp lại trận này.
  - `required_flag`: trận chỉ bắt đầu khi đã có cờ này (ví dụ `level_1.sword_pickup`).
  - `spawn_interval`: khoảng cách thời gian giữa các con xuất hiện.
  - `aggro_on_start`: quái nhắm player ngay khi xuất hiện.
  - `spawn_effect`: hiệu ứng lúc quái xuất hiện (tuỳ chọn).
  - `trigger_size`: kích thước vùng kích hoạt.
- Signal: `started` (trận bắt đầu) và `cleared` (đã thắng). Nối `cleared` vào cửa hoặc lối ra trong scene level.
- Thêm loại quái mới chỉ cần thả scene quái vào `Enemies`, không phải sửa code.
- **Lưu ý:** không xoay node gốc của quái, vì hướng quái nằm ở `Model`.

## Ánh sáng / không khí gió
- **WorldEnvironment:**
  - Trời trắng xanh. Phía dưới đảo là màu trời nhạt, để đảo trông như nổi giữa trời.
  - Sương độ cao: chân đảo tan vào mây (`fog_height` −2).
  - Glow nhẹ cho đèn lồng, mắt quái, pha lê.
  - Tonemap AgX.
- **Đèn:**
  - `DirectionalLight3D`: nắng chiều ấm.
  - `WindFill`: đèn phụ xanh lạnh từ phía ngược nắng, không đổ bóng.
- **Biển mây:** `assets/shaders/cloud_sea.gdshader`, mây 3 tông cắt sắc, trôi theo `wind_direction`.
- **`AmbientWind`** (`assets/vfx/wind/ambient_wind.tscn`):
  - Vệt gió trắng cuộn và lá bay, phủ quanh player.
  - Nối với player bằng signal `ZoneRoot.player_spawned` → `set_follow_target`.
- **`LightShafts`** (`objects/light_shaft/`): cột nắng chỉ đặt ở những nơi cần dẫn mắt người chơi: xuất phát, kiếm, dash, sách, thuyền, trận cuối.
- Hướng gió chung là `(0.6, 0, -1)`, dùng cho cả mây và vệt gió. Đổi hướng gió thì phải đổi cả hai chỗ.

## Kiểm thử
- `tests/test_level_1.tscn`: chạy headless, với APPDATA trỏ vào `.godot/lvl_runtime`.
  - Kiểm đường qua làn mới.
  - Kiểm 6 đoạn rào.
  - Kiểm 4 trận đánh: chờ cờ, xuất hiện, không rơi khỏi sân, thắng thì lưu cờ.
  - Kiểm lối ra hiện ra.
  - Kiểm tải lại khu thì không gặp lại trận đã thắng.
- `tests/capture_level_1.tscn`: chạy có cửa sổ, chụp 8 khu bằng camera game. Đặt `SHOT_DIR` để chọn thư mục lưu ảnh.
