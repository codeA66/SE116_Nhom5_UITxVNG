# Tier 3 map Lửa — Lò Bát Quái

Cập nhật ngày 18/11/2026. Tài liệu lưu thiết kế đã thống nhất, hiện trạng triển khai và ý tưởng còn chờ làm.

## Quyết định về nhảy — áp dụng khi thiết kế Tier 3

Người dùng xác nhận ngày 17/11/2026 rằng game hiện không dùng nhảy và dự kiến bỏ cơ chế này trong tương lai. Mọi concept, plan và walkthrough Tier 3 phải có tuyến hoàn thành bằng di chuyển trên mặt đất, cầu hoặc dốc. Các tuyến vượt bệ phải đi bộ/chạy qua được. Phòng Khảm đã dựng theo quyết định này.

## Camera và hướng di chuyển — đọc trước khi thiết kế phòng

Tier 3 sẽ được tích hợp vào Map Lửa `levels/zone_3_fire/level_3/level_3.tscn`. Concept, bố cục phòng và walkthrough dùng cấu hình `Zone3CameraView` của map này làm chuẩn.

| Thông số | Map Lửa — `level_3` |
|---|---|
| Khoảng cách tới điểm bám | 32 m |
| Góc cúi — pitch | 50° |
| Góc xoay ngang — yaw | 45° |
| FOV | 30° |

Camera nằm phía Đông Nam so với điểm bám và nhìn chéo xuống về Tây Bắc. Vì vậy, hướng lên màn hình tương ứng Tây Bắc của phòng.

Quy ước tọa độ dùng xuyên suốt sơ đồ và walkthrough là **Bắc = `-Z`, Nam = `+Z`, Đông = `+X`, Tây = `-X`**. Với góc camera này, Bắc hiện về phía trên bên phải màn hình, Đông về phía dưới bên phải, Nam về phía dưới bên trái và Tây về phía trên bên trái.

Player quy đổi input theo hướng camera, chiếu hướng tiến và hướng phải xuống mặt phẳng ngang. Bảng dưới áp dụng khi camera giữ yaw 45°, dùng các phím đang gán trong Input Map.

| Input | Hướng trên màn hình | Hướng trong phòng | Dấu tọa độ `(X, Z)` |
|---|---|---|---|
| W | Lên | Tây Bắc | `(-, -)` |
| D | Phải | Đông Bắc | `(+, -)` |
| S | Xuống | Đông Nam | `(+, +)` |
| A | Trái | Tây Nam | `(-, +)` |
| W + D | Chéo lên phải | Bắc | `(0, -)` |
| S + D | Chéo xuống phải | Đông | `(+, 0)` |
| S + A | Chéo xuống trái | Nam | `(0, +)` |
| W + A | Chéo lên trái | Tây | `(-, 0)` |

Input chéo được chuẩn hóa để giữ cùng tốc độ tối đa với input một hướng. Bảng mô tả hướng điều khiển mong muốn; vận tốc thực tế còn chịu gia tốc, va chạm và trạng thái di chuyển.

Khi lên concept, plan và walkthrough, ghi hướng theo tọa độ phòng kèm mốc địa hình, chẳng hạn “đi tới cửa Bắc có ký hiệu Khảm”. Nếu chỉ dẫn theo màn hình thì ghi rõ “trên/phải màn hình”. Bố trí tuyến đi bộ/chạy, mép bệ, cầu, van và gợi ý tương tác cần được kiểm tra với đầy đủ cấu hình camera Map Lửa ở bảng trên để bảo đảm nhìn thấy đường đi và chỗ đặt chân.

Thông tin trên được đối chiếu từ `Zone3CameraView` trong `level_3.tscn`, `camera_view_data.gd`, `Player.get_move_direction()` và Input Map. Khi đổi yaw ở scene khác, cần quy đổi lại bảng hướng theo camera đang dùng.

Preview đã dùng khoảng cách 32 m, FOV 30°, pitch 50° và yaw 45° theo cấu hình Map Lửa.

## 1. Nguồn và phạm vi

- Nguồn concept của người dùng: `concept tier 3.txt`, cùng sơ đồ tám nhánh và sơ đồ đường tia của phòng Ly đã gửi trong hội thoại.
- Quyết định bổ sung của người dùng trong hội thoại được ghi vào các mục hiện trạng bên dưới.
- Phòng Ly, Khảm và Tốn có scene và logic thử thách trong preview.
- Phần phòng 4–8 mô tả luồng dự kiến. Số lượng vật thể, kích thước, timing, damage và thứ tự thao tác cụ thể còn cần chốt trước khi triển khai.
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

Quyết định về hồi sinh ngày 17/11/2026 quy định Thái Cực Đỉnh có hai mốc checkpoint. Mốc đầu khi player từ Tier 2 qua Tier 3. Mốc thứ hai sau khi giải đủ tám phòng và chuẩn bị tương tác với Lò. Mỗi phòng tự quản lý thất bại cục bộ theo độ phức tạp. Với Khảm, thất bại ở phase 1 reset phòng về cửa vào; thất bại ở phase 2 đưa player về bệ seal và chỉ reset phase 2. Cả hai giữ nguyên máu. Bệ seal là mốc hồi sinh cục bộ trong phiên chơi, không ghi thêm checkpoint toàn khu. Tiến độ các ấn trong phiên chơi được giữ qua reset cục bộ. Chết thật vẫn khôi phục bản chốt ở checkpoint gần nhất theo luồng hiện tại. Hai mốc checkpoint này còn chờ nối khi tích hợp Tier 3 vào tuyến chính của Map Lửa.

### 2.2. Phòng trung tâm đã dựng

Scene `t3_00_crucible_heart.tscn`, controller `t3_00_crucible_heart.gd`.

- Sảnh bát giác rộng khoảng 32 m, có tám cửa rộng 4 m.
- Bệ giữa rộng 8 m, cao hơn mặt sàn 0,18 m, có mép vát để đi lên.
- Điểm đặt NPC là `CentralPlatform/FurnaceAnchor`, tại `(0, 0.5, 0)` so với gốc phòng.
- Trước mỗi cửa có ký hiệu ba hào của quẻ tương ứng. Khi cờ hoàn thành được bật, ký hiệu đổi sang màu sáng và phát sáng.
- Mỗi nhánh có `ConnectionAnchor` để nối phòng. Trong hệ tọa độ của phòng trung tâm, đầu các nhánh cách tâm 20 m.
- Preview nối Ly ở Nam, Khảm ở Bắc và Tốn ở Đông Nam. Năm nhánh còn lại có rào tạm.
- Chưa tích hợp tier 3 vào tuyến đi hoàn chỉnh của `level_3.tscn`.

