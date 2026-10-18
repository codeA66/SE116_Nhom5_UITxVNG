# Hệ thống kiếm và cung

Nhánh: `weapon_system`. Dùng player cáo hiện tại, FSM hiện tại và hệ thống `DamageInfo` / `HurtboxComponent` hiện có.

## Chạy thử

- **F5**: chơi màn chính. Trong `Area11_Sword`, kiếm ở `(15, 9, -127)`, cung ở `(17, 9, -127)` — cách nhau 2 m trên cùng sân.
- Thử nhanh: mở `tests/test_movement.tscn` hoặc `tests/test_game.tscn`, nhấn **F6**. Cả hai scene cũng có cung cạnh kiếm.
- **F**: nhặt vật gần nhất; prompt ghi rõ “Nhặt Kiếm” hoặc “Nhặt Cung”. Vũ khí mới được tự chọn sau động tác nhặt.
- **1**: chọn kiếm. **2**: chọn cung. Chỉ chọn được vũ khí đã nhặt.
- **J**: chém hoặc bắn một mũi tên. Bấm lại để tấn công tiếp.
- **WASD**: chọn hướng di chuyển/ra đòn. Khi không di chuyển, bắn theo hướng nhân vật đang nhìn. Có hỗ trợ quay về mục tiêu gần trong góc cho phép, giống kiếm.

Hai ô hình thoi nằm dưới thanh máu. Chưa nhặt thì biểu tượng mờ; đã nhặt thì biểu tượng hiện rõ; đang chọn thì viền sáng xanh và ghi “ĐANG DÙNG”. Nếu bấm đổi trong lúc chém, bắn, nhặt hoặc dash, game nhớ lựa chọn cuối và đổi khi trở lại trạng thái di chuyển. Không đổi khi đã chết.

Cung hiện bắn thẳng, tên vô hạn; chưa có tích lực khi giữ nút, trọng lực đạn hoặc ngắm bằng chuột.

## Node được thêm / đổi

Trong `entities/player/player.tscn` (đồng thời cập nhật scene demo `generated/fox_player.tscn`):

```text
Player
├─ Model
│  └─ ArrowSpawn (Marker3D)                  ← mới: vị trí phóng tên
├─ WeaponSocket (BoneAttachment3D)          ← đổi từ Node3D, bám Hand_L
│  └─ BowVisual                            ← tạo khi chọn cung, xóa khi chọn kiếm
│     ├─ Limb0 … Limb5 (MeshInstance3D)      ← thân cung
│     ├─ Grip (MeshInstance3D)              ← tay cầm
│     ├─ TopString (MeshInstance3D)
│     └─ BottomString (MeshInstance3D)
└─ HUD
   └─ WeaponSlots (Control)                 ← mới
      ├─ SwordSlot (Control)
      │  ├─ Icon (TextureRect)
      │  ├─ Key (Label)
      │  ├─ Name (Label)
      │  └─ Status (Label)
      ├─ BowSlot (Control, các con như SwordSlot)
      └─ Hint (Label)
```

`WeaponSocket` dùng **Use External Skeleton**, trỏ tới skeleton của cáo; **Bone Name = Hand_L**. Kiếm vẫn dùng mesh `Sword` đã skin vào tay phải trong GLB, chỉ ẩn/hiện theo vũ khí được chọn. Các mesh con của `BowVisual` được script tạo khi scene sẵn sàng, có xem trước khi mở riêng `assets/weapons/bow_visual.tscn`.

Trong màn chính: thêm `Area11_Sword/BowPickup`, instance của `objects/pickups/weapon_pickup.tscn`; giữ các node con `Visual` và `InteractableComponent/CollisionShape3D`. Gán `weapon = resources/weapons/bow.tres`, `persistent_id = level_1.bow_pickup`. Bảng `SignSword` được cập nhật phím điều khiển.

Khi bắn, thêm một instance `objects/projectiles/arrow.tscn` vào cùng scene với player:

```text
Arrow (Node3D)
├─ Shaft (MeshInstance3D)
├─ Tip (MeshInstance3D)
└─ Feather (MeshInstance3D)
```

Tên quét ray trên toàn bộ đoạn di chuyển mỗi physics frame, gồm cả đoạn từ thân người đến `ArrowSpawn` ở frame đầu. Nhờ đó tường mỏng hoặc tường sát người vẫn chặn được tên. Tên gây sát thương một lần qua `HurtboxComponent`, rồi bị xóa khi va chạm hoặc hết tuổi thọ. Không cần thêm `Area3D`/`CollisionShape3D` vào tên. Collision mask mặc định: **world + enemy**, không chứa player.

## Các thông số nên chỉnh

