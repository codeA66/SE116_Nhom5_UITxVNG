# Bộ model kiến trúc map Lửa (zone 3) — fire_kit v1

Bộ module dựng map zone 3 theo lưới **2 m / 4 m**, cùng quy chuẩn với `map_wind/wind_palace_v1` (sàn dày 0,32 m, tường cao 4 m, dày 0,7 m).
Làm theo `docs/art_style_guide.md`: low-poly, tô bằng vertex color, không texture, pivot ở đáy giữa, scale và rotation đã apply.

- File nguồn Blender (ngoài project): `D:/SE116/blend_sources/fire_kit/fire_kit_v1.blend`
- Vật liệu trong GLB: `Fire_VertexColor` và `Fire_VertexColor_Emission` (dùng chung với `inferno_kit`, `lavaplant_kit`).
- Chưa có collider: đặt hình cơ bản trong Godot.

## Bảng màu

| Vai trò | Màu |
|---|---|
| Tường | `#3A2E32` |
| Chi tiết, viền, nắp tường | `#5A3E36` |
| Sàn | `#6B4A3E` |
| Khe nối | `#2A2024` |
| Phát sáng (dung nham, rãnh lửa) | `#FF7A1A` |
| Cổng dịch chuyển | `#8A3CFF` |
| Lửa (lõi) | `#FFC24A` |
| Gỗ / gỗ viền | `#4A3A2E` / `#5C4836` |
| Kim loại | `#4A4048` |
| Vật tương tác (giống zone 1) | `#3FE0D0` |

## Danh sách đợt 1 (23 model)

| Nhóm | Model | Kích thước (rộng × sâu × cao, m) |
|---|---|---|
| Sàn | `floor_2m`, `floor_4m`, `floor_cracked_4m`, `floor_edge_4m` (có gờ mép), `floor_lava_grate_4m` (song sắt trên rãnh lửa), `corridor_floor_2m` (2 × 4, có gờ hai bên) | mặt sàn cao 0,32 |
| Tường | `wall_4m`, `wall_low_4m` (1,25), `wall_corner_4m` (chữ L), `wall_pillar`, `wall_end_2m`, `wall_broken_4m`, `wall_doorway_4m` (lỗ 2 × 2,85) | cao 4 |
| Hàng rào | `fence_2m` (trụ gạch ở đầu x = −1, chân đá, hai thanh sắt, chấn song; chóp và vạch giữa trụ là lava phát sáng), `fence_post` (trụ lẻ khép cuối dải) | cao 1,31 |
| Vật cản đốt được | `barricade_burnable_4m` (rào gỗ mục đóng chéo quấn dây leo khô, rộng 4 m; dùng trong `objects/gates/burnable_barrier`) | cao 3,1 |
| Đuốc / lửa trại | `hand_torch` (cán gỗ, vòng sắt, quấn vải; con `Flame*` tự sáng; dùng cho đuốc cầm tay và bó gậy), `campfire_big` (vòng đá, củi xếp nón, than hồng; con `Flame*`) | 1,2 / 2,4 |
| Nền đỡ | `foundation_4m`, `foundation_edge_4m` (đáy lởm chởm, có vệt dung nham) | 4 × 4 × 4, mặt trên ở 4 m |
| Đường đi | `stair_4m` (8 bậc × 0,25 = lên 2 m), `bridge_4m` (3 × 4), `bridge_broken_4m` | |
| Cổng | `gate_frame_4m` (lỗ 2,2 × 3,3), `gate_door_4m` (song sắt, đặt vào khung) | |
| Dung nham | `lava_plane_4m` (2 tam giác, thay bằng shader sau), `lavafall_4m` (thác đứng 4 × 4) | |
| Cổng dịch chuyển | `portal_frame` + node con `Surface` (mặt tím, ẩn/hiện bằng code) | 4,65 × 1,6 × 6,05 |

## Danh sách đợt 2 (16 model)

Phần có tên trong ngoặc là **node con riêng** trong GLB, để code bật/tắt, xoay hoặc gắn VFX.

| Nhóm | Model |
|---|---|
| Đèn, lửa | `torch_wall` (gắn mặt tường, nhô ra phía trước), `torch_standing`, `lamp_hanging` (xích hướng lên, treo từ trần), `fire_pillar` (cột lửa Arena, cao ~4 m), `fire_pit` (hố lửa Ø 2,7 m) — đều có `Flame` |
| Xích | `chain_hanging_4m`, `chain_wall` (vắt 3 m trên tường) |
| Vật chứa | `barrel`, `crate_stack` |
| Cơ chế | `switch_obelisk` (`Crystal`), `lever_fire` (`Handle`, pivot ở trục gạt, đang nghiêng 30°), `pressure_plate` (`Plate`, hạ xuống khi nhấn), `wall_secret_4m` (giống `wall_4m`, có vết nứt gợi ý) |
| Landmark | `altar` (`Crystal`), `checkpoint_shrine_fire` (`Flame`, tắt khi chưa kích hoạt), `arena_gate` (lỗ 4 × 4,5 m, `Door` song sắt) |

Rương, kho báu, xương, cột gãy, bệ, đá vụn dùng từ `inferno_kit`.

## Cách ghép

- Phòng đặt trên `foundation_*` (mặt trên ở 4 m), sàn đặt lên trên nền. Mép ngoài dùng `foundation_edge_4m`.
- Tường đặt lên mặt sàn (y = 0,32 so với đáy sàn). Góc dùng `wall_corner_4m` hoặc `wall_pillar`.
- Tầng chênh 2 m nối bằng `stair_4m`; chênh 4 m dùng hai `stair_4m` liên tiếp.
- `portal_frame` dùng ở hai nơi: điểm xuất hiện (tây nam) và phòng cuối sau boss (đông bắc).
- **Ròng rọc cứu con tin** (dựng bằng `D:/SE116/blend_sources/fire_kit/build_pulley_rescue.py`, chạy Blender nền trên `fire_kit_v1.blend`): `hanging_cage.glb` (gốc ở móc treo), `hostage_prisoner.glb`, `pulley_gantry.glb` (giàn 10 m, con `Wheel` quay quanh trục X), `winch_crank.glb` (con `Drum` quay quanh trục X).
- **Bệ đỡ cổng xoáy** (dựng bằng `D:/SE116/blend_sources/fire_kit/build_portal_pedestal.py`, dùng lại `Builder` của `build_pulley_rescue.py`): `portal_pedestal.glb` — bậc đá 2 tầng 5,6 × 2,2 m, 2 cột cao 4,4 m ở x ±2,55 có rãnh rune xanh phát sáng, vòm cung 15 khối, ổ đá năng lượng phía trước (+Z Godot 1,55 m, mặt trên ≈ 0,79 m). Dùng trong `objects/core/portal/vortex/vortex_portal_visual.tscn`.
