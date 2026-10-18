# Quái 2 — Hộ Vệ Khiên (tên tạm: `ShieldBearer`)

> Trạng thái: **PLAN, chưa code**. Mọi file trong mục 7 chỉ được tạo sau khi người dùng duyệt.
> Planner được người dùng cho phép tự quyết các câu hỏi thiết kế; mọi quyết định nằm ở mục 10 kèm lý do, người dùng đổi được.

## 0. Yêu cầu gốc (người dùng đặt)

- HP 4.
- 2 trạng thái: (1) cầm khiên **chặn tấn công**; (2) **giơ khiên lên tụ lực, đập xuống đất tạo sóng kích**.
- **Không bị thổi bay** bởi skill gió.

Phân vai với 2 con còn lại (tránh trùng): Quái 1 = lính lướt chém HP 3, bị thổi bay (nhanh, nhẹ). Quái 3 = pháp sư bay, bắn cầu, dịch chuyển (tầm xa). Quái 2 = **chậm, nặng, phòng thủ phía trước, đòn vùng** → dạy người chơi **vòng ra sau / sườn** và **nhảy qua sóng**.

## 1. Tham khảo (đã tra, có nguồn)

| Game | Điều rút ra | Nguồn |
|---|---|---|
| Hollow Knight — Great Husk Sentry | Giơ khiên về phía người chơi để chặn; sau khi chặn hoặc chờ một lúc thì hạ khiên ra đòn, lúc đó để hở ngắn. → nhịp "thủ – mở – thủ". | https://hollowknight.wiki.fextralife.com/Great+Husk+Sentry |
| Hollow Knight — Husk Guard | Đập xuống tạo sóng chạy dọc mặt đất về hai phía, càng đi càng rộng/nhanh; cách né thông dụng là **nhảy qua**, rồi nhảy vào đánh 1–2 nhát. | https://hollowknight.wiki/w/Husk_Guard (trang chặn bot, đọc qua kết quả tìm kiếm) |
| Zelda — Darknut | Khiên làm đòn **từ phía trước vô hiệu**, phải đánh từ **sườn hoặc sau**; Twilight Princess: khiên hấp thụ tên bắn thẳng. | https://zeldawiki.wiki/wiki/Darknut |
| Death's Door — Black Iron Knight, Guardian of the Door | **Không tìm thấy** quái khiên chặn đòn trong Death's Door. Chỉ có đòn đập gây sát thương vùng: Black Iron Knight nhảy vào gây AoE quanh chùy; Guardian of the Door nhấc tháp đập xuống tạo sóng kích nhỏ. | https://forzarc.gfinity.net/deaths-door/deaths-door-black-iron-knight/ , https://forzarc.gfinity.net/deaths-door/deaths-door-guardian-of-the-door-boss-fight/ |

Không ghi số liệu (máu, sát thương, thời gian) của các game trên vì nguồn không cho số đáng tin; mọi số ở mục 3 là của mình, tính theo player hiện có.

## 2. Hành vi + sơ đồ state

```
            thấy player                     can_attack()
  Idle ⇄ Patrol ─────────► ShieldAdvance ─────────────────► ShieldSlam
    ▲   (dùng chung)        (chase_state)                  (attack_state)
    │                        │  ▲      ▲                        │
    │   bỏ đuổi              │  │      └──── hết duration ──────┘
    └────────────────────────┘  │
                     bị chặn đòn│ hết block_react_time
                                ▼
                            ShieldBlock
  Mọi state ──hết máu──► Dead (dùng chung)
  Hurt: không vào (stagger_on_hit = false). Blown: không vào (wind_multiplier = 0, stagger_on_wind = false).
```

- **Khiên luôn giơ phía trước** (Idle, Patrol, ShieldAdvance, ShieldBlock): đòn tới trong cung 120° phía trước bị chặn, không mất máu.
- **ShieldAdvance** (thay Chase): đi chậm tới player, giữ khoảng cách `preferred_distance`; quay người chậm (dễ bị vòng ra sau). Hết hồi chiêu + player trong `attack_range` → ShieldSlam.
- **ShieldBlock**: vừa chặn một đòn → khựng tại chỗ `block_react_time`, khiên rung, bị đẩy lùi nhẹ; vẫn đang chặn. Hết thời gian → ShieldAdvance. Đánh khiên liên tục không có lợi gì (không mất máu), nhưng cũng không bị phạt thêm.
- **ShieldSlam**: 3 pha theo `AttackData`:
  1. **Tụ lực** (0 → `active_start`): quay mặt về player rồi khoá hướng, giơ khiên qua đầu, nháy telegraph, hiện vòng báo phạm vi sóng trên đất. **Khiên tắt chặn** → mặt trước hở (cơ hội đánh trực diện). Có giáp (không bị khựng) nên không thể chém để hủy đòn.
  2. **Đập** (`active_start` → `active_end`): hitbox cận chiến trước mặt bật; phát **1 sóng kích hình vòng** từ điểm khiên chạm đất.
  3. **Hồi** (`active_end` → `duration`): đứng yên, khiên vẫn tắt chặn → khoảng hở lớn nhất để phản công.
