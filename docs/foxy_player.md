# Foxy — model, animation và scene Godot

Mở `res://tests/player/fox/fox_demo.tscn` trong Godot rồi nhấn **F6**.
Demo có sẵn kiếm và dash để thử, không cấp vật phẩm hay ghi tiến trình lúc khởi động.

- `entities/player/foxy/foxy_player.gd` (`FoxyPlayer`): script của `player.tscn`, gắn model / animation Foxy vào Player.
- `entities/player/foxy/foxy_bow_animations.gd`: dựng clip cung (`Idle_Bow`, `Run_Bow`, `Bow_Shoot`) từ Idle/Run lúc chạy.
- `assets/characters/foxy/foxy.glb`: model Foxy (rig `Foxy_Rig`, kiếm gắn sẵn vào tay phải, blend shape `Blink` trên mặt).
- `assets/shaders/foxy_toon.gdshader`: shader toon cho thân; viền dạng inverted hull đã bake trong mesh.
- `resources/player/foxy_animation_markers.tres`: mốc vung kiếm (`hit_start` / `hit_end`) của Attack_1/2/3.
- `tests/fox/fox_player.tscn`: player dùng Foxy và FSM/component hiện có (scene demo).

Tên clip, tên xương, đường dẫn rig, màu viền, nhịp chớp mắt đều là `@export` trên `FoxyPlayer`,
đổi model khác không phải sửa code.

## Animation

Clip trong `foxy.glb`: Idle, Idle_Sword, Run, Run_Sword, Walk, Jump, Jump_Start, Jump_Land, TMP_JumpAir,
Fall, Land, Dash, Dodge_Roll, PickUp, Attack_1, Attack_2, Attack_3, Attack_Melee, Hurt, Death.

`clip_map` đổi tên animation mà FSM / AttackData yêu cầu sang clip Foxy. Combo kiếm 3 nhát
(`resources/weapons/sword.tres`):

| AttackData | Clip Foxy |
|---|---|
| `sword_slash_1` (`Melee_1H_Attack_Slice_Horizontal`) | Attack_1 |
| `sword_slash_2` (`Attack_Backhand`) | Attack_2 |
| `sword_slash_3` (`Attack_Finisher`) | Attack_3 |

Idle/Run/Fall lặp (`loop_clips`). Clip Dash được nén đúng thời gian của DashData.
Tốc độ phát Run chạy theo vận tốc ngang (`run_reference_speed`), blend 0.08 s.
Track blend shape trong clip bị bỏ khi nạp để code điều khiển chớp mắt.

## Mốc vung kiếm

Đo bằng Godot headless: lấy mẫu vị trí đầu kiếm theo từng khung 1/60 s ở tốc độ gốc.
Cả ba clip vung nhanh nhất trong khoảng 0.067–0.100 s (đầu kiếm 60–77 m/s), sau 0.117 s gần như đứng yên.
Marker đặt `hit_start = 0.05`, `hit_end = 0.133` để hitbox bật đủ vài khung vật lý.
`attack.gd` chia marker cho `AttackData.anim_speed` ra giây thực; clip không có marker thì dùng
`active_start` / `active_end` trong AttackData.

## Tích hợp

Player chính `entities/player/player.tscn` dùng Foxy. Nhấn **F5** để chơi ở các khu hiện có.

Hai tùy chọn `preview_sword` và `preview_dash` chỉ bật trong demo / test
(kiếm xem thử là `preview_weapon`, mặc định `sword.tres`).
Player thường vẫn cần nhặt vũ khí và mở khóa dash theo tiến trình.

## Kiểm tra

Chạy scene `tests/fox/runtime_check.tscn` (hoặc `main_player_check.tscn` để kiểm tra `player.tscn`):
rig có xương tay cầm cung, kiếm hiện, đủ clip cung và marker, chuyển động xương của mọi clip,
Run, Jump, Dash, chém trúng hình nộm và hồi về Idle.
Khi chạy có giao diện, kiểm tra lưu ảnh `user://fox_preview_game.png`.