### 2.3. Hướng và số thứ tự phòng

Quy ước trong scene: Bắc = `-Z`, Nam = `+Z`, Đông = `+X`, Tây = `-X`. Bảng này mô tả vị trí cửa đã dựng; số 1–8 là số phòng trong concept, không phải thứ tự bắt buộc người chơi phải đi.

| Số phòng | Quẻ | Hướng từ trung tâm | ID phong ấn | Trạng thái |
|---|---|---|---|---|
| 1 | Ly ☲ — Hỏa | Nam | `ly` | Đã dựng và có câu đố hai phase |
| 2 | Khảm ☵ — Thủy | Bắc | `kham` | Có van, làm nguội, sàn sập và reset cục bộ |
| 3 | Tốn ☴ — Phong | Đông Nam | `ton` | Có tuyến mang lửa qua ba cụm gió trong preview |
| 4 | Chấn ☳ — Lôi | Đông | `chan` | Có cửa/ký hiệu; thử thách còn ở concept |
| 5 | Cấn ☶ — Sơn | Đông Bắc | `can_son` | Có cửa/ký hiệu; thử thách còn ở concept |
| 6 | Đoài ☱ — Trạch | Tây | `doai` | Có cửa/ký hiệu; thử thách còn ở concept |
| 7 | Càn ☰ — Thiên | Tây Bắc | `can_thien` | Có cửa/ký hiệu; thử thách còn ở concept |
| 8 | Khôn ☷ — Địa | Tây Nam | `khon` | Có cửa/ký hiệu; thử thách còn ở concept |

Các cờ trung tâm có dạng `level_3.t3_seal_<id>`.

### 2.4. Camera và di chuyển

Thông số camera, bảng quy đổi input và quy ước viết walkthrough được đặt ở mục **Camera và hướng di chuyển — đọc trước khi thiết kế phòng** ngay đầu tài liệu.

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

## 4. Phòng 2 — Khảm ☵: Hầm Hơi Ngưng Tụ

**Tên tiếng Anh:** The Scalding Condenser.

**Scene:** `t3_02_kham_condenser.tscn`. **Controller:** `t3_02_kham_condenser.gd`.

### 4.1. Vị trí và bố cục hiện tại

- Nằm ở nhánh Bắc của Thái Cực Đỉnh. Trong preview, gốc Khảm là `(0, 0, -37)`; cửa Nam local `(0, 0.32, 17)` trùng đầu nhánh Bắc của trung tâm.
- Hồ dung nham bao quanh các bệ gạch đá và đường magma. Dùng model Map Lửa; mặt đường chơi chính ở cao độ local `y = 0.32`.
- Phase 1 gồm bệ A ở cửa vào, bệ B giữa phòng, bệ C ở Tây, cầu vòng cố định C → B và bệ seal ở Bắc.
- Chạm seal sẽ hạ/ẩn bố cục phase 1, giữ bệ seal và đưa vào bố cục quay về. Không có đường hồi riêng chạy dọc mép Đông như bản layout cũ.
- Phase 2 gồm hành lang đá từ seal tới D, tuyến đúng D → E → G → bệ cuối/cửa Nam và nhánh bẫy D → F. Cầu magma F → bệ cuối vẫn nối liền, phần sàn bẫy trắng cũ đã bỏ.
- Sáu đá magma phun hơi nằm ngoài mép đường: hai ở phase 1, bốn ở phase 2. Đá phun không có collider để đứng lên hoặc dùng làm đường tắt; đã thay các hộp xả vàng và vỉ xanh.
- Bệ A/B/C/D/E/G, bệ seal, cầu vòng và bệ cuối đứng được lâu. Bệ F chỉ sập khi đánh van F. Các đoạn đường magma nguội chia thành ô sập độc lập.
- Lan can đá ở mép Nam seal/cầu Tây chỉ bật trong phase 2 để chặn roll từ seal thẳng sang E; đường Tây tới D vẫn mở. Không đổi khoảng cách roll hoặc vị trí E/G; cú roll khó từ góc E sang G được giữ lại.

### 4.2. Gimmick đã triển khai

Đánh van để làm nguội đường magma, vượt các ô sắp sập và canh nhịp hơi nóng. Hai phase phải hoàn thành trong một lượt phòng; thất bại ở lượt về chỉ làm lại phase 2.

- **Nhiệt mặt đường:** HOT có gân magma sáng mạnh và gây reset; COLD màu xám, đi được. Trong WARNING, đá đỏ dần và gân sáng dần trong 2 giây trước khi nóng hẳn; giai đoạn này vẫn đi được. Đánh lại van làm nguội và phục hồi các ô đã sập trên nhánh được cấp lạnh.
- **Sàn sập:** đặt chân lên ô nguội là bắt đầu rung, sau **0,5 giây** mất va chạm và rơi xuống rồi ẩn. Ô chưa chạm còn nguyên; ô đã rơi không tự hồi trong cùng lượt. Không còn vòng tròn vàng dưới chân.
- **Hơi nóng:** nghỉ → hơi mỏng báo trước → luồng hơi lan ra → phun đầy mới gây hại. Luồng lan trong một tuổi hạt, mặc định **0,8 giây**, chưa gây reset. Sau khi đầy, nguy hiểm kéo dài **1,5 giây**. Dừng vent hoặc đổi phase hủy cả thời điểm gây hại đang chờ.
- **Dodge roll:** i-frames né được hơi nóng, kể cả lúc luồng vừa chuyển sang gây hại. Nếu hết bất tử mà vẫn ở trong hơi đang phun đầy thì reset; rời vùng hoặc hết nhịp phun sẽ hủy kiểm tra chờ. Quy tắc này không miễn nhiễm magma nóng hay cứu khi rơi mất sàn.
- **Van F:** một đòn hợp lệ làm bệ mất va chạm ngay; cả sàn và van chìm 5 m trong 0,65 giây. Bẫy không có nhịp báo nứt 0,5 giây như ô đường. Player thực sự rơi xuống dung nham rồi mới reset về seal.
- **Thất bại cục bộ:** nhận một đòn hợp lệ, chạm đường nóng, trúng hơi hoặc rơi xuống dung nham đều giữ nguyên máu, kể cả khi còn 1 máu. Phase 1 tạo lại phòng và đưa về cửa; phase 2 chỉ tạo lại stage quay về và đưa về seal.
- **Di chuyển:** đi bộ/chạy và roll; không cần nhảy. Phòng không còn quái truy đuổi, NavigationAgent hoạt động, bùn, tích nhiệt hoặc quái kéo chân.