- **Gió**: cú thổi và cột gió không đẩy được (hệ số 0). Có hiệu ứng "gió tách quanh khiên" để người chơi biết là gió có trúng nhưng vô dụng.

Vòng lặp người chơi: vòng ra sau đánh (không bị khựng nên đánh 1–2 nhát rồi rút) **hoặc** chờ nó tụ lực → chém mặt trước → nhảy/dash qua sóng → chém lúc nó hồi.

## 3. Thông số (kèm lý do công bằng)

Số player dùng để tính: chạy 6 m/s, dash 2.73 m (có i-frame), tầm kiếm 1.65 m, nhảy `jump_height` 2.0 m, `time_to_apex` 0.38 s, `fall_gravity_mult` 1.8 (từ `movement_stats.gd` + `player_movement.tres`).

### EnemyData (`resources/enemies/shield_bearer.tres`)

| Thông số | Giá trị | Lý do |
|---|---|---|
| max_health | 4 | Yêu cầu. |
| detect_range / lose_range / leash_range | 7 / 11 / 12 | Như quái mẫu, leash ngắn hơn vì quái chậm, không nên lôi đi xa. |
| attack_range | 4.0 | Bắt đầu tụ lực khi player trong 4 m: sóng tới player sau ≈0.45 s kể từ lúc đập, player đã thấy 0.9 s tụ lực. |
| hitbox_reach | 1.8 | Đòn đập trực diện, xa hơn tầm kiếm 1.65 một chút: đứng sát trước mặt lúc đập là bị phạt. |
| attack_cooldown | 2.5 | Giữa 2 lần đập có ≥2.5 s để vòng ra sau đánh. |
| patrol_radius | 2.5 | Lính gác, đi ít. |
| patrol_speed_scale | 0.5 | |
| stagger_on_hit | **false** | Quái nặng có giáp: không bị khựng, không chém hủy được tụ lực (xem QĐ-4). Enemy sẵn có nhánh "đẩy nhẹ knockback × 0.3". |
| knockback_friction | 30 | Bị đẩy lùi rất ngắn. |
| wind_multiplier | **0.0** | Không bị thổi (yêu cầu). `WindReceiverComponent.push()` nhân 0 → không trôi; `Enemy._on_wind_pushed` thoát sớm khi hệ số 0. |
| stagger_on_wind | false | Chắc chắn không vào Blown. |
| corpse_time | 1.5 | Dài hơn thời gian sóng (≈0.75 s) để sóng đang chạy không bị xoá theo quái (xem QĐ-9). |

### ShieldBearerData (kế thừa EnemyData, thêm)

| Thông số | Giá trị | Lý do |
|---|---|---|
| shockwave | `ShockwaveData` | Xem dưới. |
| preferred_distance | 2.0 | Dừng ngoài tầm kiếm (1.65): player phải chủ động bước vào/vòng ra. |
| block_react_time | 0.3 | Khựng ngắn khi bị chặn: đủ thấy phản hồi, không đủ để player vòng ra sau miễn phí. |
| block_pushback_scale | 0.25 | Bị đẩy lùi chút ít khi chặn (cảm giác va chạm). |

### MovementStats (`resources/enemies/shield_bearer_movement.tres`)

| Thông số | Giá trị | Lý do |
|---|---|---|
| max_speed | 2.2 | Chậm hơn nhiều so với player 6 m/s: luôn chạy thoát được. |
| ground_accel / ground_decel / turn_accel | 12 / 20 / 15 | Nặng nề. |
| rotation_speed | 3.0 | Quay chậm (quái mẫu 8): dash 2.73 m vòng sườn là thoát khỏi cung khiên trong ≈0.3–0.5 s. Cần đo ở test. |

### AttackData đòn đập (`resources/enemies/shield_bearer_slam.tres`)

