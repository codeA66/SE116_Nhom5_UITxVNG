# CLAUDE.md — SE116 Nhóm 5 (UITxVNG)

Tài liệu này là quy tắc bắt buộc cho Claude khi làm việc trong project. Mọi câu trả lời và mọi dòng code phải tuân theo.

## 1. Thông tin project

- Engine: **Godot 4.7.2** (stable), ngôn ngữ **GDScript**.
- Thể loại: **3D hành động + giải đố**, camera nhìn chéo từ trên xuống, di chuyển 8 hướng.
- Cốt truyện: chú cáo phiêu lưu trên đảo Foxy, vượt 4 khu vực (khu đầu là **Map Gió**) rồi đánh Final Boss ở Đền Trung Tâm.
- Vòng lặp: đi qua từng phòng → nhặt kỹ năng (dash, double jump, ...) → dùng kỹ năng mở đường và đánh boss. Skill có thể tương tác với platform.
- **Không có wall jump** (đã chốt bỏ).
- GDD: https://docs.google.com/document/d/1qCVMmGQN1oJioUDbPiM-4gmw_NNKXITcRHQCiNvJGJo

## 2. CẤM ĐOÁN

1. **Không được tạo, sửa hay xóa bất kỳ file nào trong project khi chưa được người dùng đồng ý rõ ràng.**
   - Trước khi code: trình bày kế hoạch (file nào, làm gì) và **chờ người dùng xác nhận "đồng ý" / "ok, làm đi"**.
   - Đồng ý cho một việc không có nghĩa là đồng ý cho việc khác. Phát sinh thêm file hoặc thay đổi ngoài kế hoạch thì phải hỏi lại.
   - Được phép đọc file, tìm kiếm, phân tích mà không cần hỏi.
2. **Cấm bịa.**
   - Không bịa API, class, hàm, property, signal của Godot. Không chắc API có tồn tại ở Godot 4.x thì phải nói rõ "chưa chắc" và kiểm tra tài liệu (docs.godotengine.org) trước khi dùng.
   - Không bịa tên asset, link, giá, license, tính năng của tool/asset. Không kiểm tra được thì nói thẳng là chưa kiểm tra.
   - Không khẳng định code "chạy được" nếu chưa chạy thử. Báo đúng kết quả, kể cả lỗi.
   - Không bịa nội dung GDD. Thông tin GDD chưa có thì hỏi, không tự điền.
3. Không commit / push git khi chưa được yêu cầu.
4. Không tự cài plugin, addon hay tải asset khi chưa được yêu cầu.
5. Không dùng cú pháp Godot 3 (`KinematicBody`, `yield`, `export var`, `onready var`, `move_and_slide(velocity)`...).

## 3. Cấu trúc thư mục (tổ chức theo tính năng)

```
addons/        plugin bên thứ 3
assets/        asset dùng chung: models, textures, materials, audio, fonts, vfx, shaders
entities/      player/, enemies/ (_base/), bosses/, npcs/
components/    health, hitbox, hurtbox, state_machine... tái sử dụng
abilities/     dash/, double_jump/, các skill nhặt được
objects/       door_locked, key, traps, platforms, wind_zone, checkpoint, pickups
levels/        hub_temple/, zone_1_wind/ (rooms/), ..., final_arena/
ui/            hud/, menus/, dialogs/, theme/
autoload/      game_manager, save_manager, audio_manager, event_bus
resources/     dữ liệu .tres: stats, ability data (để cân bằng game)
tests/         scene thử nghiệm
docs/          tài liệu
```

## 4. Quy ước code

### Yêu cầu tính mở rộng cao (bắt buộc)