### 4.3. Mốc bố trí

Tọa độ dưới đây là local so với gốc phòng Khảm. Các van và mốc hồi sinh nằm trên mặt sàn; gốc collider bệ có cao độ riêng.

| Bộ | Vật thể/mốc | Tọa độ local `(x, y, z)` | Vai trò |
|---|---|---|---|
| Cửa vào | SouthConnection | `(0, 0.32, 17)` | Nối nhánh Bắc trung tâm |
| Hồi sinh phase 1 | Start | `(0, 0.32, 15)` | Điểm làm lại từ đầu phòng |
| Phase 1 | Van A | `(-2, 0.32, 13)` | Làm nguội A → B |
| Phase 1 | Van B | `(-0.6, 0.32, 0.7)` | Đổi cấp lạnh Tây/Bắc |
| Phase 1 | Van C | `(-16.8, 0.32, 0.6)` | Xả áp, tắt hơi Bắc, nâng cầu vòng |
| Hồi sinh phase 2 | Seal | `(3.5, 0.32, -18.7)` | Giữ lại khi làm lại lượt về |
| Phase 2 | Van D | `(-14.6, 0.32, -4.3)` | Cấp lạnh D → E và D → F |
| Phase 2 | Van E | `(1.4, 0.32, -10.5)` | Cấp lạnh E → G |
| Phase 2 | Van F | `(-14.6, 0.32, 6.5)` | Nhánh bẫy; đánh van làm chìm bệ |
| Phase 2 | Van G | `(12, 0.32, -2.5)` | Cấp lạnh đường về bệ cuối |
| Phase 2 | Bệ cuối — gốc collider | `(1, 0.08, 14.7)` | Vùng đi tới cửa Nam |
| Phase 2 | SealRail — gốc collider | `(-1.2, 1.02, -16.4)` | Lan can 18,4 × 1,4 × 0,5 m chặn roll sang E |

### 4.4. Walkthrough cho người chơi

#### Bước 1 — Vào hầm và mở đường tới B

1. Từ trung tâm, qua cửa Bắc có ký hiệu Khảm tới bệ A.
2. Đánh van A để làm nguội đường tới bệ B; lần đầu đồng thời khởi động hơi Tây theo chu kỳ và hơi Bắc liên tục.
3. Chạy qua các ô A → B, không đứng chờ trên ô đang rung. Có thể đứng trên bệ B để quan sát.

#### Bước 2 — Xả áp ở C

1. Đánh B lần đầu để cấp lạnh sang Tây; đường Bắc vẫn nóng.
2. Canh nhịp hoặc roll qua hơi Tây, vượt các ô B → C trước khi sập.
3. Đánh C để tắt hơi Bắc và nâng cầu vòng cố định.
4. Qua cầu vòng từ C trở về mép Bắc bệ B. Cầu này không sập theo bước chân.

#### Bước 3 — Tới seal và đổi phase

1. Đánh B lần nữa để chuyển lạnh sang Bắc; nhánh Tây nóng lại.
2. Đi theo đường Bắc, rẽ tới bệ seal trước khi hết thời gian lạnh/cảnh báo.
3. Khi C đã xả áp, B đang chọn Bắc và đường Bắc chưa HOT, chạm seal sẽ bắt đầu phase 2.
4. Sàn cũ tắt va chạm, hạ 4 m trong 0,8 giây rồi ẩn. Bệ seal còn nguyên; bố cục D/E/F/G xuất hiện.

Chạm seal chỉ hoàn thành lượt đi, chưa giải ấn Khảm ở trung tâm.

#### Bước 4 — Giải tuyến quay về

1. Từ seal đi Tây qua cầu đá và xuống hành lang cố định tới D.
2. Đánh D để mở cả nhánh E và nhánh F. Chọn Đông rồi Bắc qua hơi, rẽ Đông tới bệ E.
3. Đánh E, đi Nam rồi Đông tới G. Bệ E và G đứng được để quan sát nhịp.
4. Đánh G để làm nguội đường về và khởi động hai miệng phun. Canh nhịp trên bệ G hoặc dùng roll né hơi; không dừng lâu trên các ô magma nguội.
5. Đi Nam, rẽ Tây qua miệng phun thứ nhất rồi xuống Nam qua miệng thứ hai tới bệ cuối.

Tuyến đúng: **seal → D → E → G → bệ cuối/cửa Nam**.

Nhánh F là hướng sai: từ D đi Nam tới F vẫn đứng được, nhưng đánh van F sẽ làm cả bệ sập ngay. Nếu rơi, player trở lại seal với phase 1 đã giải và bệ/van F được phục hồi cho lượt thử lại.

#### Bước 5 — Hoàn thành và trở về

1. Qua vùng hoàn thành ở bệ cuối/cửa Nam để giải ấn Khảm.
2. Các tuyến phase 2 được làm nguội, phục hồi và giữ ổn định; hơi dừng, van và bẫy được vô hiệu hóa.
3. Đi tiếp về trung tâm; ký hiệu Khảm sáng và tiến độ tăng thêm một ấn.
4. Nạp lại tiến độ đã hoàn thành đưa phòng thẳng vào bố cục quay về an toàn, không phát lại sự kiện giải ấn.

### 4.5. Đáp án cho biên tập và debug