| Thông số | Giá trị | Lý do |
|---|---|---|
| animation | `&"ShieldSlam"` | 1 clip gộp 3 pha, mốc khớp số dưới. |
| damage | 1 | Player có `fixed_damage_per_hit = 1` nên số này chỉ có ý nghĩa với hurtbox khác. |
| knockback | 8.0 | Mạnh hơn quái mẫu (6): đòn nặng. |
| active_start | 0.9 | Tụ lực 0.9 s (quái mẫu 0.5): telegraph dài vì đòn vùng khó né hơn. |
| active_end | 1.0 | Hitbox cận chiến bật 0.1 s. |
| duration | 2.0 | Hồi 1.0 s: khoảng hở chính. |
| lunge_speed / lunge_time | 0 / 0 | Không lướt (state riêng cũng bỏ qua). |

### ShockwaveData (`resources/enemies/shield_bearer_shockwave.tres`)

| Thông số | Giá trị | Lý do |
|---|---|---|
| damage / damage_type / knockback | 1 / PHYSICAL / 7.0 | |
| start_radius | 0.6 | Bắt đầu ngay mép khiên. |
| max_radius | 6.0 | Lớn hơn attack_range 4 m; ra xa > 6 m là an toàn. |
| speed | 7.0 m/s | Nhanh hơn player chạy (6) → không chạy thoát được khi ở gần, phải **nhảy hoặc dash**. Thời gian sống (6 − 0.6)/7 ≈ 0.77 s. |
| band_width | 0.6 m | Độ dày vòng sóng. |
| hit_height | 0.45 m | Chân player cao hơn mức này (so với mặt đất nơi đập) thì không trúng. |
| ignore_invincibility | false | Dash (có i-frame) đi xuyên được. |
| blocked_by_world | true | Không trúng xuyên tường (raycast layer world). |

**Kiểm tra né bằng nhảy (tính tay, phải đo lại ở test):** g = 2h/t² = 2·2/0.38² ≈ 27.7 m/s², v₀ ≈ 10.5 m/s. Chân vượt 0.45 m sau ≈0.045 s; lên đỉnh ở 0.38 s; rơi từ 2 m về 0.45 m với trọng lực ×1.8 mất ≈0.25 s → **thời gian chân cao hơn 0.45 m ≈ 0.58 s**. Vòng sóng đè lên hurtbox player (bán kính 0.4) trong (0.6 + 2·0.4)/7 ≈ **0.2 s**. → Cửa sổ bấm nhảy hợp lệ ≈ 0.38 s: đủ rộng, không phải canh khung hình. Nhả nút sớm (jump cut) vẫn né được nếu nhảy đúng lúc vì chỉ cần 0.45 m.

## 4. Hitbox / hurtbox / collision chuẩn

| Thành phần | Hình | Vị trí (trong Model, +Z = trước) | Layer / Mask |
|---|---|---|---|
| Thân (CharacterBody3D) | Capsule r 0.45, cao 1.9, tâm y 0.95 | gốc | layer 4 (enemy, kế thừa) / mask 257 (kế thừa) |
| HurtboxComponent (đổi script thành GuardedHurtboxComponent) | Capsule r 0.5, cao 2.0, tâm y 1.0 | gốc | layer 4 (kế thừa) |
| Model/Hitbox (đòn đập) | Box rộng 1.4, cao 1.2, tâm y 0.6; `set_reach(1.8)` | trước mặt | layer 16 / mask 2 (kế thừa) |
| EnemySensor | Sphere theo detect_range | kế thừa | mask 2 |
| WindReceiverComponent | giữ nguyên (hệ số 0) | | 128 / 64 |
| GroundShockwave/DetectArea | Cylinder r = max_radius + 0.5, cao 2·hit_height + 1 | tâm điểm đập | layer 0 / mask 2 (hurtbox player) |
| Model/ShockwaveOrigin (Marker3D) | — | (0, 0, 0.75): chỗ mép dưới khiên chạm đất | — |

Không cần thêm collision layer mới.

## 5. Phương án animation

Model low-poly tách khối cứng (không rig xương): AnimationPlayer key transform của từng phần (Body, Head, ArmL, ArmR, Shield). Tên clip khớp hằng số của `EnemyState` để tự chạy; thiếu clip thì `Enemy.play_anim/play_action` tự bỏ qua (quái chạy được với hình tạm).

| Clip | Dài | Nội dung |
|---|---|---|
| Idle | 1.6 s loop | Thở chậm, khiên nhích nhẹ. |
| Walk | 1.0 s loop | Bước nặng, khiên giữ trước ngực (dùng cho Patrol và ShieldAdvance). |
| GuardBlock | 0.3 s | Khiên giật về sau 10–15° rồi về chỗ, thân lùi nhẹ. |
| ShieldSlam | 2.0 s | 0–0.9 s giơ khiên qua đầu (chậm dần, rung nhẹ ở 0.6–0.9 s); 0.9–1.0 s đập xuống (nhanh); 1.0–2.0 s khiên cắm đất, thở dốc, rút khiên lên ở 1.7–2.0 s. |
| Hurt | 0.2 s | Giật thân (chỉ dùng nếu sau này bật stagger). |
| Death | 1.0 s | Khiên đổ ra trước, thân sụp. |

