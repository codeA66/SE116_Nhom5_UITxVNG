# Polar Bear và Monkey Squad

Mở `tests/new_enemy_test/new_enemy_test.tscn`, nhấn **F6** để chạy sân thử riêng. Scene chính của game giữ nguyên. Sân có 1 Armored Polar Bear, 1 Monkey Chieftain và 3 Monkey Grunt. Player Foxy được trang bị kiếm/dash bằng các cờ preview có sẵn, không ghi mở khóa vào save.

- WASD di chuyển, J/chuột trái đánh, Space nhảy, Shift dash.
- Tab đổi camera theo player/toàn cảnh, R dựng lại trận. Không còn chữ hướng dẫn trên mặt đất hoặc panel hướng dẫn.
- Giao diện sân thử chỉ có nút **Bất tử**, bật mặc định để tập né. Tắt nút để nhận sát thương bình thường; HUD chiến đấu của player vẫn hoạt động.

## Hành vi

Quái nghỉ bằng Idle và đi bộ từng đoạn ngắn quanh vị trí spawn khi chưa thấy player. Khi mất mục tiêu hoặc vượt giới hạn đuổi, quái trở về khu spawn. Khoảng phát hiện, giới hạn đuổi và bán kính đi tuần chỉnh trong từng `*_data.tres`.

| Enemy | Khi phát hiện | Đòn đánh | Hồi chiêu |
| --- | --- | --- | --- |
| Chieftain | Vỗ ngực buff bản thân và grunt trong bán kính 8 m; báo cho squad | Nhảy tới điểm đón hướng di chuyển của player, cào hai tay lúc đáp | 1 giây sau khi kết thúc đòn |
| Grunt | Chạy áp sát | Chọn ngẫu nhiên `Lunge_Slash_01` hoặc `02`, phát nhanh 1,5 lần, giữ dao/ngón tay từ GLB | 0,5 giây sau khi kết thúc đòn |
| Polar Bear | Chọn phép theo khoảng cách | Ice khi gần và sẵn sàng, Wind khi sẵn sàng; nếu cả hai đang hồi thì áp sát dùng physical claw | Ice và Wind độc lập, mỗi chiêu 5 giây sau khi kết thúc; physical claw 3 giây |

Hai loại khỉ chạy 6 m/s khi chưa buff, bằng tốc độ chạy mặc định của player. Buff kéo dài 10 giây, hồi 30 giây từ lúc bắt đầu vỗ ngực: tốc độ di chuyển và animation tấn công tăng 12%, cooldown giảm 12%. Đầu đàn không lặp vỗ ngực trong 30 giây hồi, tiếp tục chạy/vồ bình thường. Sóng âm lan ra từ ngực lúc vỗ; aura và vòng sáng đỏ đánh dấu các con đang được buff. Mỗi đòn chốt tốc độ khi bắt đầu để hitbox/root motion vẫn khớp nếu buff hết giữa đòn; không sửa tài nguyên movement/skill dùng chung. Trong cooldown, chúng đi bộ áp sát với 28% tốc độ; xa hơn 4,5 m thì chạy, gần khoảng cách dừng thì Idle và quay nhìn player. Grunt không dùng vỗ ngực. Các clip khác vẫn nằm trong AnimationPlayer để xem hoặc dùng về sau.

Wind đặt dấu báo tại chân player lúc bắt đầu phép; vùng này giữ nguyên khi player né đi. Bán kính 2,9 m, gấp đôi bản đầu. Ice phát animation nhanh 1,4 lần, theo hướng player trong windup rồi khóa hướng; dải băng dài 7,7 m, hitbox rộng 3 m, lan hết trong khoảng 0,65 giây, đỉnh băng nằm xa hơn trước. Gió kéo dài thêm 2 giây, tổng 5,17 giây từ dấu báo; hitbox còn đến hết hiệu ứng và kéo nhẹ player bên trong với tốc độ 0,35 m/s. Băng giữ lâu hơn 2 giây trước khi vỡ (3,35 giây), tổng hiệu ứng 4,4 giây; collision giữ đến khi băng bắt đầu vỡ. Bước vào các vùng tồn tại muộn vẫn trúng đòn, mỗi hurtbox chịu một lần cho mỗi cast.

