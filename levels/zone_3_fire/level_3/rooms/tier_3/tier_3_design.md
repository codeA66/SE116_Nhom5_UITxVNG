# Tier 3 map Lửa — Lò Bát Quái

Cập nhật ngày 16/11/2026. Tài liệu lưu thiết kế đã thống nhất, hiện trạng triển khai và ý tưởng còn chờ làm.

## 1. Nguồn và phạm vi

- Nguồn concept của người dùng: `concept tier 3.txt` trong Downloads, cùng sơ đồ tám nhánh và sơ đồ đường tia của phòng Ly đã gửi trong hội thoại.
- Quyết định bổ sung của người dùng trong hội thoại được ghi vào các mục hiện trạng bên dưới.
- Phần phòng Ly mô tả scene và logic hiện có. Phòng 2–8 lưu lại ý tưởng từ concept; chưa có scene hay logic thử thách tương ứng.
- Các luồng dự kiến của phòng 2–8 diễn giải cơ chế trong concept, chưa phải walkthrough đã dựng và kiểm thử. Số lượng vật thể, kích thước, timing, damage và thứ tự thao tác cụ thể còn cần chốt trước khi triển khai.
- Tất cả nội dung riêng của tier 3 nằm trong `levels/zone_3_fire/level_3/rooms/tier_3/`.

## 2. Tổng thể tầng 3

### 2.1. Chủ đề và vòng chơi

Map Lửa mang chủ đề địa ngục, kiến trúc lấy cảm hứng từ Nether Fortress của Minecraft. Tier 3 dựa trên Lò Bát Quái của Thái Thượng Lão Quân, kết hợp gạch đen, đồng nung, dung nham và công trình luyện kim.

Phòng trung tâm là **Thái Cực Đỉnh — The Crucible Heart**. Tám nhánh dẫn tới tám phòng quẻ. Người chơi giải đố hoặc chiến đấu để giải từng phong ấn rồi trở về trung tâm. Concept gốc có tám sợi xích đồng khóa nắp lò; hệ xích hoạt động chưa được triển khai.

Trình tự mục tiêu đã thống nhất:

1. Gặp NPC Lò Bát Quái ở giữa phòng trung tâm, có hội thoại.
2. Hoàn thành tám thử thách để giải tám phong ấn.
3. Mở lò và chiến đấu với chính cái lò dưới dạng boss hoặc mini-boss để áp chế nó.
4. Nhận phần thưởng sau khi áp chế. Nội dung phần thưởng để sau tính.

NPC, hội thoại, trận áp chế và phần thưởng hiện đều chưa được triển khai. Đã có điểm đặt NPC và signal tiến độ để nối các hệ này về sau.

### 2.2. Phòng trung tâm đã dựng

Scene `t3_00_crucible_heart.tscn`, controller `t3_00_crucible_heart.gd`.

- Sảnh bát giác rộng khoảng 32 m, có tám cửa rộng 4 m.
- Bệ giữa rộng 8 m, cao hơn mặt sàn 0,18 m, có mép vát để đi lên.
- Điểm đặt NPC là `CentralPlatform/FurnaceAnchor`, tại `(0, 0.5, 0)` so với gốc phòng.
- Trước mỗi cửa có ký hiệu ba hào của quẻ tương ứng. Khi cờ hoàn thành được bật, ký hiệu đổi sang màu sáng và phát sáng.
- Mỗi nhánh có `ConnectionAnchor` để nối phòng. Trong hệ tọa độ của phòng trung tâm, đầu các nhánh cách tâm 20 m.
- Hiện chỉ phòng Ly được nối và chơi thử trong `crucible_heart_preview.tscn`. Các nhánh khác có rào tạm trong scene preview.
- Chưa tích hợp tier 3 vào tuyến đi hoàn chỉnh của `level_3.tscn`.

### 2.3. Hướng và số thứ tự phòng

