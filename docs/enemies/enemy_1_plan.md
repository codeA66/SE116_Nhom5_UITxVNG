# Kế hoạch Quái 1 — "Liềm gió tha hoá" (lướt rồi chém)

Trạng thái: **KẾ HOẠCH, chưa code.** Mọi con số dưới đây là **đề xuất của planner**, không phải số liệu lấy từ game khác.
Người dùng đã uỷ quyền cho planner tự quyết các câu hỏi thiết kế (xem mục 0); người dùng có thể đổi bất kỳ quyết định nào.

Yêu cầu gốc (người dùng chốt): **HP 3**, đánh thường = **lướt một đoạn rồi chém**, **telegraph rõ ràng**, **bị skill gió (E) thổi bay được**.

---

## 0. Quyết định của planner (người dùng có thể đổi)

| # | Quyết định | Lý do ngắn |
|---|---|---|
| D1 | Animation theo **phương án B: model khối rời (rigid parts) + clip animation dựng trong Godot** (AnimationLibrary `.tres`), không rig Blender | Người dựng là AI qua Blender MCP: rig + weight paint dễ lỗi; low-poly mặt phẳng hợp khối rời; clip trong Godot khớp chính xác thời gian với `.tres` (windup 0.65 s...), cả nhóm sửa được trong Animation editor. Không dùng Tween trong code (animation là dữ liệu, không phải logic) |
| D2 | Một state mới **`DashSlash`** (một node, 4 pha: lấy đà → lướt → chém → hồi), đặt ở `entities/enemies/_base/states/` để boss/quái sau dùng lại | Giống cách `attack.gd` có sẵn làm (dòng thời gian trong một state), dọn dẹp tập trung ở một `exit()`; tách 4 node sẽ phải truyền hướng/khoảng cách qua lại và mỗi node đều phải tự dọn hitbox/telegraph → dễ sót |
| D3 | Thông số lướt nằm trong Resource mới **`DashSlashData`**, gán vào chính node state `DashSlash` (`@export`). `EnemyData.attack` = đòn chém (AttackData) | Không sửa `EnemyData`/`AttackData`; quái khác muốn lướt chỉ cần `.tres` mới |
| D4 | Sát thương **1**/đòn, knockback player **7 m/s** | Player có `fixed_damage_per_hit = 1` (player.tscn) nên số damage không đổi kết quả; 7 m/s đẩy ~0.8 m (friction player 30) đủ cảm nhận, không văng xuống vực ngay |
| D5 | Lướt tối đa **3.5 m** ở **14 m/s** (0.25 s); kích hoạt khi player ≤ **4.4 m** | Dài hơn dash player (2.73 m) một chút → chạy lùi thẳng không đủ an toàn tuyệt đối nhưng vẫn né được (xem 2.3); bắt đầu ngoài tầm kiếm 1.65 m để người chơi phải đọc telegraph chứ không chỉ chém trước |
| D6 | **Không lướt xuyên qua player**: dừng lướt khi tới cách vị trí player **hiện tại** 1.0 m, hoặc đi hết quãng đã chốt, hoặc đụng tường, hoặc phía trước là mép vực | Thân quái không có mask `player` (mask 257) nên nếu không chặn sẽ lướt xuyên qua người, đòn chém sẽ ra sau lưng → khó đọc |
| D7 | **Bám hướng 0.45 s đầu, khoá hướng 0.20 s cuối** của pha lấy đà | Người chơi có 0.20 s + thời gian lướt để né sau khi hướng đã chốt; khớp mốc phản xạ người ~200–300 ms (nguồn [6]) |
| D8 | **Không** sát thương khi chạm thân lúc lướt; chỉ hộp chém trong active frames | Đòn đọc được rõ: "lướt tới → chém"; tránh trúng đòn khó hiểu |
| D9 | **Không giáp**: bị chém ở bất kỳ pha nào cũng khựng (dùng `stagger_on_hit = true` có sẵn) | Quái yếu (HP 3), dạy người chơi phản đòn; khác biệt rõ với Quái 2 (khiên, HP 4) |
| D10 | `wind_multiplier = 1.2` → bị thổi ~**5.2 m** | Quái nhẹ, bay xa hơn chuẩn; khe vực trong `test_enemies.tscn` rộng 6 m nên thổi từ gần mép là rơi; Quái 2 = 0 (không bị thổi) → tương phản |
| D11 | Chống chém xuyên hàng rào/tường bằng **ShapeCast3D** trong scene quái 1, rút ngắn tầm hộp chém qua `hitbox.set_reach()` (hàm public) | Không sửa `HitboxComponent` dùng chung; ShapeCast quét cả bề ngang hộp nên chặn được cả góc chéo (một tia giữa thì không) |
| D12 | Kiểm tra đường thẳng **một lần khi vào DashSlash**: bị chắn trước khi tới player thì huỷ, bắt đầu cooldown, quay về Chase (không hiện telegraph) | Tránh cảnh quái sau hàng rào cứ lấy đà rồi đâm vào rào; chỉ chạy 1 lần mỗi đòn → không tốn hiệu năng |
| D13 | Lướt **dừng ở mép vực** (`stop_at_ledge = true`), nhưng **không** né gai | Quái không tự sát một cách ngớ ngẩn; nhưng dụ quái lao vào gai là cách chơi dùng môi trường (review Death's Door nói quái lăn có thể bị dụ vào địa hình, nguồn [1]) |
| D14 | Telegraph = **tư thế lấy đà** (khom, kéo liềm ra sau) + **overlay cam** có sẵn (`set_telegraph`) suốt 0.65 s + **mắt và lưỡi liềm loé sáng** đúng lúc khoá hướng + chỗ cắm âm thanh. **Không** vẽ vạch dưới đất ở bản đầu | Nguồn [5][7]: telegraph nên kết hợp animation + hiệu ứng + âm thanh. Vạch đất để sau nếu playtest thấy khó đọc |
| D15 | Trong cooldown giữ hành vi `Chase` gốc (đứng yên trong tầm 4.4 m, quay mặt theo player) | Open/closed: không cần state mới; tạo khoảng hở để player áp sát đánh |
| D16 | Không tạo script riêng cho quái 1 (dùng `enemy.gd`) | Không có logic riêng ngoài state; tránh file rỗng. Thêm sau nếu cần |
| D17 | Ý tưởng hình: **kamaitachi (chồn liềm) bị tha hoá** | Yêu quái Nhật cưỡi gió lốc, chém bằng móng như liềm (nguồn [8][9]) → hợp Map Gió và đúng kiểu đòn lướt-chém. Cần người dùng duyệt (mục 8) |

---

## 1. Tham khảo

Không tìm được số liệu frame chính thức của Death's Door (wiki fandom trả lỗi 402; không có bài phân tích frame). Những gì kiểm chứng được:

- Death's Door: một quái đầu game **lăn tới**, đòn "được báo trước nhưng nhanh bất ngờ"; người chơi né hoặc bắn tên làm nó ngã ngửa → **khoảng hở**; có thể dụ vào địa hình / quái khác [1]. Review chung: quái báo trước khá rõ, thắng nhờ đọc pattern [2][3]; dash có cooldown, dùng hết thì dễ bị trừng phạt [1].
- Cấu trúc đòn: **Anticipation → Attack → Recovery**; hitbox chỉ bật giữa đòn; pha hồi là cửa sổ phản công [4].
- Telegraph thường kết hợp **animation + âm thanh + hiệu ứng (charge-up)**, không chỉ animation [5].
- Telegraph quá ngắn thì đòn "vô hình", quá dài thì mất áp lực [6]; phản xạ người ~200–300 ms là ràng buộc thiết kế [6]. Lỗi hay gặp: quái hồi gần như tức thì [7].

Nguồn:
1. https://www.digitallydownloaded.net/?p=41057 , https://shacknews.com/article/125627/deaths-door-review-reaping-revenge
2. https://checkpointgaming.net/features/2021/06/deaths-door-preview-a-morbid-mashup-of-monsters-inc-meets-dark-souls
3. https://primagames.com/review/deaths-door-review-beautiful-dance-life-and-death
4. https://www.gamedeveloper.com/game-platforms/anatomy-of-an-enemy-attack-in-dark-souls-3 (chỉ đọc trích đoạn tìm kiếm)
5. https://gamedeveloper.com/design/enemy-attacks-and-telegraphing (Mike Stout, chỉ đọc trích đoạn)
6. https://www.wayline.io/blog/level-up-indie-game-melee-combat , https://playbooks.com/skills/omer-metin/skills-for-antigravity/combat-design
7. https://bugnet.io/blog/how-to-design-enemy-attack-telegraphs , https://itch.io/post/5080113
8. https://yokai.jp/en/yokai/kamaitachi
9. https://en.wikipedia.org/wiki/Kamaitachi

---

## 2. Hành vi

### 2.1 Tóm tắt
Đi tuần quanh chỗ xuất phát → thấy player (7 m) thì đuổi → player vào 4.4 m và hết cooldown → **DashSlash**: khom người lấy đà 0.65 s (bám hướng, rồi khoá hướng + loé sáng) → lướt thẳng tới tối đa 3.5 m → chém ngang một nhát → đứng hồi 0.69 s (cửa sổ phản công) → cooldown 1.4 s (đứng rình, quay mặt theo player) → lặp. Bị chém thì khựng; bị gió E thổi thì trôi theo gió (rơi vực / vào gai là chết).

### 2.2 Sơ đồ state

```
            ┌──────────── (dùng lại, không sửa) ─────────────┐
 Idle ⇄ Patrol ──thấy player──▶ Chase ──can_attack()──▶ DashSlash (MỚI)
   ▲                             ▲  │                      │
   └──── bỏ đuổi (lose/leash) ───┘  │                      ├─ hết pha hồi ─▶ Chase (còn mục tiêu) / Idle
                                    │                      └─ bị chắn đường lúc vào ─▶ Chase (+ cooldown)
 Bất kỳ state nào (Enemy tự chuyển, có sẵn):
   bị chém (stagger_on_hit) ─▶ Hurt ─hết stun─▶ Chase / Idle
   bị cú thổi (stagger_on_wind, wind_multiplier ≠ 0) ─▶ Blown ─hết lực đẩy─▶ Chase / Idle
   hết máu / KillZone / gai ─▶ Dead
```

- Node gốc `Enemy1`: `attack_state = &"DashSlash"`, `chase_state = &"Chase"` (giữ).
- Node `Attack` của scene gốc vẫn còn (Godot không xoá được node kế thừa) nhưng không bao giờ được chuyển tới.
- `Chase.can_attack()` dùng `data.attack_range` = **4.4 m** (tầm kích hoạt lướt).

### 2.3 Dòng thời gian DashSlash (đề xuất)

| t (s) | Pha | Việc | Player thấy |
|---|---|---|---|
| 0 | Vào state | Kiểm tra đường thẳng tới player (D12); quay mặt ngay; dừng; `set_telegraph(true)`; phát clip `DashSlash_Windup`; âm thanh lấy đà | Quái khom, kéo liềm ra sau, phủ cam |
| 0 → 0.45 | Lấy đà – bám | `face_direction()` theo player (xoay mượt) | Quái xoay theo mình |
| 0.45 | Khoá | Chốt hướng + quãng lướt = clamp(khoảng cách − 1.0, 0, 3.5); clip có track bật `EyesGlow`, `BladeGlow` | **Loé sáng** = "sắp lao" |
| 0.45 → 0.65 | Lấy đà – khoá | Đứng yên, không xoay | 0.20 s để bắt đầu né |
| 0.65 | Lướt | `set_telegraph(false)`; clip `DashSlash_Dash`; vận tốc ngang = hướng × 14 m/s; bật `LedgeProbe`; vệt bụi (nếu có) | Quái lao thẳng |
| 0.65 → ≤ 0.90 | Lướt | Dừng khi: đi đủ quãng, **hoặc** cách player hiện tại ≤ 1.0 m, **hoặc** `is_on_wall()`, **hoặc** probe không thấy sàn | |
| lúc dừng (= s0) | Chém | Vận tốc ngang về 0 ngay; `force_shapecast_update` → `set_reach(min(reach, khoảng trống))`; clip `DashSlash_Slash` | |
| s0 + 0.04 → s0 + 0.16 | Active | `hitbox.activate(slash)` / `deactivate()` | Lưỡi quét ngang |
| s0 + 0.16 → s0 + 0.85 | Hồi | Đứng yên, tắt glow (track clip), tư thế gục, liềm chạm đất | **Cửa sổ phản công 0.69 s** |
| s0 + 0.85 | Kết thúc | → Chase/Idle; `exit()` dọn dẹp + `start_attack_cooldown()` (1.4 s) | |

**Tính công bằng (đề xuất, cần đo thật ở mục 7):**
- Từ lúc khoá hướng đến khi hộp chém bật: 0.20 + thời gian lướt (0 → 0.25) + 0.04 = **0.24 → 0.49 s**. Từ lúc telegraph đầu tiên xuất hiện: **0.69 → 0.94 s**.
- Né ngang: cần ra khỏi nửa bề ngang hộp (0.8) + bán kính hurtbox player (0.4) = **1.2 m**. Chạy 6 m/s mất 0.2 s; dash player 2.73 m/0.18 s kèm i-frames 0.18 s → **né được bằng cả chạy lẫn dash**, dash an toàn hơn.
- Lùi thẳng: quái dừng cách điểm player lúc khoá 1.0 m, lưỡi với tới thêm 0.4 m → player phải lùi > 0.8 m trong ≤ 0.49 s (chạy 6 m/s đi được ~2.9 m) → né được.
- Áp sát lúc quái đang lấy đà: tầm kiếm player 1.65 m, chém trúng là quái khựng, huỷ đòn (D9).
- Phản công: hồi 0.69 s; đòn kiếm player dài 0.35 s (active 0.10) → kịp 1–2 nhát. HP 3 → cần 2 lượt phản công hoặc chuỗi khựng.

---

## 3. Thông số đề xuất

### 3.1 `resources/enemies/enemy_1.tres` (EnemyData)

| Trường | Giá trị | Lý do |
|---|---|---|
| display_name | "Liềm gió tha hoá" (tạm, mục 8) | |
| max_health | **3** | Người dùng chốt |
| movement | `enemy_1_movement.tres` | |
| detect_range / lose_range / leash_range | 7 / 11 / 14 | Như quái mẫu; lớn hơn tầm lướt 4.4 |
| attack | `enemy_1_slash.tres` | |
| attack_range | **4.4** | = lướt tối đa 3.5 + dừng cách 1.0 − 0.1 dư |
| hitbox_reach | **1.4** | Khớp đầu lưỡi liềm lúc duỗi hết (~1.3 m) + dư; ngắn hơn kiếm player 1.65 |
| attack_cooldown | **1.4** | Tổng chu kỳ ≥ 0.65 + 0.25 + 0.85 + 1.4 ≈ 3.15 s, không dồn dập |
| patrol_radius | 3.0 | |
| patrol_wait_min / max | 1.0 / 2.5 | |
| patrol_speed_scale | 0.45 | |
| stagger_on_hit | true | D9 |
| stun_time | 0.35 | |
| knockback_friction | 25 | |
| wind_multiplier | **1.2** | D10 |
| stagger_on_wind | true | |
| corpse_time | 1.2 | |

### 3.2 `resources/enemies/enemy_1_movement.tres` (MovementStats)
max_speed **3.8** (player 6 → player chạy thoát được), ground_accel 30, ground_decel 40, turn_accel 50, rotation_speed **10** (pha bám hướng xoay đủ nhanh để bám nhưng không giật). Nhảy giữ mặc định (quái không nhảy, chỉ dùng để tính trọng lực).

### 3.3 `resources/enemies/enemy_1_slash.tres` (AttackData — mốc tính từ **lúc bắt đầu pha chém**)
animation `DashSlash_Slash`, anim_speed 1.0, damage **1**, damage_type PHYSICAL, knockback **7.0**, hitstop 0.05 (hiện quái không dùng), active_start **0.04**, active_end **0.16**, duration **0.85**, lunge_speed **0**, lunge_time 0 (lướt do DashSlashData lo).

### 3.4 `resources/enemies/enemy_1_dash_slash.tres` (DashSlashData — class mới)

| Trường | Giá trị | Ghi chú |
|---|---|---|
| windup_time | 0.65 | Tổng lấy đà |
| track_time | 0.45 | Bám hướng tới mốc này; code clamp ≤ windup_time |
| windup_animation | `DashSlash_Windup` | |
| dash_animation | `DashSlash_Dash` | |
| dash_speed | 14.0 | |
| dash_max_distance | 3.5 | |
| stop_distance | 1.0 | Dừng khi cách player (hiện tại) chừng này; cũng dùng để tính quãng lúc khoá |
| dash_timeout_extra | 0.1 | Lưới an toàn: lướt không quá max/speed + 0.1 s (kẹt góc) |
| stop_at_ledge | true | D13 |
| require_clear_path | true | D12 |
| path_block_tolerance | 0.5 | Vật cản cách player < 0.5 m thì vẫn coi là thông (player đứng sát tường) |

---

## 4. Va chạm và hitbox

Mọi shape gán **shape mới** trong `enemy_1.tscn` (theo `docs/character_guide.md` mục 4), không sửa shape của scene gốc. Toạ độ trong hệ của node cha (Model quay theo hướng nhìn, mặt trước +Z).

| Node | Shape | Vị trí | Layer / Mask |
|---|---|---|---|
| `CollisionShape3D` (thân) | Capsule r **0.35**, h **1.3** | y 0.65 | layer 4 (enemy), mask 257 (world + player_blocker) — giữ như gốc |
| `HurtboxComponent/CollisionShape3D` | Capsule r **0.45**, h **1.4** | y 0.7 | layer 4 (giữ) |
| `WindReceiverComponent/CollisionShape3D` | Capsule r 0.35, h 1.3 | y 0.65 | 128 / 64 (giữ) |
| `Model/Hitbox/CollisionShape3D` | Box **(1.6, 0.9, 1.3)**, `resource_local_to_scene = true` | (0, **0.8**, **0.75**) → mép sau z 0.1, mép xa z 1.4, y 0.35–1.25 | layer 16 (enemy_hitbox), mask 2 (player) — giữ |
| `Model/SlashClearance` (ShapeCast3D, MỚI) | Box (1.6, 0.9, 0.1) | (0, 0.8, 0.1), `target_position` (0, 0, 1.3) | mask **257**, `enabled = false`, `exclude_parent = true` |
| `Model/LedgeProbe` (RayCast3D, MỚI) | — | (0, 0.5, **0.8**), `target_position` (0, −1.3, 0) → thấy sàn thấp hơn tới 0.8 m | mask **1**, `enabled = false` |

Giải thích:
- Hurtbox to hơn thân 0.1 m để kiếm player dễ trúng (player hitbox y 0.2–1.6 phủ quái cao 1.3 m).
- Mép dưới hộp chém 0.35 m: không quét vào sàn/bậc thấp; vẫn chồng lên hurtbox player (y 0.1–1.7).
- **Mỗi đòn trúng 1 lần**: `HitboxComponent` đã có `_already_hit`; DashSlash chỉ gọi `activate()` đúng 1 lần mỗi lượt. Player còn i-frames 0.5 s.
- **Không trúng xuyên rào/tường**: thân quái dừng ở rào (mask 257) nhưng hộp chém 1.4 m vẫn chạm player sau rào dày 0.3 m (0.35 + 0.3 + 0.35 = 1.0 < 1.4). Vì vậy lúc bắt đầu pha chém: `SlashClearance.force_shapecast_update()`; có va chạm thì `reach = 0.1 + safe_fraction × 1.3 + 0.05` rồi `hitbox.set_reach(min(data.hitbox_reach, reach))`. `exit()` luôn trả lại `set_reach(data.hitbox_reach)`.
- **Chưa chắc** (phải kiểm docs.godotengine.org trước khi code): `ShapeCast3D.force_shapecast_update()`, `get_closest_collision_safe_fraction()`, `RayCast3D.force_raycast_update()` có chạy khi `enabled = false` không. Nếu không: bật `enabled` chỉ trong khung cần rồi tắt; hoặc dùng `PhysicsDirectSpaceState3D.intersect_ray/cast_motion` với query cache sẵn (không tạo mới mỗi frame).
- Shape hitbox bị `set_reach()` sửa lúc chạy → bắt buộc `resource_local_to_scene` để con này không đổi tầm của con khác (character_guide mục 5 đã đo shape dùng chung). Có bài test riêng (mục 7).

---

## 5. Animation và model

### 5.1 Hai phương án

| | **A. Rig + animation trong Blender** | **B. Khối rời + clip dựng trong Godot (ĐÃ CHỌN, D1)** |
|---|---|---|
| Cấu trúc model | 1 mesh liền + Armature ~20 xương, weight paint; clip là Action Blender, xuất trong .glb | Mỗi bộ phận là object riêng, gốc (origin) đặt ở khớp, lồng nhau theo cây; **không** armature, **không** animation trong .glb |
| Đưa vào Godot | Copy clip từ AnimationPlayer của .glb sang AnimationPlayer gốc (như `entities/player/foxy/foxy_player.gd::_install_animations`, cần tách thành component dùng chung) hoặc "Save to file" từng clip | Tạo `enemy_1_animations.tres` (AnimationLibrary) gán vào AnimationPlayer gốc; track trỏ `Visual/Enemy1Model/<Bộ phận>:rotation` (root_node `../Model` có sẵn) |
| Ưu | Biến dạng mềm, chuyển động tự nhiên | Không lỗi weight; khớp thời gian tuyệt đối với `.tres`; ai trong nhóm cũng sửa được trong Godot; hợp phong cách khối phẳng |
| Nhược | AI rig/weight dễ lỗi; đổi windup_time phải sửa clip trong Blender rồi xuất lại; phải viết thêm bước cài clip | Khớp nối lộ (che bằng khối chồng nhau); chuyển động cứng hơn nếu key ít |

### 5.2 Clip cần có (tên phải trùng, `Enemy.play_anim` bỏ qua clip thiếu)
`Idle` (lặp, 2 s), `Walk` (lặp, 0.8 s), `Run` (lặp, 0.5 s), `Hurt` (0.35 s), `Death` (1.0 s), `DashSlash_Windup` (**0.65 s**), `DashSlash_Dash` (0.25 s, giữ khung cuối), `DashSlash_Slash` (**0.85 s**). Tất cả **tại chỗ** (code di chuyển thân). Mọi clip trừ hai clip DashSlash_Windup/Slash phải có track `visible = false` cho `EyesGlow`, `BladeGlow` ở khung 0 để chắc chắn tắt glow khi bị ngắt đòn.

Tư thế chính (gợi ý cho người dựng clip):
- **Windup**: 0→0.3 s Hips hạ 0.12 m, Torso cúi thêm 25°, `ArmBlade_R` kéo ra sau (yaw +70°, nâng 30°), đuôi dựng; 0.3→0.45 s rung nhẹ ±3° (căng); **0.45 s** bật `EyesGlow`/`BladeGlow` + scale 1→1.3→1 trong 0.1 s; 0.45→0.65 s giữ.
- **Dash**: Torso nghiêng trước 35°, liềm kéo sau lưng, chân thu.
- **Slash**: 0→0.04 s liềm ở sau phải; 0.04→0.16 s quét ngang cung ~150° sang trước trái; 0.16 s tắt glow; 0.16→0.85 s gục: thân đổ trước, đầu cúi, mũi liềm chạm đất (tư thế "đang hở"), 0.7→0.85 s đứng dậy.

### 5.3 ĐẶC TẢ MODEL (cho người dựng Blender)

**Ý tưởng:** chồn liềm (kamaitachi) linh giới bị tha hoá. Dáng khom, đứng hai chân sau, cẳng tay phải là **lưỡi liềm** liền khối. Đuôi xoắn như gió lốc. Dấu hiệu tha hoá: các mảng **mực đen tím loang** trên lông, mắt đỏ son. **Không** dùng huy hiệu/biểu tượng phe xâm lược, **không** chibi, đầu nhỏ.

**Kích thước (m, so player 1.8 m):**
- Cao tới đỉnh đầu **1.30** (khom), tai tới 1.40. Rộng vai 0.55, rộng tổng (không kể liềm) ≤ 0.70.
- Tay liềm: vai → khuỷu 0.35, khuỷu → mũi liềm **0.80** (lưỡi cong, bản rộng 0.12, dày 0.03). Duỗi thẳng ra trước: mũi liềm ~1.25–1.30 m tính từ tâm.
- Đuôi dài 0.8, xoắn 1.5 vòng, cao không quá 1.2.
- Thân phải nằm trong capsule r 0.35 cao 1.3 (trừ tay liềm và đuôi).

**Bảng màu (vertex color, ít bão hoà + 1 nhấn):**

| Phần | Hex |
|---|---|
| Lông chính (xám tro ấm) | `#8A8580` |
| Bụng, mặt, trong tai | `#B8B2A8` |
| Mảng mực tha hoá | `#3A3340` |
| Lưỡi liềm (thép xám xanh) | `#7F8A90`, cạnh lưỡi `#C9D1D4` |
| Mắt (vertex, lúc thường) | `#C8553D` |
| Glow (material riêng, chỉ `EyesGlow` / `BladeGlow`) | `#FF7A4D` |

Nền sàn `#1F1F21` → thân xám tro tương phản rõ; glow cam trùng màu overlay telegraph `(1, 0.45, 0.25)` có sẵn → "cam = nguy hiểm".

**Cây object (tên chính xác, origin = khớp). Toạ độ Godot (X, Y lên, Z trước) → Blender (X, −Z, Y):**

| Object | Cha | Origin Godot | Origin Blender | Nội dung |
|---|---|---|---|---|
| `Enemy1Model` | — | (0, 0, 0) | (0, 0, 0) | Empty gốc, giữa hai chân, sát đất |
| `Hips` | Enemy1Model | (0, 0.55, 0) | (0, 0, 0.55) | Hông |
| `Leg_L` | Hips | (+0.15, 0.50, 0) | (0.15, 0, 0.50) | Chân trái (gập kiểu thú), bên +X |
| `Leg_R` | Hips | (−0.15, 0.50, 0) | (−0.15, 0, 0.50) | Chân phải |
| `Torso` | Hips | (0, 0.60, 0) | (0, 0, 0.60) | Thân, sẵn nghiêng trước 20° |
| `Head` | Torso | (0, 1.05, 0.15) | (0, −0.15, 1.05) | Đầu, mõm nhọn về +Z |
| `EyesGlow` | Head | trùng Head | | 2 mảng mắt, material `Enemy1_Glow` |
| `Arm_L` | Torso | (+0.22, 0.95, 0.05) | (0.22, −0.05, 0.95) | Tay trái ngắn, móng |
| `ArmBlade_R` | Torso | (−0.22, 0.95, 0.05) | (−0.22, −0.05, 0.95) | Tay phải + lưỡi liềm |
| `BladeGlow` | ArmBlade_R | trùng ArmBlade_R | | Dải cạnh lưỡi, material `Enemy1_Glow` |
| `Tail_1` | Hips | (0, 0.55, −0.20) | (0, 0.20, 0.55) | Nửa đầu đuôi |
| `Tail_2` | Tail_1 | khớp giữa đuôi | | Nửa sau đuôi |

**Kỹ thuật:**
- Mặt trước nhìn **−Y trong Blender** (exporter glTF "+Y Up" đổi Blender −Y → glTF/Godot **+Z**; Blender +Y → Godot −Z).
- Đơn vị 1 = 1 m, scale object áp dụng (Apply Scale) trước khi xuất, **trừ** việc giữ origin ở khớp.
- **Không** armature, **không** action (phương án B).
- Shading phẳng, cạnh sắc. Tam giác: **1.200–2.500** (giới hạn quái thường ≤ 5.000).
- Vertex color tên **`Col`**, material tên **`Kit_Stone`** cho mọi phần trừ glow (Godot map sang `assets/models/wind_kit/wind_kit_material.tres` như `rock_m.glb.import`). Material thứ hai **`Enemy1_Glow`** cho `EyesGlow`, `BladeGlow`.
- Kiểm tra tùy chọn xuất vertex color của exporter theo đúng phiên bản Blender đang dùng (đối chiếu `assets/models/wind_kit/source/wind_kit.blend`) — planner chưa kiểm tra tên tuỳ chọn.
- Xuất **`assets/models/enemies/enemy_1/enemy_1.glb`**, lưu nguồn `assets/models/enemies/enemy_1/source/enemy_1.blend`.
- Ảnh kiểm tra: chụp từ góc camera game (nghiêng 50°, xa) để chắc silhouette tay liềm và tư thế khom đọc được ở ~7% chiều cao màn hình.

---

## 6. ĐẶC TẢ CODE (cho người code)

### 6.1 File tạo mới

| File | Nội dung |
|---|---|
| `entities/enemies/_base/dash_slash_data.gd` | `class_name DashSlashData extends Resource`, các trường mục 3.4 (`@export_group` Timing / Dash / Safety / Animation) |
| `entities/enemies/_base/states/dash_slash.gd` | `extends EnemyState`, state mới (6.3) |
| `entities/enemies/enemy_1/enemy_1.tscn` | New Inherited Scene từ `entities/enemies/_base/enemy.tscn` |
| `entities/enemies/enemy_1/enemy_1_animations.tres` | AnimationLibrary (mục 5.2) — làm khi có model |
| `assets/models/enemies/enemy_1/enemy_1_glow_material.tres` | StandardMaterial3D unshaded, albedo `#FF7A4D`, `cast_shadow` tắt ở mesh glow |
| `resources/enemies/enemy_1.tres`, `enemy_1_movement.tres`, `enemy_1_slash.tres`, `enemy_1_dash_slash.tres` | Mục 3 |
| `tests/test_enemy_1.tscn` + `tests/test_enemy_1.gd` | Scene đo tự động (mục 7), dựa trên layout `test_enemies.tscn` |

Sửa: chỉ **thêm** một instance `Enemy1` vào `tests/test_enemies.tscn` (gần khe vực và gần gai) — phải xin phép riêng.

### 6.2 Cấu trúc `enemy_1.tscn`

```
Enemy1 (kế thừa Enemy)        data = enemy_1.tres, attack_state = &"DashSlash"
├── CollisionShape3D          shape mới (mục 4)
├── Model
│   ├── Visual
│   │   ├── Body, Eye         (của gốc) visible = false
│   │   └── Enemy1Model       instance enemy_1.glb
│   ├── Hitbox/CollisionShape3D   shape mới, local_to_scene
│   ├── SlashClearance        ShapeCast3D MỚI
│   ├── LedgeProbe            RayCast3D MỚI
│   ├── DashTrail             GPUParticles3D MỚI (tuỳ chọn, emitting = false, amount ≤ 24, one_shot false)
│   └── Sfx                   Node3D: Windup, Dash, Slash (AudioStreamPlayer3D, stream trống = chỗ cắm sẵn)
├── AnimationPlayer           libraries: "" = enemy_1_animations.tres
├── HurtboxComponent/CollisionShape3D, WindReceiverComponent/CollisionShape3D   shape mới
└── StateMachine
    ├── (Idle, Patrol, Chase, Attack, Hurt, Dead, Blown của gốc)
    └── DashSlash             dash_slash.gd; data = enemy_1_dash_slash.tres; node_paths: clearance, ledge_probe, dash_trail, windup_sfx, dash_sfx, slash_sfx
```

Trước khi có model thật: vẫn chạy được với hình tạm (giữ `Body`/`Eye` hiện), `play_action` tự bỏ qua clip thiếu.

### 6.3 `dash_slash.gd` — yêu cầu

- Thứ tự script, static typing, comment tiếng Việt theo CLAUDE.md.
- `signal phase_started(phase: Phase)` — để VFX/âm thanh/test móc vào mà không sửa state.
- `enum Phase { WINDUP, DASH, SLASH }` (pha hồi nằm trong SLASH sau `active_end`).
- `@export var data: DashSlashData`, `@export var clearance: ShapeCast3D`, `@export var ledge_probe: RayCast3D`, `@export var dash_trail: GPUParticles3D`, `@export var windup_sfx / dash_sfx / slash_sfx: AudioStreamPlayer3D` (null = bỏ qua).
- Mỗi pha một hàm `_enter_xxx()` / `_update_xxx(delta)`; `physics_update` chỉ gọi hàm của pha hiện tại (không if/else dài).
- **enter**: D12 (kiểm tra đường đi một lần: dùng `clearance`/ray hướng tới player; bị chắn ở khoảng cách < `distance_to_target() − path_block_tolerance` → `enemy.start_attack_cooldown()` rồi `transition_to(enemy.chase_state)`, return trước khi bật telegraph). Sau đó: `face_instantly`, dừng ngang, `set_telegraph(true)`, `play_action(windup_animation)`.
- **WINDUP**: `apply_gravity`, `move_toward_direction(Vector3.ZERO)` để hãm; trước `track_time` gọi `face_direction(direction_to_target)`; tại `track_time` chốt `_direction = get_facing_direction()` và `_dash_distance = clamp(distance_to_target() − stop_distance, 0, dash_max_distance)`.
- **DASH**: `set_telegraph(false)`; set `velocity.x/z` mỗi frame = `_direction × dash_speed`; cộng quãng đã đi bằng độ dời vị trí thật (không phải speed × delta, vì có thể bị tường chặn); dừng theo D6/D13 + timeout. Ledge probe chỉ bật trong pha này.
- **SLASH**: dừng ngang ngay; clamp tầm (mục 4); `play_action(enemy.data.attack.animation)`; bật/tắt hitbox theo `active_start/active_end`; hết `duration` → `enemy.chase_state` nếu `has_target()` không thì `IDLE`.
- **exit** (gọi cả khi bị Hurt/Blown/Dead ngắt): `set_telegraph(false)`, `hitbox.deactivate()`, `hitbox.set_reach(enemy.data.hitbox_reach)`, tắt probe/clearance/particle, `enemy.start_attack_cooldown()`.
- Hiệu năng: không tạo mảng/Dictionary/query mới mỗi frame; probe/clearance tắt ngoài pha cần; không `get_node` mỗi frame.
- Chỉ dùng API public của `Enemy`/`Character`/`HitboxComponent` (đã có: `direction_to_target`, `distance_to_target`, `has_target`, `face_instantly`, `face_direction`, `get_facing_direction`, `apply_gravity`, `move_toward_direction`, `set_telegraph`, `play_action`, `start_attack_cooldown`, `hitbox.activate/deactivate/is_active/set_reach`).

### 6.4 KHÔNG được sửa
`entities/_base/*` (character, attack_data, movement_stats), `entities/enemies/_base/enemy.gd|enemy.tscn|enemy_data.gd`, mọi state có sẵn trong `entities/enemies/_base/states/`, `components/*` (hitbox, hurtbox, wind_receiver, enemy_sensor, state_machine...), `resources/enemies/base_enemy*.tres`, mọi file player, mọi level. Phát sinh nhu cầu sửa → dừng lại hỏi.

### 6.5 Kiểm chứng API trước khi code
Đã thấy trong code project: `CharacterBody3D.is_on_wall()` chưa dùng ở đâu → kiểm docs. `ShapeCast3D`, `RayCast3D.force_raycast_update`, `GPUParticles3D.emitting`, `AnimationPlayer.libraries` với key rỗng `""` (thư viện mặc định để tên clip không có tiền tố) → kiểm docs Godot 4.x trước khi dùng.

---

## 7. Checklist nghiệm thu (reviewer đo hành vi thật)

Cách đo chung: `tests/test_enemy_1.gd` nghe `StateMachine.state_changed` và `DashSlash.phase_started` ghi mốc thời gian (`Time.get_ticks_msec`), ghi vị trí quái mỗi physics frame, đếm `HurtboxComponent.hurt` của player; chụp ảnh 1280×720 ở góc camera game. Player điều khiển bằng script giả lập input hoặc đặt vị trí trực tiếp.

**Hành vi chính**
- [ ] Telegraph: từ lúc vào DashSlash đến lúc hitbox bật đo được 0.69–0.94 s (±1 frame). Ảnh chụp ở t = 0.1, 0.45, 0.6 s thấy rõ tư thế khom + overlay cam + glow (so với ảnh Idle).
- [ ] Bám hướng: player chạy vòng trong 0.45 s đầu → hướng quái thay đổi; sau 0.45 s player di chuyển → hướng quái **không** đổi.
- [ ] Quãng lướt: player đứng yên ở 4.4 / 3.0 / 1.5 / 0.8 m → quái dừng cách player 1.0 m (±0.1), lướt ≤ 3.5 m; ở 0.8 m quái chém tại chỗ.
- [ ] Không xuyên player: player chạy về phía quái lúc lướt → quái dừng ở ~1.0 m, không vượt qua.
- [ ] Trúng đúng 1 lần mỗi đòn: player đứng trong hộp suốt active → `hurt` đếm đúng 1; player đã đứng sẵn trong hộp trước khi bật vẫn bị trúng.
- [ ] Né: (a) chạy ngang ngay khi loé sáng → không trúng; (b) dash ngang → không trúng; (c) lùi thẳng → không trúng; (d) đứng yên → trúng.
- [ ] Phản công: chém quái trong pha hồi → quái khựng; 3 nhát → chết; chém trong pha lấy đà → huỷ đòn, telegraph tắt, cooldown chạy.
- [ ] Cooldown: sau khi đòn kết thúc, ≥ 1.4 s mới vào DashSlash lần nữa; không nhấp nháy telegraph.
- [ ] Bị chắn: player đứng sau rào/tường trong 4.4 m → quái không lấy đà, không đâm vào rào liên tục.
- [ ] Rào/tường mỏng: quái ép sát rào dày 0.3 m, player sát phía bên kia, thẳng và chéo 45° → **không** trúng. Khi không có rào ở cùng vị trí → trúng.
- [ ] Mép vực: player đứng bên kia khe vực → quái dừng ở mép, không rơi. Tắt `stop_at_ledge` → quái rơi và chết.
- [ ] Gai: dụ quái lướt vào gai (`test_enemies` Spikes ở x 8) → quái chết.
- [ ] Gió: thổi E lúc Idle / lấy đà / lướt / hồi → vào Blown, telegraph + hitbox tắt, tầm hitbox trả về 1.4; quãng trôi đo được ~5.2 m (±0.5) trên sàn phẳng; thổi từ cách mép khe 1 m → rơi vào KillZone, chết.
- [ ] Hai quái cùng loại: con A bị rút tầm (sát rào) → tầm hộp của con B không đổi (kiểm `resource_local_to_scene`).
- [ ] Glow tắt khi bị ngắt đòn ở mọi pha (ảnh chụp sau Hurt/Blown).
- [ ] Hiệu năng: ngoài DashSlash, probe/clearance `enabled = false`; không cảnh báo/lỗi trong Output.

**Thông số cực đoan / lệch** (mỗi mục: không lỗi, không kẹt state, hành vi hợp lý)
- [ ] windup_time 0.05 và 3.0; track_time > windup_time (phải clamp); track_time 0.
- [ ] dash_max_distance 0 (chỉ chém tại chỗ) và 12 (lướt dài: dừng ở tường, mép vực, timeout).
- [ ] dash_speed 2 và 40 (40 m/s ≈ 0.67 m/frame: không xuyên rào 0.3 m, không vượt mép vực vì probe chậm).
- [ ] stop_distance 0 và 3 (> dash_max_distance).
- [ ] hitbox_reach 0.2 và 4.0 (rào vẫn chặn được); attack_range < hitbox_reach.
- [ ] Hộp chém không vuông (1.6 × 0.9 × 1.3 đã lệch; thử thêm 0.3 × 2 × 3).
- [ ] wind_multiplier 0 (không vào Blown, không trôi), 3.0 (≈32 m: xem có bay qua khe 6 m sang FarSide không — ghi lại kết quả).
- [ ] attack_cooldown 0 (không lỗi lặp vô hạn trong cùng frame).
- [ ] Quái trên dốc / bậc thang: lướt không bay lên, không nảy.

Báo cáo nghiệm thu phải ghi số đo thật, ảnh, và mục chưa test được.

---

## 8. Câu hỏi còn lại cho người dùng (planner không tự quyết được)

1. **Ý tưởng/lore**: duyệt hình tượng **kamaitachi (chồn liềm) bị tha hoá** và tên hiển thị tạm "Liềm gió tha hoá"? GDD chưa có mô tả quái này, planner không tự điền vào GDD.
2. **Hàng rào chặn cả quái** (ảnh hưởng thiết kế màn của bạn): thân mọi quái có mask `world + player_blocker` (257), nên quái **không bị thổi qua** các mép có rào/collider vô hình. Muốn thổi quái rơi vực thì màn phải chừa đoạn mép hở (như khe vực trong `test_enemies.tscn`). Planner giữ nguyên mask (không sửa code dùng chung); nếu bạn muốn quái bị thổi qua rào thì cần một thiết kế riêng (quái đi tuần/đuổi phải tự tránh mép) — báo lại để lên kế hoạch.