Squash & stretch: dùng `SquashStretch` sẵn có của Character (co giãn Model/Visual) cho lúc đập.

## 6. Đặc tả model

- **Ý tưởng**: sinh vật linh giới bị tha hoá — một **linh hồn đá/rêu** mang **mảnh cửa đền vỡ** làm khiên. Không áo giáp phe phái, không biểu tượng quân đội/phe xâm lược. Thân khom, vai to, chân ngắn: hình khối "nặng" nhìn là biết gió không đẩy được (art_style_guide: vật nặng phải nhìn ra bằng hình dáng).
- **Kích thước**: cao 2.0 m (cao hơn player 1.8), rộng vai 1.0 m. Khiên: cao 1.2 × rộng 0.9 × dày 0.12 m, mép dưới cách đất 0.15 m khi thủ, mặt khiên ở z ≈ +0.55.
- **Pivot**: gốc model ở giữa hai chân, sát đất; mặt quay **+Z**. Khiên pivot tại tay cầm (để xoay giơ lên/đập xuống đúng). Tay pivot ở vai.
- **Phần tách / tên node** (trong .glb): `Body`, `Head`, `ArmL`, `ArmR`, `Shield`, `Eyes` (mắt phát sáng: vật liệu riêng thứ 2 cho phép theo art guide).
- **Màu**: xám đá ấm + rêu nâu xám, ít bão hoà; mắt và vết nứt trên khiên màu nhấn của quái (cam đất/hổ phách, khớp telegraph cam sẵn có). **Không dùng trắng/xanh nhạt** (dành cho gió).
- **Poly**: ≤ 5.000 tri (quái thường). 1 vật liệu + 1 vật liệu phát sáng.
- **Xuất**: `assets/models/enemies/shield_bearer/shield_bearer.glb`, đặt vào `Model/Visual` của `shield_bearer.tscn`, xoá `Body`/`Eye` hình tạm (ẩn hoặc xoá node kế thừa — xoá node kế thừa không được trong inherited scene, nên **đặt `visible = false`**).
- Trước khi dựng: tham khảo silhouette Darknut / Great Husk Sentry (nguồn mục 1) theo memory "reference famous games before art".

## 7. Đặc tả code

### 7.1 Cơ chế chặn theo hướng (mở rộng, KHÔNG sửa HurtboxComponent)

Hiện trạng đã đọc: mọi nguồn sát thương (`HitboxComponent._on_area_entered`, `Arrow`, `DamageArea`) gọi `hurtbox.receive_hit(info)`; `HitboxComponent` **không dùng** giá trị trả về và vẫn phát `hit` → player vẫn có hitstop khi chém trúng khiên (tốt: cảm giác "keng"). `Arrow` gọi `receive_hit` rồi `queue_free()` → tên trúng khiên biến mất (khớp Darknut). Knockback trong `DamageInfo` = hướng từ người đánh tới mục tiêu (kiếm) hoặc hướng bay (tên).

Thiết kế:

- `components/hit_guard/hit_guard.gd` — `class_name HitGuard extends Node`. Lớp cơ sở "bộ lọc chặn đòn": `@export var enabled: bool = true`; `func try_block(info: DamageInfo) -> bool` trả `false`. Kiểu chặn mới (giáp sau lưng, khiên nguyên tố...) = thêm lớp con, không sửa gì.
- `components/hit_guard/directional_hit_guard.gd` — `class_name DirectionalHitGuard extends HitGuard`. `@export var facing_node: Node3D` (gán `Model`), `@export_range(0, 360) var arc_degrees: float = 120.0`, `@export var blocks_hazards: bool = false`. Cache `cos(arc/2)` khi set. `try_block`: tắt → false; `info.ignores_invincibility and not blocks_hazards` → false (bẫy môi trường không bị khiên chặn); hướng đòn tới = `-info.knockback` (bỏ y); nếu ≈ 0 thì dùng `info.source.global_position - facing_node.global_position`; vẫn ≈ 0 → false (không xác định được thì cho trúng). Chặn nếu `facing.dot(hướng tới) >= cos(arc/2)`, `facing` lấy từ `facing_node.global_basis.z`.
- `components/hurtbox/guarded_hurtbox_component.gd` — `class_name GuardedHurtboxComponent extends HurtboxComponent`. `signal blocked(info: DamageInfo, guard: HitGuard)`; `@export var guards: Array[HitGuard] = []`. Override `receive_hit(info)`: nếu `not is_alive()` → false; duyệt `guards`, guard nào `try_block` → `blocked.emit(info, guard)`, return false (không trừ máu, không đổi i-frame, không phát `hurt`); không guard nào chặn → `return super(info)`. Vì là lớp con nên `Enemy.hurtbox: HurtboxComponent` vẫn nhận được, `Enemy._on_hurt` không đổi.
  - Chưa chắc: đổi script của node kế thừa `HurtboxComponent` trong inherited scene vẫn giữ các property kế thừa (`health`, `collision_layer`, shape). Phải kiểm tra trong editor ngay bước đầu; nếu mất thì gán lại trong `shield_bearer.tscn`.