Quy ước trong scene: Bắc = `-Z`, Nam = `+Z`, Đông = `+X`, Tây = `-X`. Bảng này mô tả vị trí cửa đã dựng; số 1–8 là số phòng trong concept, không phải thứ tự bắt buộc người chơi phải đi.

| Số phòng | Quẻ | Hướng từ trung tâm | ID phong ấn | Trạng thái |
|---|---|---|---|---|
| 1 | Ly ☲ — Hỏa | Nam | `ly` | Đã dựng và có câu đố hai phase |
| 2 | Khảm ☵ — Thủy | Bắc | `kham` | Có cửa/ký hiệu; thử thách còn ở concept |
| 3 | Tốn ☴ — Phong | Đông Nam | `ton` | Có cửa/ký hiệu; thử thách còn ở concept |
| 4 | Chấn ☳ — Lôi | Đông | `chan` | Có cửa/ký hiệu; thử thách còn ở concept |
| 5 | Cấn ☶ — Sơn | Đông Bắc | `can_son` | Có cửa/ký hiệu; thử thách còn ở concept |
| 6 | Đoài ☱ — Trạch | Tây | `doai` | Có cửa/ký hiệu; thử thách còn ở concept |
| 7 | Càn ☰ — Thiên | Tây Bắc | `can_thien` | Có cửa/ký hiệu; thử thách còn ở concept |
| 8 | Khôn ☷ — Địa | Tây Nam | `khon` | Có cửa/ký hiệu; thử thách còn ở concept |

Các cờ trung tâm có dạng `level_3.t3_seal_<id>`.

### 2.4. Camera và di chuyển

Preview dùng camera yaw 45°, pitch 50°, khoảng cách 46 m, FOV 40°. Input di chuyển được quy đổi theo camera; hướng người chơi thấy khi giữ W không đồng nhất với trục Bắc của sơ đồ.

Khi đọc walkthrough phải dùng hướng trong không gian phòng và các mốc địa hình. Đường đi, cầu, cửa và chỗ đứng tương tác cần kiểm tra bằng camera chơi thực tế; không thay hướng cửa chỉ vì W đi chéo so với trục thế giới. Camera không thay đổi quy ước hướng của tám quẻ.

## 3. Phòng 1 — Ly ☲: Xưởng Đúc Tâm Hỏa

**Tên tiếng Anh:** The Core Foundry.

**Scene:** `t3_01_li_foundry.tscn`. **Controller:** `t3_01_li_foundry.gd`.

### 3.1. Vị trí và bố cục hiện tại

- Nằm ở nhánh Nam của phòng trung tâm.
- Trong preview, gốc Ly là `(0, 0, 36)`; phòng trung tâm ở gốc `(0, 0, 0)`.
- Phòng rộng khoảng 24 × 32 m. Điểm nối phía Bắc của Ly ở tọa độ local `(0, 0.32, -16)`, trùng đầu nhánh Nam của trung tâm khi đặt như preview.
- Tiền sảnh ở phía Bắc, xưởng chính ở phía Nam. Tường ngăn có hai cửa ở `z = -8`.
- **Cửa 1 — TutorialGate:** local `(0, 0.32, -8)`, cửa vào ban đầu.
- **Cửa 2 — ShortcutGate:** local `(10, 0.32, -8)`, cửa hồi ở phía Đông.
- Hai cửa và phần tường ngăn đã được nâng cao để chặn player. Có khe tia ở phía Tây của tường ngăn cho tuyến A → B.
- Giữa phòng có rãnh dung nham; tuyến bảo trì và cầu sàn lưới giúp đi vòng tới các gương trên hai bờ và trên cầu.
- Bệ phong ấn nằm phía cuối phòng, gần local `(0, 0.32, 13.5)`.

### 3.2. Gimmick đã triển khai

Phản chiếu **Lục Đinh Thần Hỏa** bằng các gương đồng để nung bộ nhận tia. Người chơi thực hiện hai bộ câu đố liên tiếp trong cùng phòng.

