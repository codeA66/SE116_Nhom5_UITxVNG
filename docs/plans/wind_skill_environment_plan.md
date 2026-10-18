# Kế hoạch: Skill gió đẹp + Môi trường phản ứng với gió + Câu đố gió

> Tài liệu giao cho AI/người khác làm. Đọc hết file này và `CLAUDE.md` trước khi code.
> Mọi quyết định mặc định được ghi ở mục **0. Quyết định đã chốt**. Muốn đổi thì hỏi người dùng trước khi code.

## 0. Quyết định đã chốt (người dùng duyệt trước khi giao việc)
- **Phạm vi:** 3 phần, làm theo thứ tự A → B → C. Xong phần nào thì test và báo phần đó.
- **Không đổi gameplay** của cú thổi hiện có (lực, tầm, cooldown trong `abilities/wind_blast/wind_blast.tres`). Chỉ thêm hình và phản ứng.
- **Màu gió:** trắng / xanh nhạt (giống VFX gió hiện có). Không dùng màu khác.
- **Câu đố:** đặt **3 câu đố** vào Level 1 (mục C), mỗi câu chỉ dùng skill đã có ở thời điểm đó.
- **Không** tải asset, plugin hay âm thanh. Âm thanh chỉ để chỗ cắm (`AudioStreamPlayer3D` trống).
- **Không commit git.**

## 1. Bối cảnh code (đã có sẵn, đọc trước)
| Thành phần | File | Ghi chú |
|---|---|---|
| Dữ liệu cú thổi | `abilities/wind_blast/wind_blast_data.gd`, `wind_blast.tres` | `reach` 5, `width` 2.5, `height` 2, `active_start`/`active_time`/`duration`/`cooldown` |
| Vùng thổi | `abilities/wind_blast/wind_blast_area.gd/.tscn` (gắn dưới `Model` của player) | Có các signal `charge_started(data)`, `blast_started(data)`, `blast_stopped`, `pushed(receiver)` → **dùng các signal này để bật VFX/phản ứng, không sửa logic** |
| State player | `entities/player/states/wind_blast.gd` | Phím `skill` (E) |
| Vật nhận gió | `components/wind_receiver/wind_receiver_component.gd` | `signal pushed(impulse)`, `push()`, `move_with_wind()`, `is_being_pushed()`; layer 8 (`wind_receiver` = 128), vùng gió layer 7 (`wind` = 64) |
| Vùng gió cố định | `objects/wind_zone/` + `resources/wind/*.tres` | Gió xuôi / ngược / nhịp / đẩy lên |
| VFX gió có sẵn | `assets/vfx/wind/` (đọc `README.md`): `wind_blast_vfx`, `wind_burst_vfx`, `wind_impact_pool`, `wind_zone_vfx`, `ambient_wind`; shader `assets/shaders/wind_*.gdshader`, `wind_flow.gdshaderinc` | **Tái dùng phong cách và hàm của các file này**. Kiểm tra xem `wind_blast_vfx` đã gắn vào player chưa và nó đang trông thế nào trước khi làm mới |
| Model bộ gió | `assets/models/wind_kit/*.glb` | Có `windmill`, `flag_pole`, `grass_tuft`, `shrub_s/m/l`, `hanging_lantern`, `petal_drift`, `wind_gate*`, `updraft_vent`; vật liệu dùng chung `wind_kit_material.tres` |
| Đèn lồng đung đưa | `objects/hanging_lantern/` | Đã có chuyển động lắc; cần thêm phản ứng khi bị thổi |
| Level 1 | `levels/zone_1_wind/level_1/level_1.tscn` | Đọc `docs/level_1_layout.md`. Scene rất lớn (khoảng 4000 dòng): **sửa bằng script (Node.js/GDScript) theo từng block, không viết tay cả file**; sao lưu trước khi sửa |
| Test | `tests/test_level_1.tscn` + các test khác | Phải luôn PASS |

Collision layers: 1 world, 2 player, 3 enemy (4), 4 player_hitbox (8), 5 enemy_hitbox (16), 6 pickup (32), 7 wind (64), 8 wind_receiver (128), 9 player_blocker (256).

## 2. Phần A: Skill gió đẹp (VFX cú thổi)
Mục tiêu: bấm E thấy rõ một luồng gió mạnh hình nón bắn ra trước mặt. Phong cách nét sắc, low-poly, kiểu Death's Door / Zelda Wind Waker.

Làm `assets/vfx/wind/wind_blast_cone/` (hoặc nâng cấp `wind_blast_vfx` nếu nó đã gắn vào player; kiểm tra trước). Bật và tắt bằng signal của `WindBlastArea`.