### 7.2 Sóng kích (vật thể mới, tái sử dụng được cho boss/quái khác)

- `objects/shockwave/shockwave_data.gd` — `class_name ShockwaveData extends Resource`: các trường ở bảng ShockwaveData (mục 3), `@export_group` Damage / Shape / Rules.
- `objects/shockwave/ground_shockwave.gd` + `.tscn` — `class_name GroundShockwave extends Node3D`.
  - Cây node: `GroundShockwave (Node3D, top_level = true)` → `Ring (MeshInstance3D, PlaneMesh 1×1, cast_shadow off, shader ring)`, `Dust (GPUParticles3D, giới hạn ≤ 48 hạt, one_shot)`, `DetectArea (Area3D, layer 0, mask 2, monitorable false)` → `CollisionShape3D (CylinderShape3D, resource_local_to_scene)`.
  - `signal finished`. Public: `launch(origin: Vector3, data: ShockwaveData, source: Node) -> void`, `is_active() -> bool`, `stop() -> void`.
  - Theo dõi mục tiêu bằng `area_entered/area_exited` (lưu `HurtboxComponent` + bán kính hurtbox đọc từ shape Capsule/Sphere/Cylinder con đầu tiên, cache lúc vào, không đọc mỗi frame). Không quét overlap mỗi frame.
  - `_physics_process` chỉ bật khi đang chạy: `prev_r = r; r += speed·delta`. Với mỗi mục tiêu chưa trúng: `d` = khoảng cách ngang tới tâm; **kiểm tra quét** `d ∈ [prev_r − band/2 − r_hurt, r + band/2 + r_hurt]` (không lọt khi speed rất lớn / band rất mỏng); `0 − hit_height_below ≤ (hurtbox.global_position.y − origin.y) ≤ hit_height` (hurtbox player đặt ở gốc nhân vật = chân); nếu `blocked_by_world` thì raycast `PhysicsRayQueryParameters3D.create(...)` + `direct_space_state.intersect_ray` (đã dùng trong `arrow.gd`) mask world từ tâm (+0.3 m) tới mục tiêu (+0.3 m), có va chạm → không trúng. Trúng → `receive_hit(DamageInfo.new(...))` hướng đẩy = từ tâm ra ngoài, `ignores_invincibility` theo data, đánh dấu đã trúng (mỗi sóng trúng một mục tiêu đúng 1 lần).
  - `r >= max_radius` → `stop()`: tắt `monitoring` (deferred), ẩn Ring, `set_physics_process(false)`, phát `finished`.
  - Shader ring nhận `radius`, `band_width`, `max_radius`; cập nhật bằng `set_instance_shader_parameter` (chưa chắc tên tham số instance uniform trong shader 4.7 — kiểm tra docs `GeometryInstance3D.set_instance_shader_parameter` và `instance uniform` trước khi dùng) để dùng chung 1 material, không `duplicate()`.
  - **Pool**: mỗi quái giữ **1 instance** làm con (top_level nên không xoay/đi theo quái); hồi chiêu 2.5 s > thời gian sống 0.77 s nên 1 là đủ, không `instantiate()/queue_free()` mỗi đòn.
- `assets/shaders/shockwave_ring.gdshader` — unshaded, blend mix, vẽ vành tròn mềm mép trên plane theo `radius`/`band_width`, alpha giảm theo `radius/max_radius`; thêm chế độ `preview` (alpha thấp, vạch đứt) cho vòng báo phạm vi.

### 7.3 Quái

