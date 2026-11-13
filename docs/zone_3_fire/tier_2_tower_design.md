# Thiết kế lại Tier 2 map Lửa: "Tháp Lò Rèn"

Trạng thái bản 2: **giai đoạn 1 (mảnh vỡ thay sách, HUD đếm mảnh) đã làm và qua test**; lối 02 → T1 giữ cổng nhưng chỉ mở theo cờ `level_3.t2_tower_unlocked` (chưa có gì đặt cờ này tới giai đoạn 3-4). **Giai đoạn 2 (bệ công tắc `ShardAltar` ở (278, 4.32, 46)) đã làm và qua test** (`shard_altar_test` 12 kiểm tra, đi bộ + interact thật; lưu cờ `level_3.t2_shard_switch`). **Giai đoạn 3 (thử thách u tối `DarkTrial`) đã làm và qua test** (`dark_trial_test` 34 kiểm tra): trụ Bắc (308, 8.32, 12) nhện lửa, Đông (351.5, 4.32, 39.5) sói bóng (dời từ 344, 41 vì chỗ đó là vực), Nam (312, 0.32, 92) Quỷ Xương Lửa; đồng hồ 120 s; thắng lưu `level_3.t2_dark_trial_done`. Thời gian lộ trình chưa đo bằng đi bộ thật (ước tính trên giấy ~55 s đi bộ + đánh). Thắp lò mới thử bằng `BurnableComponent.ignite()`, chưa thử bằng Phun lửa thật. Giai đoạn 4-6 chưa làm (xem mục 0). Trạng thái bản 1: **đã duyệt; giai đoạn 1 (bố cục + nối) và giai đoạn 2 (cổng + cờ) và giai đoạn 3 (quái từng tầng) giai đoạn 4 (sách + miếu) và giai đoạn 5 (dọn phòng, cơ chế bỏ) đã làm và qua test** (`tier_2_layout_test` 57 kiểm tra, có đi bộ thật từ sảnh chân tháp lên tầng boss). Giai đoạn 6 (test đi trọn vòng) chưa làm. Giai đoạn 2 lệch thiết kế một chỗ: bỏ `SummitGate` vì phòng boss không có cửa ở tường bắc (một tấm cổng giữa phòng thì đi vòng qua được); "mở cổng" là khung cổng tier 3 hiện ra khi hạ boss như cũ. Giai đoạn 3 lệch bảng mục 5: T1 4 sói (không phải 3), T2 1 Quỷ Xương Lửa + 3 slime, T3 5 slime + 3 sói, T4 Slime Mẹ thông số mặc định (không rút còn 2 con), T5 một đợt (không hai đợt). Thời gian hạ đo bằng người chơi máy: T1 ~10 s, T2 ~5 s, T3 ~4 s, T4 ~18 s, T5 ~10 s; tầng slime ngắn hơn mục tiêu.

## 0. Bản 2 (đã duyệt hướng, chưa làm): mảnh vỡ, bệ công tắc, thử thách u tối, truyền tống

Bản 2 thay mục 2 (vòng chơi), mục 4 (cửa tháp theo 3 sách) và mục 6.4 (sách). Bố cục tháp 6 tầng (mục 3.2) và giao tranh từng tầng (mục 5) giữ nguyên.

### 0.1 Vòng chơi

```
01 Cổng đáp ─► 02 Sảnh búa (mini game búa đập) ─► 03 Hub ─┬─► Bắc  04 → 05 ─► mảnh vỡ 1
                                                          ├─► Đông 06 → 07 ─► mảnh vỡ 2
                                                          └─► Nam  08 → 09 ─► mảnh vỡ 3
mang mảnh tới bệ giữa Hub ─► đủ 3 mảnh: công tắc sáng ─► THỬ THÁCH U TỐI (có đồng hồ)
  ─► Hub + 3 phòng xa tối hẳn, kích hoạt 3 trụ năng lượng (có quái canh)
  ─► đủ 3 trụ: vòng truyền tống giữa Hub mở ─► dịch chuyển tới T1 ─► T1…T5 ─► boss T6 ─► cổng tier 3
```

### 0.2 Quyết định đã chốt

