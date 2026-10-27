# Kế hoạch Thiết kế Boss 1: "Dị Thú Tha Hoá" (Mutant Boss - Map Gió)

Tài liệu đặc tả kỹ thuật và kế hoạch triển khai Boss đầu tiên cho `levels/zone_1_wind/level_1/level_1.tscn` (tại `T2Room27BossGate`).

---

## 1. Tổng quan & Ý tưởng Thiết kế

- **Tên Boss:** Dị Thú Tha Hoá (*Corrupted Mutant*).
- **Vị trí xuất hiện:** Cuối Level 1, khu vực `BossEntry` của `T2Room27BossGate` (hoặc đấu trường riêng kết nối qua cổng).
- **Mục tiêu gameplay:** 
  - Là bài kiểm tra tổng hợp kỹ năng của người chơi ở Level 1: né đòn quét kiếm bằng Dash, né sóng chấn bằng Jump, và đặc biệt là **dùng Kỹ năng Gió (E) để phản đòn cầu lửa phá khiên bất tử**.
- **Triết lý hiển thị (Diegetic Design):** 
  - **Không dùng thanh máu Boss trên HUD.** Toàn bộ trạng thái trận đấu (lượng máu tương đối, trạng thái khiên bất tử, số tầng khiên còn lại, cơ hội phản đòn) được thể hiện $100\%$ qua **dấu hiệu thị giác (Visual Cues)** trên chính thân Boss và đấu trường.
- **Máu tối đa:** 20 HP (Foxy đánh kiếm thường = 1 sát thương / nhát, chém kết liễu = 2 sát thương, tên bắn = 1).
- **Đặc điểm thể chất & Cơ chế I-Frames (Khung bất tử khi nhận đòn):**
  - Kích thước: Capsule bán kính `0.85 m`, chiều cao `3.0 m` (to gấp 1.7 lần Player Foxy).
  - Kháng khựng đòn (Super Armor): Không bị khựng giật khi bị chém thường, chỉ bị choáng khi bị cầu lửa dội ngược phá vỡ khiên.
  - **Cơ chế I-Frames theo Phase (chống người chơi spam combo):**
    - **Phase 1 (100% → 50%) & Phase 2 (50% → 20%):** Boss có `invincibility_time = 0.6s` trên `HurtboxComponent`. Sau mỗi nhát chém trúng, Boss chớp đỏ và bất tử 0.6s, ngăn Foxy chém liên hoàn cả combo 3 nhát trong một nhịp.
    - **Phase Cuối (< 20% HP):** **Tắt I-Frames hoàn toàn** (`invincibility_time = 0.0s`). Đổi lại, Boss trở nên **cực kỳ hung hãn** (tốc độ di chuyển nhanh, xuất chiêu dồn dập). Nếu người chơi né thành công và tìm được sơ hở, có thể dồn trọn combo kết liễu Boss ngay lập tức!

---

## 2. Hệ thống Dấu hiệu Thị giác (Visual Cues) thay thế Thanh Máu

Vì game không dùng thanh máu, người chơi nhận biết trạng thái của Boss qua các dấu hiệu trực quan sau:

### 2.1 Trạng thái Máu & Thương tích (Damage States)
- **Giai đoạn 1 (100% → 50% HP):**
  - Cơ thể nguyên vẹn, dáng đứng vững chãi.
  - Khi trúng đòn: Phát hit flash trắng/đỏ nhẹ (có sẵn từ `character.gd` / `CombatFx`).
- **Giai đoạn 2 (50% → 20% HP - Sau khi vỡ khiên 1):**
  - Mắt rực lửa cam/đỏ, gai lưng bắt đầu bốc khói tha hoá nhẹ.
  - Nhịp thở nặng nề hơn khi dừng lại giữa các đòn đánh.
- **Giai đoạn Kết liễu (< 20% HP - Sau khi vỡ khiên 2):**
  - Khói tha hoá bốc lên dày đặc từ các khớp và lưng.
  - Bước chân hơi loạng choạng, báo hiệu Boss đã cạn kiệt sinh lực và có thể bị hạ gục chỉ bằng 1 combo dứt điểm.