- `entities/enemies/shield_bearer/shield_bearer_data.gd` — `class_name ShieldBearerData extends EnemyData`: `shockwave: ShockwaveData`, `preferred_distance`, `block_react_time`, `block_pushback_scale`.
- `entities/enemies/shield_bearer/shield_bearer.gd` — `class_name ShieldBearer extends Enemy`.
  - `signal slammed(position: Vector3)` (chỗ cắm rung camera / âm thanh sau này; hiện project **chưa có** hệ thống screen shake — đã grep).
  - `@onready`: `guard: DirectionalHitGuard = $HurtboxComponent/ShieldGuard`, `shockwave: GroundShockwave = $GroundShockwave`, `shockwave_origin: Marker3D = $Model/ShockwaveOrigin`, `guarded_hurtbox := hurtbox as GuardedHurtboxComponent`.
  - `_ready()`: `super()`; assert `data is ShieldBearerData`; nối `guarded_hurtbox.blocked` → `_on_blocked`; nối `wind_receiver.pushed` → `_on_wind_deflected` (chỉ phát VFX gió tách).
  - Public: `shield_data() -> ShieldBearerData`, `set_guard(on: bool)`, `launch_shockwave()` (gọi `shockwave.launch(shockwave_origin.global_position, ...)` + `slammed.emit`), `show_slam_preview(on: bool)`.
  - `_on_blocked(info, _guard)`: đẩy lùi `info.knockback × block_pushback_scale`, phát VFX tia lửa + âm thanh chặn; nếu state hiện tại là `chase_state` hoặc `ShieldBlock` → `state_machine.transition_to(&"ShieldBlock")`.
- `entities/enemies/shield_bearer/states/shield_advance.gd` (extends EnemyState): giống tinh thần Chase nhưng dừng ở `preferred_distance`, bỏ đuổi dùng `should_give_up_chase()`, ra đòn dùng `can_attack()` → `enemy.attack_state`. Anim `Walk`.
- `entities/enemies/shield_bearer/states/shield_block.gd`: đứng yên, hãm vận tốc bằng `knockback_friction`, anim `GuardBlock`, hết `block_react_time` → `enemy.chase_state` / IDLE.
- `entities/enemies/shield_bearer/states/shield_slam.gd`: `enter`: `set_guard(false)`, khoá hướng về player (`face_instantly`), telegraph on, `show_slam_preview(true)`, play `ShieldSlam`. Tới `active_start`: telegraph off, preview off, `hitbox.activate(attack)`, `launch_shockwave()`. Tới `active_end`: `hitbox.deactivate()`. Không lướt; `move_toward_direction(ZERO)`. Hết `duration` → chase_state/IDLE. `exit`: `set_guard(true)`, telegraph off, preview off, hitbox off, `start_attack_cooldown()`. (Không gọi `stop()` sóng khi exit: sóng đã phóng thì chạy hết.)
- `entities/enemies/shield_bearer/shield_bearer.tscn` — **New Inherited Scene từ `enemy.tscn`**:
  - Root: script `shield_bearer.gd`, `data = shield_bearer.tres`, `chase_state = &"ShieldAdvance"`, `attack_state = &"ShieldSlam"`.
  - Đổi shape thân + hurtbox theo mục 4 (shape mới, local).
  - `HurtboxComponent`: script → `guarded_hurtbox_component.gd`, `guards = [ShieldGuard]`; con mới `ShieldGuard (DirectionalHitGuard)`, `facing_node = ../../Model`.
  - `Model/ShockwaveOrigin (Marker3D)`, `GroundShockwave` (instance `ground_shockwave.tscn`), `Model/Visual/ShieldBearerModel` (glb, khi có), `SlamPreview` (MeshInstance3D dùng shader ring chế độ preview, mặc định ẩn), `BlockSparks` / `WindDeflect` (GPUParticles3D one_shot).
  - `StateMachine`: thêm `ShieldAdvance`, `ShieldBlock`, `ShieldSlam`. Giữ các state kế thừa.
  - Body/Eye hình tạm: `visible = false` khi có model thật; trước đó thêm khối hộp tạm `ShieldPlaceholder` để thấy hướng khiên.
- Resource: `resources/enemies/shield_bearer.tres` (ShieldBearerData), `shield_bearer_movement.tres`, `shield_bearer_slam.tres`, `shield_bearer_shockwave.tres`.

### 7.4 Test

- `tests/test_enemy_2.tscn` + `tests/test_enemy_2.gd` (scene riêng, **không sửa** `tests/test_enemies.tscn` của nhóm — xem câu hỏi Q2). Sân phẳng, 1 bức tường, 1 bục cao 1 m, 1 player, 1 ShieldBearer. Script chạy headless `--script`, in PASS/FAIL từng mục ở mục 9.

