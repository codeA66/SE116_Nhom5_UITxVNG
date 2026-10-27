# Polar Bear và Monkey Squad

Mở `tests/new_enemy_test/new_enemy_test.tscn`, nhấn **F6** để chạy sân thử riêng. Scene chính của game giữ nguyên. Sân có 1 Armored Polar Bear, 1 Monkey Chieftain và 3 Monkey Grunt. Player Foxy được trang bị kiếm/dash bằng các cờ preview có sẵn, không ghi mở khóa vào save.

- WASD di chuyển, J/chuột trái đánh, Space nhảy, Shift dash.
- Tab đổi camera theo player/toàn cảnh, R hoặc nút **Đặt lại trận thử** dựng lại trận.
- **Hồi máu sau mỗi lần trúng đòn** bật mặc định để tập né. Bộ đếm vẫn ghi số lần trúng; tắt tùy chọn để nhận sát thương bình thường.

## Hành vi

Quái nghỉ bằng Idle và đi bộ từng đoạn ngắn quanh vị trí spawn khi chưa thấy player. Khi mất mục tiêu hoặc vượt giới hạn đuổi, quái trở về khu spawn. Khoảng phát hiện, giới hạn đuổi và bán kính đi tuần chỉnh trong từng `*_data.tres`.

| Enemy | Khi phát hiện | Đòn đánh | Hồi chiêu |
| --- | --- | --- | --- |
| Chieftain | Vỗ ngực/gầm một lần; báo cho 3 grunt trong squad | Chạy áp sát, nhảy vồ/cào hai tay | 3 giây sau khi kết thúc đòn |
| Grunt | Chạy áp sát | Chọn ngẫu nhiên `Lunge_Slash_01` hoặc `02`, giữ dao/ngón tay từ GLB mới nhất | 3 giây sau khi kết thúc đòn |
| Polar Bear | Chọn phép theo khoảng cách | Ice khi gần và sẵn sàng, Wind khi sẵn sàng; nếu cả hai đang hồi thì áp sát dùng physical claw | Ice và Wind độc lập, mỗi chiêu 5 giây sau khi kết thúc; physical claw 3 giây |

Hai loại khỉ đứng Idle và xoay theo player trong suốt cooldown, rồi mới tiếp tục đuổi/đánh. Grunt không dùng vỗ ngực. Các clip khác vẫn nằm trong AnimationPlayer để xem hoặc dùng về sau.

Wind đặt dấu báo tại chân player lúc bắt đầu phép; vùng này giữ nguyên khi player né đi. Ice theo hướng player trong windup, khóa hướng khi hết windup rồi mọc về phía đó. Sau khi physical claw kết thúc, gấu đặt một dấu magic claw ở vị trí player lúc ấy; **2 giây tiếp theo không gây sát thương**, sau đó mới bật collision trong 0,3 giây. Mỗi lần kích hoạt chỉ gây sát thương một lần trên mỗi hurtbox. Phép chỉ đánh layer player, không đánh các quái khác.

## Tổ chức và chỉnh thông số

- Model, GLB animation, thư viện retarget và bản Blender gốc: `assets/models/enemies/blenderimport/`.
- Mỗi model có `source/*.blend` và `.gdignore`: Godot dùng GLB nên máy chạy project không cần cài Blender. Không di chuyển/xóa bản gốc trong project `animation3d_test`.
- Scene/script enemy: `entities/enemies/{armored_polar_bear,monkey_chieftain,monkey_grunt}/`. Kế thừa scene Enemy của đồ án, dùng Health/Hurtbox/Hitbox/EnemySensor/WindReceiver/FSM có sẵn.
- Thông số riêng trong `*_data.tres`, `movement.tres`, `skills/*.tres`. Chỉnh damage, tầm đánh, active frames, windup, cooldown tại đây. `duration` là thời gian thực của đòn; nếu đổi tốc độ animation cần đổi các mốc thời gian theo.
- Các state dùng chung ở `entities/enemies/wildlife/_shared/states/`. `MonkeySquad` liên kết đầu đàn và các grunt bằng signal `engaged`.
- Scene hazard và collision ở `wildlife/_shared/hazards/`. VFX gốc đã chuyển sang `assets/vfx/enemies/`; hiệu ứng được ObjectPool tạo sẵn và tắt xử lý khi nhả về. Dấu báo claw đã đặt nằm trên mặt đất.
- Chuyển động lao trong clip được tách khỏi rig thành Curve metadata rồi áp lên CharacterBody qua vật lý. Vì vậy đòn không dịch hình một mình, không tiến gấp đôi và bị tường chặn.

## Thư viện animation

`assets/models/enemies/blenderimport/animation_manifest.json` liệt kê đầy đủ clip, thời lượng và root distance.

| Model | Số clip | Nguồn |
| --- | ---: | --- |
| Polar Bear | 34 | Đủ 6 pack Rig_Large: General, MovementBasic, MovementAdvanced, CombatMelee, Simulation, Special; giữ các clip T-Pose theo namespace |
| Chieftain | 8 | Đi bộ gốc, run, root-motion run, Idle, ChestBeat, ChestBeat_Roar, Leap_Claw_Attack, Demo_All |
| Grunt | 7 | Đi bộ gốc, run, root-motion run, Idle, Lunge_Slash_01, Lunge_Slash_02, Demo_All |

Tên clip `_Loop` được chuẩn hóa bỏ hậu tố; các clip Idle/Walk/Run phù hợp đã bật loop. Bản GLB và BLEND nguồn vẫn nguyên bản. KayKit CC0 và credit gốc nằm tại `armored_polar_bear/rig_large/License.txt`.

Nếu thay GLB hoặc Rig_Large, import trước rồi bake lại thư viện:

```powershell
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tools/bake_new_enemy_animations.gd --quit-after 180
```

## Kiểm tra

```powershell
godot --headless --path . --fixed-fps 60 res://tests/new_enemy_test/verify_new_enemies.tscn --quit-after 12000
```

Bài test đo thư viện/đường dẫn animation, cảm biến, patrol, Run, vỗ ngực một lần, random hai đòn, cooldown đứng xoay, root motion và tường, Wind/Ice tracking, vùng sát thương thực, delay 2 giây, né đòn, phe, pool và dọn hiệu ứng khi chết. Có kiểm tra cả scene với player Foxy thật và đủ squad.

Chụp ảnh kiểm tra trên renderer thật (thư mục đích phải tồn tại):

```powershell
godot --path . --fixed-fps 60 res://tests/new_enemy_test/capture_preview.tscn --quit-after 300 -- --output-dir 'D:/preview'
```

Thông số sức mạnh hiện tại dành cho sân test; cần cân bằng tiếp khi đặt vào map chính.

Kết quả kiểm tra tích hợp: **71/71** mục đạt; bộ test enemy hiện có `test_enemy_1.tscn` cũng báo `ENEMY1_CHECK PASSED`. Đã render model và ba VFX bằng GL Compatibility. Godot hiện báo một texture 4 KB chưa giải phóng lúc đóng renderer; cảnh enemy cũ cũng có cùng cảnh báo này, không phát sinh lỗi shader/VFX trong cảnh mới.