- **Mọi code phải viết theo kiến trúc mở rộng được ngay từ lần đầu**, kể cả bản hướng dẫn, ví dụ hay prototype. Không viết bản "đơn giản cho dễ hiểu" rồi mới tái cấu trúc sau.
- Thêm tính năng mới (state, kỹ năng, loại quái, vật thể tương tác) phải **thêm file / node mới**, không phải sửa logic có sẵn (nguyên tắc open/closed).
- Hành vi nhân vật (player, quái, boss) **luôn dùng FSM dạng node** (`components/state_machine/`). Cấm dồn logic vào `if/else` hay `match` dài trong một script.
- Logic dùng chung tách thành **component** hoặc lớp cơ sở để tái sử dụng; không copy-paste giữa các entity.
- Các phần giao tiếp với nhau qua **signal / EventBus / hàm public rõ ràng**, không truy cập trực tiếp biến private của node khác.
- Dữ liệu cấu hình (stats, ability, enemy) tách ra **Resource**, để thêm nội dung mới không cần sửa code.
- Trước khi đưa code, tự kiểm tra: "Nếu thêm Dash / Attack / một loại quái mới thì có phải sửa file này không?" Nếu có, thiết kế lại.

- File/thư mục: `snake_case`. Node và `class_name`: `PascalCase`. Hằng số: `UPPER_SNAKE_CASE`. Biến/hàm private: tiền tố `_`.
- Scene và script cùng tên, cùng thư mục (`player.tscn` + `player.gd`).
- **Static typing bắt buộc**: `var speed: float = 6.0`, `func _move(delta: float) -> void:`.
- Thứ tự trong script: `class_name` → `extends` → doc comment `##` → signals → enums → constants → `@export` → biến public → biến private → `@onready` → hàm built-in (`_ready`, `_physics_process`...) → hàm public → hàm private.
- Thông số chỉnh được (tốc độ, lực nhảy, damage, thời gian...) dùng `@export` (gom bằng `@export_group`) hoặc Resource `.tres`. **Không hard-code số ma thuật.**
- Logic di chuyển đặt trong `_physics_process`. Input dùng **Input Map** (`move_left`, `move_right`, `move_forward`, `move_back`, `jump`, `dash`, `attack`, `skill`), không dùng phím cứng.
- Player dùng **state machine** (idle, run, jump, fall, dash, attack...), không dồn hết vào một hàm `if/else` dài.
- Giao tiếp giữa các hệ thống dùng **signal** hoặc `EventBus`. Tránh `get_node("../../..")`.
- Máu, sát thương: dùng component (`HealthComponent`, `HitboxComponent`, `HurtboxComponent`) để player, quái, boss dùng chung.
- Collision layer phải đặt tên trong Project Settings và dùng nhất quán.
- Comment bằng tiếng Việt, ngắn gọn, chỉ giải thích "tại sao", không giải thích điều hiển nhiên.

### Hiệu năng (bắt buộc)

- **Không viết code làm giảm hiệu năng; luôn chọn cách tối ưu nhất** trong khi vẫn giữ kiến trúc mở rộng được.
- **Ưu tiên signal / sự kiện thay cho kiểm tra mỗi frame.** Không quét `get_overlapping_areas()`, `get_nodes_in_group()`, `find_children()` trong `_process` / `_physics_process` khi có thể theo dõi bằng signal vào/ra.
- **Tắt xử lý khi không cần:** `set_process(false)` / `set_physics_process(false)` khi node không có việc gì (vùng trống, hiệu ứng đã xong, vật đã dùng).
- **Không cấp phát trong vòng lặp nóng:** không tạo mảng, Dictionary, Resource, node mới mỗi frame; cache lại tham chiếu (`@onready`, biến thành viên).
- **Không `get_node()` / `$Path` lặp lại mỗi frame**: lấy một lần vào `@onready`.
- **Vật lý:** dùng collision layer/mask để lọc ngay từ engine thay vì lọc bằng code; Area3D chỉ bật `monitoring` khi cần.
- **Hình ảnh:** particle có giới hạn số hạt hợp lý; tắt `cast_shadow` cho mesh/hiệu ứng nhỏ không cần bóng; dùng chung material/mesh khi không cần riêng (chỉ `duplicate()` khi bắt buộc).
- **Thứ cần tạo/xóa liên tục** (đạn, hiệu ứng trúng đòn, số sát thương...) dùng **object pool** thay vì `instantiate()` / `queue_free()` mỗi lần.
- Khi có lựa chọn giữa cách dễ viết và cách nhanh hơn mà độ phức tạp tương đương, chọn cách nhanh hơn và ghi chú lý do bằng comment.