### 7.5 KHÔNG được sửa

`entities/enemies/_base/*` (enemy.gd, enemy.tscn, enemy_data.gd, mọi state dùng chung), `components/hurtbox/hurtbox_component.gd`, `components/hitbox/hitbox_component.gd`, `components/wind_receiver/*`, `components/damage*`, `entities/player/*`, `objects/projectiles/arrow.gd`, `project.godot` (không cần layer/input mới), `tests/test_enemies.tscn`, `docs/enemies/enemy_1_plan.md`, `docs/enemies/enemy_3_plan.md`. Phát sinh nhu cầu sửa → dừng lại hỏi.

## 8. Đặc tả VFX / âm thanh

Tham khảo: Death's Door dùng nền gần đơn sắc + một màu nhấn (art_style_guide); đòn đập của Guardian of the Door là sóng nhỏ quanh điểm đập (nguồn mục 1).

| Hiệu ứng | Khi nào | Cách làm | Giới hạn |
|---|---|---|---|
| Telegraph thân | Tụ lực 0 → 0.9 s | `telegraph_material` sẵn có của Enemy (cam) | — |
| Vòng báo phạm vi | Tụ lực | `SlamPreview`: shader ring chế độ preview, bán kính = max_radius, alpha ~0.25, đậm dần tới lúc đập | 1 draw call |
| Sóng kích | Đập → hết | `Ring` shader: vành màu đất/hổ phách, mép trước sáng hơn, mờ dần theo bán kính | 1 draw call, cast_shadow off |
| Bụi + đá vụn | Lúc đập + theo vòng | `GPUParticles3D` one_shot ≤ 48 hạt, phát tại tâm; (vòng hạt theo mép: dùng emission shape ring — **chưa chắc** tên enum `EMISSION_SHAPE_RING` trong ParticleProcessMaterial 4.7, kiểm tra docs; không có thì chỉ phát ở tâm) | ≤ 48 hạt |
| Tia lửa chặn | Bị chặn | `BlockSparks` one_shot ≤ 12 hạt màu hổ phách tại mặt khiên; khiên rung (anim GuardBlock) | ≤ 12 hạt |
| Gió tách | Bị cú thổi trúng | `WindDeflect` ≤ 16 hạt bụi lệch hai bên khiên. Không dùng màu trắng/xanh của gió cho thân quái; hạt bụi màu xám | ≤ 16 hạt |
| Âm thanh | Chặn, tụ lực, đập, bước chân, chết | `AudioStreamPlayer3D` để trống stream (chỗ cắm sẵn) | — |

## 9. Checklist nghiệm thu (đo hành vi thật, không đọc property)

Chạy headless theo `.claude/agents/enemy-planner.md`, xoá `savegame.json` trước và sau.

Chặn đòn
- [ ] Chém từ chính diện: HP quái giữ 4, phát `blocked`, không phát `hurt`, player vẫn hitstop.
- [ ] Chém từ sau lưng và từ sườn 90°: HP giảm 1, quái **không** vào Hurt, chỉ bị đẩy nhẹ.
- [ ] Biên cung: đòn ở 55° → chặn, 65° → trúng (arc 120°). Lặp với arc 10°, 180°, 359°, 0°.
- [ ] Bắn tên trực diện: tên biến mất, HP không đổi. Bắn sau lưng: HP giảm.
- [ ] Trong pha tụ lực và hồi: chém trực diện trúng (khiên tắt), quái không bị hủy đòn.
- [ ] Gai (DamageArea `ignore_invincibility`) từ phía trước vẫn gây sát thương (khiên không chặn bẫy).
- [ ] 4 nhát trúng → Dead, collision tắt, xác biến mất sau corpse_time.

Gió
- [ ] Cú thổi trúng: vị trí quái lệch < 0.05 m, state không đổi sang Blown, VFX gió tách chạy.
- [ ] Đứng trong cột gió hướng lên: không bị nâng.