1. **Lấy đà** (`charge_started`), khoảng 0.12 s: vài nét gió nhỏ hút vào tay player theo hình xoắn, vòng sáng nhỏ co lại.
2. **Bắn** (`blast_started`):
   - **Lõi nón:** 5–8 dải gió cong (ribbon, shader có sẵn trong `wind_flow.gdshaderinc`) bắn từ player ra tới `reach`, xoắn nhẹ quanh trục, đầu dải sáng nhất.
   - **Vòng sóng** đứng (vuông góc hướng thổi) mở rộng từ 0 đến `width`, mép sắc, khoảng 0.2 s.
   - **Hạt:** 15–25 hạt bụi/lá bay theo hướng thổi, tăng tốc rồi tản ra ở cuối tầm.
   - **Vệt trên mặt đất:** quét một dải bụi/gợn sát mặt đất theo hướng thổi.
3. **Trúng vật** (`pushed(receiver)`): gọi `wind_impact_pool` có sẵn tại vị trí vật, tạo chùm nét gió bật ra.
4. **Kích thước lấy từ `WindBlastData`** (`reach`, `width`, `height`), không viết cứng số; đổi `.tres` thì hình đổi theo.
5. Hiệu năng: tối đa khoảng 60 hạt mỗi cú thổi; dùng pool nếu tạo nhiều lần; `cast_shadow` tắt; không `_process` khi không thổi.

**Nghiệm thu A:**
- Ảnh từ camera game ở khung 0 / 0.1 / 0.2 / 0.35 s, trên nền sáng và nền tối.
- Đổi `reach` 2 và 10, `width` 1 và 6: hình khớp với vùng đẩy thật (bật debug collision để so).
- Bấm E liên tục 30 lần: số node không tăng.

## 3. Phần B: Môi trường phản ứng với gió
Mục tiêu: mọi thứ nhẹ trong thế giới phản ứng khi bị thổi (cả cú thổi E lẫn vùng gió cố định). Thế giới phải "sống".

Làm **một component dùng chung** `components/wind_reactive/wind_reactive_component.gd` (+ Resource `WindReactData`):
- Gắn vào vật trang trí cùng một `WindReceiverComponent` (Area3D, layer 128, mask 64), hoặc tự nghe va chạm với vùng thổi.
- Phát `reacted(direction: Vector3, strength: float)`. Hình ảnh do từng loại vật tự xử lý (open/closed).
- **Không quét mỗi frame:** chỉ chạy `_process` trong lúc đang phản ứng (lắc rồi tắt dần), xong thì `set_process(false)`.
- Rất nhiều cỏ/bụi: làm phản ứng bằng **shader** (uniform hướng + độ mạnh + thời điểm bị thổi, rạp theo `TIME` rồi hồi lại). CPU chỉ đặt uniform một lần khi bị thổi. Với cỏ số lượng lớn, cân nhắc đổi sang `MultiMesh` + một vùng nhận chung để không tạo hàng trăm Area3D.

Danh sách vật cần phản ứng (mỗi loại một scene nhỏ trong `objects/wind_reactive/` hoặc thêm vào scene có sẵn):

| Vật | Phản ứng khi bị thổi | Ghi chú |
|---|---|---|
| Cỏ (`grass_tuft`) | Rạp theo hướng gió rồi đàn hồi lại, vài cọng bứt bay | Shader đỉnh lệch theo chiều cao |
| Bụi cây (`shrub_*`) | Lắc mạnh, rơi lá (5–8 hạt) | |
| Đèn lồng (`hanging_lantern`) | Biên độ lắc tăng mạnh rồi tắt dần, ánh sáng chập chờn | Sửa `hanging_lantern.gd`: thêm hàm public `apply_gust(direction, strength)` |
| Cờ (`flag_pole`) | Vải bay phấp phới mạnh hơn theo hướng gió | Shader vải |
| Cối xay (`windmill`) | Cánh quay nhanh lên rồi chậm dần | Dùng cho câu đố C1 |
| Cánh hoa (`petal_drift`) | Bung lên và bay theo hướng gió | |
| Lá/bụi trên đất | Vùng lá khô: thổi thì tung lên rồi rơi lại | Scene mới `leaf_pile` |

**Nghiệm thu B:**
- Ảnh trước/trong/sau cú thổi cho từng loại vật.
- Cảnh 200 bụi cỏ: thời gian mỗi frame lúc không thổi và lúc đang thổi (ms/frame), chênh lệch thấp.
- Vùng gió cố định (`WindZone`) cũng làm cỏ/cờ trong vùng rạp/bay liên tục.