- Mỗi gương có bốn nấc theo các hướng đúng/sai trong sơ đồ người dùng đã duyệt.
- Tương tác chỉ hiện **“XOAY GƯƠNG”**. A–G là tên node dùng cho biên tập và tài liệu, không xuất hiện trong gợi ý tương tác.
- `AnimationPlayer` nội suy chuyển động xoay và hình phản xạ cùng nhịp vật lý. Một lần tương tác chuyển đúng một nấc, dùng cung xoay ngắn nhất.
- Tia phản xạ theo hướng tới thực tế và pháp tuyến gương. Không nối tia giả theo tên gương hoặc danh sách đường đi định sẵn.
- **Tia không gây sát thương cho player**, theo quyết định bỏ damage vì khó né.
- Phải giữ tia liên tục trên bộ nhận trong 2 giây theo dữ liệu mặc định. Khi ngắt tia trước khi hoàn thành, nhiệt tích lũy trở về 0.
- Mesh của tất cả khối lock được ẩn trong editor và khi chơi. Vùng nhận tia vẫn hoạt động.
- Cửa khóa nhấp nháy đỏ; khi bộ nhận của cửa được chiếu, cửa có phản hồi sáng theo mức nung.
- Nguồn lửa và gương của mỗi phase nằm chung một rig có animation nâng/hạ. Va chạm và tương tác của bộ hạ xuống được tắt.

### 3.3. Mốc bố trí

Tọa độ dưới đây là gốc node so với phòng Ly khi rig đang nâng. Vị trí mặt phản xạ và điểm phát tia có offset riêng, không phải tất cả đều bằng gốc node.

| Bộ | Vật thể | Tọa độ local `(x, y, z)` | Vai trò |
|---|---|---|---|
| Phase 1 | FireEmitter | `(-9, 0.32, -12)` | Phát tia về A ở tiền sảnh |
| Phase 1 | MirrorA | `(-5, 0.32, -12)` | Chuyển tia tới cửa 1 hoặc B |
| Phase 1 | MirrorB | `(-9, 0.32, -3)` | Nhận tia qua khe tường, chuyển tới C |
| Phase 1 | MirrorC | `(5.2, 1.32, 8.2)` | Gương trên tuyến cầu, chuyển tới bệ |
| Phase 1 | TutorialLock | `(0, 1.97, -8.65)` | Bộ nhận mở cửa 1 |
| Phase 1 | FinalLock | `(0, 2.7, 13.5)` | Bộ nhận của bệ phong ấn |
| Phase 2 | FireEmitter | `(9, 0.32, 13.5)` | Nguồn thứ hai ở cuối phòng |
| Phase 2 | MirrorD | `(10, 0.32, 3)` | Chuyển tới E; có hướng sai chiếu thẳng G |
| Phase 2 | MirrorE | `(-6, 0.32, -1)` | Chuyển tới F ở bờ Tây |
| Phase 2 | MirrorF | `(-2.4, 1.32, 7)` | Gương trên cầu, chuyển tới G |
| Phase 2 | MirrorG | `(5, 0.32, -3)` | Chuyển tới bộ nhận cửa 2 |
| Phase 2 | ExitLock | `(10, 1.97, -7.35)` | Bộ nhận mở cửa hồi và hoàn thành Ly |
| Tiếp tục | PhaseTwoSpawn | `(8.8, 0.4, -4.2)` | Điểm nạp phase 2 bên trong xưởng |

### 3.4. Walkthrough cho người chơi

#### Bước 1 — Mở đường vào xưởng

1. Từ Thái Cực Đỉnh, đi theo ký hiệu Ly ở cửa Nam vào tiền sảnh.
2. Cửa 1 và cửa 2 ban đầu đều đóng. Bộ gương phase 1 đang ở trên sàn; bộ phase 2 được hạ và ẩn.
3. Đến gương gần nguồn lửa ở góc Tây Bắc tiền sảnh, tức A trong tài liệu.
4. Xoay A để đưa tia từ nguồn tới bộ nhận cửa 1.
5. Giữ tuyến này tới khi nung hoàn tất. Cửa 1 mở, cho phép vào xưởng chính.

