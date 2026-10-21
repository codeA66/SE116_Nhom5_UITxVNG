# Cáo tinh — model, animation và scene Godot

Mở `res://tests/fox/fox_demo.tscn` trong Godot rồi nhấn **F6**.
Demo có sẵn kiếm và dash để thử, không cấp vật phẩm hay ghi tiến trình lúc khởi động.

- WASD: di chuyển; Space: nhảy; Shift: dash; J: chém ngang; E: tương tác.
- `entities/player/fox_player.gd`: script của `player.tscn`, gắn model / animation cáo vào Player.
- `tests/fox/fox_player.tscn`: player dùng model cáo và FSM/component hiện có (scene demo).
- `assets/characters/fox/fox_spirit.glb`: rig 22 xương, 4 mesh nhân vật và kiếm gắn vào Weapon_R.
- `assets/characters/fox/fox_sword.glb`: kiếm riêng cho vật phẩm nhặt.
- `resources/weapons/fox_sword.tres` + `resources/attacks/fox_slash.tres`: kiếm xem thử (chỉ dùng khi bật `preview_sword`).
- `resources/player/fox_animation_markers.tres`: mốc vung kiếm (hitbox, vệt chém) của các clip chém.
- `assets/characters/fox/source/fox_spirit_animated.blend`: file Blender chỉnh sửa rig, mesh, kiếm và animation.
- `assets/characters/fox/source/*.py`: script dựng animation (`expressive_motion.py`, `refine_locomotion.py`,
  `combo_attacks.py` cho 2 đòn combo). Chạy bằng `blender -b fox_spirit_animated.blend --python <script>`.
- `assets/characters/fox/source/animation_manifest.json`: thời lượng và chế độ lặp của các clip.

## Animation

Idle, Idle_Sword, Run, Run_Sword, Jump, Fall, Land, Dash, PickUp,
Attack_Horizontal, Attack_Backhand, Attack_Finisher, Hurt, Death.

Combo kiếm 3 nhát (`resources/weapons/sword.tres`): Attack_Horizontal (phải sang trái),
Attack_Backhand (trái sang phải), Attack_Finisher (thủ thế xa, vung rộng, khuỵu người).

Idle/Run/Fall lặp. Các clip hành động chạy một lần. FSM điều khiển vật lý;
animation được làm tại chỗ, không kéo vị trí CharacterBody3D.
Tư thế T-pose vẫn là bind pose của skeleton.

## Tích hợp

Player chính `entities/player/player.tscn` hiện dùng model và animation cáo.
Nhấn **F5** để chơi game với player cáo ở các khu hiện có.
`tests/fox/fox_player.tscn` vẫn là scene riêng dùng cho demo và tái sử dụng.

Hai tùy chọn `preview_sword` và `preview_dash` chỉ bật trong demo.
Player thường vẫn cần nhặt vũ khí và mở khóa dash theo tiến trình.
Model kiếm tự tạo được dùng thay cho model tạm; không dùng mesh/animation KayKit.

Chu kỳ chạy 0.533 s và idle 3 s được dựng riêng bằng IK tay/chân rồi bake thành keyframe.
Tay liền khối, giữ thẳng từ vai tới bàn tay, hạ cạnh hông và đung đưa từ vai.
Góc cầm kiếm do xương Weapon_R riêng điều khiển, không bẻ cổ tay hoặc khuỷu.
Hông và vai xoay ngược nhẹ; đuôi có độ trễ.
Tốc độ phát chạy chuyển mượt theo vận tốc, với thời gian blend 0.08 s.
Gấu áo có trọng số theo đùi để giảm xuyên vải; chưa có mô phỏng vải hoặc IK runtime.
Material dùng palette 128×32 có vùng đệm, lọc nearest không mipmap để giữ ba màu
ở camera xa. Model ít polygon nên tắt LOD tự sinh và nén mesh.

Ảnh động quay trực tiếp từ Godot: `preview_run.gif`, `preview_idle.gif`.

## Kiểm tra

Chạy scene `tests/fox/runtime_check.tscn` để kiểm tra đủ 12 clip,
chuyển động xương, Run, Jump, Dash, chém trúng hình nộm và hồi về Idle.
Kiểm tra không ghi tiến trình bằng cách sử dụng các tùy chọn preview.
Khi chạy có giao diện, kiểm tra lưu ảnh `user://fox_preview_game.png`.
