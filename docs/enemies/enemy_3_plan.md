# Quái 3: Pháp sư Hồn Trôi (tên tạm) — Plan

> Trạng thái: **PLAN, chưa code**. Mọi file trong mục 7 chỉ được tạo sau khi người dùng đồng ý.
> Người dùng đã cho planner tự quyết các câu hỏi thiết kế: xem mục 2 "Quyết định của planner" (đổi được).

## 0. Yêu cầu gốc (người dùng đặt)

- HP 3.
- Luôn bay, **không thể bị rơi**, bay ở độ cao ngang player (tham khảo phù thuỷ / pháp sư bay của Death's Door).
- Tấn công: bắn quả cầu; player dùng gió (skill E, `WindBlastArea`) đẩy được quả cầu.
- Đôi khi dịch chuyển tới vị trí thích hợp để tung chiêu tiếp.
- Bộ ba quái: Quái 1 lính lướt chém HP3 (bị thổi bay), Quái 2 khiên nặng HP4 (không bị thổi), **Quái 3 là quái đánh xa duy nhất** → buộc player phải lao vào hoặc dùng gió phản đạn.

### Tham khảo Death's Door (đã kiểm tra nguồn)

Nguồn: EIP Gaming, *Death's Door Walkthrough – Part 2: Lost Cemetery* (https://eip.gg/deaths-door/guides/walkthrough-part-2-lost-cemetery/), đoạn giới thiệu "floating mage":
- Pháp sư bay bắn đạn và dịch chuyển; đạn **phản lại được** bằng một nhát cận chiến đúng lúc.
- Đánh trúng thì nó bị hất văng và **không tấn công lại cho tới khi đã dịch chuyển đi rồi hiện lại**.
- Cách đánh khuyên dùng: lao vào đánh ngay lúc nó vừa hiện ra.
- (Trong game gốc cần 5 đòn mới chết; game mình người dùng đặt HP 3.)

Những gì **không** kiểm tra được (wiki Fandom/BreezeWiki chặn truy cập): tên chính thức của quái, thời gian niệm phép, tốc độ đạn, cách chọn chỗ dịch chuyển. Mọi con số dưới đây là của planner, **không lấy từ Death's Door**.

Ghi chú lệch tài liệu: `docs/art_style_guide.md` dòng 119 ghi ý tưởng "Quái bay: bị gió thổi rơi khỏi không trung" (trạng thái "Chưa"). Plan này theo yêu cầu mới của người dùng (**không rơi**); gió chỉ đẩy ngang và ngắt chiêu.

---

## 1. Hành vi + sơ đồ state

Vòng đánh chính (học từ Death's Door): **giữ khoảng cách → niệm cầu (báo trước) → bắn → (bắn lần 2) → dịch chuyển → hiện ra (khoảng hở) → lặp**. Bị đánh trúng → khựng → dịch chuyển ngay (không bắn tiếp tại chỗ).

```
                 thấy player
   Idle ⇄ Patrol ───────────────► KeepDistance (chase_state) ◄──────────────┐
     ▲                              │  │  │                                  │
     │ bỏ đuổi                      │  │  └─ cần dịch chuyển ─► Teleport ────┘
     └──────────────────────────────┘  │       (bắn đủ N quả / player áp sát
                                       │        quá lâu / mất đường bắn lâu /
                     hết hồi + trong   │        vừa bị đánh)
                     tầm + có đường bắn▼
                                   CastOrb (attack_state) ──► KeepDistance

  Bất kỳ state nào: trúng đòn ─► Hurt (dùng chung) ─► KeepDistance ─► Teleport ngay
                    trúng cú thổi ─► Blown (dùng chung, trôi ngang, KHÔNG rơi)
                    hết máu ─► Dead (dùng chung; xác rơi xuống bằng trọng lực thường)
```

| State | File | Mới / dùng chung | Việc làm |
|---|---|---|---|
| Idle, Patrol | `_base/states/` | dùng chung | Bay lơ lửng thay cho đi bộ (nhờ `apply_gravity` bị ghi đè, xem mục 7) |
| **KeepDistance** | `wisp_caster/states/keep_distance.gd` | **mới** | Giữ khoảng cách [min, max] với player, bay ngang chậm (strafe), quay mặt về player; quyết định bắn hay dịch chuyển |
| **CastOrb** | `wisp_caster/states/cast_orb.gd` | **mới** | Niệm (telegraph) → khoá hướng → bắn 1 quả → hồi |
| **Teleport** | `wisp_caster/states/teleport.gd` | **mới** | Biến mất → (dấu hiệu ở chỗ mới) → hiện ra (khoảng hở không bắn) |
| Hurt, Blown, Dead | `_base/states/` | dùng chung | Không sửa. Hurt/Blown gọi `apply_gravity` → bay lơ lửng; Dead → rơi (xem 7.2) |

Cấu hình qua export có sẵn của `Enemy`: `chase_state = &"KeepDistance"`, `attack_state = &"CastOrb"`. Không sửa `chase.gd` / `attack.gd`.

### Chi tiết từng state mới

**KeepDistance** (mỗi physics frame, không cấp phát):
1. `should_give_up_chase()` → Patrol (như Chase gốc).
2. Có yêu cầu dịch chuyển (`wants_teleport()`, xem dưới) và hết hồi dịch chuyển → Teleport.
3. `can_attack()` (hết hồi + trong `attack_range`) **và** `has_line_of_sight()` **và** đã qua `post_appear_delay` → CastOrb.
4. Di chuyển: khoảng cách < `preferred_min` → lùi ra xa; > `preferred_max` → lại gần; trong khoảng → bay ngang (vuông góc hướng tới player) với `strafe_speed_scale`, đổi chiều ngẫu nhiên mỗi `strafe_switch_min..max` giây. Luôn `face_direction` về player.
5. Đếm thời gian: player trong `panic_distance` liên tục; không có đường bắn liên tục. Tia đường bắn **chỉ bắn 1 lần mỗi `los_check_interval` (0.15 s)**, không phải mỗi frame.

Điều kiện `wants_teleport()` (một trong các điều sau):
- Đã bắn `casts_before_teleport` quả kể từ lần hiện ra trước.
- Player ở trong `panic_distance` lâu hơn `panic_time`.
- Mất đường bắn lâu hơn `no_los_time`.
- Vừa bị đánh trúng (`teleport_on_hurt`), giống Death's Door.

**CastOrb** (dùng `data.attack: AttackData` có sẵn cho mốc thời gian + sát thương):
- `0 → aim_lock_time`: `set_telegraph(true)`, quả cầu nhỏ lớn dần ở tay, **hướng còn xoay theo player**.
- `aim_lock_time → attack.active_start`: **khoá hướng** (player thấy hướng đã chốt, kịp né ngang).
- `attack.active_start`: bắn 1 quả (lấy từ pool), `set_telegraph(false)`, tăng bộ đếm số quả đã bắn.
- `→ attack.duration`: hồi, đứng yên (khoảng hở để player đánh).
- `exit()`: tắt telegraph, huỷ quả cầu đang niệm nếu chưa bắn (bị Hurt/Blown ngắt), `start_attack_cooldown()`.
- Đứng yên trên không lúc niệm (`move_toward_direction(Vector3.ZERO)`), trọng lực = hover.

**Teleport** (3 pha):
1. **Vanish** (`vanish_time`): telegraph, model co lại/xoáy (animation), vẫn đánh được (phần thưởng cho player đã áp sát).
2. **Hidden** (`hidden_time`): tắt hurtbox (`monitorable = false`), tắt va chạm thân (`collision_layer = 0`), ẩn model, tắt WindReceiver. Đầu pha: chọn điểm (mục 1.1); đặt **dấu hiệu dưới đất ở điểm mới** (vòng xoáy tím) để player đoán và lao tới. Cuối pha: `teleport(point, hướng nhìn về player)` (hàm có sẵn của `Character`, đã có `reset_physics_interpolation()`).
3. **Appear** (`appear_time`): hiện lại, bật hurtbox/va chạm/WindReceiver; **không được bắn** (khoảng hở kiểu Death's Door). Sau đó về KeepDistance; reset bộ đếm số quả, bắt đầu `teleport_cooldown`, bắt đầu `post_appear_delay`.
- Không tìm được điểm hợp lệ → hiện lại **tại chỗ cũ** (không bao giờ dịch vào chỗ sai). Vẫn tính hồi dịch chuyển để không thử lại mỗi frame.
- Bị đánh trong pha Vanish/Appear → Hurt như thường (Hurt dùng chung). Lúc Hidden không thể bị đánh (hurtbox tắt). Phải bật lại hurtbox/va chạm trong `exit()` để Hurt/Blown chen ngang không để quái tàng hình.

### 1.1 Chọn điểm dịch chuyển (component `TeleportPointFinder`)

Chạy **một lần mỗi lần dịch chuyển** (đầu pha Hidden), tối đa `candidate_count` (12) ứng viên, dừng ở ứng viên hợp lệ đầu tiên theo thứ tự đã xáo:

1. **Vị trí**: vòng quanh player bán kính `[ring_min, ring_max]`, góc ngẫu nhiên; độ cao = mặt đất + `hover_height`.
2. **Đủ xa chỗ cũ**: cách vị trí hiện tại ≥ `min_jump_distance` (dịch chuyển phải thấy rõ).
3. **Trong khu vực**: cách `home_position` ≤ `leash_range − leash_margin` (không dịch ra ngoài vùng canh, không kéo quái sang phòng khác).
4. **Trên nền đi được**: tia thẳng xuống (mask `world` = 1) phải chạm đất trong `max_ground_drop`. Không dịch tới ngay trên vực (sau đó vẫn tự bay qua vực được).
5. **Không kẹt trong khối**: `intersect_shape` với capsule thân quái tại điểm đó, mask `world | enemy | player_blocker` (1 + 4 + 256 = 261), exclude chính nó → phải rỗng. Nhờ vậy **không dịch vào hàng rào, khối chặn vô hình layer 9, tường, quái khác**.
6. **Có đường bắn**: tia từ ngực ứng viên tới ngực player, mask `world` (1) → không bị chặn (cùng luật với đạn, xem 2).
7. **Trên màn hình**: điểm nằm trong khung nhìn camera (`Camera3D.is_position_in_frustum()`; **chưa kiểm lại trên docs 4.7, phải kiểm trước khi code**). Không camera → bỏ qua điều kiện này.

Chi phí: tối đa 12 × (2 tia + 1 truy vấn hình) ≈ 36 truy vấn **một lần** mỗi 3+ giây → không đáng kể. Không chạy mỗi frame.

---

## 2. Quyết định của planner (người dùng đổi được)

| # | Câu hỏi | Quyết định | Lý do |
|---|---|---|---|
| D1 | Quả cầu bị thổi ngược có gây sát thương cho quái không? | **Có, 1 sát thương, trúng mọi quái** (không chỉ con bắn). | Đúng tinh thần Death's Door (phản đạn để đánh từ xa) và "môi trường là vũ khí" của game. HP 3 = 3 lần phản đạn hoặc trộn với chém. |
| D2 | Kiếm có phản được quả cầu không? | **Không, chỉ gió phản được.** | Yêu cầu chỉ nhắc gió; giữ vai trò riêng cho skill E. Muốn thêm sau: chỉ cần thêm cách nhận đòn kiếm, không sửa phần bay. |
| D3 | Phản xong có ngắm hộ không? | **Có, aim assist một lần lúc bị thổi**: nếu có hurtbox quái còn sống lệch ≤ `reflect_aim_angle` (25°) so với hướng thổi và trong `reflect_aim_range` thì bẻ hướng về con gần nhất. Quét group `hurtbox` **một lần** tại khoảnh khắc phản, không mỗi frame. | Hướng thổi = hướng cáo nhìn; không có hỗ trợ thì rất khó phản trúng con đang bay ngang. Giống soft lock có sẵn của player. |
| D4 | Đạn có xuyên khối chặn vô hình layer 9 không? | **Xuyên** (mask không có 256), giống tên của player (`arrow.gd` mask 5 = world + enemy). Tia kiểm tra đường bắn cũng chỉ dùng mask `world`. | Khối chặn vô hình; đạn nổ giữa không trung trước một thứ không nhìn thấy trông như lỗi. Hàng rào thấy được (nếu ở layer world) vẫn chặn đạn. |
| D5 | Thân quái có bị layer 9 chặn không? | **Có** (giữ mask 257 của `Character`). | Quái không bay ra khỏi khu vực có rào. Hệ quả: vực có viền khối chặn layer 9 thì quái cũng không bay qua; vực không có viền thì bay qua. Level designer cần biết điều này (xem câu hỏi Q2). |
| D6 | Bay qua vực, chạm KillZone / gai / nước chết người? | **Miễn nhiễm khi còn sống** (ghi đè `on_kill_zone_entered`, `on_lethal_zone_entered` trong `FlyingEnemy`). | Yêu cầu "không thể bị rơi"; hurtbox lơ lửng vẫn có thể chạm vùng gai cao 1 m. Chết rồi thì xác rơi bình thường. |
| D7 | Gió có tác dụng gì lên quái? | **Đẩy ngang + ngắt chiêu** (`wind_multiplier = 1.0`, `stagger_on_wind = true`), không rơi. Cột gió đứng (WindZone) có thể nâng tạm, hết gió thì hover kéo về. | Cho skill E một phản ứng rõ với quái bay (ngắt niệm phép), giống "bị hất văng" của Death's Door, mà không vi phạm "không rơi". |
| D8 | Khi nào dịch chuyển? | Sau **2 quả**, hoặc bị áp sát < 3 m quá 0.5 s, hoặc mất đường bắn > 1.5 s, hoặc **vừa trúng đòn**. Hồi dịch chuyển tối thiểu 3 s. | Nhịp Death's Door: đánh trúng thì nó chạy, phải đuổi. Hồi 3 s chống dịch liên tục gây ức chế. |
| D9 | Có báo trước khi dịch chuyển không? | **Có, cả hai đầu**: co xoáy ở chỗ cũ (0.35 s) + vòng xoáy dưới đất ở chỗ mới suốt pha Hidden (0.45 s). | Công bằng: player đọc được chỗ sắp hiện, lao tới đánh lúc Appear (khoảng hở). |
| D10 | Chọn vị trí thế nào? | Mục 1.1 (vòng quanh player, trong vùng canh, trên đất, không kẹt khối/rào, có đường bắn, trên màn hình). Không có chỗ hợp lệ → hiện lại chỗ cũ. | Không bao giờ bắn từ ngoài màn hình hay từ sau tường. |
| D11 | Ngắm thế nào? | Ngắm thẳng **ngực player tại lúc khoá hướng** (3D, có tính chênh độ cao), **không đoán trước** vị trí. | Chạy ngang là né được → dạy player di chuyển; vẫn trúng khi player đứng yên. |
| D12 | Quả cầu có bị WindZone tĩnh (cột gió) làm lệch không? | **Không** (WindReceiver của quả cầu có `collision_mask = 0`, chỉ để cú thổi tìm thấy). | Quỹ đạo dễ đoán; đỡ chi phí theo dõi vùng gió. |
| D13 | Dash xuyên quả cầu? | Quả cầu chạm hurtbox player là nổ, dù đòn bị i-frames chặn hay không. | Đơn giản, dễ đọc; dash vẫn giúp không mất máu. |
| D14 | Quái chết thì quả cầu đang bay? | **Tan hết** (nổ nhỏ, không gây sát thương), quả đã bị phản thì **giữ nguyên** (đạn của player). | Pool là con của quái, xác bị `queue_free` sau 1.2 s; cho tan có chủ đích thay vì biến mất đột ngột. |
| D15 | Đạn bằng gì? | `Area3D` hình cầu + signal `area_entered` / `body_entered` (theo dõi bằng sự kiện, đúng CLAUDE.md), bay tay mỗi frame. Tốc độ ≤ 10.5 m/s → mỗi frame đi ≤ 0.18 m < đường kính hitbox 0.44 m → không xuyên vật mỏng 0.3 m. | Đạn chậm, không cần quét tia như tên (18 m/s). Ghi chú ràng buộc tốc độ trong comment. |
| D16 | Pool đạn | Component mới `ObjectPool` (chưa có trong project), 3 quả sẵn, thiếu thì tạo thêm. Đạn `top_level = true` để không bay theo quái. | CLAUDE.md bắt buộc pool cho thứ tạo/xoá liên tục. Dùng lại được cho tên của player sau này (không sửa `arrow.gd` trong plan này). |

---

## 3. Thông số (mặc định) + vì sao công bằng

Tham chiếu player: chạy 6 m/s, dash 2.73 m, tầm kiếm 1.65 m; cú thổi: tầm 5 m, rộng 2.5 m, cao 2 m, bật 0.12 s sau khi bấm, mở 0.12 s, hồi 0.5 s (`wind_blast_data.gd`).

### EnemyData (kế thừa, file `resources/enemies/wisp_caster.tres`)
| Thông số | Giá trị | Lý do |
|---|---|---|
| `max_health` | 3 | Người dùng đặt |
| `detect_range` / `lose_range` / `leash_range` | 9 / 13 / 14 | Phát hiện xa hơn quái cận chiến (7) vì đánh xa |
| `attack_range` | 9 | Bắn tối đa 9 m: bay 9 m mất ~1.3 s |
| `attack_cooldown` | 1.6 s | Giữa 2 quả có ≥ 1.6 s + niệm 0.7 s để áp sát |
| `stagger_on_hit` | true | Trúng đòn là ngắt niệm phép |
| `stun_time` | 0.3 s | |
| `wind_multiplier` / `stagger_on_wind` | 1.0 / true | D7 |
| `patrol_radius` | 3 | Lượn nhẹ quanh chỗ canh |
| `corpse_time` | 1.2 | Giữ mặc định |

### MovementStats (`resources/enemies/wisp_caster_movement.tres`)
| Thông số | Giá trị | Lý do |
|---|---|---|
| `max_speed` | 3.0 | Bằng nửa player → luôn đuổi kịp được |
| `air_accel` | 10 | Quái không bao giờ chạm đất nên `move_toward_direction` chỉ dùng `air_accel`: trôi mềm, "lơ lửng" |
| `rotation_speed` | 10 | |
| `max_fall_speed`, `jump_*` | giữ mặc định | Chỉ dùng khi xác rơi |

### AttackData cho CastOrb (`resources/enemies/wisp_caster_orb_attack.tres`)
| Thông số | Giá trị | Lý do |
|---|---|---|
| `damage` | 1 | Player luôn mất 1 máu/đòn (`fixed_damage_per_hit = 1`) |
| `knockback` | 4.0 | |
| `active_start` (lúc bắn) | 0.7 s | Telegraph dài, đọc được ở camera xa |
| `duration` | 1.15 s | 0.45 s hồi sau khi bắn = khoảng hở |
| `lunge_speed` | 0 | Không lao |

### CasterEnemyData (mới, kế thừa EnemyData)
| Thông số | Giá trị | Lý do |
|---|---|---|
| `preferred_min` / `preferred_max` | 5.5 / 8 m | Ngoài tầm kiếm, nhưng trong tầm thổi (5 m) khi player tiến thêm 1 bước |
| `panic_distance` / `panic_time` | 3.0 m / 0.5 s | Áp sát đủ lâu → nó chạy; vẫn kịp chém 1–2 nhát |
| `strafe_speed_scale` | 0.4 | Bay ngang 1.2 m/s, đổi chiều 1.5–3 s |
| `aim_lock_time` | 0.5 s | Khoá hướng 0.2 s trước khi bắn |
| `casts_before_teleport` | 2 | D8 |
| `teleport_on_hurt` | true | D8 |
| `no_los_time` | 1.5 s | |
| `post_appear_delay` | 0.5 s | Quả đầu sau khi hiện ra sớm nhất 0.5 + 0.7 = 1.2 s → chạy 6 m/s áp sát được 7 m |
| `los_check_interval` | 0.15 s | Hiệu năng |
| `orb` | `SpiritOrbData` | |
| `teleport` | `TeleportData` | |
| `hover` | `HoverStats` | |

### SpiritOrbData (`resources/enemies/wisp_caster_orb.tres`)
| Thông số | Giá trị | Lý do |
|---|---|---|
| `speed` | 7.0 m/s | Từ 7 m: bay 1.0 s; player chạy ngang đi được 6 m → né dễ khi đã đọc telegraph. Lọt vào vùng thổi 5 m trong ~0.7 s → đủ thời gian bấm E |
| `lifetime` | 3.0 s | ~21 m rồi tan |
| `hit_radius` | 0.22 m | Nhỏ hơn hình (0.3 m): sượt qua thì không tính, nghiêng về phía player |
| `wind_catch_radius` | 0.45 m | Vùng cho cú thổi bắt được, rộng hơn hitbox → dễ phản |
| `reflect_speed_mult` | 1.5 | Phản lại nhanh hơn (10.5 m/s), cảm giác "trả đòn" |
| `reflect_aim_angle` / `reflect_aim_range` | 25° / 12 m | D3 |
| `reflected_attack` | AttackData damage 1, knockback 5 | Sát thương khi trúng quái |

### TeleportData
| Thông số | Giá trị |
|---|---|
| `vanish_time` / `hidden_time` / `appear_time` | 0.35 / 0.45 / 0.35 s |
| `ring_min` / `ring_max` | 5.5 / 8 m (bằng khoảng giữ cách) |
| `min_jump_distance` | 3 m |
| `candidate_count` | 12 |
| `max_ground_drop` | 4 m |
| `leash_margin` | 1 m |
| `cooldown` | 3 s |
| `require_on_screen` | true |

### HoverStats (component dùng lại cho mọi quái bay / boss)
| Thông số | Giá trị | Lý do |
|---|---|---|
| `hover_height` | 0.5 m | Gốc thân cách đất 0.5 m → hurtbox (capsule cao 1.8, gốc ở 0) phủ 0.5–2.3 m, chồng lên hộp kiếm của player (0.2–1.6 m) và vùng thổi (−0.1–1.9 m) → **chém và thổi đều trúng**. Tên bay ở ~1.0 m cũng trúng |
| `vertical_stiffness` | 8 /s | `velocity.y = (độ cao đích − y) × stiffness`, mượt khi qua bậc |
| `max_vertical_speed` | 4 m/s | Xuống bậc/vách cao không giật |
| `probe_up` / `probe_length` | 0.5 / 6 m | Tia xuống tìm đất, mask `world` |
| Hết đất (trên vực) | giữ độ cao đất gần nhất | Bay ngang qua vực, không hụt xuống |

---

## 4. Hitbox / hurtbox chuẩn

| Vùng | Hình | Layer / mask | Ghi chú |
|---|---|---|---|
| Thân (CharacterBody3D) | capsule r 0.35 cao 1.8 (kế thừa) | layer `enemy` 4, mask 257 (world + player_blocker) | D5 |
| HurtboxComponent | capsule r 0.4 cao 1.8 (kế thừa) | layer 4 | Theo model: nếu model thấp hơn 1.8 m thì thu capsule cho khớp (mục 5) |
| WindReceiverComponent | capsule kế thừa | layer 128, mask 64 | Bị thổi được |
| `Model/Hitbox` (kế thừa, cận chiến) | không dùng | — | Quái không có đòn cận chiến; vẫn để node vì `Enemy` cần (`$Model/Hitbox`), luôn tắt. `hitbox_reach` để mặc định |
| **Quả cầu – hitbox** | `Area3D` cầu r 0.22 | layer 0; mask trước phản: world 1 + player 2 = **3**; sau phản: world 1 + enemy 4 = **5** | Đổi mask bằng `set_deferred` (đổi trong callback va chạm) |
| **Quả cầu – WindReceiver** | cầu r 0.45 | layer 128, mask **0** | D12; `monitorable = true` có sẵn trong component |
| Tia đường bắn | ngực quái (gốc + 1.1) → ngực player (gốc + 1.0) | mask 1 | D4 |
| Truy vấn điểm dịch chuyển | capsule thân | mask 261 | Mục 1.1 |

Xử lý va chạm quả cầu: `area_entered` → nếu là `HurtboxComponent` thì `receive_hit(DamageInfo)` rồi nổ; `body_entered` → nếu body **không** có node `HurtboxComponent` (tức là tường/sàn) thì nổ, còn body là nhân vật thì để `area_entered` lo (tránh trúng 2 lần). Mỗi quả chỉ gây sát thương **một lần** (cờ `_spent`).

Nguồn sát thương (`DamageInfo.source`): trước phản = con quái bắn; sau phản = `null` (`WindReceiverComponent.pushed` chỉ trả `impulse`, không biết ai thổi; không bịa thêm tham số). Hệ quả: quái bị cầu phản trúng mà chưa có mục tiêu thì không tự quay sang đuổi ai — chấp nhận được.

---

## 5. Đặc tả model

Phong cách: low-poly, ít bão hoà, đọc được ở ~7% chiều cao màn hình. Quái là **sinh vật linh giới bị tha hoá**, không biểu tượng phe phái. **Không dùng trắng / xanh nhạt** (dành cho gió).

Ý tưởng hình dáng (planner đề xuất, chưa tham khảo hình Death's Door cụ thể — cần tra ảnh trước khi dựng, theo quy tắc "tham khảo trước khi vẽ"): một **hồn đèn trùm áo choàng rách**, không chân, thân thuôn nhọn xuống dưới như giọt nước ngược; hai cánh tay gầy dài nhô ra từ áo; mặt là một mặt nạ gốm nứt với 2 hốc mắt phát sáng tím; đuôi áo tua rua đung đưa.

| Mục | Yêu cầu |
|---|---|
| Kích thước | Cao **1.4 m** (từ mép dưới áo tới đỉnh mũ), rộng ~0.8 m. Lơ lửng 0.5 m → đỉnh ở ~1.9 m, ngang đầu cáo |
| Pivot | **Mép dưới áo tại (0,0,0)** (thay cho "giữa hai chân"), mặt hướng **+Z**, Y lên, 1 đơn vị = 1 m |
| Tam giác | ≤ 5.000 (quái thường), nên ~2.000 |
| Vật liệu | 1 vật liệu chính (texture palette chung) + 1 vật liệu phát sáng riêng (mắt + quả cầu trên tay) để đổi cường độ khi niệm |
| Màu | Áo xám tím đậm `#3A3346`, mặt nạ gốm xám `#8C8A86`, phát sáng **tím hồng tha hoá** `#C0509A` (đề xuất, nhóm chốt) |
| Phần tách / tên node | `WispCaster` (gốc) → `Robe` (thân + tua áo, có xương để đung đưa), `Mask`, `Arm_L`, `Arm_R`, `Hand_R` (gắn điểm bắn), `Eyes` (mesh phát sáng) |
| Điểm bắn | Marker `Model/OrbSpawn` đặt ở tay phải, ~ (0.25, 1.1, 0.35) theo model thật |
| Xuất | `.glb` vào `assets/models/enemies/wisp_caster/wisp_caster.glb` |

### Animation (tên clip trùng hằng số trong `EnemyState` để tự chạy)
| Clip | Dùng ở | Nội dung |
|---|---|---|
| `Idle` | Idle, KeepDistance | **Nhấp nhô lên xuống ±0.08 m chu kỳ ~1.2 s đặt trong clip** (không làm bằng code, để không đụng `SquashStretch` và hitbox), tua áo đung đưa |
| `Walk` / `Run` | Patrol | Nghiêng người 10° theo hướng bay |
| `Cast` | CastOrb | 0–0.5 s giơ tay tụ cầu; 0.5–0.7 s ngửa ra; 0.7 s phóng; hồi |
| `Vanish` / `Appear` | Teleport | Xoáy co lại về một điểm / ngược lại |
| `Hurt` | Hurt, Blown | Giật ngửa ra sau, mặt nạ lệch |
| `Death` | Dead | Áo xẹp, mặt nạ rơi |

Model chưa có thì dùng hình tạm (capsule tím + quả cầu ở tay) như `enemy.tscn`; `play_anim` của `Enemy` tự bỏ qua clip thiếu.

---

## 6. Đặc tả VFX / âm thanh

| Hiệu ứng | Đặc tả | Hiệu năng |
|---|---|---|
| Quả cầu đang niệm | Cầu tím nhỏ ở `OrbSpawn` lớn dần 0 → 0.3 m trong `active_start`, + overlay telegraph cam có sẵn của `Enemy` | Mesh dùng chung, không đổ bóng |
| Quả cầu bay | Lõi tím hồng phát sáng + vệt đuôi ngắn (GPUParticles3D ≤ 16 hạt, local_coords = false) | `cast_shadow = off`; dùng chung material |
| Quả cầu bị phản | **Đổi sang trắng ánh xanh `#D9F2FF`** (màu gió) + vài vệt gió quấn quanh | Chỉ hợp lệ vì giờ nó là "đạn gió" của player; đổi bằng material thứ hai dùng chung, không `duplicate()` |
| Nổ | Vụ nổ nhỏ (≤ 12 hạt, 0.3 s), tím hoặc trắng xanh tuỳ trạng thái | Particle nằm trong scene quả cầu, tái dùng cùng pool |
| Vanish / Appear | Xoáy khói tím co về / nở ra (≤ 20 hạt) | |
| Dấu hiệu chỗ hiện ra | Vòng xoáy tím dẹt dưới đất (decal hoặc mesh phẳng) tại điểm mới, mờ dần vào lúc Appear | 1 node con của quái, `top_level`, ẩn/hiện, không tạo mới |
| Blob shadow | Kế thừa `BlobShadow` → bóng dưới đất cho biết vị trí khi lơ lửng; trên vực không có bóng | Có sẵn |
| Âm thanh (chỗ cắm sẵn) | `CastSound`, `FireSound`, `ReflectSound`, `ImpactSound`, `VanishSound`, `AppearSound`, `HoverLoop` (AudioStreamPlayer3D, stream trống) | |

---

## 7. Đặc tả code

### 7.1 Không được sửa
`entities/_base/*`, `entities/enemies/_base/enemy.gd`, `enemy.tscn`, `enemy_data.gd`, mọi file trong `entities/enemies/_base/states/`, `components/wind_receiver/*`, `abilities/wind_blast/*`, `objects/projectiles/arrow.*`, `entities/player/*`, file của Quái 1 / Quái 2.
Quái 3 **không cần sửa file nào có sẵn**: dùng export `chase_state` / `attack_state`, ghi đè hàm trong lớp con, nghe signal `pushed` có sẵn.

### 7.2 File tạo mới

| File | class_name | Nội dung |
|---|---|---|
| `components/hover/hover_component.gd` | `HoverComponent` (Node) | Bắn tia xuống (mask world) mỗi physics frame **chỉ khi được gọi**, tính `velocity.y` để giữ `hover_height`; nhớ độ cao đất gần nhất cho lúc ở trên vực. Hàm public `apply(body: CharacterBody3D, delta: float) -> void`. Cache `PhysicsRayQueryParameters3D` một lần, chỉ đổi `from`/`to` (không cấp phát mỗi frame) |
| `components/hover/hover_stats.gd` | `HoverStats` (Resource) | Thông số mục 3 |
| `entities/enemies/_base/flying_enemy.gd` | `FlyingEnemy extends Enemy` | Lớp cơ sở cho mọi quái bay (file mới, không sửa base). Ghi đè `apply_gravity(delta)`: còn sống → `hover.apply(self, delta)`; chết → `super(delta)` (xác rơi). Ghi đè `on_kill_zone_entered()` và `on_lethal_zone_entered(_red_flash)`: bỏ qua khi còn sống (D6) |
| `components/teleport_point_finder/teleport_point_finder.gd` | `TeleportPointFinder` (Node) | Mục 1.1. `find_point(around: Vector3, home: Vector3, current: Vector3, data: TeleportData) -> Vector3` + `has_found` / trả về `current` khi thất bại. Cache query object. Dùng lại được cho boss |
| `entities/enemies/wisp_caster/teleport_data.gd` | `TeleportData` (Resource) | |
| `objects/projectiles/spirit_orb.gd` + `.tscn` | `SpiritOrb extends Area3D` | Bay thẳng, `set_physics_process(false)` khi nằm trong pool. `launch(...)`, nghe `WindReceiverComponent.pushed` → `_reflect(impulse)`. Signal `finished(orb)` để pool thu lại. Không `queue_free` |
| `objects/projectiles/spirit_orb_data.gd` | `SpiritOrbData` (Resource) | |
| `components/object_pool/object_pool.gd` | `ObjectPool` (Node) | `scene: PackedScene`, `initial_size`, `acquire() -> Node`, `release(node)`, `release_all()`. Đối tượng nhả về: ẩn, tắt process, tắt `monitoring` |
| `entities/enemies/wisp_caster/caster_enemy_data.gd` | `CasterEnemyData extends EnemyData` | Thông số mục 3 |
| `entities/enemies/wisp_caster/wisp_caster.gd` | `WispCaster extends FlyingEnemy` | API mỏng cho state: `caster_data`, `has_line_of_sight() -> bool` (tia ngực–ngực), `wants_teleport() -> bool`, `fire_orb(direction)`, `begin_charge()` / `cancel_charge()`, `set_hidden(on)`, `show_appear_marker(point)`, bộ đếm/hồi (`notify_cast()`, `notify_teleported()`); nghe `hurtbox.hurt` (node con của chính nó) để bật cờ dịch chuyển; nghe `died` của chính nó → `pool.release_all()` (D14). Không chứa logic chọn hành vi (logic nằm ở state) |
| `entities/enemies/wisp_caster/wisp_caster.tscn` | — | **New Inherited Scene từ `enemy.tscn`**: script `wisp_caster.gd`, `data = wisp_caster.tres`, `chase_state = KeepDistance`, `attack_state = CastOrb`; thêm `HoverComponent`, `TeleportPointFinder`, `OrbPool` (ObjectPool), `Model/OrbSpawn`, `AppearMarker`, âm thanh; thêm 3 node state vào `StateMachine` |
| `entities/enemies/wisp_caster/states/keep_distance.gd` | — (extends EnemyState) | Mục 1 |
| `entities/enemies/wisp_caster/states/cast_orb.gd` | — | Mục 1 |
| `entities/enemies/wisp_caster/states/teleport.gd` | — | Mục 1. Dùng `enemy.teleport()` có sẵn |
| `resources/enemies/wisp_caster.tres`, `wisp_caster_movement.tres`, `wisp_caster_orb_attack.tres`, `wisp_caster_orb.tres`, `wisp_caster_reflected_attack.tres`, `wisp_caster_teleport.tres`, `wisp_caster_hover.tres` | — | Thông số mục 3 |
| `tests/test_wisp_caster.gd` + `.tscn` | — | Script test headless (mục 8). Không đụng `tests/test_enemies.tscn` (có thể có agent khác dùng); nếu người dùng muốn thêm quái vào sân chung thì hỏi riêng |

State kiểu ép kiểu: state mới cần `WispCaster` → khai báo `@onready var caster: WispCaster = owner as WispCaster` + `assert`, giống `EnemyState._ready`.

### 7.3 API Godot sẽ dùng (đã có trong project hoặc cần kiểm)
- Đã dùng trong project: `PhysicsRayQueryParameters3D.create`, `direct_space_state.intersect_ray`, `Area3D.area_entered/body_entered`, `set_deferred`, `reset_physics_interpolation`, `Character.teleport()`, `WindReceiverComponent.pushed`.
- Có trong Godot 4.x nhưng project chưa dùng → **kiểm tra lại docs 4.7 trước khi code**: `PhysicsShapeQueryParameters3D` + `PhysicsDirectSpaceState3D.intersect_shape()`, `Camera3D.is_position_in_frustum()`, `Viewport.get_camera_3d()`.
- Ghi đè `apply_gravity` (hàm thường của `Character`): GDScript cho phép lớp con ghi đè; state dùng chung gọi `enemy.apply_gravity(delta)` sẽ chạy bản của `FlyingEnemy`. Cần kiểm bằng test thật (mục 8), không chỉ đọc code.

### 7.4 Tự kiểm "thêm X có phải sửa file này không?"
- Thêm quái bay khác (dơi, boss bay) → kế thừa `FlyingEnemy` + `HoverStats` mới. Không sửa.
- Thêm loại đạn khác (cầu lửa, đạn nổ chùm) → scene đạn mới + Data mới, cùng `ObjectPool`. Không sửa `cast_orb.gd` nếu đạn dùng chung giao diện `launch()` (cân nhắc lớp cơ sở `EnemyProjectile` nếu Quái 2/boss cũng bắn — xem Q4).
- Thêm cách phản đạn bằng kiếm → thêm nhận diện đòn kiếm trên đạn, không đụng hover / teleport.

---

## 8. Checklist nghiệm thu (đo hành vi thật, headless + chụp ảnh)

Chạy: `"<Godot exe>" --headless --path . --script tests/test_wisp_caster.gd`; xoá `"$APPDATA/Godot/app_userdata/SE116/savegame.json"` trước và sau.

**Bay / hover**
- [ ] Đứng yên 3 s: `global_position.y` = đất + 0.5 ± 0.05; `is_on_floor()` luôn false.
- [ ] Bay qua bậc cao 0.5 m và xuống vách 3 m: y bám theo, tốc độ đứng ≤ 4 m/s, không giật (ghi y mỗi frame).
- [ ] Đẩy (gió) qua vực trong sân test: không rơi, không chết, độ cao giữ ±0.05; KillZone không giết.
- [ ] Bay qua `spike_trap` lethal: không chết.
- [ ] Đi vào khối chặn layer 9: bị chặn (D5).
- [ ] Đứng trong cột gió đứng: bị nâng, ra khỏi thì về lại hover_height trong ≤ 1 s.
- [ ] Chết trên đất: xác rơi xuống đất; chết trên vực: xác rơi, bị xoá sau `corpse_time`, không lỗi console.
- [ ] Chém (kiếm) và bắn tên khi quái đang lơ lửng: trúng (đo HP giảm).

**Bắn cầu**
- [ ] Từ lúc vào CastOrb tới lúc bắn = 0.7 s ± 1 frame; telegraph bật suốt pha niệm.
- [ ] Player chạy ngang sau `aim_lock_time`: quả cầu trượt (không đuổi theo). Player đứng yên: trúng, mất đúng 1 máu, 1 lần.
- [ ] Quả cầu gặp tường world: nổ, không xuyên; gặp khối chặn layer 9: bay xuyên (D4).
- [ ] Không bắn khi có tường che giữa quái và player.
- [ ] Bị chém trong lúc niệm: huỷ quả đang niệm, không bắn ra sau đó.
- [ ] Pool: 20 lần bắn liên tục → số node SpiritOrb ≤ kích thước pool đã tăng, không có `instantiate` mới sau khi đủ (đếm node).

**Phản cầu bằng gió**
- [ ] Bấm E khi quả cầu cách 1, 3, 5 m: bị phản; cách 5.5 m: không phản.
- [ ] Phản thẳng về quái (lệch ≤ 25°): trúng, quái mất 1 máu, quái vào Hurt → Teleport.
- [ ] Phản lệch 40°: không bẻ hướng, bay theo hướng thổi.
- [ ] Quả đã phản không làm player mất máu; trúng Quái 1 / quái mẫu khác cũng gây 1 sát thương.
- [ ] Màu đổi sang trắng xanh khi phản (chụp ảnh).

**Dịch chuyển**
- [ ] Sau 2 quả → Teleport. Bị chém → Teleport ngay sau Hurt. Áp sát < 3 m quá 0.5 s → Teleport. Hai lần dịch cách nhau ≥ 3 s.
- [ ] Lặp 200 lần chọn điểm trong sân có rào + khối layer 9 + vực + cột: **0 điểm** nằm trong khối/rào, trên vực, ngoài leash, bị tường che, ngoài màn hình. Ghi số lần thất bại → hiện lại chỗ cũ.
- [ ] Trong pha Hidden: chém/bắn/thổi không có tác dụng; dấu hiệu dưới đất hiện đúng chỗ sẽ xuất hiện (chụp ảnh).
- [ ] Bị Hurt/Blown chen ngang Teleport: không bao giờ kẹt tàng hình (hurtbox, va chạm, model bật lại).
- [ ] Sau Appear ≥ 1.2 s mới có quả đầu tiên.

**Thông số lệch / cực đoan**
- [ ] `hover_height` = 0.0, 0.1, 3.0: 0 không kẹt sàn/nảy; 3.0 thì kiếm chém hụt (ghi nhận, báo người dùng là giới hạn thiết kế).
- [ ] `max_vertical_speed` = 0.5 và 50: không rung, không xuyên sàn.
- [ ] `speed` cầu = 1 và 25: 25 m/s vượt giới hạn D15 → kiểm có xuyên tường 0.3 m không; nếu xuyên thì báo và cân nhắc quét tia như `arrow.gd`.
- [ ] `ring_min > ring_max`, `candidate_count = 1`, `ring_max` rất lớn (50): không treo, không lỗi, rơi về "hiện chỗ cũ".
- [ ] `casts_before_teleport = 0` và `99`; `teleport_on_hurt = false`.
- [ ] `wind_multiplier = 0`: không bị thổi, vẫn phản cầu được.
- [ ] `hit_radius` 0.05 / 1.5; `reflect_aim_angle` 0 / 180.
- [ ] Nhiều quái (5 con) cùng sân: FPS không giảm rõ; console không lỗi.

---

## 9. Câu hỏi cho người dùng (chỉ những điều planner không thể quyết)

- **Q1 (lore)**: Tên chính thức và hình tượng của quái? Plan dùng tên tạm "Pháp sư Hồn Trôi" (`wisp_caster`), hình "hồn đèn áo choàng, mặt nạ gốm nứt". Đổi tên thì đổi tên thư mục/file trước khi code.
- **Q2 (level)**: Ở Map Gió, viền vực có đặt khối chặn vô hình layer 9 không? Nếu có thì theo D5 quái **không bay qua** vực đó. Muốn quái bay qua vực có viền layer 9 thì cần tách layer riêng cho "rào chặn quái" — việc này đụng `project.godot` và level, phải hỏi riêng.
- **Q3 (phối hợp)**: Màu phát sáng tím hồng `#C0509A` có trùng màu nhấn của khu Lửa/Băng hay quái của bạn cùng nhóm không? (art guide chưa chốt hex.)
- **Q4 (phối hợp)**: Quái 2 hoặc boss có bắn đạn không? Nếu có, nên tạo lớp cơ sở chung `EnemyProjectile` ngay bây giờ (để `SpiritOrb` kế thừa) thay vì `SpiritOrb` đứng riêng.