Mục đích của cửa 1 là dạy thao tác xoay và nung bộ nhận. Người chơi kích hoạt bằng tia, không cần đánh phá cửa.

#### Bước 2 — Giải bệ phong ấn bằng bộ thứ nhất

1. Xoay lại A để dẫn tia qua khe tường tới B.
2. Đi qua cửa 1 vào xưởng. Tiến tới B ở bờ Tây và xoay để phản xạ tới C.
3. Đi theo tuyến bảo trì, lên cầu sàn lưới và tiếp cận C ở phần phía Nam.
4. Xoay C cho tia chiếu tới bộ nhận trên bệ phong ấn cuối phòng.
5. Giữ tia liên tục tới khi nung hoàn tất.

Tuyến đúng: **Nguồn 1 → A → B → C → bệ phong ấn**.

Hoàn thành bệ mới kết thúc phase 1, chưa giải ấn Ly ở trung tâm. Nếu bệ hoàn thành trong khi player còn ngoài xưởng, cửa 1 giữ mở để player vào trước khi bắt đầu đổi bộ.

#### Bước 3 — Chuyển phase

1. Khi player đã trong xưởng, cửa 1 đóng và giữ đóng.
2. Bộ A/B/C cùng nguồn lửa thứ nhất hạ xuống bằng animation.
3. Bộ D/E/F/G cùng nguồn lửa thứ hai nâng lên.
4. Cửa 2 tiếp tục đóng. Player phải giải bộ thứ hai để mở đường về.

Ra/vào mép `WorkshopArea` hoặc tiến sát cửa 1 trong phase 2 không mở lại cửa.

#### Bước 4 — Giải bộ hồi và mở cửa 2

1. Đi tới D ở bờ Đông và dẫn tia nguồn thứ hai sang E ở bờ Tây.
2. Vòng theo tuyến đi được tới E; xoay E để đưa tia lên F trên cầu.
3. Lên cầu tới F; xoay F để đưa tia về G ở bờ Đông gần tường ngăn.
4. Đi tới G; xoay G để đưa tia vào bộ nhận cửa 2.
5. Giữ tia liên tục tới khi nung hoàn tất.

Tuyến đúng: **Nguồn 2 → D → E → F → G → bộ nhận cửa 2**.

D có một hướng chiếu thẳng G nhưng đây là hướng sai. Với cùng một tư thế G, tia tới từ D phản xạ theo hướng khác tia tới từ F. Điều kiện này được thực hiện bằng phản xạ hình học thực tế.

#### Bước 5 — Hoàn thành và trở về

1. Cửa 2 mở, bật cờ hoàn thành Ly.
2. Bộ D/E/F/G và nguồn lửa thứ hai hạ xuống bằng animation như bộ thứ nhất; tia tắt, tương tác và va chạm của bộ này được vô hiệu hóa.
3. Cửa 1 tiếp tục đóng. Đi qua cửa 2 ở phía Đông, vào tiền sảnh rồi trở về trung tâm.
4. Ký hiệu Ly tại trung tâm sáng lên, tiến độ tăng thành 1/8 nếu các ấn khác chưa được giải.
5. Nạp lại tiến độ đã hoàn thành giữ cả hai bộ dưới sàn và cửa 2 mở.

### 3.5. Đáp án cho biên tập và debug

Nấc dưới đây đánh số từ 0. Chúng phụ thuộc cấu hình hướng hiện tại của scene; nếu thay vị trí gương hoặc `angle_targets` thì phải kiểm tra lại.