| Thao tác/mục tiêu | Kết quả |
|---|---|
| Đánh A | Làm nguội A → B trong 6 giây; lần đầu bật hơi Tây/Bắc |
| Đánh B lần lẻ từ đầu lượt | Chọn Tây, làm nguội B → C trong 8 giây; Bắc HOT |
| Đánh C | Xả áp một lần, tắt hơi Bắc và nâng cầu vòng C → B |
| Đánh B lần chẵn | Chọn Bắc, làm nguội đường seal trong 8 giây; Tây HOT |
| Chạm seal | Chỉ đổi phase nếu C đã xả áp, B chọn Bắc và đường Bắc không HOT |
| Đánh D | Làm nguội/phục hồi D → E và D → F trong 9 giây; bật chu kỳ hơi D → E |
| Đánh E | Làm nguội/phục hồi E → G trong 9 giây |
| Đánh F — hướng sai | Làm nguội cầu F → bệ cuối trong 9 giây và bật hơi trên cầu, đồng thời làm sập bệ F ngay |
| Đánh G | Làm nguội/phục hồi đường về trong 10 giây; bật hai miệng phun trên tuyến |
| Tới vùng cuối phase 2 | Ghi cờ hoàn thành Khảm, dừng các thử thách |

Thời gian lạnh ở bảng là tổng thời gian đi được, bao gồm 2 giây WARNING đỏ dần cuối kỳ. Đánh lại van phục hồi nhánh tương ứng và bắt đầu lại thời gian lạnh; nhánh đang không được B chọn sẽ HOT ngay.

Trong lượt walkthrough đã đo, tuyến D → E đi trực tiếp được; sau đòn đánh G, chờ khoảng 3 giây trên bệ rồi xuất phát qua tuyến về đã hoàn thành cả hai phase không reset. Đây là nhịp thử theo cấu hình hiện tại, không phải điều kiện bắt buộc; dodge roll cũng né được hơi trong khoảng bất tử.

### 4.6. Tiến độ và liên kết với lò

| Cờ/mốc | Ý nghĩa |
|---|---|
| `level_3.t3_seal_kham` | Đã về tới vùng cuối phase 2 và giải ấn Khảm |
| Seal trong lượt chơi | Mốc hồi sinh cục bộ phase 2, không ghi thêm checkpoint hoặc cờ lưu phase riêng |

- Controller phát `phase_two_started` khi bố cục quay về được bật; `activated` và `seal_released(seal_id)` khi hoàn thành.
- Trung tâm theo dõi cờ `GameState` để cập nhật ký hiệu và tiến độ tám ấn. Nạp lại phòng đã hoàn thành không phát lại sự kiện giải ấn.
- Reset cục bộ giữ máu và tiến độ các ấn khác trong phiên. Phase 1 làm lại cả phòng; phase 2 giữ controller/bệ seal và chỉ thay `ReturnStage`.
- Hurtbox cho phép phòng chặn một đòn hợp lệ trước khi trừ máu, tránh chết/reload toàn scene khi chỉ còn 1 máu. Khi ra khỏi phòng hoặc phòng bị gỡ, bộ chặn được tháo.
- Đây không phải cơ chế hồi đầy máu khi vào phòng. Hai checkpoint toàn Tier 3 vẫn là quyết định ở mục 2.1, chờ tích hợp vào tuyến chính; mốc seal không thay thế chúng.

### 4.7. Các thành phần và thông số

| Thành phần | Trách nhiệm |
|---|---|
| `t3_02_kham_condenser.gd` | Van A/B/C, cầu vòng, đổi phase, reset cục bộ và cờ hoàn thành |
| `puzzles/strike_valve/` | Nhận đòn player, xoay van, phát signal và ngăn nhiều lần kích trong một đòn |
| `puzzles/cooling_path/` | Nhiệt HOT/COLD/WARNING/SAFE, đỏ dần, thời gian lạnh và vùng gây reset |
| `puzzles/kham_sinking_route/` | Chia collider thành ô, tái sử dụng FSM Solid/Cracking/Fallen của `CrumblingFloor` |
| `puzzles/steam_vent/` | Chu kỳ hơi, đồng bộ lúc phun đầy, né bằng i-frames và tiếp xúc với player |
| `assets/vfx/fire/hot_steam/` | Đá magma, shader hơi và hai emitter tạo sẵn dùng chung cả hai phase |
| `puzzles/kham_return_stage/` | Bố cục D/E/F/G, đường về và dữ liệu phase 2 |
| `puzzles/valve_sink_trap/` | Nghe signal van, tắt va chạm và làm chìm bệ/van F |
| `components/combat/hurtbox/hurtbox_component.gd` | Bộ chặn đòn hợp lệ trước khi trừ máu cho reset cục bộ |

| Dữ liệu | Thông số hiện tại |
|---|---|
| `puzzles/kham_puzzle_data.tres` | A → B lạnh 6 giây, Tây/Bắc 8 giây; WARNING 2 giây; xoay van 0,35 giây; nâng cầu 0,8 giây; hạ phase 1 sâu 4 m trong 0,8 giây |
| `puzzles/kham_return_stage/kham_return_data.tres` | D/E/F lạnh 9 giây, G 10 giây |
| `puzzles/kham_sinking_route/kham_sink_data.tres` | Ô mục tiêu 1,8 × 1,8 m, tối đa 128 ô/collider nguồn; rung 0,035 m, sập sau 0,5 giây; không tự hồi |
| `puzzles/valve_sink_trap/valve_sink_trap_data.tres` | Bệ F mất va chạm ngay, chìm 5 m trong 0,65 giây |
| `assets/vfx/fire/hot_steam/hot_steam_data.tres` | Luồng 40 hạt, báo trước 8 hạt, tuổi hạt/nhịp lan 0,8 giây; kích thước mây và đá chỉnh qua Resource |

| Nhịp hơi theo chu kỳ | Nghỉ | Báo trước | Lan luồng, an toàn | Phun đầy, nguy hiểm |
|---|---|---|---|---|
| Phase 1 — Tây | 1 giây | 0,8 giây | 0,8 giây | 1,5 giây |
| Phase 2 — D → E, F → cuối, hai miệng tuyến G | 1,5 giây | 0,8 giây | 0,8 giây | 1,5 giây |

Miệng Bắc phase 1 bắt đầu lan luồng ngay khi A khởi động rồi phun liên tục, cho tới khi C tắt. Nhịp lan lấy theo tuổi hạt VFX; đổi tuổi hạt cũng đổi thời điểm bắt đầu gây hại.

Các ô trên cùng tuyến dùng chung material; đỏ dần chạy bằng một tween cho cả tuyến. Ô lành và ô rơi đã ẩn không cập nhật vật lý. Vent chỉ theo dõi hết i-frames khi có player đang bất tử trong luồng; không quét danh sách va chạm mỗi frame. Hạt và node VFX được tạo sẵn, dùng lại theo từng nhịp.