### 2.2 Trạng thái Khiên Bất Tử (Invulnerable Shield Visuals)
- **Hình dạng khiên:** Sử dụng quả cầu 3D (`SphereMesh` bán kính ~`2.0 m`, `cull_mode = CULL_DISABLED`) bao bọc toàn thân Boss với vật liệu bán trong suốt (`transparency = ALPHA`), cho phép **nhìn xuyên qua được** để thấy rõ chuyển động của Boss bên trong.
- **Kích hoạt khiên (Mốc 50% & 20%):**
  - Boss phát animation `Buff` (gồng nộ), mặt đất xung quanh rung chuyển (`ScreenShake`).
  - Quả cầu khiên hiện lên bao quanh thân Boss.
- **Phản hồi khi người chơi cố đánh vào khiên:**
  - Kiếm/tên chạm vào quả cầu khiên lập tức bật ngược tia lửa kim loại (`CombatFx.spawn_hit_spark`) kèm âm thanh "keng" đanh thép. Boss không hề xi nhê, không nhận sát thương.
- **Hiển thị số tầng khiên theo màu sắc và độ đậm nhạt:**
  - **Ở mốc 50% (Khiên 1 tầng):** Quả cầu khiên hiện lên với độ đậm màu vừa phải. Khi bị cầu lửa dội ngược trúng $\to$ Quả cầu khiên vỡ/tắt ngay lập tức, Boss bị choáng (Stunned) gục xuống trong 2.5 giây.
  - **Ở mốc 20% (Khiên 2 tầng cường hoá):** 
    + *Ban đầu (2 tầng):* Quả cầu khiên hiện lên với **màu sắc đậm, rõ nét** (Alpha ~0.65).
    + *Trúng cầu lửa lần 1 (Bị nứt/suy yếu):* Quả cầu khiên **nhạt màu hẳn đi** (Alpha giảm xuống ~0.25, đổi sang sắc thái mờ ảo) để báo hiệu khiên đã bị nứt/giảm còn 1 tầng!
    + *Trúng cầu lửa lần 2 (Vỡ khiên):* Quả cầu khiên biến mất hoàn toàn $\to$ Boss kiệt sức choáng 3.0 giây, mở màn cho Phase Cuối hung hãn!

---

## 2. Pacing trận đấu & Cơ chế Khiên Bất Hoại (Shield Mechanic)

### Giai đoạn 1: 100% → 50% HP (Chiến đấu cận chiến & Sóng chấn)
- **Hành vi:**
  - Boss bước đi (`Walk`) áp sát người chơi.
  - Cự ly gần ($< 3.5\text{ m}$): Tung đòn quét tay trái hoặc phải (`Normal_Attack_1`, `Normal_Attack_2`) có telegraph rõ ràng (giơ tay lùi ra sau 0.6s).
  - Cự ly xa ($> 5.0\text{ m}$): Tung cú nhảy vồ dậm đất (`Jump Attack`), khi tiếp đất sinh ra vòng sóng chấn mặt đất (`GroundShockwave`), buộc người chơi phải canh thời điểm bấm Nhảy hoặc Dash qua vành sóng.

### Bước ngoặt 1: Mốc 50% HP (Bật Khiên Tầng 1 - Cần 1 lần phản cầu)
- **Kích hoạt:** Máu bị khóa cứng ở mốc $50\%$ (10 HP), Boss lập tức ngắt đòn đang đánh, lùi lại và phát animation `Buff` (gồng nộ).
- **Trạng thái:**
  - Bật lớp giáp bất tử (`is_invulnerable = true`, `shield_stacks = 1`) có hiệu ứng quả cầu năng lượng bọc quanh thân.
  - Trong trạng thái này, mọi đòn chém hoặc bắn tên của người chơi đều bật ra vô hiệu.
- **Tấn công bằng Cầu Lửa (`Cast_Fireball`):**
  - Boss lùi chân, tụ quả cầu lửa rồi chưởng thẳng về phía Foxy.
- **Khắc chế:**
  - Người chơi đứng đón hướng bay của cầu lửa, canh thời điểm nhấn **Skill Gió (E)**.
  - Luồng gió đẩy ngược quả cầu $180^\circ$ bay thẳng về phía Boss.
  - Cầu lửa trúng Boss $\to$ Khiên nổ tung (`shield_stacks = 0`), Boss bị choáng (Stunned) gục xuống trong 2.5 giây.
  - Mở khóa máu $\to$ Người chơi dồn sát thương tiếp.