| Mục | Chốt |
|---|---|
| Phần thưởng mỗi hướng | **Chỉ mảnh vỡ** (bỏ 3 sách Khiên xỉ, Lốc Lửa, Móc kéo khỏi tier 2) |
| Mini game từng hướng | **Chưa chốt** (người dùng nghĩ thêm). Tạm giữ nội dung đang có để vòng chơi vẫn chạy |
| Phòng 02 | **Đưa búa đập trở lại** làm mini game canh nhịp. Đặt búa xa khung cửa, đo lại bằng đi bộ thật (lần trước búa hất người chơi kẹt vào cửa ở z ≈ 44,5) |
| Ghép công tắc | Mang mảnh tới **bệ giữa Hub**, bấm tương tác để đặt; đặt từng mảnh được |
| Thử thách u tối | 3 trụ năng lượng ở 3 phòng **xa** Hub (người dùng: "xa hơn cũng được"), có quái canh, có đồng hồ. Hết giờ: tắt hết trụ, làm lại; checkpoint Hub |
| Đồng hồ | Bắt đầu 120 s. Trụ ở phòng xa nên phải đo bằng đi bộ thật rồi chỉnh (`@export`) |
| Vào tháp | Bước vào **vòng truyền tống giữa Hub** → dịch tới T1. Bỏ `TowerGate` ở cửa bắc 02 (đóng hẳn lối đó) |
| Cảm giác leo lên | Giữ 6 tầng cầu thang cao dần 4 m; thêm chữ "Tầng N / 6" khi vào tầng; T6 nhìn xuống thấy Hub. Lò cao `ForgeFurnace` ở Hub bừng lửa khi tháp mở |
| Phòng tối 07 | Giữ nguyên, vẫn cần Cung Lửa từ tier trước |

### 0.3 Đã chốt thêm

1. Trụ năng lượng ở **05, 07, 09**.
2. Cổng xoáy 07 → Hub mở theo cờ **mảnh vỡ Đông**.
3. Trụ = **trụ sinh quái**: phá xong (hạ quái / phá trụ) thì **thắp lửa** vào trụ là xong một trụ. Dựa trên `SpawnerCage` + `IgnitableBrazier` có sẵn.
4. Quái: sói, Quỷ Xương Lửa, slime và **nhện lửa** (`fire_spider`, có sẵn).

Hệ thống có sẵn dùng lại (đã rà code): `InteractableComponent` + action `interact`, `Pickup`/`KeyPickup`, `PowerSocket` (một cờ mỗi ổ), `IgnitableBrazier`/`BrazierGroup`, `SpawnerCage`, `DarkZone` (nhiều hộp AABB), `WarpPortal` (đích phải là một `WarpPortal`), `ForgeHammer`. **Chưa có:** đồng hồ đếm ngược, HUD đếm mảnh (chỉ có `Tier3OfferingHud` riêng cho tier 3).

### 0.4 Cần kiểm tra trong code trước khi lên kế hoạch (chưa kiểm)

- Có sẵn cơ chế mang vật / bệ đặt vật / tương tác giữ nút hay phải làm mới (phải theo FSM, Resource, signal).
- Cơ chế "tối" của phòng 07 (`blackout`) dùng lại cho Hub + 3 phòng được không.
- `WarpPortal` có dùng được làm vòng truyền tống một chiều tới T1 không.
- HUD có chỗ hiện số mảnh và đồng hồ chưa.

### 0.5 Giai đoạn (mỗi giai đoạn dừng để test và người dùng xem)

1. Mảnh vỡ thay sách (3 vật nhặt, cờ, HUD đếm mảnh). Bỏ `TowerGate`.
2. Bệ công tắc giữa Hub (đặt mảnh, sáng khi đủ 3).
3. Thử thách u tối: tối hóa, 3 trụ, quái canh, đồng hồ, reset khi hết giờ.
4. Vòng truyền tống giữa Hub → T1; chữ tầng; lò cao bừng lửa.
5. Búa đập ở phòng 02 (đo kẹt cửa).
6. Test đi trọn vòng bản 2 (3 mảnh → bệ → u tối → truyền tống → 6 tầng → boss).

Ghi chú sau khi dựng: khe giữa hai phòng lệch 4 m là hai ô cầu thang (đã thêm điểm đầu `"S"` vào `CONNECTORS` để ô đầu cũng là cầu thang; nếu không, cần khe 12 m).

## 1. Mục tiêu và ràng buộc

Vòng chơi người dùng chốt (nguyên văn ý): đánh xung quanh lấy skill → vào tháp → leo, đánh quái từng tầng → tầng cao nhất đánh boss → mở cổng.