| Mục tiêu | Nấc đúng |
|---|---|
| Mở cửa 1 | A = 3 |
| Giải bệ phase 1 | A = 0, B = 1, C = 2 |
| Giải cửa 2 | D = 3, E = 0, F = 2, G = 1 |
| Hướng sai D → G | D = 1; G giữ nấc 1 vẫn không dẫn tới bộ nhận cửa 2 |

Giá trị ban đầu dùng `initial_steps = [1, 2, 0, 0]`; bộ thứ nhất lấy ba phần tử đầu, bộ thứ hai lấy cả bốn.

### 3.6. Tiến độ và liên kết với lò

| Cờ | Ý nghĩa |
|---|---|
| `level_3.t3_ly_tutorial` | Đã nung bộ nhận mở cửa 1 |
| `level_3.t3_ly_pedestal` | Đã hoàn thành bệ phase 1, tiếp tục ở phase 2 |
| `level_3.t3_seal_ly` | Đã giải phase 2, mở cửa 2 và giải ấn Ly |

- Controller phòng Ly phát `activated` và `seal_released(seal_id)` khi hoàn thành lượt cuối.
- Phòng trung tâm theo dõi cờ trong `GameState`, không phụ thuộc truy cập biến private của phòng Ly.
- `CrucibleHeart` cung cấp `seal_released(seal_id)`, `seals_progressed(released, total)` và `all_seals_released` để NPC/lò dùng về sau.
- Nạp tiến độ hoàn thành cập nhật ký hiệu và cửa, không phát lại sự kiện hoàn thành của phòng Ly.
- Hồ sơ chỉ có cờ hoàn thành Ly vẫn mở được cửa hồi và giữ các rig ẩn.
- Khi nạp giữa phase 2 hoặc player vừa được spawn mà còn ngoài xưởng, controller đặt player tại `PhaseTwoSpawn` để tránh bị khóa ngoài cửa 1. Player đã ở trong vùng xưởng thì giữ vị trí hiện tại.
- Đi sát cửa hoặc rời mép vùng phát hiện khi đang chơi không làm player tự dịch chuyển.

### 3.7. Các thành phần và thông số

| Thành phần | Trách nhiệm |
|---|---|
| `puzzles/rotating_mirror/` | Nấc xoay, nội suy và mặt phản xạ |
| `puzzles/fire_beam/` | Raycast, phản xạ và vẽ các đoạn tia tái sử dụng |
| `puzzles/heat_lock/` | Tích nhiệt, cờ hoàn thành và signal bộ nhận |
| `puzzles/beam_puzzle_stage/` | Một rig câu đố, animation nâng/hạ và bật/tắt các thành phần |
| `puzzles/gate_feedback/` | Nhấp nháy cửa khóa và sáng khi nung |
| `puzzles/li_puzzle_data.gd` + `.tres` | Dữ liệu dùng chung của câu đố |

Thông số mặc định trong resource: thời gian xoay gương 0,35 giây, nung 2 giây, mỗi animation nâng/hạ 0,8 giây, độ thụt rig 5 m. Đổi phase gồm hạ bộ cũ rồi nâng bộ mới.

Tia yêu cầu truy vết lại sau thay đổi góc, tái sử dụng các đoạn mesh và tắt xử lý vật lý khi không cần. Bộ nhận chỉ tích nhiệt khi đang nhận tia. Không có vùng damage cho tia.

### 3.8. Đã kiểm tra và phần chưa làm

Đã chạy walkthrough bằng input di chuyển và tương tác thực tế, đi qua hai phase rồi trở về qua cửa 2. Lượt kiểm tra gần nhất của chức năng hạ bộ cuối và nhãn tương tác có **424 kiểm tra đạt**, gồm nhãn HUD khi focus gương, raycast tới cửa hồi, chuyển động hạ thực tế, va chạm bị tắt, tiến độ trung tâm và nạp lại checkpoint.

Đã chạy lại toàn bộ 424 kiểm tra trên nhánh tier 3 tách từ `origin/main` tại commit nền `4addc1f`; kết quả vẫn đạt, không cần mang theo hai commit cập nhật boss.

