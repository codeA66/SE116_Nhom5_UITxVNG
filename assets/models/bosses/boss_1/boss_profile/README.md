# Boss Crimson — Boss 1

Model và animation lấy từ `BossCrimson_Godot.zip` do người dùng cung cấp.

## Tài nguyên

- `model/boss_1.glb`: model, texture nhúng, skin, 34 xương Mixamo và 10 animation gốc. Godot tạo ba ảnh albedo cùng metadata nhập từ các texture nhúng.
- `animation/boss_animation_library.tres`: thư viện in-place dùng cho gameplay, lấy chuyển động từ GLB mới; không dùng animation của skeleton cũ.
- `boss.tscn`: visual độc lập, tự phát Idle và gắn Charge VFX.
- `vfx/charge_vfx/`: VFX húc gồm vệt gió ở đầu/sừng, vòng va chạm và bụi chân.
- `vfx/fireball_vfx/`: VFX cầu lửa có sẵn, được giữ nguyên.
- Texture và `source_fbx/` của model trước được giữ lại; chúng không điều khiển bộ animation mới.

## Animation

| Tên trong thư viện | Nguồn | Thời lượng | Lặp |
| --- | --- | --- | --- |
| Idle | Idle | 4,033 s | Có |
| Walk | Walk | 1,433 s | Có |
| Normal_Attack_1 | Normal_Attack_1 | 2,667 s | Không |
| Normal_Attack_2 | Normal_Attack_2 | 2,667 s | Không |
| Cast_Fireball | Cast_Fireball | 3,367 s | Không |
| Jump_Attack / Jump Attack | Jump_Attack | 3,700 s | Không |
| Roaring / Buff | Roaring | 5,400 s | Không |
| Taunt | Taunt | 2,833 s | Không |
| Dying | Dying | 4,600 s | Không |
| Charge | Charge | 3,200 s | Không |
| Orc Idle | Idle | 4,033 s | Có |

Các alias giữ giao diện animation của FSM hiện tại. Chiêu húc đã được gắn vào AI bằng state `Charge` và `ChargeController`; scene demo vẫn dùng được độc lập.

## Gắn vào gameplay

`entities/bosses/boss_1/boss_1.tscn` vẫn dùng AnimationPlayer ở gốc, trỏ vào `Model/Visual/BossModel`. Model và Charge VFX cùng tỉ lệ 2,7. VFX dùng đường dẫn tường minh tới AnimationPlayer đang điều khiển boss và `Armature/Skeleton3D` mới.

Không lưu pose xương của model cũ trong `boss.tscn`. Không có hai AnimationPlayer cùng tự phát clip trong gameplay.

Mốc animation trong scene boss:

- Cận chiến: ngừng xoay ở 1,00 s, active từ 1,13 đến 1,40 s của clip. FSM chia các mốc cho tốc độ phase.
- Nhảy dậm: lấy đà 0,50 s, tác động 1,60 s của clip; FSM chia theo tốc độ phase.
- Cầu lửa: phóng ở 1,93 s.
- Charge VFX: impact ở 64/30 s; phát một lần mỗi lượt, được reset khi phát lại.

Thư viện gameplay đã được bake in-place theo lựa chọn của người dùng:

- X/Z của Hips được giữ tại mốc Idle, tính theo hệ tọa độ model sau khi chuyển từ hệ trục của skeleton. Không khóa nhầm trục đứng của rig.
- Giữ nhún, cúi và ngã theo trục đứng của các clip thông thường.
- Riêng `Jump_Attack` / `Jump Attack`, bỏ phần nâng Hips vượt độ cao Idle vì controller đã tạo quỹ đạo bay; giữ hạ người, co gối và tư thế tiếp đất. Có key tại điểm chuyển để giữ liên tục chuyển động.
- Các key xoay khớp, thời lượng, alias, VFX Charge và VFX fireball được giữ nguyên. Xử lý nằm trong tài nguyên animation, không thêm công việc mỗi frame vào controller.
- GLB không bị ghi lại và vẫn chứa đủ animation/chuyển vị gốc. Metadata thư viện lưu mốc in-place, chính sách độ cao và SHA-256 của GLB nguồn để đối chiếu.

## Xem thử và kiểm tra