| Điều đã chốt | Điều chưa chốt |
|---|---|
| Game **không có nhảy**: mọi chỗ phải qua được bằng đi bộ, đánh, dash hoặc skill | Boss tầng cao nhất hạ bằng cách nào (giữ boss tạm) |
| 3 khu quanh tháp, mỗi khu 1 trận quái rồi 1 skill (Khiên xỉ, Lốc Lửa, Móc kéo) | Cổng tier 3 nối đi đâu (tier 3 chưa có) |
| Nhận đủ 3 skill thì cửa tháp mở | |
| Tháp **5 tầng + tầng boss**, skill dùng trong tháp là tùy chọn, không bắt buộc | |
| Cách dựng **B: tháp xoắn ngang** (các phòng cao dần, không chồng lên nhau) | |

Chỉ sửa map Lửa (zone 3). Không đụng map Gió.

## 2. Vòng chơi

```
01 Cổng đáp ─► 02 Sảnh chân tháp ─► 03 Sân tháp (Hub) ─┬─► Khu Bắc  (04 Xưởng gỗ, 05 Sảnh Slime)   ─► bệ skill: Khiên xỉ
   (checkpoint)    (cửa tháp ĐÓNG)      (trận mở màn)   ├─► Khu Đông (06 Xưởng tối, 07 Phòng tối om) ─► bệ skill: Lốc Lửa
                                                        └─► Khu Nam  (08 Sân thủy triều, 09 Sảnh ma trơi) ─► bệ skill: Móc kéo
đủ 3 skill ─► cửa tháp (cửa bắc 02) mở ─► T1 ─► T2 ─► T3 ─► T4 ─► T5 ─► Tầng boss ─► hạ boss ─► mở cổng
```

- Ba khu làm theo thứ tự nào cũng được; không có khóa giữa các khu.
- Về lại sảnh chân tháp từ Hub chỉ là một đoạn đi bộ ngắn (02 nằm giữa 01 và Hub).
- Mỗi trận quái lưu cờ (`Encounter.persistent_id`) nên không phải đánh lại khi chết rồi hồi sinh ở checkpoint.

## 3. Bố cục

Quy tắc dựng giữ nguyên như tier 1: biên phòng là bội số 4, cửa ở tâm ô `4k + 2`, mặt đi lại = `y + 0,32`. Cầu thang nối hai độ cao lệch 4 m cần **khe 8 m** (hai ô cầu thang) giữa hai phòng.

### 3.1 Phòng giữ lại (đổi nội dung, không đổi chỗ)

| Phòng | Vai trò mới | Thay đổi |
|---|---|---|
| 01 Cổng đáp | Điểm vào, checkpoint đầu | Bỏ cửa nam của lối tắt 11 → 01 |
| 02 Búa nện | **Sảnh chân tháp**: chứa cửa tháp (`TowerGate`) ở cửa bắc | Bỏ 12 búa; đổi tên thành "Sảnh chân tháp"; cửa bắc dời sang x = 250 để vào T1 |
| 03 Hub | Sân tháp, trận mở màn `T2HubAmbush` giữ nguyên | Bỏ 3 ống dẫn lõi |
| 04, 05 | **Khu Bắc**: `T2TimberCaster`, `T2SlimeHall` | Bỏ lõi lò; bệ ở 05 đặt sách **Khiên xỉ** |
| 06, 07 | **Khu Đông**: `T2DarkForgePack` (3 sói) | Bỏ lõi; bệ ở 07 đặt sách **Lốc Lửa**; cổng xoáy về Hub giữ (mở khi nhặt sách) |
| 08, 09 | **Khu Nam**: sân thủy triều + sảnh ma trơi | Xem 3.3 |
| Hang băng | Bí mật phụ, ngoài đường chính | Giữ nguyên |

### 3.2 Phòng mới: Tháp xoắn ngang

Sáu phòng ở góc tây bắc (x 200–264, z 0–36), đi ngược chiều kim đồng hồ, mỗi phòng cao hơn phòng trước 4 m. Camera nhìn từ đông nam nên phòng cao nằm phía sau, ít che phòng thấp.

