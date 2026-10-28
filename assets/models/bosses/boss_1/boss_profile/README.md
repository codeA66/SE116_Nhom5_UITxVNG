# Boss Profile Package (Standalone Assets)

Gói tài nguyên hoàn chỉnh của Boss (3D Model, Texture, Animation Library, VFX), được đóng gói độc lập để dễ dàng copy và tích hợp vào bất kỳ project Godot 4 nào mà không phụ thuộc vào code script cũ.

---

## 1. Cấu trúc thư mục

```
boss_profile/
├── README.md                          # Tài liệu hướng dẫn này
├── Boss2.glb                          # 3D Model nhân vật (15k polygon, đã tối ưu)
├── Boss2_texture_pbr_20250901.png      # Texture bề mặt PBR
├── boss.tscn                          # Scene visual chuẩn của Boss (có sẵn Skeleton + AnimationPlayer)
├── animation/
│   └── boss_animation_library.tres    # Thư viện toàn bộ 10 Animation đã chuẩn hóa
├── vfx/
│   └── fireball_vfx/                  # 3D Model hiệu ứng quả cầu lửa (scene.gltf, scene.bin)
└── source_fbx/                        # Các file animation FBX gốc tải từ Mixamo
    ├── Mutant Swiping.fbx
    ├── Mutant Swiping(flip).fbx
    ├── Fireball.fbx
    ├── Mutant Jump Attack.fbx
    ├── Orc Idle.fbx
    ├── Mutant Dying.fbx
    ├── Mutant Roaring.fbx
    ├── Standing Taunt Battlecry.fbx
    ├── Mutant Breathing Idle.fbx
    └── Mutant Walking.fbx
```

---

## 2. Danh sách Animation trong `boss_animation_library.tres`

Tất cả các animation dưới đây đã được xử lý cân chỉnh:
- **Khóa xương cổ & đầu (`mixamorig_Head`, `mixamorig_Neck`)**: Chống méo / kéo dãn đầu.
- **Khóa trôi vị trí gốc (`lock_hips_root_motion`)**: Hitbox luôn cố định bám sát CharacterBody3D, không bị lệch khi nhân vật chuyển động.
- **Hạ góc vai & cánh tay**: Không bị quặp hoặc xuyên qua lồng ngực/bụng.
- **Cân bằng trục tọa độ**: Đứng thẳng $100\%$ vững chãi trên hai chân.

| Tên Animation | Thời lượng | Mô tả chi tiết |
| :--- | :---: | :--- |
| `Idle` | 2.50s | Tư thế đứng thở, đảo mắt quan sát. (Loop) |
| `Orc Idle` | 3.90s | Tư thế đứng gù gầm gừ đặc trưng của Orc/Mutant. (Loop) |
| `Walk` | 1.20s | Bước đi nặng nề, dồn trọng tâm. (Loop) |
| `Normal_Attack_1` | 2.70s | Đòn đánh thường quét tay trái từ ngoài vào trong. |
| `Normal_Attack_2` | 2.70s | Đòn đánh thường quét tay phải (flip) từ ngoài vào trong. |
| `Jump Attack` | 3.73s | Nhảy vồ lên không trung và dậm mạnh xuống đất. |
| `Cast_Fireball` | 3.40s | Bước lùi một chân, hai tay tụ cầu lửa rồi chưởng về phía trước. |
| `Roaring` | 3.47s | Ngửa cổ gầm vang thị uy. |
| `Taunt` | 3.87s | Đập ngực khiêu khích đối thủ. |
| `Buff` | 2.87s | Gồng năng lượng tăng cường sức mạnh. |
| `Dying` | 3.53s | Gục ngã khi hết máu. |

---

## 3. Cách tích hợp vào Project mới

### Bước 1: Copy thư mục
Copy nguyên thư mục `boss_profile` vào thư mục dự án mới của bạn (ví dụ đặt tại `res://boss_profile/` hoặc `res://characters/boss_profile/`).

### Bước 2: Sử dụng trong Scene Character của bạn
Trong project mới, bạn tạo một node `CharacterBody3D` (ví dụ `BossEnemy.tscn`):
1. Thêm `CollisionShape3D` (khuyên dùng CapsuleShape3D: `radius = 0.85`, `height = 3.0`, vị trí `y = 1.5`).
2. Kéo thả file `boss.tscn` vào làm node con của `CharacterBody3D`.
3. Trong script điều khiển boss của bạn, chỉ cần gọi:
   ```gdscript
   @onready var anim_player: AnimationPlayer = $Boss/AnimationPlayer

   func _ready() -> void:
       anim_player.play("Idle")

   func perform_attack() -> void:
       anim_player.play("Normal_Attack_1")
   ```

---

## 4. Tích hợp VFX Fireball (Tùy chọn)

- File model cầu lửa nằm tại `res://boss_profile/vfx/fireball_vfx/scene.gltf`.
- Bạn có thể kéo file này vào một `Area3D` đạn bay của bạn, gắn `OmniLight3D` màu cam (`energy = 3.5`, `range = 6.0`) để tạo ánh sáng lập lòe đẹp mắt.