### 4.8. Đã kiểm tra và phần chưa làm

Các lượt kiểm tra đã chạy bằng input, tiếp xúc và va chạm thật; số dưới đây là từng bộ kiểm tra, không cộng các lượt chạy lại thành tổng mới:

- **Dodge roll né hơi:** 12 kiểm tra đạt cả headless và cửa sổ game OpenGL, gồm roll xuyên hơi, hết bất tử trong luồng, hơi bật giữa cú roll, vào hơi khi không roll và hủy xử lý chờ khi dừng vent.
- **Đỏ dần/sập 0,5 giây:** 11 kiểm tra đạt trong cửa sổ game, đo rung, mất va chạm, chuyển động rơi, hủy chuyển màu bằng van và giữ 1 máu khi reset.
- **Walkthrough theo nhịp mới:** 10 kiểm tra đạt cho cả hai phase với sàn 0,5 giây, đi trực tiếp D → E và chờ khoảng 3 giây sau đòn G trước khi qua tuyến về; không nhảy, rơi hoặc reset. Chạy thẳng không chờ đã trúng hơi cuối tuyến.
- **Dữ liệu/sàn/reset:** 23 kiểm tra đạt về collider, ô đã chạm/ô chưa chạm, phục hồi bằng van, reset theo phase, dữ liệu rỗng và nạp lại tiến độ hoàn thành. Bộ này đã chạy sau khi đồng bộ hơi; các lượt đo timing 0,5 giây nằm ở bộ riêng phía trên.
- **Cấu hình lệch/cực đoan:** trước các lượt chỉnh timing cuối đã thử sàn nhỏ/không vuông/rất lớn, kích thước ô bằng không/âm, giới hạn ô, thời gian nứt 0,05–5 giây; đá phun nhỏ/lớn/không vuông, số hạt và tuổi hạt 0,1–3 giây; bẫy F chìm 0,5–20 m trong 0,05–3 giây.
- **Bệ F và lan can seal:** đã thử đánh kiếm thật làm chìm bệ/van F, reset riêng phase 2 và phục hồi F; đã đo chặn roll từ nhiều mép seal/cầu Tây với 9/12 m/s, giữ được cú roll khó E → G. Các bộ này thuộc lượt trước khi chỉnh hơi/sàn cuối, không phải xác nhận toàn bộ timing cũ còn nguyên.
- **Hình ảnh:** đã chụp/kiểm tra hơi mỏng, luồng hơi đầy, đá đỏ dần và lan can trong camera chơi thực tế.

Lỗi `Assertion failed: Khảm cần KhamPuzzleData` trước đây do preview ghi đè `data = null` và `phase_one_platforms = []`; đã bỏ ghi đè và có cấu hình/mốc dự phòng khi export bị xóa. Các lượt mới không còn assertion này. Lỗi deferred `GDScript::ensure` và cảnh báo texture khi thoát OpenGL có sẵn vẫn xuất hiện, chưa xử lý trong phạm vi Khảm.

Khảm hiện nối và chơi thử qua preview; chưa tích hợp vào tuyến hoàn chỉnh `level_3.tscn`. NPC, hai checkpoint toàn tầng, trận áp chế Lò và phần thưởng vẫn chưa được triển khai. Concept cũ về quái truy đuổi/bùn/tích nhiệt/kéo chân đã bỏ, không phải hạng mục chờ làm của phòng. Concept Đoài giữ hướng trụ nam châm/phế kim ở mục phòng Đoài bên dưới.

## 5. Phòng 3 — Tốn ☴: Hành Lang Bão Tro

**Tên tiếng Anh:** The Ashen Gale.

**Scene:** `t3_03_ton_ashen_gale.tscn`. **Controller:** `t3_03_ton_ashen_gale.gd`.

### 5.1. Vị trí và bố cục hiện tại

- Phòng nối với cửa Đông Nam của Thái Cực Đỉnh trong `crucible_heart_preview.tscn`. Trong preview hiện tại, gốc phòng ở `(25.455844, 0, 25.455844)` và quay 45° quanh trục Y so với sảnh trung tâm.
- Từ tiền sảnh, tuyến chính đi theo local +Z qua cụm gió 1, rẽ +X qua cụm 2 rồi tiếp tục +Z qua cụm 3. Cả tuyến đi bộ hoặc chạy được.
- Ở chiếu nghỉ sau cụm 1, nhánh đi thẳng theo +Z dẫn tới đuốc bẫy ở cuối đường cụt. Tuyến chính rẽ sang cầu ngang.
- Sau cụm 3, cầu dài bên phải có cụm gió 4, hai bình phong và hốc trú sau tường. Đuốc trong hốc là điều kiện bắt buộc của bệ. Đường lên bệ dốc về cầu ngang trên cao, có mép xuống một chiều về tiền sảnh.
- Phòng dùng khoảng tối để làm nổi bật tàn đỏ của đuốc, ánh sáng của đuốc đã thắp và hướng gió. Thử thách hiện dùng gió và vực. Máy bắn tên đã được gỡ khỏi phòng.

### 5.2. Gimmick đã triển khai

- Bấm **truyền lửa** tại nguồn để mở cửa vào tuyến. Lửa bay theo player, không tự hao và vẫn được giữ khi châm đuốc dọc đường. Đuốc đã thắp chỉ chiếu sáng và giữ sáng tới hết lượt.
- Bốn cụm gió dùng một chu kỳ. Mũi tên sát sàn hiện ở cuối thời gian lặng để báo hướng. Vệt tro dài và sáng xuất hiện khi gió thổi.
- Bình phong tự qua lại ngang với từng luồng. Khi player đứng sau phần chắn, bình phong chặn lực đẩy và phơi gió. Khi đứng trong gió, độ phơi tăng dần, lửa lập lòe rồi tắt khi chạm ngưỡng. Khi được che hoặc rời gió, độ phơi giảm dần.
- Đòn không có lửa cộng độ phơi ngay cả khi trú. Đòn vũ khí ép lửa và kỹ năng lửa trong danh sách cấu hình không cộng phơi. Roll đang thực hiện dập lửa ngay.
- Hết lửa hoặc rơi vực đưa player về đầu phòng với đầy máu. Đuốc, nhịp gió và vị trí bình phong về trạng thái đầu lượt.