### Giai đoạn 2: 50% → 20% HP (Cuồng nộ tăng tốc)
- Tốc độ di chuyển tăng $25\%$ (`Walk` nhanh hơn).
- Tần suất dùng `Jump Attack` dậm đất cao hơn.
- Cho phép combo 2 đòn quét tay liên tiếp (`Normal_Attack_1` $\to$ `Normal_Attack_2`).

### Bước ngoặt 2: Mốc 20% HP (Bật Khiên Cường Hoá - Cần 2 lần phản cầu)
- **Kích hoạt:** Máu bị khóa cứng ở mốc $20\%$ (4 HP), Boss phát animation `Buff` lần 2.
- **Trạng thái:** Bật Giáp Cường Hoá (`shield_stacks = 2`).
- **Thử thách cao trào:**
  - **Lần phản 1:** Boss tung quả cầu lửa thứ 1 $\to$ Player phản bằng Gió E trúng Boss $\to$ Khiên nứt vỡ 1 nửa (`shield_stacks = 1`), Boss gầm thị uy (`Roaring`) hoặc nhảy dậm đất 1 nhịp.
  - **Lần phản 2:** Boss tụ quả cầu lửa thứ 2 $\to$ Player tiếp tục phản thành công trúng Boss $\to$ Khiên vỡ vụn hoàn toàn, Boss kiệt sức choáng 3.0 giây.
- **Kết liễu (20% → 0% HP):**
  - Mở khóa máu, người chơi tung combo dứt điểm 4 HP còn lại.
  - Boss phát animation `Dying`, tắt hitbox và kích hoạt mở cửa qua màn.

---

## 3. Phân tích Kế thừa / Tái sử dụng / Tạo mới

| Thành phần | Loại | Kế thừa / Dùng từ đâu | Lý do |
|---|---|---|---|
| **Scene gốc Boss** (`boss_1.tscn`) | **Kế thừa** | Kế thừa từ `entities/_base/character.tscn` | Tận dụng trọn vẹn Jolt Physics 3D, hệ thống máu `HealthComponent`, vùng nhận đòn `HurtboxComponent`, co giãn `SquashStretch`, bóng `BlobShadow`, `WindReceiverComponent` và khung `StateMachine` có sẵn. |
| **Visual & Model** | **Tái sử dụng** | `assets/models/bosses/boss_1/boss_profile/Boss2.glb` | Dùng model có sẵn từ boss profile (15k poly đúng trần Art Guide). Nhúng vào node `Model/Visual` của scene. |
| **Animation Library** | **Tái sử dụng** | `boss_animation_library.tres` | Dùng 10 clips đã chuẩn hóa root-motion và xương từ `boss_profile/animation/`. |
| **Sóng kích mặt đất** | **Tái sử dụng** | `objects/shockwave/ground_shockwave.tscn` | Cơ chế sóng chấn đã có sẵn, chỉ cần gọi `launch()` khi Boss tiếp đất trong đòn `Jump Attack`. |
| **Script chính Boss** (`boss_1.gd`) | **Tạo mới** | `extends Character` | Quản lý logic đặc thù của Boss: khóa máu 50%/20%, đếm stack khiên, super armor (chặn stagger), điều phối chuyển phase và phát signal cho Boss UI. |
| **Các FSM States** | **Tạo mới** | `extends State` (`components/state_machine/state.gd`) | Đảm bảo tính mở rộng (Open/Closed): mỗi hành vi nằm ở một file riêng biệt (`boss_idle.gd`, `boss_chase.gd`, `boss_melee.gd`, `boss_jump_slam.gd`, `boss_buff.gd`, `boss_cast_fireball.gd`, `boss_stunned.gd`, `boss_dead.gd`). |
| **Dữ liệu Boss** (`boss_1_data.tres`) | **Tạo mới** | `extends Resource` (`boss_data.gd`) | Lưu trữ toàn bộ thông số tốc độ, máu, damage, tầm đánh để chỉnh trong Inspector, không hard-code số. |
| **Quả cầu lửa phản đòn** (`boss_fireball.tscn`) | **Tạo mới** | `extends Area3D` (dùng mesh từ `boss_profile/vfx/fireball_vfx/scene.gltf`) | Cần cơ chế đặc thù: gắn `WindReceiverComponent`, nghe signal gió thổi từ Player $\to$ đảo vector bay về Boss, đổi phe sát thương và phá khiên. Codebase hiện tại chưa có loại projectile phản đòn này. |
| **VFX Lồng Khiên & Dấu hiệu** (`boss_shield_vfx.tscn`) | **Tạo mới** | `extends Node3D` | Lồng khiên năng lượng + 2 lõi cầu sáng xoay quanh hiển thị số tầng khiên trực tiếp trên Boss thay vì dùng UI thanh máu. |