## 4. Phần C: Câu đố bằng gió (đặt vào Level 1)
Nguyên tắc (Nintendo kishōtenketsu / Zelda): giới thiệu cơ chế an toàn → thử thật → biến tấu. Câu đố phải **nhìn là hiểu**, có dấu hiệu thị giác (cối xay có ký hiệu gió, đèn sáng khi đúng).

Làm các object tái dùng trong `objects/`:

1. **`wind_turbine_switch` (cối xay công tắc):** thổi E vào thì cánh quay, đủ thời gian thì phát `activated`. Có loại giữ vĩnh viễn và loại hết gió thì tắt (có `@export`).
2. **`wind_door` / nâng cầu:** nghe `activated` của một hay nhiều công tắc (mảng NodePath, chế độ AND), rồi mở cửa / hạ cầu. Lưu trạng thái bằng `GameState.set_flag(persistent_id)` giống `Pickup`/`Encounter`.
3. **`blowable_cover` (đống lá/cỏ che lối):** thổi thì tung bay, lộ lối đi hoặc rương bí mật. Lưu cờ.
4. **`push_block` (bệ đá trượt):** thổi đẩy trượt theo lưới 1 ô, dừng khi chạm tường, rơi vào ô công tắc trên sàn thì kích hoạt. Dùng `WindReceiverComponent` + `CharacterBody3D`.

**Đặt vào Level 1** (vị trí cụ thể tự chọn, ghi lại trong `docs/level_1_layout.md`; phải sau khi player có sách gió, tức khu 14–15 trở đi, hoặc làm đoạn tắt quay lại):
- **C1:** thổi cối xay → hạ cầu sang một mỏm có phần thưởng nhỏ (hồi máu hoặc vật trang trí bí mật).
- **C2:** đống lá che một lối tắt trên cao nguyên sách.
- **C3** (biến tấu): 2 cối xay phải quay cùng lúc (đứng giữa thổi qua lại kịp thời gian) mới mở cổng tới bờ xa, hoặc đẩy bệ đá vào ô công tắc.
- Không được làm kẹt tiến trình chính: đường chính vẫn đi được nếu chưa giải câu đố phụ (C1, C2 là phụ; C3 nếu chặn đường chính thì phải có gợi ý rõ).

**Nghiệm thu C:**
- Test tự động `tests/test_wind_puzzles.gd/.tscn`: thổi bằng cách gọi API/Input thật → công tắc kích hoạt → cửa mở; thoát vào lại thì trạng thái được giữ; thông số cực đoan (thời gian quay 0 và 30 s, nhiều công tắc).
- `tests/test_level_1.tscn` vẫn PASS; thêm kiểm tra không kẹt tiến trình.
- Ảnh chụp từng câu đố trước và sau khi giải.

## 5. Quy tắc chung (bắt buộc)
- Theo `CLAUDE.md`:
  - static typing, thứ tự khai báo, `@export` mọi thông số;
  - signal thay vì quét mỗi frame, tắt process khi rảnh, pool cho thứ tạo liên tục;
  - comment tiếng Việt ngắn giải thích "tại sao";
  - không cú pháp Godot 3, không bịa API (không chắc thì xem docs.godotengine.org).
- Chạy Godot headless/test luôn với `APPDATA` và `LOCALAPPDATA` trỏ vào `.godot/<tên>_runtime`, để không ghi đè save thật và không tạo thư mục rác (`export_templates`, `script_templates`...) ở gốc project. Sau khi chạy, kiểm tra gốc project không có thư mục lạ.
- Lệnh mẫu (Git Bash):
  ```
  G="<đường dẫn Godot_v4.7.2-stable_win64.exe>"; R="$(pwd)/.godot/lvl_runtime"; mkdir -p "$R"
  APPDATA="$(cygpath -w "$R")" LOCALAPPDATA="$(cygpath -w "$R")" "$G" --headless --path . res://tests/test_level_1.tscn
  ```
- Model `.blend` mới (nếu có) phải nằm trong thư mục `source/` có `.gdignore`.
- Chỉ báo "chạy đúng" khi đã đo hành vi thật hoặc chụp ảnh. Báo đúng cả lỗi.
- Báo cáo cuối: `docs/vfx/wind_skill_report.md` gồm danh sách file tạo/sửa, ảnh, số đo hiệu năng, kết quả test, việc chưa làm được.

## 6. Ước lượng và gợi ý chia việc
- **A (VFX skill):** 1 agent làm VFX.
- **B (môi trường):** 1 agent; phần shader cỏ/cờ là việc chính.
- **C (câu đố + đặt vào level):** 1 agent code; nên làm sau A và B.
- **Review cuối:** Opus kiểm tra ảnh, chạy lại test và đọc code theo các mục nghiệm thu ở trên.