### 5.3. Mốc bố trí

Tọa độ dưới đây là local của scene phòng. Hướng gió cũng tính theo trục local của phòng, trước khi xoay scene vào preview.

| Node hoặc vị trí | Tọa độ local `(x, y, z)` | Vai trò |
|---|---|---|
| `Restart` | `(0, 0.39, 2.65)` | Vị trí hồi sinh đầu phòng |
| `Source` | `(-1, 0.32, 4.6)` | Nhận lửa mang theo và mở cửa vào tuyến |
| `EntryGate` | `(0, 1.65, 9.65)` | Khóa tuyến thử thách trước khi nhận lửa |
| `First` | `(0, 1.24, 16.85)` | Cụm 1, thổi theo +X |
| `Bend` | `(9, 1.24, 25.25)` | Cụm 2, thổi theo −Z |
| `Final` | `(17, 1.24, 38.5)` | Cụm 3, thổi theo −X |
| `FalseTrailTorch` | `(-0.12, 0.32, 51.35)` | Đuốc bẫy ở cuối nhánh cụt |
| `CornerTorch` | `(25.45, 0.32, 50.55)` | Đuốc X cam soi đoạn cầu dọc ở góc dưới |
| `Return` | `(25.45, 1.24, 27.4)` | Cụm 4, thổi theo +X. Hai bình phong xuất phát lệch 1,45 giây |
| `Seal` | `(8.15, 2.45, 5)` | Bệ giải ấn trên lối hồi có ký hiệu Tốn tự phát sáng |
| `ReturnTorch` | `(27, 0.32, 26.2)` | Đuốc bắt buộc sau tường che trên cầu dọc |

### 5.4. Walkthrough cho người chơi

#### Bước 1 — Nhận lửa

Từ cửa Đông Nam, tới đuốc nguồn đã cháy và bấm **truyền lửa**. Châm thêm đuốc tiền sảnh nếu cần nhìn rõ mép cầu.

#### Bước 2 — Vượt cụm đầu và đọc chỗ rẽ

Nhìn mũi tên báo hướng, nương theo phía khuất của bình phong và tiến khi gió lặng. Sau cụm đầu, rẽ qua cầu ngang. Nếu thắp đuốc cuối nhánh cụt, cả mảng sàn dưới đuốc rung trong 2,7 giây rồi sập. Chạy ngược về phần sàn cố định trước khi hết thời gian. Rơi khỏi mảng sàn này đặt lại phòng.

#### Bước 3 — Qua hai cụm còn lại

Ở cụm 2, quan sát lại hướng gió để chọn đúng phía bình phong. Tạm dừng tại khoảng sàn an toàn nếu lửa đang lập lòe. Canh nhịp vượt cụm 3, sau đó rẽ qua cầu dài bên phải vào cụm 4. Nương theo hai bình phong. Ở giữa cầu, đi vòng vào phía khuất của tường và thắp đuốc bắt buộc. Tiếp tục tới dốc dẫn lên cầu ngang.

#### Bước 4 — Giải ấn và trở về

Giữ lửa tới bệ trên cầu ngang, bấm **truyền lửa**, rồi đi tới mép lối hồi và bước xuống tiền sảnh để về Thái Cực Đỉnh.

### 5.5. Đáp án cho biên tập và debug

| Kiểm tra | Kết quả mong đợi |
|---|---|
| Mang lửa và thắp đuốc đường cụt | Cả mảng sàn rung rồi sập. Nếu kịp chạy thoát, player giữ lửa |
| Đi vào cầu ngang từ tiền sảnh trước khi giải | Chênh cao chặn chiều đi ngược tới bệ |
| Vòng đủ tuyến và thắp bệ | Nếu đuốc bắt buộc đã thắp, bệ sáng và gió dừng |
| Làm tắt lửa trước khi giải | Player hồi đầy máu ở đầu phòng và phải nhận lửa lại |

### 5.6. Tiến độ và liên kết với lò

- Phòng ghi cờ `level_3.t3_seal_ton` vào `GameState` khi bệ được thắp, sau đó phát `activated` và `seal_released(&"ton")`.
- Trung tâm đọc cờ để cập nhật ký hiệu và tiến độ tám ấn. Nạp lại cờ đã hoàn thành sẽ mở cửa vào tuyến, bật sáng đuốc và giữ gió ở trạng thái tắt.
- Reset thử thách trước khi hoàn thành chỉ đặt lại các thành phần trong phòng Tốn và trạng thái player. Thao tác này không ghi thêm checkpoint.

### 5.7. Các thành phần và thông số

| Thành phần hoặc dữ liệu | Trách nhiệm và thông số mặc định |
|---|---|
| `t3_03_ton_ashen_gale.gd` | Một nhịp gió dùng chung, trạng thái cổng, reset lượt và tiến độ |
| `puzzles/ton_puzzle_data.tres` | Lặng 1,8 giây, báo trước trong 0,45 giây cuối, thổi 4,2 giây |
| `puzzles/ton_carried_flame/` | Lửa bay theo, lập lòe và tắt. Ngưỡng phơi 1,6, bắt đầu báo ở 45%, hồi 0,65 mỗi giây, đòn không lửa cộng 0,55 |
| `puzzles/ton_flame_station/` | Nguồn, đuốc và bệ dùng chung tương tác. Đèn khi thắp có năng lượng 6,5 và tầm 15 m. Tàn đuốc tự phát sáng. Lửa đi theo chiếu tới 9 m |
| `puzzles/ton_wind_screen/` | Vùng gió, bình phong, mũi tên và vệt tro. Cụm 1/2/3 có hành trình 8/8/11 m và tốc độ bình phong 2,6/2,2/2,7 m/s. Cụm 4 dài 37,2 m, bình phong chạy 3,6 m/s |
| `entities/player/player.gd` | Phát tín hiệu `combat_action_committed` để phòng tính phơi cho đòn đã thực sự tung |

### 5.8. Đã kiểm tra và phần chưa làm