## 5. Game feel — checklist bắt buộc

Code điều khiển nhân vật phải có đủ các mục dưới đây (trừ khi người dùng bỏ). Mọi thông số đều phải `@export` để chỉnh được.

### Di chuyển
- **Acceleration / deceleration** riêng biệt, không đổi vận tốc tức thì.
- **Turn acceleration**: đổi hướng ngược nhanh hơn tăng tốc thường, tránh cảm giác trơn trượt.
- **Air control** riêng (gia tốc trên không khác dưới đất).
- **Xoay model mượt** theo hướng di chuyển (lerp góc), model xoay chứ không xoay cả body.
- **Di chuyển theo hướng camera**: input được quy đổi theo góc camera.
- **Chuẩn hóa input chéo**: đi chéo không nhanh hơn đi thẳng; hỗ trợ analog stick có deadzone.
- Xử lý **dốc và bậc thang** (`floor_max_angle`, `floor_snap_length`), không bị nảy khi xuống dốc.

### Nhảy
- **Coyote time**: vẫn nhảy được trong vài khung hình sau khi rời mép.
- **Jump buffer**: bấm nhảy trước khi chạm đất một chút vẫn được tính.
- **Variable jump height** (jump cut): nhả nút sớm thì nhảy thấp.
- **Fall gravity multiplier**: rơi nhanh hơn lúc bay lên, nhảy không bị "lơ lửng".
- **Apex hang**: giảm trọng lực ngắn ở đỉnh cú nhảy để dễ canh.
- **Terminal velocity**: giới hạn tốc độ rơi tối đa.
- Lực nhảy tính từ **chiều cao và thời gian lên đỉnh**, không đoán số.
- **Double jump**: reset khi chạm đất; coyote time không tiêu hao lượt double jump.
- **Ledge forgiveness**: hụt mép platform một chút vẫn được đẩy lên (nếu khả thi trong 3D).

### Dash
- **Dash buffer** và **cooldown**.
- **I-frames** (bất tử) trong lúc dash.
- Dash theo hướng input; không có input thì dash theo hướng nhân vật đang quay.
- Có giới hạn số lần dash trên không; reset khi chạm đất.
- Kết thúc dash giữ lại một phần quán tính.

### Combat
- **Attack buffer**: bấm đánh trong lúc animation trước chưa xong vẫn được ghi nhận.
- **Combo window**: khoảng thời gian nối đòn.
- **Animation cancel**: cho phép hủy đòn đánh bằng dash ở các frame quy định.
- **Hitstop**: dừng hình vài khung khi đánh trúng.
- **Knockback** cho cả mục tiêu và (nhẹ) người đánh.
- **Hit flash** và **i-frames khi bị đánh**.
- Hitbox chỉ bật trong **active frames** của đòn đánh, mỗi đòn chỉ trúng một mục tiêu một lần.
- Hướng đòn đánh theo input, có **soft lock / aim assist** nhẹ về quái gần nhất.

### Phản hồi (juice)
- **Camera** đi theo mượt (smoothing), có lookahead theo hướng di chuyển.
- **Screen shake** khi đánh trúng, bị đánh, tiếp đất mạnh.
- **Squash & stretch** khi nhảy và tiếp đất.
- **Particle**: bụi khi chạy, nhảy, tiếp đất, dash; vệt khi chém.
- **Âm thanh** cho mỗi hành động (để chỗ cắm sẵn nếu chưa có file).
- **Bóng đổ dưới chân** (blob shadow) để người chơi biết vị trí tiếp đất trong 3D.

## 6. Quy trình làm việc

1. Đọc yêu cầu → hỏi lại nếu chưa rõ.
2. Trình bày kế hoạch: danh sách file sẽ tạo/sửa, cấu trúc node, Input Map cần thêm.
3. **Chờ người dùng đồng ý.**
4. Code theo đúng quy ước trên.
5. Chạy thử nếu có thể; báo đúng kết quả, liệt kê những gì chưa test được và những thông số người dùng nên chỉnh.