Trước đó đã kiểm tra lặp lại việc tiến sát cửa 1 trong phase 2 ở scene riêng lẫn preview; cửa không phát sự kiện mở. Đã kiểm tra nhiều lần xoay A; góc đo lớn nhất mỗi lần khoảng 157,714°, không còn quay hơn một vòng.

Đã chụp hình trong Godot để kiểm tra gợi ý “XOAY GƯƠNG”, bộ gương đang hạ, bộ gương đã hạ và cửa hồi mở. Phiên chụp có cảnh báo rò rỉ texture khi thoát engine; chưa xác định nguyên nhân. Bộ kiểm tra headless nói trên không báo lỗi.

Những mục của concept Ly chưa triển khai: quái Walking Braziers, đạn lửa hình quạt, sàn phun lửa theo nhịp và báo trước 1 giây. Scene có các marker dự phòng nhưng chưa có encounter hoạt động tương ứng. Thuật ngữ dodge-roll trong concept không đồng nghĩa đã thêm một kỹ năng lộn cho player.

## 4. Phòng 2–8 — Ý tưởng lưu từ concept

Tất cả phòng bên dưới mới có cửa và ký hiệu ở trung tâm. Hướng trong mỗi mục lấy từ scene trung tâm hiện tại; vị trí cụ thể, cao độ và layout phòng thử thách chưa chốt. Các cách né, parry, kỹ năng Hàn hay tương tác môi trường được nhắc dưới đây là yêu cầu của concept, cần đối chiếu bộ kỹ năng hiện có trước khi dựng.

### 4.1. Phòng 2 — Khảm ☵: Hầm Hơi Ngưng Tụ

**The Scalding Condenser — nhánh Bắc.**

- **Không khí:** tối, ẩm và ngột ngạt; hồ làm mát dưới đáy lò bốc hơi sôi, sương trắng đục hạn chế tầm nhìn. Concept tham chiếu cảm giác vùng Quarry trong Tunic.
- **Gimmick:** đánh vào van xả nước lạnh để ngưng tụ hơi nước, lộ các bệ đá dưới mặt nước sôi. Hơi nóng có ý tưởng làm mờ màn hình và rút máu khi đứng lâu.
- **Luồng dự kiến:** quan sát khu hơi nước → tìm van → xả lạnh để thấy bệ → vượt hồ theo tuyến vừa lộ → xử lý khu van tiếp theo và chạm mục tiêu phong ấn → mở đường hồi.
- **Combat/bẫy:** hồn ma tro ẩn trong sương, hiện khi player tới gần hoặc sương tan; ống dẫn xì hơi ngang đường.
- **Còn cần chốt:** cách đọc đường khi sương dày, thời gian ngưng tụ, tính tồn tại của các bệ, lượng damage và điểm hồi khi rơi.

### 4.2. Phòng 3 — Tốn ☴: Hành Lang Bão Tro

**The Ashen Gale — nhánh Đông Nam.**

- **Không khí:** cửa Tốn gợi chỗ Tôn Ngộ Không tránh lửa; khói bụi, gió rít, ống thông gió và hành lang hẹp trên vực. Không nhấn vào lửa trực tiếp.
- **Gimmick:** mang lửa giữa các đuốc trong những nhịp gió lặng hoặc sau bình phong đá. Gió theo chu kỳ có thể thổi tắt đuốc; nếu mọi đuốc tắt, concept cho bóng tối đẩy player về đầu phòng.
- **Luồng dự kiến:** nhận lửa ở đầu tuyến → quan sát nhịp gió → nấp sau bình phong và chuyển lửa sang đuốc kế tiếp → duy trì chuỗi đuốc tới mục tiêu phong ấn → mở đường hồi.
- **Combat/bẫy:** gió đẩy player trượt ra mép vực; địch tầm xa ở đầu gió bắn tên lửa nhanh hơn nhờ gió.
- **Còn cần chốt:** cách mang lửa, điều kiện đuốc tắt, reset cả phòng hay từng đoạn và lực gió phù hợp điều khiển camera 45°.