Các đuốc được đánh dấu dùng nhóm đèn cục bộ bố trí theo hình dạng của tuyến. Đuốc ngã rẽ đầu soi hai nhánh tạo thành chữ L. Đuốc cụm 2, đuốc sau tường và đuốc X cam soi các dải dọc. Hai góc quay vào cầu bên phải đã được bổ sung mặt sàn. Bẫy `puzzles/ton_torch_trap.gd` làm rơi cả mảng 5,7 × 12,8 m và hoàn nguyên cùng lượt thử.

Đã kiểm tra chạy bộ thoát bẫy, đứng lại để rơi và reset, đi qua hai phần sàn lấp góc, và việc nhóm đèn chỉ bật khi thắp đúng đuốc. Đã xem cả bốn vùng sáng qua camera game.

Lượt trước đã kiểm thử ba cụm đầu và nhánh cụt trên Godot 4.7.2, đồng thời xem ánh đuốc, mũi tên và vệt tro qua camera. Mục tiêu 2–3 phút vẫn cần đo qua lượt chơi với người mới.

Lượt cập nhật cầu dọc đã kiểm tra bằng input di chuyển cả hai nửa của cụm 4, lối vòng qua tường tới đuốc và dốc lên bệ. Đã xác nhận không thể đi ngược từ tiền sảnh lên lối hồi, bệ chỉ nhận lửa sau khi đuốc bắt buộc sáng, player bước xuống được và ánh sáng phục hồi khi ra khỏi vùng tối. Đã xem tàn đuốc trước và sau khi thắp cùng ký hiệu Tốn bằng camera game.

## 6. Phòng 4–8 — Thiết kế và hiện trạng

Cả năm phòng đã có cửa và ký hiệu ở trung tâm. Thử thách còn ở giai đoạn concept.

### 6.1. Phòng 4 — Chấn ☳: Bệ Rèn Thiên Lôi

**The Thunder Anvil — nhánh Đông.**

- **Không khí:** búa máy nện khối thiên thạch, điện xanh tím và âm thanh kim loại theo nhịp.
- **Gimmick:** búa tạo sóng xung kích đồng thời cấp điện cho rãnh đồng. Đẩy khối dẫn điện vào vị trí để nối mạch mở cửa trước khi điện tắt.
- **Luồng dự kiến:** đọc nhịp búa → nhận biết rãnh đang có điện → đặt khối dẫn đúng đường mạch → canh chu kỳ búa để cấp điện → vượt cửa và xử lý mục tiêu phong ấn → mở đường hồi.
- **Combat/bẫy:** dụ địch giáp nặng vào búa hay dòng điện để phá giáp. Cách tránh sóng cần được chốt theo bộ di chuyển hiện dùng và quyết định về nhảy ở đầu tài liệu.
- **Còn cần chốt:** quy tắc đẩy khối, trạng thái mạch có lưu giữa chu kỳ không, báo trước búa và khả năng tránh sóng với bộ kỹ năng hiện có.

### 6.2. Phòng 5 — Cấn ☶: Vách Đá Hắc Diện Thạch

**The Obsidian Bulwark — nhánh Đông Bắc.**

- **Không khí:** mê cung cao độ bằng các khối đá núi lửa đen bóng, kiến trúc phòng thủ nặng.
- **Gimmick:** tránh tầm nhìn của Con Mắt Lò quét tia nhiệt; đẩy khối đá chắn và tận dụng góc khuất để tới phá mắt. Concept gốc nêu bị soi quá 1,5 giây sẽ bị thiêu; chưa có thông số damage thực thi.
- **Luồng dự kiến:** nhận diện hướng quét → đi qua vùng khuất → bố trí khối che để tạo đường tiếp cận → áp sát phá mắt → giải mục tiêu phong ấn và mở đường hồi.
- **Combat/bẫy:** golem ngụy trang trong tường, kích hoạt khi player quay lưng hoặc qua vạch cấm.
- **Còn cần chốt:** thời gian tích lũy/reset khi bị soi, cách hiển thị vùng nguy hiểm, liên hệ giữa vật che và camera, điều kiện đánh thức golem.

### 6.3. Phòng 6 — Đoài ☱: Đầm Lầy Xỉ Kim Loại

**The Molten Mire — nhánh Tây.**

- **Không khí:** vùng trũng chứa xỉ quặng sền sệt, bọt khí lưu huỳnh vàng và pháp bảo rèn hỏng.
- **Bản sắc mới:** giải đố sắp xếp địa hình bằng phế kim và lực hút/đẩy. Nhịp chính là quan sát, bố trí rồi đi qua các cầu đã ghép; player có chỗ đứng để suy nghĩ và sửa cách bố trí.
- **Gimmick chính:** điều khiển các trụ nam châm môi trường để kéo hoặc đẩy khối phế kim tới vị trí ghép cầu. Các mảnh pháp bảo và bản kim loại tạo mặt cầu liền giữa bệ đá; mọi tuyến bắt buộc đều đi bộ hoặc roll qua được, không cần nhảy hay kỹ năng mới của player.
- **Quy tắc cầu trong concept:** khối đã vào vị trí giữ đường đi ổn định cho tới khi player chủ động đổi cấu hình. Các câu đố sau yêu cầu tái sử dụng khối hoặc phối hợp nhiều trụ để nối các bệ theo thứ tự. Cần có cách thu hồi hoặc trả khối về mốc bố trí để sửa nước đi sai và tránh kẹt phòng.
- **Vai trò của xỉ:** giữ không khí đầm luyện kim và ranh giới nguy hiểm bên dưới cầu. Đoài không dùng làm nguội xỉ, tích nhiệt hoặc kéo chân làm vòng giải đố chính. Khảm hiện tập trung vào van và các ô đường đi sập sau khi giẫm lên.
- **Combat/bẫy:** định hướng dùng địch canh bệ thao tác hoặc chiếm một đoạn cầu, tạo tình huống phải xử lý chướng ngại trước khi đổi cấu hình. Khối phế kim đang dịch chuyển cần báo trước vùng quét hoặc kẹp. Không dùng cuộc truy đuổi dài làm áp lực xuyên suốt căn phòng. Loại địch và tương tác chiến đấu với trụ chưa chốt.
- **Hiện trạng:** mới cập nhật concept; chưa có scene phòng, layout chi tiết hay logic nam châm được dựng và kiểm thử.

**Luồng dự kiến**