Physical claw có clip thu tay lấy đà mới: windup 0,7 giây, dài hơn bản đầu 0,5 giây; hitbox chỉ bật sau windup. Ngay khi animation cào vật lý kết thúc, gấu hiện dấu magic claw dưới chân player. Dấu theo player trong 0,5 giây đầu rồi khóa vị trí; **tổng 1,5 giây chuẩn bị không gây sát thương**, sau đó bật collision trong 0,3 giây. Bán kính hitbox claw là 2,2 m. Vệt cào dùng lại nguyên các lớp Core/Glow/Smoke/Embers/Streaks của DarkClaw gốc, render trong SubViewport trong suốt lên CanvasLayer bám vị trí chiêu. Nó giữ nguyên hình và góc từ mọi camera, luôn nổi trên 3D; viewport 512×512 chỉ render khi vệt cào đang hiện. Dấu báo vẫn nằm trên mặt đất để player né.

Cú vồ của đầu đàn dự đoán vị trí player sau 0,45 giây theo vận tốc ngang. Trong 0,85 giây windup, nó cập nhật điểm đón và quay người theo; sau đó khóa điểm đáp, nhảy tối đa 7,5 m và tới nơi đúng mốc cào 1,45 giây. Tường và quái khác vẫn chặn được cú vồ.

Mỗi lần kích hoạt chỉ gây sát thương một lần trên mỗi hurtbox. Phép chỉ đánh layer player, không đánh các quái khác. Body của mọi Enemy bật mask enemy, kể cả scene cũ đã override mask. `EnemySpacing` theo dõi hàng xóm bằng signal và giúp đi vòng nhau khi áp sát. Khi vượt leash, wildlife trở về gần bán kính spawn rồi mới nhận lại mục tiêu; tránh vòng lặp Patrol/Chase ở mép leash. Watch có khoảng đệm khi đổi Walk/Run/Idle, và các state không phát clip trung gian trong một frame trước đòn đánh.

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
| Polar Bear | 35 | Đủ 34 clip của 6 pack Rig_Large, giữ T-Pose theo namespace; thêm `BearActions/Claw_Windup` |
| Chieftain | 8 | Đi bộ gốc, run, root-motion run, Idle, ChestBeat, ChestBeat_Roar, Leap_Claw_Attack, Demo_All |
| Grunt | 7 | Đi bộ gốc, run, root-motion run, Idle, Lunge_Slash_01, Lunge_Slash_02, Demo_All |

Tên clip `_Loop` được chuẩn hóa bỏ hậu tố; các clip Idle/Walk/Run phù hợp đã bật loop. Bản GLB và BLEND nguồn vẫn nguyên bản. KayKit CC0 và credit gốc nằm tại `armored_polar_bear/rig_large/License.txt`.

Nếu thay GLB hoặc Rig_Large, import trước rồi bake lại thư viện:

```powershell
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tools/bake_new_enemy_animations.gd --quit-after 180
godot --headless --path . --script res://tools/bake_bear_claw_windup.gd --quit-after 180
```

## Kiểm tra

```powershell
godot --headless --path . --fixed-fps 60 res://tests/new_enemy_test/verify_new_enemies.tscn --quit-after 12000
```

Bài test đo thư viện/đường dẫn animation, cảm biến, patrol, Run, buff vỗ ngực 10 giây/hồi 30 giây, tầm buff, tốc độ/animation đồng bộ, random hai đòn, cooldown vừa đi vừa hồi, điểm đón/khóa hướng/đúng nhịp đáp của cú vồ, tường và crowd collision, Wind/Ice tracking, vùng sát thương mở rộng, dấu báo theo player 0,5 giây rồi khóa, delay tổng 1,5 giây, vùng tồn tại gây sát thương khi vào muộn/kéo nhẹ, overlay theo camera, ổn định ở mép leash, né đòn, phe, pool và dọn hiệu ứng khi chết. Có kiểm tra cả scene với player Foxy thật và đủ squad.

Chụp ảnh kiểm tra trên renderer thật (thư mục đích phải tồn tại):

```powershell
godot --path . --fixed-fps 60 res://tests/new_enemy_test/capture_preview.tscn --quit-after 300 -- --output-dir 'D:/preview'
```

Thông số sức mạnh hiện tại dành cho sân test; cần cân bằng tiếp khi đặt vào map chính.

Kết quả kiểm tra tích hợp: **115/115** mục đạt; hai bộ test enemy cũ ở bản tích hợp trước báo `ENEMY1_CHECK PASSED` và `ENEMY2_CHECK PASSED`. Đã render animation và ba VFX bằng GL Compatibility, kiểm tra overlay từ hai góc camera. Godot hiện báo một texture 4 KB chưa giải phóng lúc đóng renderer; cảnh enemy cũ cũng có cùng cảnh báo này, không phát sinh lỗi shader/VFX trong cảnh mới.