### 4.3. Phòng 4 — Chấn ☳: Bệ Rèn Thiên Lôi

**The Thunder Anvil — nhánh Đông.**

- **Không khí:** búa máy nện khối thiên thạch, điện xanh tím và âm thanh kim loại theo nhịp.
- **Gimmick:** búa tạo sóng xung kích đồng thời cấp điện cho rãnh đồng. Đẩy khối dẫn điện vào vị trí để nối mạch mở cửa trước khi điện tắt.
- **Luồng dự kiến:** đọc nhịp búa → nhận biết rãnh đang có điện → đặt khối dẫn đúng đường mạch → canh chu kỳ búa để cấp điện → vượt cửa và xử lý mục tiêu phong ấn → mở đường hồi.
- **Combat/bẫy:** nhảy hoặc né sóng; dụ địch giáp nặng vào búa hay dòng điện để phá giáp.
- **Còn cần chốt:** quy tắc đẩy khối, trạng thái mạch có lưu giữa chu kỳ không, báo trước búa và khả năng tránh sóng với bộ kỹ năng hiện có.

### 4.4. Phòng 5 — Cấn ☶: Vách Đá Hắc Diện Thạch

**The Obsidian Bulwark — nhánh Đông Bắc.**

- **Không khí:** mê cung cao độ bằng các khối đá núi lửa đen bóng, kiến trúc phòng thủ nặng.
- **Gimmick:** tránh tầm nhìn của Con Mắt Lò quét tia nhiệt; đẩy khối đá chắn và tận dụng góc khuất để tới phá mắt. Concept gốc nêu bị soi quá 1,5 giây sẽ bị thiêu; chưa có thông số damage thực thi.
- **Luồng dự kiến:** nhận diện hướng quét → đi qua vùng khuất → bố trí khối che để tạo đường tiếp cận → áp sát phá mắt → giải mục tiêu phong ấn và mở đường hồi.
- **Combat/bẫy:** golem ngụy trang trong tường, kích hoạt khi player quay lưng hoặc qua vạch cấm.
- **Còn cần chốt:** thời gian tích lũy/reset khi bị soi, cách hiển thị vùng nguy hiểm, liên hệ giữa vật che và camera, điều kiện đánh thức golem.

### 4.5. Phòng 6 — Đoài ☱: Đầm Lầy Xỉ Kim Loại

**The Molten Mire — nhánh Tây.**

- **Không khí:** vùng trũng chứa xỉ quặng sền sệt, bọt khí lưu huỳnh vàng và pháp bảo rèn hỏng.
- **Gimmick:** xỉ làm chậm và tích tụ Thiêu Đốt. Dùng nguồn Hàn hoặc trụ làm mát để tạo lớp vỏ cứng tạm thời; lớp vỏ sẽ nứt rồi chìm.
- **Luồng dự kiến:** tìm nguồn làm mát → làm cứng một đoạn bề mặt → vượt qua trước khi vỏ vỡ → chuyển tiếp qua các vùng làm mát tới mục tiêu phong ấn → mở đường hồi.
- **Combat/bẫy:** quái dạng lỏng trồi lên, kéo chân nếu đứng một chỗ lâu.
- **Còn cần chốt:** dùng kỹ năng/vũ khí Hàn hay trụ môi trường, thời gian sống của vỏ, khả năng hồi lại đường, ngưỡng Thiêu Đốt và cơ chế kéo chân.

### 4.6. Phòng 7 — Càn ☰: Thiên Đỉnh Quang Lộ

**The Zenith Spire — nhánh Tây Bắc.**