- Chạy `vfx/charge_vfx/charge_vfx_demo.tscn`: tự húc một lần, dùng action `jump` để phát lại; không thêm phím cứng hoặc Input Map mới.
- Chạy `tests/enemies/boss/test_boss_profile.tscn`: kiểm tra 34 xương, 13 tên clip/alias, loop, track, pose; đo Hips khi lấy mẫu toàn bộ clip và khi blend; đồng bộ và tái phát VFX; tỉ lệ nhỏ/lớn, hướng -Z, giới hạn số vệt/hạt; va chạm cận chiến thật ở phase 1/3; cầu lửa thật; nhảy thật và đáp ở hai hướng, scale 0,5/2 và tốc độ phase 1/3; các mốc khóa máu, phá khiên và chết.
- Khi chạy tự động trên Windows, đặt APPDATA và LOCALAPPDATA vào thư mục riêng dưới `.godot/` để không chạm save thật.
- Ảnh kiểm tra cục bộ: `.godot/boss_crimson_integration/`.

Kết quả chạy Godot 4.7.2 Compatibility: test profile hoàn tất mã 0, không lỗi kiểm tra. Đo được active cận chiến ở khoảng 0,733 s (phase 1) và 0,567 s (phase 3), mỗi đòn trúng một lần; cầu lửa xuất hiện khoảng 1,933 s. Mốc lấy mẫu có sai số một vài khung vật lý. Độ trôi ngang Hips của nguồn đạt khoảng 2,749 m ở scale 2,7; thư viện in-place giữ độ trôi dưới 0,001 m khi thử cả scale và hướng nhảy khác nhau. Đối chiếu bản trước/sau bake không thay đổi 29.897 key ngoài track vị trí Hips (tính cả alias). Đã chụp các tư thế Idle, đánh, chưởng, nhảy và Charge VFX.

## Chiêu húc và kích thước

- Cấu hình: `resources/enemies/bosses/boss_1/boss_1_charge.tres`. Sát thương: `boss_1_charge_attack.tres` cùng thư mục.
- Mặc định cảnh báo 0,9 s, tốc độ 16 m/s, quãng đường 10 m, hồi phục 0,65 s; cooldown phase 1/2/3 là 10/8/6 s. Cooldown bắt đầu lúc thực sự lao đi.
- Trong cảnh báo, boss theo hướng player; hết cảnh báo thì khóa hướng. Dải đỏ bao trọn chiều rộng và đoạn quét của hitbox, nên phần chỉ thị tính cả đầu/đuôi hitbox ngoài quãng đường tâm boss.
- Dừng ở tường, mép sàn hoặc hết quãng đường. `stop_on_player_hit` cho phép dừng ngay khi chạm player, mặc định tắt. Mỗi hurtbox chỉ nhận một lần sát thương mỗi lượt. Quét ShapeCast chống bỏ sót ở tốc độ cao; ray kiểm tra vật cản ngăn đánh xuyên tường.
- `ChargeController` nghe sự kiện vào Idle/Chase và hết cooldown, không quét mục tiêu mỗi frame. Chiêu chỉ được chọn khi có mục tiêu, boss trên sàn, trong khoảng 4–12 m và không có khiên; xác suất mặc định 45%. Idle/Chase dùng chung ActionSelector; sự kiện vào state chỉ đề nghị xét chiêu mở rộng, không bỏ qua thời gian nghỉ để chọn các chiêu cũ.
- Debug tại node `ChargeController`: `enabled`, `debug_force_charge` (bỏ qua xác suất, vẫn kiểm tra mục tiêu/tầm/khiên/cooldown), `debug_log`. State `StateMachine/Charge` cũng có `debug_log` và các tham chiếu animation/hitbox/VFX. Toàn bộ thông số chuyển động, sát thương, hình hộp và các mốc animation nằm trong Resource; màu, viền và dò sàn nằm ở node `ChargeLaneIndicator`.
- Animation được phát bình thường bằng các đoạn cảnh báo/tông/hồi phục, với tốc độ khớp thời gian và quãng đường cấu hình. Không pause rồi seek mỗi frame vì cách đó giữ nguyên blend và làm xương đứng yên. Khi thoát chiêu, bỏ giới hạn đoạn để Idle/Walk/đòn khác phát đầy đủ. Test kiểm tra cả chuyển động xương chân thực tế trong lúc tông, không chỉ vị trí boss hoặc VFX.
- Kích thước: node `Size.multiplier` ở scene boss là 1,25; ở scene cầu lửa là 1,5. Component áp dụng từ scale ban đầu, hỗ trợ chỉnh runtime và không tăng dồn qua pool. Model, collider, hurtbox, khiên và điểm phóng cùng theo scale boss; cầu lửa `top_level` nên không bị nhân thêm scale của boss.
- Có thể nối âm thanh/phản hồi vào `Charge.charge_started`, `Charge.charge_finished` và `ChargeHitbox.hit`.
- Kiểm tra: `tests/enemies/boss/test_boss_charge.tscn`; thêm đối số `-- --capture` khi chạy có cửa sổ để lưu ảnh vào `.godot/boss_charge_test/`. Bao gồm va chạm thật, né sau khóa hướng, đổi hướng lúc cảnh báo, tường/player sau tường, mép sàn, hủy chiêu, dừng khi trúng, speed 600, quãng đường 0,01/20 m, hitbox rộng-ngắn/hẹp-dài, scale 0,5/2, hồi chiêu, kích thước cầu lửa qua pool, va chạm ở mép bán kính mới và phản gió phá khiên.