| Muốn chỉnh | Nơi chỉnh | Giá trị hiện tại / ý nghĩa |
| --- | --- | --- |
| Vị trí cung trong map | `Area11_Sword/BowPickup > Transform > Position` | `(17, 9, -127)` |
| Kích thước cung khi nằm trên đất | `resources/weapons/bow.tres > Model Scale` | `1.0` |
| Tốc độ tên | `bow.tres > Projectile Speed` | `18 m/s` |
| Thời gian tồn tại | `bow.tres > Projectile Lifetime` | `1.5 s`, tầm bay tối đa khoảng `27 m` |
| Tầm tìm mục tiêu hỗ trợ | `bow.tres > Attack Range` | `12 m`; đây không phải tầm bay tối đa |
| Góc hỗ trợ hướng đánh/bắn | `Player > Combat > Soft Lock Angle` | `60°` so với hướng input/nhìn |
| Sát thương, lực đẩy | `resources/attacks/bow_shot.tres` | `Damage = 1`, `Knockback = 2.5` |
| Thời điểm thả tên | `bow_shot.tres > Active Start` | `0.24 s` từ lúc nhấn J |
| Tổng thời gian bắn | `bow_shot.tres > Duration` | `0.55 s` |
| Mốc được hủy bằng dash | `bow_shot.tres > Cancel Start` | `0.38 s` |
| Điểm sinh tên | `Player/Model/ArrowSpawn > Position` | `(-0.06, 1.02, 0.55)`, trong không gian Model |
| Vị trí/kích thước HUD | `ui/hud/weapon_slots.tscn` | Chỉnh offsets của root và hai slot |
| Màu sáng ô chọn | `SwordSlot` / `BowSlot > Accent Color` | Xanh `#7be9ff` |
| Hình biểu tượng | `ui/hud/icons/sword.svg`, `bow.svg` | SVG có thể sửa/thay độc lập |
| Hình dáng, màu cung | `assets/weapons/bow_visual.gd` | Mảng `points`, bán kính và material của thân/dây |
| Tư thế tay | `generated/fox_bow_animations.gd > _arm_pose()` | Hướng xương cánh tay/cẳng tay và bàn tay |

Giữ `0 < active_start < duration`, `anim_speed > 0`. Cung dùng `active_start` để phóng đúng một tên; `active_end` dành cho cửa sổ hitbox cận chiến. Các animation `Idle_Bow`, `Run_Bow`, `Bow_Shoot` được dựng từ clip gốc khi chạy, dùng thời gian trong `bow_shot.tres`; chỉnh resource rồi chạy lại để xem. Dây cung có động tác kéo/thả riêng trong `generated/fox_player.gd`.

## Luồng code và lưu tiến trình

- `WeaponData`: thêm `Slot` (`SWORD = 0`, `BOW = 1`) và cấu hình projectile. Kiếm cũ mặc định ở slot 0.
- `PlayerProgress.weapons`: giữ các vũ khí đã nhặt; `PlayerProgress.weapon` giữ vũ khí đang chọn.
- `GameState.add_weapon()`: nhận vũ khí. `select_weapon(slot)`: chọn vũ khí đã có. Signal hiện có cập nhật model/HUD và tự lưu.
- `Player`: đọc Input Map `weapon_1` / `weapon_2`, giữ yêu cầu đổi trong lúc thực hiện hành động; `shoot_arrow()` tạo tên.
- `StateMachine/Attack`: dùng chung cho kiếm và cung. Với kiếm bật hitbox như cũ; với cung phóng tên ở `active_start`, không bật hitbox kiếm. Chụp dữ liệu vũ khí khi bắt đầu đòn để việc đổi vũ khí không thay đổi đòn đang diễn ra.
- Save JSON lên **version 3**, thêm `weapons`, giữ `weapon` và các cờ pickup. Save v1/v2 có kiếm sẽ tự chuyển sang danh sách sở hữu. Chuyển scene/tải save giữ cả hai vũ khí và ô đang chọn.

`generated/fox_demo.tscn` có tùy chọn `preview_sword` dành riêng cho xem animation kiếm; dùng player/màn chính hoặc `tests/test_movement.tscn` để thử hệ thống đổi vũ khí thực tế.

## Kiểm tra tự động

Từ PowerShell tại repo, thay đường dẫn Godot theo máy:

```powershell
.\tests\run_weapon_tests.ps1 -GodotPath 'D:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
```

Thêm `-Visual` để chạy có render và xuất ảnh `.godot/weapon_pickups.png`, `weapon_sword_equipped.png`, `weapon_bow_equipped.png`, `weapon_bow_draw.png`. Script cô lập APPDATA/LOCALAPPDATA trong `.godot/weapon_runtime`, sau đó khôi phục biến môi trường; không thay save cá nhân. Scene tự động không được chạy trực tiếp bằng F6 với save thật, còn hai scene chơi thử phía trên chạy bình thường.

`tests/test_weapon_system.tscn` kiểm tra input nhặt/đổi/đánh, HUD, model đang cầm, kiếm gây sát thương, bắn đúng một tên, va chạm tường mỏng và tường sát người, tên hết hạn, bị ngắt khi kéo cung, save v3, chuyển save v2 và tạo player mới. Các bài kiểm tra rig/player cũ đã cập nhật cho ba clip cung mới.

Tham khảo API: [BoneAttachment3D](https://docs.godotengine.org/en/stable/classes/class_boneattachment3d.html), [ray casting trong Godot](https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html).