- **Không khí:** ý tưởng nằm sát nắp lò, ánh sáng lọt qua khe thành những cột sáng giữa không gian tối. Cao độ thực của phòng chưa dựng.
- **Gimmick:** cầu chỉ hiện khi được chiếu sáng. Bật/tắt cửa chớp trên trần để đổi đường đi; concept còn có lối ẩn đọc từ một góc camera.
- **Luồng dự kiến:** quan sát khe sáng và cầu → điều chỉnh cửa chớp → xác nhận tuyến cầu đang hiện → đi tới điểm điều khiển tiếp theo → mở tuyến tới mục tiêu phong ấn → mở đường hồi.
- **Combat/bẫy:** thiên binh tha hóa bắn vũ khí ánh sáng trên hành lang hẹp không lan can; concept có yêu cầu parry hoặc né chính xác.
- **Còn cần chốt:** khả năng đổi góc camera của game, cách đọc cầu khi camera cố định, có yêu cầu parry hay không và cách tránh khóa player khi tắt cầu.

### 4.7. Phòng 8 — Khôn ☷: Hầm Mộ Tro Tàn

**The Cinder Catacombs — nhánh Tây Nam.**

- **Không khí:** ý tưởng ở đáy lò, tro cốt tích tụ, bình tro xếp thành hàng; tĩnh, u ám, tham chiếu cảm giác Death’s Door. Cao độ thực chưa dựng.
- **Gimmick:** lớp tro che công tắc áp lực, bẫy chông và lối ngầm. Dùng đòn diện rộng hoặc lướt để thổi tro, đọc mạch ngầm và tìm hầm bí mật.
- **Luồng dự kiến:** làm lộ dấu dưới tro → phân biệt công tắc và bẫy → lần theo bản đồ/mạch ngầm → mở lối xuống mục tiêu phong ấn → mở đường hồi.
- **Combat/bẫy:** đánh vỡ bình tro có thể thả bầy quái nhỏ; địch tinh anh hồi sinh từ tro nếu xác chưa được thanh tẩy bằng lửa thiêng.
- **Còn cần chốt:** hành động nào dọn được tro, tro có phủ lại không, cơ chế thanh tẩy xác và mức độ bắt buộc của lối ngầm.

## 5. Cách mở scene và tiếp tục phát triển

1. Mở `crucible_heart_preview.tscn` bằng F6 để chạy tuyến trung tâm → Ly → trung tâm. Scene này có spawn, lighting và camera riêng.
2. Có thể F6 `t3_01_li_foundry.tscn` để thử riêng phòng Ly. Khi phòng được đặt dưới `ZoneRoot`, player nhúng của phòng sẽ được bỏ và dùng player do zone tạo.
3. Tiến độ được đọc từ `GameState`; checkpoint cũ có thể làm phòng vào thẳng phase 2 hoặc trạng thái đã hoàn thành. Khi kiểm thử từ đầu cần dùng hồ sơ thử trống, không xóa hồ sơ người chơi ngoài ý muốn.
4. Khi thêm phòng 2–8, dựng vào nhánh có ký hiệu tương ứng, nối cờ `level_3.t3_seal_<id>` đã khai báo tại trung tâm. Chi tiết thử thách phải được chốt riêng trước khi code.
5. Ưu tiên tái sử dụng asset của project. Chỉ tạo model mới khi thật sự cần theo yêu cầu của người dùng.
6. Sau tám phong ấn, dùng signal trung tâm để nối trình tự hội thoại, mở lò và trận áp chế. Không coi giải đủ 8/8 là đã thắng trận lò hoặc đã nhận phần thưởng.

## 6. Phạm vi bàn giao Git

Nhánh `feature/fire-map/tier-3` được tách từ bản `main` trên remote tại thời điểm bàn giao. Phạm vi commit là thư mục `rooms/tier_3`, bao gồm trung tâm, phòng Ly, các component câu đố, preview và tài liệu này. Những thay đổi boss và các chỉnh sửa ngoài tier 3 không nằm trong commit.