## Dọn code boss (2026-11-16)

- HealthComponent của scene dùng BossPhaseController (kế thừa HealthComponent): chặn sát thương vượt mốc trước signal chết; khiên chặn tại BossHurtbox, không trừ rồi cộng lại HP. Mốc mặc định 50% / 20%, hồi 40%; HP cực nhỏ vẫn giữ ít nhất 1 HP ở các mốc.
- Phá hết khiên trở lại Idle. Phase 3 nhân damage cho melee, shockwave, magma, Charge và fireball. AttackData/MovementStats/material thay đổi theo instance, không sửa Resource nguồn. Đạn giữ damage tại thời điểm phóng.
- Boss chết hủy magma, sóng, chỉ thị, hitbox, trả toàn bộ cầu lửa thuộc boss về pool và dọn minion. Hủy hazard nhiều lần không phát finished lặp.
- Inspector: Minions chứa scene, số lượng và bán kính triệu hồi; HitFeedback chứa màu/thời gian flash; Cooldowns chứa Timer dùng lại; ActionSelector chứa danh sách BossActionRule theo thứ tự ưu tiên. ChargeController đăng ký vào selector chung và giữ API debug request_charge.
- Damage/knockback nằm ở AttackData từng chiêu, tốc độ/damage cơ bản cầu lửa nằm ở scene BossFireball. Các trường trùng không được sử dụng trong BossData đã bỏ, Resource Forge Boss đã được chuyển theo. Stunned và các trường cấu hình cho state này đã bỏ theo thiết kế mới.
- Animation hành động phát từ đầu với tốc độ phase; active frames/shoot time dùng cùng hệ số. Charge VFX đọc thời điểm playback thật. Cập nhật mục tiêu vòng Jump Slam không reset tiến trình nạp. Hit flash chỉ cache mesh model và dùng Timer, không tạo Tween mỗi hit.
- Fireball quét hình cầu trên đoạn di chuyển: World và hurtbox tách riêng, chọn va chạm gần nhất; kiểm tra ở speed 600 với tường mỏng 0,05 m. Các sweep chỉ cập nhật khi đạn đang hoạt động.
- Magma mặc định tiếp tục dùng hitbox chỉnh tay. Đổi spoke_count runtime rebuild ngoài callback vật lý; giới hạn 1–64. Các nhánh dùng chung 2 material chỉ thị trong mỗi instance.

### Kiểm tra

Chạy từng scene: tests/enemies/boss/test_boss_1.tscn, test_boss_profile.tscn, test_boss_charge.tscn. Test cũ dạng SceneTree đã chuyển sang scene Node3D và fixture dùng chung, không ghi trực tiếp biến private của hurtbox. Dùng APPDATA/LOCALAPPDATA riêng trong .godot/boss_cleanup_test khi chạy tự động.

Bài hồi quy có va chạm thật cho các đòn, khiên/khóa máu với HP 1/50/5000, hệ số 0/2/7, Resource giữa hai boss, player cũ rời sau player mới, ba loại minion, hủy/rebuild magma, chế độ hitbox magma tự dựng, thời gian/tốc độ animation bằng 0. Bộ Charge giữ các trường hợp hitbox không vuông, scale nhỏ/lớn, tường, mép vực và chuyển động xương thật.

Đo riêng _update_telegraph trong headless Godot 4.7.2: 5 mẫu x 10.000 lượt, trung vị trước 13,0079 us/lượt (16 material), sau 5,1109 us/lượt (2 material). Đây là phép đo CPU của chỉ thị, không phải FPS toàn cảnh; baseline và log lưu trong .godot/boss_cleanup_test.