1. Từ bệ vào quan sát trụ đầu và một khối phế kim; điều khiển trụ để ghép cầu đầu tiên và học cách đổi vị trí khối.
2. Sang bệ tiếp theo, quan sát những điểm ghép cầu có thể nối; chọn trụ cần điều khiển để mở đường tới bệ thao tác kế tiếp.
3. Tái bố trí các khối đã dùng, phối hợp lực hút/đẩy giữa các trụ để ghép tuyến tới bệ phong ấn. Khi chọn sai, thu hồi khối và thử cách bố trí khác.
4. Xử lý chướng ngại hoặc địch cục bộ tại các bệ cần thao tác, hoàn thành cấu hình cầu để tiếp cận mục tiêu phong ấn.
5. Giải mục tiêu rồi mở cấu hình cầu hồi nối về cửa Tây trung tâm. Đường hồi cần được kiểm tra để player không bị khóa bên kia sau khi thay đổi các khối.

**Còn cần chốt:** cách tương tác với trụ; cách chọn hút/đẩy và nhóm khối bị ảnh hưởng; khối chạy theo ray, điểm ghép hay quy tắc nào; hình dạng và số lượng khối; cách thể hiện trạng thái cầu đã khóa; vùng an toàn khi chuyển khối; cách thu hồi; bố cục đường hồi; loại địch và luật hồi sinh cục bộ. Những chi tiết này cần được duyệt trong plan riêng trước khi dựng phòng.

### 6.4. Phòng 7 — Càn ☰: Thiên Đỉnh Quang Lộ

**The Zenith Spire — nhánh Tây Bắc.**

- **Không khí:** ý tưởng nằm sát nắp lò, ánh sáng lọt qua khe thành những cột sáng giữa không gian tối. Cao độ thực của phòng chưa dựng.
- **Gimmick:** cầu chỉ hiện khi được chiếu sáng. Bật/tắt cửa chớp trên trần để đổi đường đi; concept còn có lối ẩn đọc từ một góc camera.
- **Luồng dự kiến:** quan sát khe sáng và cầu → điều chỉnh cửa chớp → xác nhận tuyến cầu đang hiện → đi tới điểm điều khiển tiếp theo → mở tuyến tới mục tiêu phong ấn → mở đường hồi.
- **Combat/bẫy:** thiên binh tha hóa bắn vũ khí ánh sáng trên hành lang hẹp không lan can; concept có yêu cầu parry hoặc né chính xác.
- **Còn cần chốt:** khả năng đổi góc camera của game, cách đọc cầu khi camera cố định, có yêu cầu parry hay không và cách tránh khóa player khi tắt cầu.

### 6.5. Phòng 8 — Khôn ☷: Hầm Mộ Tro Tàn

**The Cinder Catacombs — nhánh Tây Nam.**

- **Không khí:** ý tưởng ở đáy lò, tro cốt tích tụ, bình tro xếp thành hàng; tĩnh, u ám, tham chiếu cảm giác Death’s Door. Cao độ thực chưa dựng.
- **Gimmick:** lớp tro che công tắc áp lực, bẫy chông và lối ngầm. Dùng đòn diện rộng hoặc lướt để thổi tro, đọc mạch ngầm và tìm hầm bí mật.
- **Luồng dự kiến:** làm lộ dấu dưới tro → phân biệt công tắc và bẫy → lần theo bản đồ/mạch ngầm → mở lối xuống mục tiêu phong ấn → mở đường hồi.
- **Combat/bẫy:** đánh vỡ bình tro có thể thả bầy quái nhỏ; địch tinh anh hồi sinh từ tro nếu xác chưa được thanh tẩy bằng lửa thiêng.
- **Còn cần chốt:** hành động nào dọn được tro, tro có phủ lại không, cơ chế thanh tẩy xác và mức độ bắt buộc của lối ngầm.

## 7. Cách mở scene và tiếp tục phát triển

1. Mở `crucible_heart_preview.tscn` bằng F6 để từ trung tâm đi Ly ở Nam, Khảm ở Bắc hoặc Tốn ở Đông Nam. Scene này có spawn, lighting và camera riêng.
2. Có thể F6 `t3_01_li_foundry.tscn` để thử riêng phòng Ly. Khi phòng được đặt dưới `ZoneRoot`, player nhúng của phòng sẽ được bỏ và dùng player do zone tạo.
3. Tiến độ được đọc từ `GameState`; checkpoint cũ có thể làm phòng vào thẳng phase 2 hoặc trạng thái đã hoàn thành. Khi kiểm thử từ đầu cần dùng hồ sơ thử trống, không xóa hồ sơ người chơi ngoài ý muốn.
4. Khi thêm phòng 4–8, dựng vào nhánh có ký hiệu tương ứng, nối cờ `level_3.t3_seal_<id>` đã khai báo tại trung tâm. Chi tiết thử thách phải được chốt riêng trước khi code.
5. Ưu tiên tái sử dụng asset của project. Chỉ tạo model mới khi thật sự cần theo yêu cầu của người dùng.
6. Sau tám phong ấn, dùng signal trung tâm để nối trình tự hội thoại, mở lò và trận áp chế. Không coi giải đủ 8/8 là đã thắng trận lò hoặc đã nhận phần thưởng.

## 8. Phạm vi bàn giao Git

Nhánh `feature/fire-map/tier-3` được tách từ bản `main` trên remote tại thời điểm bàn giao. Phạm vi commit là thư mục `rooms/tier_3`, bao gồm trung tâm, phòng Ly, các component câu đố, preview và tài liệu này. Những thay đổi boss và các chỉnh sửa ngoài tier 3 không nằm trong commit.

Lượt bàn giao Khảm bổ sung scene/controller phòng, các component van/đường lạnh/sàn sập/hơi/bẫy F, cập nhật preview và thiết kế. Có thêm VFX dùng chung tại `assets/vfx/fire/hot_steam/` và bộ chặn đòn trước khi trừ máu trong `components/combat/hurtbox/hurtbox_component.gd`. Các chỉnh sửa cân bằng kỹ năng, charm, giao diện và thư viện navigation không dùng bởi Khảm không thuộc lượt commit này.

Lượt bàn giao Tốn gồm scene/controller phòng, các component mang lửa, trạm đuốc, bình phong, preview, tài liệu và tín hiệu đòn đánh trong player. Máy bắn thử và các thay đổi cân bằng ngoài phòng không thuộc lượt bàn giao này.