| Tầng | id | Biên `[x0, z0, x1, z1]` | y sàn | Cửa vào → cửa ra |
|---|---|---|---|---|
| T1 | `t2_t1_forge` | `[248, 24, 260, 36]` | 8 | S (x 250) ← 02 → W (z 30) |
| T2 | `t2_t2_anvil` | `[224, 24, 240, 36]` | 12 | E (z 30) → W (z 30) |
| T3 | `t2_t3_crucible` | `[200, 24, 216, 36]` | 16 | E (z 30) → N (x 210) |
| T4 | `t2_t4_chain` | `[200, 0, 216, 16]` | 20 | S (x 210) → E (z 6) |
| T5 | `t2_t5_smelter` | `[224, 0, 240, 16]` | 24 | W (z 6) → E (z 6) |
| Boss | `t2_t6_summit` | `[248, 0, 264, 16]` | 28 | W (z 6) → cổng ra ở tường bắc |

Nối: 02 → T1 cách 8 m (z 36–44); các cặp còn lại cách 8 m theo hàng hoặc cột (x 240–248, 216–224; z 16–24). Mỗi khe là hai ô cầu thang (`stair_4m`).

Kiểm tra trên giấy (chưa chạy): không phòng nào chồng nhau; Hub (x ≥ 264, z ≥ 36) không chạm T1 (x ≤ 260); tầng boss cách phòng 04 (x ≥ 268) 4 m; `TIER_ZONE` cần nâng trần y từ 20 lên 40 (sàn 28 + 9 m). Hộp RoomFocus của từng phòng tính theo sàn phòng (dưới 3 m, trên 9 m) nên không đổi.

Phòng bỏ khỏi bố cục: 10 Mini-boss, 11 Phần thưởng, 12 Boss cũ, đường nối lối tắt và cầu thang boss cũ. File object (`forge_hammer`, `forge_core`, `lava_tide`...) giữ lại trong `objects/`, chỉ bỏ khỏi dữ liệu bố cục.

### 3.3 Chỗ cần nhảy hiện tại

Chỉ phòng 08 buộc nhảy (6 bục đá cách nhau 2 m, chạm dung nham là chết). Phương án đề xuất: 08 thành **sân đấu thường**, bỏ `LavaTide` và 6 bục khỏi bố cục, thay bằng trận quái đợt. Bờ dung nham quanh sân chỉ là phông. Móc kéo và các vòng móc (phòng 04, 08) thành tùy chọn, không chặn đường.

## 4. Cờ và cổng

Dùng lại cơ chế cổng có sẵn (`cellar_gate`, danh sách `sources`, `FlagSource` một cờ mỗi nguồn). Không thêm script cổng mới.

| Cổng / vật | Mở khi | Cách làm |
|---|---|---|
| `TowerGate` (cửa bắc 02) | Có cả 3 sách | 3 `FlagSource` cho `level_3.t2_slag_shield_book`, `level_3.t2_fire_cyclone_book`, `level_3.t2_grapple_book` |
| Cổng giữa các tầng | Hạ hết trận quái tầng đó | `FlagSource` theo cờ `Encounter` của tầng (`level_3.t2_t1_cleared`...) |
| Cổng thưởng (`SummitGate`) | Hạ boss (`level_3.t2_boss_defeated`) | `FlagSource`, phía sau là `Tier3PortalFrame` |

Sách kỹ năng giữ nguyên dữ liệu (`FORGE_SKILL_BOOKS`), chỉ đổi vị trí: Khiên xỉ ở 05, Lốc Lửa ở 07, Móc kéo ở 09 (thay rương `WISP_CHEST`). Việc ghép skill với khu là tạm; đổi chỉ cần sửa dữ liệu.

## 5. Giao tranh

Chỉ dùng loại quái có sẵn (`caster` Quỷ Xương Lửa, `wolf` Sói Bóng, `slime` Slime Dung Nham, Slime Mẹ). Phòng tháp nhỏ (12×12 đến 16×16) nên ít quái, mạnh dần.

| Trận | Quái (đề xuất) | Mục tiêu thời gian hạ (đánh thường) |
|---|---|---|
| T1 | 3 sói | 8–10 s (đo thực: 7,8 s ở bầy 3 sói) |
| T2 | 2 Quỷ Xương Lửa + 2 slime | 10–14 s |
| T3 | 4 slime + 2 sói | 12–16 s |
| T4 | Slime Mẹ (rút gọn: tối đa 2 con sống) | 15–20 s (đo thực: 18 s) |
| T5 | 2 Quỷ Xương Lửa + 3 sói, hai đợt | 18–25 s |
| Boss | Boss tạm (`forge_boss`) | Chưa chốt (xem 8) |