---

## 4. Danh sách File sẽ tạo / tích hợp

1. **Entities & Logic:**
   - `entities/bosses/boss_1/boss_1.tscn` (Scene kế thừa `character.tscn`)
   - `entities/bosses/boss_1/boss_1.gd` (Script điều khiển chính)
   - `entities/bosses/boss_1/boss_data.gd` (Script cấu trúc Resource)
   - `entities/bosses/boss_1/states/boss_idle.gd`
   - `entities/bosses/boss_1/states/boss_chase.gd`
   - `entities/bosses/boss_1/states/boss_melee.gd`
   - `entities/bosses/boss_1/states/boss_jump_slam.gd`
   - `entities/bosses/boss_1/states/boss_buff.gd`
   - `entities/bosses/boss_1/states/boss_cast_fireball.gd`
   - `entities/bosses/boss_1/states/boss_stunned.gd`
   - `entities/bosses/boss_1/states/boss_dead.gd`
2. **Resources:**
   - `resources/bosses/boss_1/boss_1_data.tres`
3. **Vật thể, Đạn & VFX Trạng Thái:**
   - `objects/projectiles/boss_fireball/boss_fireball.tscn`
   - `objects/projectiles/boss_fireball/boss_fireball.gd`
   - `entities/bosses/boss_1/vfx/boss_shield_vfx.tscn` (Lồng khiên + các ngọc năng lượng xoay quanh biểu thị tầng khiên)
4. **Đấu trường / Tích hợp Level 1:**
   - Gắn Boss vào `levels/zone_1_wind/level_1/rooms/t2_room_27_boss_gate.tscn` tại node `BossEntry` với Encounter trigger hoặc đấu trường `boss_wind_arena.tscn`.
6. **Kiểm thử:**
   - `tests/boss/test_boss_1.tscn` (Scene test cô lập chạy bằng phím F6 hoặc headless để đo hành vi thật).

---

## 5. Checklist Nghiệm thu Kỹ thuật (Đo hành vi thật)

- [ ] **Khóa máu hoạt động chuẩn xác:** Dùng Foxy chém liên tục, máu dừng chính xác ở mốc 10 HP (50%) và 4 HP (20%), không bị mất thêm máu do spam kiếm.
- [ ] **Khiên bất tử kích hoạt:** Khi có khiên, đòn chém thường và tên bắn đều không làm mất máu Boss.
- [ ] **Kỹ năng Gió E phản cầu lửa:** Bấm E trước quả cầu lửa $\to$ quả cầu đổi hướng bay thẳng vào Boss $\to$ nổ khiên $\to$ giảm đúng số stack (`shield_stacks`).
- [ ] **Phá khiên gây choáng:** Khi stack khiên về 0 $\to$ Boss chuyển sang state Stunned đúng thời gian (2.5s / 3.0s) rồi mới hoạt động lại.
- [ ] **Sóng chấn né được:** Cú nhảy dậm đất `Jump Attack` phát sóng chấn $\to$ Foxy đứng yên bị trúng đòn; Foxy nhảy lên hoặc dash qua thì né thành công.
- [ ] **Không rò rỉ bộ nhớ (Object Pool):** Cầu lửa sinh ra và nổ/xóa không làm tăng node vô tận trong SceneTree.
- [ ] **Animation mượt mà:** Khớp với các clip có sẵn, không bị biến dạng đầu/cổ/hông.
