# Hướng dẫn dựng nhân vật (quái, boss) từ scene gốc

Mọi nhân vật (player, quái, boss) kế thừa từ một scene gốc: `entities/_base/character.tscn`.
Scene gốc đã có sẵn vật lý, xoay model, máu, nhận đòn, chịu gió, co giãn khi nhảy và bóng dưới chân.
Nhân vật mới chỉ thêm phần riêng: model, state, hitbox, thông số.

Ví dụ đầy đủ: `entities/player/player.tscn`.

## 1. Scene gốc có gì

```
Character (CharacterBody3D, character.gd)
├── CollisionShape3D       capsule r 0.35, cao 1.8, đặt ở y 0.9
├── Model                  xoay theo hướng nhân vật nhìn
│   └── Visual             chứa model; SquashStretch co giãn node này
├── AnimationPlayer        root_node = ../Model
├── HealthComponent        máu
├── HurtboxComponent       vùng nhận đòn (+ CollisionShape3D capsule r 0.4)
├── WindReceiverComponent  chịu gió (+ CollisionShape3D)
├── SquashStretch          kéo dài khi bật lên, co dẹt khi tiếp đất
├── BlobShadow             bóng tròn dưới chân
└── StateMachine           rỗng, mỗi nhân vật tự thêm state
```

**Không xóa được node của scene gốc trong scene kế thừa** (giới hạn của Godot).
Không muốn dùng một component thì tắt nó, ví dụ hurtbox: bỏ chọn `monitorable`.

## 2. Các bước tạo một con quái

1. Chuột phải `entities/_base/character.tscn` → **New Inherited Scene**.
   Lưu thành `entities/enemies/<ten_quai>/<ten_quai>.tscn`.
2. Tạo script `entities/enemies/<ten_quai>/<ten_quai>.gd`:
   ```gdscript
   class_name TenQuai
   extends Character
   ```
   Kéo script vào node gốc (thay `character.gd`).
3. Điền thông số **bắt buộc** ở node gốc:
   - `movement`: một file `MovementStats` (.tres). Thiếu thì game báo lỗi ngay khi chạy.
   - `collision_layer`: `enemy`. Scene gốc để trống layer, chỉ va chạm với `world`.
4. Đặt **máu và phe**:
   - `HealthComponent` → `max_health`.
   - `HurtboxComponent` → `collision_layer` = `enemy`. Layer này quyết định phe nào đánh được nó.
   - Tùy chọn: `invincibility_time`, `resistances` (kháng theo loại sát thương).
5. **Model**: kéo file model (.glb) vào `Model/Visual`.
   Đặt `AnimationPlayer` → `root_node` trỏ tới gốc của model, ví dụ `../Model/Visual/TenModel`.
6. **Hitbox** (nếu quái có đánh): thêm `Area3D` gắn `hitbox_component.gd` vào **`Model`** (không phải `Visual`),
   để hitbox xoay theo hướng nhìn nhưng không bị co giãn.
   Layer `enemy_hitbox`, mask `player`.
7. **State**: thêm các node state vào `StateMachine` (mỗi state một file, `extends State`).
   Chọn `StateMachine` → `initial_state`. **Bỏ trống thì game lỗi lúc chạy.**

## 3. Bảng layer va chạm

| Node | Player | Quái |
|---|---|---|
| Thân (`collision_layer`) | `player` | `enemy` |
| Thân (`collision_mask`) | `world`, `enemy` | `world` (thêm `player` nếu muốn chặn người chơi) |
| `HurtboxComponent` | layer `player` | layer `enemy` |
| Hitbox | layer `player_hitbox`, mask `enemy` | layer `enemy_hitbox`, mask `player` |
| `WindReceiverComponent` | `wind_receiver` / `wind` (có sẵn trong scene gốc) | như player |

## 4. Đổi kích thước thân

- **Gán shape mới**, đừng sửa shape có sẵn của scene gốc: ở `CollisionShape3D` → `shape` → **New CapsuleShape3D**
  (hoặc **Make Unique**). Sửa thẳng shape kế thừa có thể làm đổi luôn scene gốc. Điểm này chưa được kiểm chứng
  trong editor nên cứ làm theo cách an toàn.
- **Dời `CollisionShape3D` lên y = chiều cao / 2**. Đo thật: capsule cao 2.6 m mà vẫn để y 0.9 thì quái lún 0.4 m
  xuống sàn.
- Làm tương tự cho `HurtboxComponent/CollisionShape3D` và `WindReceiverComponent/CollisionShape3D`.

## 5. Lưu ý khi viết code

- **Shape dùng chung giữa các con cùng loại.** Đổi shape của một con lúc game chạy thì mọi con cùng loại
  đổi theo (đã đo). Cần đổi riêng thì `duplicate()` shape trước, hoặc bật `resource_local_to_scene` cho shape đó.
- **Di chuyển:** state gọi `move_toward_direction()`, `apply_gravity()`, `jump()` của `Character`.
  Không tự gọi `move_and_slide()`: `Character` đã gọi sau khi state chạy xong (kèm lực gió).
- **Chết vì môi trường:** gai và vùng chết chỉ gọi hàm nếu nhân vật có hàm đó; không có thì không xảy ra gì
  (quái đứng trên gai vẫn sống).
  - `on_lethal_zone_entered()`: gai, nước sâu, vùng chết bật `lethal`. Gai truyền thêm 1 tham số `red_flash: bool`.
  - `on_kill_zone_entered()`: vùng chết không bật `lethal` (ví dụ rơi vực).