Số liệu "đo thực" lấy từ `game_feel_test` đã chạy. Các số còn lại là mục tiêu, phải đo lại sau khi dựng. Cân bằng sát thương của người chơi máy: mất 3–6 máu mỗi trận, không chết.

## 6. Hồi sinh

Ngoài checkpoint đầu ở 01, thêm 3 miếu (`fire_checkpoint`): Hub, sảnh chân tháp (02), T3 (giữa tháp). Boss và trận quái đang đánh dở thì reset khi chết; trận đã hạ giữ nguyên.

## 7. File sẽ sửa

| File | Việc |
|---|---|
| `docs/zone_3_fire/level_3_tier_2_layout.gd` | `ROOMS`, `CONNECTORS`, `DECOR`, `ENCOUNTERS`, vị trí sách / checkpoint / cổng, `TIER_ZONE` |
| `docs/zone_3_fire/build_level_3.gd` | Bỏ búa, lõi, ống dẫn, cổng lõi, thủy triều, mini-boss; thêm cổng theo cờ và checkpoint mới |
| `levels/zone_3_fire/level_3/rooms/tier_2/*.tscn`, `level_3.tscn` | Phòng và nút mới; **sửa tại chỗ** như các lượt trước (chạy lại trình dựng sẽ xóa phần trang trí phiên khác đã sửa tay, nên chỉ chạy `--check-only`) |
| `levels/zone_3_fire/level_3/rooms/README.md` | Cập nhật mô tả tier 2 |
| Test: `tier_2_layout_test`, `fights_test`, `forge/`, `tide_wisps/`, `skills/` | Cập nhật theo bố cục mới; phòng và cơ chế bị bỏ thì bỏ test tương ứng |
| Test mới: `tower_flow_test`, dùng lại `game_feel_test` | Đi trọn vòng (xem 9) |

Không sửa `player.tscn` hay `player.gd`.

## 8. Cần bạn quyết

1. **Sân boss chỉ 16×16.** Cách dựng B với góc tây bắc ra phòng nhỏ. Nếu muốn sân boss lớn hơn (như cũ 28×28), cần dời khu Bắc (04, 05) hoặc dựng sân boss ở nơi khác và nối bằng cầu dài. Mình chưa biết boss thật sẽ cần sân cỡ nào.
2. **Cơ chế ý tưởng của các bạn trong nhóm** (Thịnh: đồ cháy ở 04, Hang băng; Thắng: phòng tối om, ma trơi). Đề xuất: giữ file, và giữ trong khu nếu không chặn đường (04, 07, 09 vẫn đi bộ qua được). Bỏ chỉ búa, lõi, thủy triều. Cần xác nhận với nhóm.
3. **Boss tầng cao nhất:** đang giữ boss tạm, vốn chỉ hạ được khi phản đòn (đo thực: 120 s đánh thường vẫn kẹt ở 15/30 máu). Cần chốt giữ cơ chế phản hay đổi.
4. **Cổng sau boss:** vẫn là khung cổng chưa nối tier 3. Giữ như vậy cho tới khi có tier 3.

## 9. Kiểm tra và giai đoạn

Giai đoạn (mỗi giai đoạn dừng để chạy test và bạn xem trước khi qua giai đoạn sau):

1. Bố cục và nối: sáu phòng tháp, cầu thang, sảnh chân tháp, `TIER_ZONE`. Test: đứng được từng phòng, tự đi từ 01 lên tầng boss không nhảy, lan can giữ.
2. Cổng và cờ: `TowerGate` theo 3 sách, cổng tầng theo trận quái, `SummitGate` theo boss.
3. Giao tranh: đặt quái từng tầng và khu, đo bằng `game_feel_test`; chỉnh số quái cho khớp bảng mục 5.
4. Skill và checkpoint: đổi chỗ sách, thêm miếu.
5. Làm phòng 08 thành sân đấu thường, dọn dữ liệu bỏ.
6. Test đi trọn vòng (`tower_flow_test`): lấy 3 skill → cổng tháp mở → hạ 5 tầng → boss → cổng mở; thêm chạy cực đoan (không nhặt đủ skill thì cổng vẫn đóng, quái bị hạ ngoài thứ tự).

Việc chưa làm và chưa kiểm tra: tòa tháp hình ảnh (mô hình tháp lớn làm phông), chụp ảnh kiểm tra tầng cao có che tầng thấp không từ camera hiện tại, cân bằng boss thật.