Đòn đập + sóng
- [ ] Từ lúc vào ShieldSlam tới lúc hitbox bật đo được 0.9 s (±1 frame); telegraph + vòng báo hiện trong khoảng đó.
- [ ] Player đứng yên cách 3 m: trúng đúng 1 lần, thời điểm ≈ active_start + (3 − 0.6)/7 s.
- [ ] Player nhảy đúng lúc (giả lập: đặt chân cao 0.5 m khi vòng đi qua): không trúng. Player chạm đất cao 0.4 m: trúng.
- [ ] Player dash xuyên vòng (đang i-frame): không trúng.
- [ ] Player đứng sau tường: không trúng. Đứng trên bục 1 m: không trúng.
- [ ] Player ở 6.5 m: không trúng; sóng tắt `_physics_process` và `monitoring` sau khi hết.
- [ ] Mỗi lần đập chỉ 1 sóng; đập lần 2 tái dùng cùng instance (không tạo node mới — đếm node con).
- [ ] Cực đoan ShockwaveData: speed 0.5 / 60; band_width 0.05 / 3; max_radius 0.6 (= start) / 30; hit_height 0 / 3 — không lỗi console, quét không lọt mục tiêu ở speed 60 + band 0.05.
- [ ] Cực đoan quái: rotation_speed 0.5 / 30, preferred_distance 0 / 10, attack_range < preferred_distance (không kẹt), attack_cooldown 0.
- [ ] Chụp ảnh: vòng sóng khớp vùng gây sát thương (vành hình vs vành va chạm) ở 3 bán kính.
- [ ] Không có lỗi/cảnh báo console trong toàn bộ test.

## 10. Quyết định của planner (người dùng đổi được)

- **QĐ-1 Cung chặn 120° phía trước.** Như Darknut: trực diện vô dụng, sườn và sau hở. 120° (không phải 180°) để dash 2.73 m sang sườn là đủ vòng qua, quái quay chậm nên người chơi có cửa.
- **QĐ-2 Khiên chặn mọi lúc trừ khi đập (tụ lực + hồi).** Đơn giản, đọc được; mở mặt trước đúng lúc nó tấn công tạo nhịp "rủi ro – phần thưởng" như Great Husk Sentry.
- **QĐ-3 Sóng né được bằng nhảy và bằng dash.** Đã tính cửa sổ ≈0.38 s (mục 3). Husk Guard cũng né bằng nhảy. Dash né vì sóng tôn trọng i-frame (bẫy môi trường mới bỏ qua i-frame).
- **QĐ-4 Không bị khựng (stagger_on_hit = false).** Nếu bị khựng, chém một nhát lúc tụ lực là hủy đòn → quái không bao giờ đập được. Quái nặng có giáp hợp hình tượng; không cần sửa `Enemy`.
- **QĐ-5 Sóng hình vòng 360°, phát từ chỗ khiên chạm đất.** Đứng sau lưng cũng phải nhảy → cân bằng với việc sau lưng không có khiên.
- **QĐ-6 Sóng chạy trên mặt phẳng độ cao điểm đập**, không bám địa hình; người đứng cao hơn `hit_height` hoặc thấp hơn hẳn thì không trúng; tường chặn sóng. Sân quái nên phẳng (đề xuất cho level design).
- **QĐ-7 Sóng chỉ trúng player** (mask hurtbox player), không trúng quái khác — giống hitbox quái hiện có.
- **QĐ-8 Đánh khiên không phạt thêm** (không phản đòn ngay), chỉ khựng 0.3 s. Giữ đúng "2 trạng thái" người dùng yêu cầu, không thêm đòn thứ 3.
- **QĐ-9 Pool 1 sóng là con của quái** (top_level). corpse_time 1.5 s > thời gian sống sóng nên quái chết ngay sau khi đập thì sóng vẫn chạy hết.
- **QĐ-10 Chặn đòn không đẩy lùi player.** Muốn có thì phải thêm API public cho player (ngoài phạm vi, file của người khác). Hiện player vẫn có hitstop + tia lửa + âm thanh làm phản hồi.
- **QĐ-11 Không đổi tên/thêm layer, không sửa test chung**; test riêng `tests/test_enemy_2.tscn`.
- **QĐ-12 Bẫy môi trường (`ignores_invincibility`) không bị khiên chặn**, vực/KillZone vẫn giết (không qua hurtbox). Quái không bị thổi nên chỉ dẫn được vào bẫy bằng cách dụ nó đi theo.

## 11. Câu hỏi cho người dùng (chỉ những gì planner không tự quyết được)

- **Q1 (lore/tên):** Tên chính thức và nguồn gốc trong cốt truyện đảo Foxy? Tạm gọi "Hộ Vệ Khiên" — linh hồn đá mang mảnh cửa đền vỡ. Có hợp lore Map Gió / GDD không?
- **Q2:** Có muốn đặt thêm 1 con vào `tests/test_enemies.tscn` dùng chung không (file chung của nhóm — cần đồng ý riêng)? Mặc định plan chỉ tạo scene test riêng.
- **Q3 (ngoài phạm vi):** Muốn player bị đẩy lùi nhẹ khi chém trúng khiên không? Cần thêm hàm public ở `player.gd` (file người khác phụ trách).
