extends SceneTree
## Dựng blockout zone 3 (map Lửa) từ bảng bố cục. Chạy: godot --headless --path <project> -s docs/zone_3_fire/build_level_3.gd
## Bố cục theo sơ đồ chú thích "Nether Wastes" (bản 3): giữ vị trí tương đối các khu, cỡ map ~180 x 104 m như zone 1.
## Tọa độ thế giới: X hướng đông, Z hướng nam. Đáy vực −8, tầng thấp 0 (phòng phía nam), tầng giữa +4 (spawn, hành lang tây,
## hub, phòng boss), tầng cao +8 (dãy phòng phía bắc). Biên phòng là bội số 4, cửa ở tâm ô (4k + 2).

const KIT: String = "res://assets/models/map_fire/fire_kit/"
const INFERNO: String = "res://assets/models/map_fire/inferno_kit/"
const OUT: String = "res://levels/zone_3_fire/level_3/"
const T: float = 0.32  # độ dày sàn: mặt đi lại = y phòng + T
const GROUND_Y: float = -8.0  # đáy vực: nền đá tối, chỗ có dung nham thì phủ mặt dung nham
const GROUND_COLOR: Color = Color(0.06, 0.035, 0.04)

# Phòng: x0,z0,x1,z1 (biên, bội số 4), y sàn, cửa {cạnh: [tọa độ tâm ô 4k+2]}, kiểu tường
const ROOMS: Array[Dictionary] = [
	# Phòng bắt đầu dựng theo lưới rồi xoay 45° quanh tâm ("yaw"), đặt tâm tại "place" để cửa đông vuông góc và khớp đầu cầu gạch Nether
	{"id": "room_01_spawn", "r": [4, 68, 28, 92], "y": 4, "exits": {"E": [78, 82]}, "wall": "full", "yaw": 45.0, "place": Vector2(19.5147, 90.4853), "low_sides": ["S", "E", "W"]},
	{"id": "room_02_combat_c2", "r": [16, 24, 36, 40], "y": 0, "exits": {"N": [22], "E": [30]}, "wall": "full"},
	{"id": "room_03_combat_treasure", "r": [32, 8, 52, 24], "y": 0, "exits": {"W": [14], "S": [50]}, "wall": "full"},
	{"id": "room_04_treasure_north", "r": [64, 0, 80, 20], "y": 8, "exits": {"S": [66]}, "wall": "full"},
	{"id": "room_05_ambush", "r": [56, 32, 68, 44], "y": 4, "exits": {"W": [42], "N": [66], "S": [62]}, "wall": "full"},
	{"id": "room_06_choke_point", "r": [96, 48, 108, 60], "y": 4, "exits": {"W": [50, 54], "E": [54]}, "wall": "low"},
	{"id": "room_07_hub", "r": [112, 36, 136, 60], "y": 4, "exits": {"W": [54], "N": [122], "E": [50], "S": [122]}, "wall": "low"},
	{"id": "room_08_arena", "r": [100, 4, 128, 24], "y": 8, "exits": {"S": [122], "W": [14]}, "wall": "full"},
	{"id": "room_09_side_room", "r": [84, 8, 96, 24], "y": 8, "exits": {"E": [14]}, "wall": "full"},
	{"id": "room_10_boss", "r": [148, 32, 176, 60], "y": 4, "exits": {"W": [50]}, "wall": "full"},
	{"id": "room_11_treasure_south", "r": [64, 68, 80, 88], "y": 0, "exits": {"N": [74], "E": [78]}, "wall": "full"},
	{"id": "room_12_drained_lava", "r": [92, 64, 108, 84], "y": 0, "exits": {"W": [78], "E": [78]}, "wall": "full"},
	{"id": "room_13_secret", "r": [112, 72, 128, 92], "y": 0, "exits": {"N": [122], "W": [78]}, "wall": "full"},
	{"id": "room_14_crumbling", "r": [132, 64, 152, 80], "y": 4, "exits": {"S": [146]}, "wall": "full"},
	{"id": "room_15_ruins_plaza", "r": [132, 92, 152, 104], "y": 0, "exits": {"N": [146]}, "wall": "low"},
]

# Đường nối: chuỗi điểm (x, y, z) là tâm ô 4 m; điểm đầu là ô đầu tiên ngoài mép phòng (hoặc sát một ô đường khác).
# Đoạn có y đổi = cầu thang (mỗi ô lên/xuống 2 m). Không rẽ ngay trên bậc thang: thêm ô chiếu nghỉ phẳng.
const CONNECTORS: Array = [
	# Phòng chiến đấu C2 → phòng kho báu / chiến đấu tây bắc (hành lang bên trái)
	[Vector3(22, 0, 22), Vector3(22, 0, 14), Vector3(30, 0, 14)],
	# Lối đi hướng tây: từ sân cuối cầu gạch Nether → điểm thắt (cầu gạch Nether dựng riêng trong _build_grand_bridge)
	[Vector3(66, 4, 54), Vector3(94, 4, 54)],
	# Hàng thứ hai song song: lối đi hướng tây rộng 8 m (z 48 → 56), hai hàng chạm nhau nên tự thành sàn vuông 4 m
	[Vector3(66, 4, 50), Vector3(94, 4, 50)],
	# Điểm thắt → hub
	[Vector3(110, 4, 54)],
	# Chốt chặn quân sự → hành lang tây (lối đi hẹp)
	[Vector3(62, 4, 46)],
	# Đường bẫy địa nhiệt: từ chân rào gỗ cạnh chốt chặn (+4) đi xuống hầm tối (tầng 0) tới phòng tây bắc
	[Vector3(50, 0, 26), Vector3(50, 0, 30), Vector3(54, 0, 30), Vector3(54, 4, 38), Vector3(54, 4, 42)],
	# Phòng chiến đấu C2 → đường bẫy địa nhiệt (nhập ở ô 50, 30) → về chốt chặn: vòng 5 → 3 → 2 → 5, không còn ngõ cụt
	[Vector3(38, 0, 30), Vector3(46, 0, 30)],
	# Chốt chặn → phòng kho báu phía bắc (lên +8)
	[Vector3(66, 8, 22), Vector3(66, 4, 30)],
	# Hub → khu sự kiện / arena phía bắc (lên +8)
	[Vector3(122, 4, 34), Vector3(122, 8, 26)],
	# Phòng phụ ↔ arena
	[Vector3(98, 8, 14)],
	# Hub → phòng boss phía đông
	[Vector3(138, 4, 50), Vector3(146, 4, 50)],
	# Hàng song song phía bắc: đường sang phòng boss rộng 8 m, chỗ đặt checkpoint trước boss
	[Vector3(138, 4, 46), Vector3(146, 4, 46)],
	# Phòng kho báu phía nam → lối đi hướng tây: lối ra một chiều (chỉ đi lên) của nhánh Hub → 13 → 12 → 11, qua dòng dung nham / vực thẳm
	[Vector3(74, 4, 58), Vector3(74, 0, 66)],
	# Đường hầm phía nam: phòng dung nham đã nứt → phòng kho báu phía nam
	[Vector3(82, 0, 78), Vector3(90, 0, 78)],
	# Phòng dung nham → khu vực bí mật S2
	[Vector3(110, 0, 78)],
	# Hub → khu vực bí mật S2 (xuống 0)
	[Vector3(122, 4, 62), Vector3(122, 0, 70)],
	# Lối Hub → góc phục kích (x 134) đã chặn hẳn: phòng 14 chỉ vào từ quảng trường tàn tích (phòng 15)
	# Góc phục kích → quảng trường tàn tích (xuống 0)
	[Vector3(146, 4, 82), Vector3(146, 0, 90)],
]

# Cầu bị dung nham ngập: đường nối giữ nguyên hình, nhưng dung nham tràn phủ mặt rồi đổ thác xuống dòng bên dưới.
# Bước vào là mất máu và bị cháy (LavaZone), không chết ngay. Khớp theo điểm đầu của đường nối trong CONNECTORS
const FLOODED_PATH_STARTS: Array[Vector3] = [Vector3(74, 4, 58)]
## Lớp dung nham phủ cao hơn mặt cầu / mặt bậc (m)
const FLOOD_SHEET_LIFT: float = 0.12
const LAVA_ZONE_SCENE: String = "res://objects/combat/hazards/lava_zone/lava_zone.tscn"
# Vùng dung nham trên đáy vực (x0, z0, x1, z1); ngoài vùng này đáy vực là đá tối
const LAVA_AREAS: Array = [
	[32, 58, 64, 100],  # hồ dung nham lớn phía tây nam (dưới cầu gạch Nether)
	[66, 56, 90, 66],  # dòng dung nham / vực thẳm cạnh đường xuống phòng kho báu phía nam
	[92, 64, 108, 84],  # hố dưới phòng dung nham đã nứt
]
const MAP_BOUNDS: Array = [-4, -4, 180, 108]
# Hộp vùng phòng (RoomFocus): dưới sàn / trên sàn (m). Dưới 7 m để không chứa biển dung nham (sàn thấp nhất y 0, biển y -7,6)
const ROOM_ZONE_BELOW: float = 3.0
const ROOM_ZONE_ABOVE: float = 9.0

# Cầu gạch Nether: tuyến chính đầu tiên từ phòng bắt đầu, chạy chéo 45° qua hồ dung nham (khớp góc camera zone 3)
const BRIDGE_START: Vector2 = Vector2(28, 82)  # tâm cửa đông phòng bắt đầu: mặt cầu bắt đầu ngay tại cửa, không có sân
const BRIDGE_END: Vector2 = Vector2(56, 54)  # tâm sân cuối cầu, nằm trên trục lối đi hướng tây (đúng 45° so với cửa)
# Quảng trường đầu cầu 12 x 12 m (x0, z0, x1, z1): gom cuối cầu, lối đi hướng tây và đường từ chốt chặn vào một sàn,
# lan can chạy theo chu vi, chỉ hở đúng chỗ các đường nhập vào (thay cho sân 8 x 8 cũ làm lan can so le)
const PLAZA: Array = [52, 48, 64, 60]
const BRIDGE_Y: float = 4.0
const FENCE_MODULE: float = 2.0  # chiều dài model fence_2m
# Bẫy trên cầu: vừa chạm mặt cầu là vòng cảnh báo hiện dưới chân rồi lửa phụt (0,9 s cảnh báo của LavaGeyser),
# sau đó cứ BRIDGE_FOLLOW_INTERVAL giây lại phun vào chỗ player đang đứng: phải chạy liên tục
const LINGER_TRAP_SCENE: String = "res://objects/combat/hazards/lava_geyser/linger_lava_trap.tscn"
const LINGER_TIME: float = 1.0
const BRIDGE_FOLLOW_INTERVAL: float = 1.3
# Quái canh cầu gạch Nether: đứng sẵn trên mặt cầu, player bước lên cầu thì thức dậy
const BRIDGE_GUARDS: Array[Vector3] = [Vector3(37, 4.32, 73), Vector3(43, 4.32, 67), Vector3(49, 4.32, 61)]
const BRIDGE_GUARD_TRIGGER: Vector3 = Vector3(30, 4, 30)
# Phòng 10: boss tạm (Boss1 của zone 1) xuất hiện khi bước vào; hạ boss thì cổng ra hiện lên (FlagReveal)
const BOSS_FIGHT_SCENE: String = "res://objects/core/encounter/boss_fight/boss_fight.tscn"
const BOSS_SCENE: String = "res://entities/bosses/boss_1/boss_1.tscn"
const BOSS_FIGHT_POS: Vector3 = Vector3(162, 4.32, 46)
const BOSS_SPAWN_OFFSET: Vector3 = Vector3(4, 0, 0)
const BOSS_FLAG: String = "level_3.boss_defeated"
const ROOM10_EXIT_PORTAL: Dictionary = {"p": Vector3(173, 4.32, 46), "yaw": -90.0}
# Phòng 4 trao kỹ năng Phun lửa; rào gỗ mục chắn lối lên phòng 3 và 2, phải đốt bằng Phun lửa mới đi được
const ABILITY_PICKUP_SCENE: String = "res://objects/core/pickups/ability/ability_pickup.tscn"
const FLAME_BREATH_DATA: String = "res://abilities/flame_breath/flame_breath.tres"
const BURNABLE_BARRIER_SCENE: String = "res://objects/gates/burnable_barrier/burnable_barrier.tscn"
const FLAME_BOOK_POS: Vector3 = Vector3(70, 8.32, 13)
## Checkpoint miếu Lửa ở góc đông nam quảng trường đầu cầu (ngoài lối cầu, lối bắc x 62 và lối tây z 50..54)
const CHECKPOINT_SCENE: String = "res://objects/core/checkpoint/fire/fire_checkpoint.tscn"
const PLAZA_CHECKPOINT_POS: Vector3 = Vector3(61, 4.32, 57.5)
## Checkpoint thứ hai ở phía nam phòng 6 (điểm thắt trước Hub), ngoài hai làn đi z 50 / 54
const ROOM6_CHECKPOINT_POS: Vector3 = Vector3(102, 4.32, 57.2)
## Checkpoint trước phòng boss: hàng bắc của đường Hub → phòng 10 (làn đi z 50 để trống)
const BOSS_CHECKPOINT_POS: Vector3 = Vector3(142, 4.32, 45.6)
## Lồng sinh quái phòng 4: phá lồng + hạ hết quái thì sách Phun lửa mới hiện (FlagReveal)
const SPAWNER_CAGE_SCENE: String = "res://objects/combat/spawner_cage/spawner_cage.tscn"
const FLAG_REVEAL_SCRIPT: String = "res://objects/combat/spawner_cage/flag_reveal.gd"
const ROOM4_CAGE_POS: Vector3 = Vector3(74, 8.32, 7)
## Vùng hoạt động phủ cả phòng 4 (x 64..80, z 0..20), tính theo vị trí lồng
const ROOM4_CAGE_AREA_SIZE: Vector3 = Vector3(15, 4, 19)
const ROOM4_CAGE_AREA_OFFSET: Vector3 = Vector3(-2, -0.32, 3)
const ROOM4_CAGE_FLAG: String = "level_3.room4_cage_cleared"
# Hầm tối: phòng 2, 3 và đường nối giữa chúng (tầng 0). Hộp (vị trí góc, kích thước) theo tọa độ thế giới
const DARK_ZONE_SCENE: String = "res://objects/world/cellar/dark_zone/dark_zone.tscn"
const BRAZIER_SCENE: String = "res://objects/world/cellar/ignitable_brazier/ignitable_brazier.tscn"
const DARK_ZONE_BOXES: Array[AABB] = [
	AABB(Vector3(16, -2, 24), Vector3(20, 9, 16)),  # phòng 2
	AABB(Vector3(32, -2, 8), Vector3(20, 9, 16)),  # phòng 3
	AABB(Vector3(20, -2, 12), Vector3(12, 9, 12)),  # đường 2 → 3 phía tây
	AABB(Vector3(36, -2, 24), Vector3(20, 9, 8)),  # đường 2 → đường bẫy địa nhiệt, chân phòng 3
	AABB(Vector3(52, -2, 32), Vector3(4, 9, 8)),  # bậc thang xuống hầm (sau rào gỗ)
]
# Lửa trại giữa phòng 5 và bó gậy (mặt sàn +4 = 4,32)
const CAMPFIRE_SCENE: String = "res://objects/world/cellar/hand_torch/campfire.tscn"
const STICK_BUNDLE_SCENE: String = "res://objects/world/cellar/hand_torch/stick_bundle.tscn"
const CAMPFIRE_POS: Vector3 = Vector3(59.5, 4.32, 37.5)
const STICK_BUNDLE_POS: Vector3 = Vector3(61.5, 4.32, 40.5)
# Cửa khóa phòng 2 (cửa đông + cửa bắc), mở khi thắp hết đuốc phòng 3 (số thứ tự trong CELLAR_TORCHES, đếm từ 1)
const CELLAR_GATE_SCENE: String = "res://objects/gates/stone_gate/fire_cellar_gate.tscn"
# Cổng khóa đường tới phòng 2: hai cửa phòng 2 + cửa tây phòng 3. Mở khi dọn xong trận ở phòng 3
const ROOM2_GATES: Array[Dictionary] = [
	{"name": "Room2EastGate", "p": Vector3(35.65, 0.32, 30), "yaw": 90.0},
	{"name": "Room2NorthGate", "p": Vector3(22, 0.32, 24.35), "yaw": 0.0},
	{"name": "Room3WestGate", "p": Vector3(32.35, 0.32, 14), "yaw": 90.0},
]
# Phòng 3: thắp 4 đuốc góc (số thứ tự trong CELLAR_TORCHES, đếm từ 1) thì phòng sáng, quái xuất hiện; hạ hết quái thì mở cổng
const ROOM3_TORCHES: Array[int] = [5, 6, 7, 8]
const ROOM3_LIGHTS: Array[Vector3] = [Vector3(36, 5, 12), Vector3(48, 5, 12), Vector3(36, 5, 20), Vector3(48, 5, 20)]
const ROOM3_ENCOUNTER_POS: Vector3 = Vector3(42, 0.32, 16)
# Phòng 2: chạm bệ thờ TriggerAltar thì mini-boss thức dậy; hạ boss thì mở cổng khóa đầu lối đi hướng tây
const ROOM2_ALTAR_POS: Vector3 = Vector3(26, 0.32, 32)
const ROOM2_ALTAR_TRIGGER: Vector3 = Vector3(3.5, 4, 3.5)
const ROOM2_BOSS_POS: Vector3 = Vector3(26, 0.32, 27.5)
const ROOM2_BOSS_SCALE: float = 1.4
## Mini-boss tạm: enemy_1 với dữ liệu riêng (nhiều máu, không khựng) tới khi có quái map Lửa
const ROOM2_BOSS_DATA: String = "res://resources/enemies/enemy_1/enemy_1_fire_miniboss.tres"
const ROOM2_BOSS_FLAG: String = "level_3.room2_miniboss"
# Phòng 8 (x 100..128, z 4..24, sàn +8): 4 lồng sinh quái bọc rào gỗ, phải Phun lửa đốt rào rồi mới chém được lồng.
# Phá đủ 4 lồng + hạ hết quái thì cổng cửa tây (sang phòng 9) chìm xuống
const CAGE_SHIELD_SCENE: String = "res://objects/combat/spawner_cage/cage_shield.tscn"
const ROOM8_CAGES: Array[Vector3] = [Vector3(108, 8.32, 9), Vector3(120, 8.32, 9), Vector3(108, 8.32, 19), Vector3(120, 8.32, 19)]
const ROOM8_CENTER: Vector3 = Vector3(114, 8.32, 14)
const ROOM8_AREA_SIZE: Vector3 = Vector3(27, 4, 19)
const ROOM8_SPAWN_INTERVAL: float = 5.0
const ROOM8_MAX_ALIVE: int = 2
## Quái xuất hiện ngoài vòng rào (rào cách tâm lồng 2,2 m)
const ROOM8_SPAWN_RADIUS: float = 3.4
const ROOM8_GATE: Dictionary = {"name": "Room8WestGate", "p": Vector3(99.65, 8.32, 14), "yaw": 90.0}
# Phòng 9: rương lớn chứa giày dung nham (đi trên dung nham không bị đốt)
const LAVA_BOOTS_CHEST_SCENE: String = "res://objects/core/pickups/chest/lava_boots_chest.tscn"
const ROOM9_CHEST_POS: Vector3 = Vector3(88, 8.32, 14)
const ROOM9_CHEST_YAW: float = 90.0
# Phòng 11 (x 64..80, z 68..88, sàn 0): 1 lồng sinh quái; phá lồng + hạ hết quái thì rương lớn hiện ra (FlagReveal)
const ROOM11_CAGE_POS: Vector3 = Vector3(72, 0.32, 78)
const ROOM11_AREA_SIZE: Vector3 = Vector3(15, 4, 19)
const ROOM11_FLAG: String = "level_3.room11_cage_cleared"
const TREASURE_CHEST_SCENE: String = "res://objects/core/pickups/chest/treasure_chest.tscn"
const ROOM11_CHEST_POS: Vector3 = Vector3(70, 0.32, 84)
# Phòng 14 (chỉ vào từ phòng 15): 2 lồng sinh quái; phá cả 2 lồng + hạ hết quái thì rương TNT hiện ra
const TNT_CHEST_SCENE: String = "res://objects/core/pickups/chest/tnt_chest.tscn"
const ROOM14_CAGES: Array[Dictionary] = [
	{"name": "Room14CageWest", "p": Vector3(137, 4.32, 69), "flag": "level_3.room14_cage_west"},
	{"name": "Room14CageEast", "p": Vector3(147, 4.32, 68), "flag": "level_3.room14_cage_east"},
]
## Vùng kích hoạt lồng: phủ cả phòng 14 (tâm 142, 72)
const ROOM14_AREA_SIZE: Vector3 = Vector3(19, 4, 15)
const ROOM14_CENTER: Vector3 = Vector3(142, 4.32, 72)
const ROOM14_CHEST_POS: Vector3 = Vector3(142, 4.32, 65.6)
# Phòng 12 (x 92..108, z 64..84, sàn 0): con tin treo trên hố dung nham giữa phòng (hố x 96..104, z 68..76).
# Cứu được thì mở cổng nam Hub (HubSouthGate lấy HostageRescue làm nguồn)
const HOSTAGE_RESCUE_SCENE: String = "res://objects/core/encounter/hostage_rescue/hostage_rescue.tscn"
const ROOM12_HOSTAGE_POS: Vector3 = Vector3(100, 0.32, 72)
const ROOM12_AREA_SIZE: Vector3 = Vector3(15, 4, 19)
const ROOM12_AREA_OFFSET: Vector3 = Vector3(0, -0.32, 2)
## Quái canh hạ lồng từ độ cao đầu tới mức đứt dây trong bao lâu (s)
const ROOM12_LOWER_TIME: float = 45.0
## Quái canh tời (vị trí so với gốc HostageRescue; tời ở (0, 0, 6,5))
const ROOM12_GUARDS: Array[Vector3] = [Vector3(-2.2, 0, 7.2), Vector3(2.2, 0, 7.2), Vector3(0, 0, 8.6)]
# Cổng xoáy năng lượng (thay cổng tím): hình dùng chung cho mọi cổng của map Lửa
const VORTEX_VISUAL_SCENE: String = "res://objects/core/portal/vortex/vortex_portal_visual.tscn"
const WARP_PORTAL_SCENE: String = "res://objects/core/portal/vortex/warp_portal.tscn"
const POWER_SOCKET_SCENE: String = "res://objects/core/portal/power/power_socket.tscn"
const ENERGY_STONE_SCENE: String = "res://objects/core/portal/power/energy_stone_pickup.tscn"
## Cổng 9 ↔ 15 hai chiều, chỉ hoạt động khi đã lắp đá năng lượng vào bệ cạnh cổng 9 (cờ PORTAL9_POWER_FLAG)
const WARP_PORTALS: Array[Dictionary] = [
	# Cổng 9 dựa tường bắc, quay mặt về nam (phía camera) cho dễ thấy; ổ nạp đá nằm trên bệ trước cổng
	{"name": "Room9WarpPortal", "p": Vector3(90, 8.32, 10.6), "yaw": 0.0, "target": "Room15WarpPortal"},
	{"name": "Room15WarpPortal", "p": Vector3(149, 0.32, 96), "yaw": -90.0, "target": "Room9WarpPortal"},
]
## Ổ nạp đá trên bệ trước cổng 9 (toạ độ cục bộ của cổng: đỉnh bệ nhỏ phía trước)
const PORTAL_SOCKET_LOCAL: Vector3 = Vector3(0, 0.8, 1.55)
const PORTAL9_POWER_FLAG: String = "level_3.portal9_powered"
const ENERGY_STONE_FLAG: String = "level_3.energy_stone"
## Đá năng lượng hiện trên sàn gỗ phòng 12 khi cứu được con tin (cạnh chỗ con tin đứng)
const ROOM12_STONE_POS: Vector3 = Vector3(99.2, 2.32, 65.6)
# Thử thách cuối ở Hub (x 112..136, z 36..60, sàn +4): trụ xanh giữa phòng; mở khi cổng xuống phòng 13 đã mở.
# Đồng ý thì sàn đổi sang lưới dung nham, phong ấn các cửa, sống 60 s giữa lửa phun. Xong thì mở cổng phòng boss
const FINAL_TRIAL_SCENE: String = "res://objects/core/encounter/final_trial/final_trial.tscn"
const TRIAL_SEAL_SCENE: String = "res://objects/core/encounter/final_trial/trial_seal.tscn"
const FINAL_TRIAL_POS: Vector3 = Vector3(124, 4.32, 48)
const FINAL_TRIAL_DURATION: float = 60.0
const FINAL_TRIAL_SEALS: Array[Dictionary] = [
	{"name": "SealWest", "p": Vector3(112.35, 4.32, 54), "yaw": 90.0},
	{"name": "SealNorth", "p": Vector3(122, 4.32, 36.35), "yaw": 0.0},
	{"name": "SealSouthWest", "p": Vector3(122, 4.32, 59.65), "yaw": 0.0},
]
const BOSS_GATE: Dictionary = {"name": "BossGate", "p": Vector3(136.35, 4.32, 50), "yaw": 90.0}
# Cổng đóng cửa nam Hub (x 122) xuống khu bí mật 13: mở khi cứu được con tin phòng 12
const HUB_SOUTH_GATE: Dictionary = {"name": "HubSouthGate", "p": Vector3(122, 4.32, 60.35), "yaw": 0.0}
# Cổng khóa đầu lối đi hướng tây: 2 cổng 4 m ghép thành 8 m ở mép đông quảng trường
const WEST_GATES: Array[Dictionary] = [
	{"name": "WestGateSouth", "p": Vector3(64.35, 4.32, 50), "yaw": 90.0},
	{"name": "WestGateNorth", "p": Vector3(64.35, 4.32, 54), "yaw": 90.0},
]
const ROOM3_ENEMIES: Array[Vector3] = [Vector3(-5, 0, -3), Vector3(5, 0, -3), Vector3(0, 0, 4)]
const ENCOUNTER_SCENE: String = "res://objects/core/encounter/encounter.tscn"
const ROOM3_ENEMY_SCENE: String = "res://entities/enemies/palace/enemy_1/enemy_1.tscn"
const FLAG_SOURCE_SCRIPT: String = "res://objects/wind_puzzle/flag_source/flag_source.gd"
const BRAZIER_GROUP_SCRIPT: String = "res://objects/world/cellar/ignitable_brazier/brazier_group.gd"
# Mái và tường cao che hầm, chia khu để cắt tường theo chỗ player đứng; box / boxes là chỉ số trong DARK_ZONE_BOXES
const CUTAWAY_SCENE: String = "res://objects/world/cellar/cutaway_zone/cutaway_zone.tscn"
const CELLAR_WALL_H: float = 4.0
# Mái hai dốc che hầm
const ROOF_MATERIAL: String = "res://assets/models/map_fire/fire_vertex_color.tres"
const ROOF_PITCH: float = 30.0  # độ dốc mái (độ)
const ROOF_OVERHANG: float = 0.6  # mái thò ra ngoài tường (m)
const ROOF_THICK: float = 0.25
const ROOF_TILE_ROW: float = 0.7  # bề rộng một hàng ngói dọc theo dốc (m)
const ROOF_COLOR_A: Color = Color(0.2, 0.075, 0.05)
const ROOF_COLOR_B: Color = Color(0.13, 0.05, 0.035)
const ROOF_EDGE: Color = Color(0.07, 0.035, 0.03)
const ROOF_RIDGE: Color = Color(0.05, 0.03, 0.03)
const ROOF_GABLE: Color = Color(0.12, 0.065, 0.055)
const CELLAR_SECTIONS: Array[Dictionary] = [
	{"name": "Room02", "room": "room_02_combat_c2", "box": 0},
	{"name": "Room03", "room": "room_03_combat_treasure", "box": 1},
	{"name": "Paths", "boxes": [2, 3, 4]},
]
# Đuốc tắt trong hầm (mặt sàn tầng 0 = 0,32): Phun lửa vào thì sáng mãi
const CELLAR_TORCHES: Array[Vector3] = [
	Vector3(19, 0.32, 27), Vector3(33, 0.32, 27), Vector3(19, 0.32, 37), Vector3(33, 0.32, 37),
	# Bốn góc phòng 3 (số 5..8): thắp đủ thì phòng sáng và quái xuất hiện
	Vector3(34.5, 0.32, 10), Vector3(49.5, 0.32, 10), Vector3(34.5, 0.32, 22), Vector3(49.5, 0.32, 22),
	Vector3(52.5, 0.32, 28.5),
]
# Một rào ở chân bậc thang đường bẫy địa nhiệt (cạnh cửa tây phòng 5): chặn lối lên phòng 3 và 2, mặt trước quay về nam
const BURNABLE_BARRIERS: Array[Dictionary] = [
	{"name": "IgniteChainBarrier", "p": Vector3(54, 4.32, 40.3), "yaw": 0.0},
]
const BRIDGE_WIDTH: float = 8.0
# Góc camera zone 3 kiểu isometric: nhìn chéo từ đông nam
const CAMERA_YAW: float = 45.0
const CAMERA_PITCH: float = 50.0
const CAMERA_DISTANCE: float = 32.0
const CAMERA_FOV: float = 30.0

var _cache: Dictionary = {}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "rooms"))
	for file: String in DirAccess.get_files_at(OUT + "rooms"):
		if file.ends_with(".tscn"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT + "rooms/" + file))
	var room_paths: Array[String] = []
	for room: Dictionary in ROOMS:
		var path: String = OUT + "rooms/" + str(room.id) + ".tscn"
		_save(_build_room(room), path)
		room_paths.append(path)
	var bridge_path: String = OUT + "rooms/nether_bridge.tscn"
	_save(_build_grand_bridge(), bridge_path)
	room_paths.append(bridge_path)
	var cover_path: String = OUT + "rooms/cellar_cover.tscn"
	_save(_build_cellar_cover(), cover_path)
	room_paths.append(cover_path)
	var conn_path: String = OUT + "rooms/connectors.tscn"
	_save(_build_connectors(), conn_path)
	_save(_build_level(room_paths, conn_path), OUT + "level_3.tscn")
	_attach_zone_root(OUT + "level_3.tscn")
	print("BUILD OK")
	quit()


func _save(root: Node, path: String) -> void:
	var packed: PackedScene = PackedScene.new()
	if packed.pack(root) != OK:
		push_error("pack failed " + path)
	if ResourceSaver.save(packed, path) != OK:
		push_error("save failed " + path)
	root.free()


func _model(file: String) -> PackedScene:
	if not _cache.has(file):
		_cache[file] = load(file)
	return _cache[file]


func _place(parent: Node, owner_node: Node, file: String, pos: Vector3, yaw: float = 0.0, node_name: String = "") -> Node3D:
	var inst: Node3D = _model(file).instantiate()
	if node_name != "":
		inst.name = node_name
	parent.add_child(inst, true)
	inst.owner = owner_node
	inst.position = pos
	inst.rotation_degrees.y = yaw
	return inst


func _group(parent: Node, owner_node: Node, node_name: String) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = node_name
	parent.add_child(n)
	n.owner = owner_node
	return n


func _box(body: StaticBody3D, owner_node: Node, center: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape, true)
	shape.owner = owner_node
	shape.transform = Transform3D(basis, center)


func _body(parent: Node, owner_node: Node) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	body.owner = owner_node
	return body


func _in_lava(x: float, z: float) -> bool:
	for a: Array in LAVA_AREAS:
		if x > a[0] and x < a[2] and z > a[1] and z < a[3]:
			return true
	return false


## Khối đá đỡ từ mặt (top_y) xuống đáy vực; lớp dưới cùng có chân lởm chởm
func _stack_foundation(parent: Node, owner_node: Node, local_xz: Vector3, top_local_y: float, world_top_y: float) -> void:
	var level: float = -4.0
	while world_top_y + level >= GROUND_Y - 0.01:
		var bottom: bool = world_top_y + level - 4.0 < GROUND_Y - 0.01
		_place(parent, owner_node, KIT + ("foundation_edge_4m" if bottom else "foundation_4m") + ".glb", local_xz + Vector3(0, top_local_y + level, 0))
		level -= 4.0


func _build_room(room: Dictionary) -> Node3D:
	var r: Array = room.r
	var x0: float = r[0]; var z0: float = r[1]; var x1: float = r[2]; var z1: float = r[3]
	var y: float = room.y
	var cx: float = (x0 + x1) * 0.5
	var cz: float = (z0 + z1) * 0.5
	var root: Node3D = Node3D.new()
	root.name = _pascal(str(room.id))
	root.position = Vector3(cx, y, cz)
	var floor_g: Node3D = _group(root, root, "Floor")
	var found_g: Node3D = _group(root, root, "Foundation")
	var wall_g: Node3D = _group(root, root, "Walls")
	var decor_g: Node3D = _group(root, root, "Decor")
	var body: StaticBody3D = _body(root, root)
	var holes: Array[Vector2] = []
	if room.id == "room_12_drained_lava":
		holes = [Vector2(98, 70), Vector2(102, 70), Vector2(98, 74), Vector2(102, 74)]
	var grate: Array[Vector2] = []
	# Hub: hình sàn do FinalTrial dựng (đổi sang lưới dung nham lúc thử thách cuối); ở đây chỉ giữ va chạm
	var floor_visual: bool = room.id != "room_07_hub"
	var tx: float = x0 + 2.0
	while tx < x1:
		var tz: float = z0 + 2.0
		while tz < z1:
			var local: Vector3 = Vector3(tx - cx, 0.0, tz - cz)
			var cell: Vector2 = Vector2(tx, tz)
			if not (cell in holes):
				var f: String = "floor_lava_grate_4m" if cell in grate else "floor_4m"
				if (room.id == "room_14_crumbling" and int(tx + tz) % 8 == 0) or (room.id == "room_15_ruins_plaza" and int(tx) % 12 == 2):
					f = "floor_cracked_4m"
				if floor_visual:
					_place(floor_g, root, KIT + f + ".glb", local)
				_box(body, root, local + Vector3(0, T * 0.5, 0), Vector3(4, T, 4))
			var edge: bool = tx < x0 + 4 or tx > x1 - 4 or tz < z0 + 4 or tz > z1 - 4
			if edge:
				_stack_foundation(found_g, root, local, 0.0, y)
			tz += 4.0
		tx += 4.0
	var exits: Dictionary = room.exits
	for side: String in ["N", "S", "W", "E"]:
		# Camera zone 3 nhìn chéo từ đông nam: tường nam và đông luôn thấp để không che phòng
		var low: bool = room.wall == "low" or side in room.get("low_sides", ["S", "E"])
		var wall_file: String = KIT + ("wall_low_4m" if low else "wall_4m") + ".glb"
		var wall_h: float = 1.25 if low else 4.0
		# Ép về float: "22.0 in [22]" là false trong GDScript nên cửa sẽ bị tường chặn
		var gaps: Array[float] = []
		for g: Variant in exits.get(side, []):
			gaps.append(float(g))
		var along_x: bool = side == "N" or side == "S"
		var a0: float = x0 if along_x else z0
		var a1: float = x1 if along_x else z1
		var a: float = a0 + 2.0
		while a < a1:
			if not (a in gaps):
				var pos: Vector3
				if side == "N": pos = Vector3(a - cx, T, z0 + 0.35 - cz)
				elif side == "S": pos = Vector3(a - cx, T, z1 - 0.35 - cz)
				elif side == "W": pos = Vector3(x0 + 0.35 - cx, T, a - cz)
				else: pos = Vector3(x1 - 0.35 - cx, T, a - cz)
				_place(wall_g, root, wall_file, pos, 0.0 if along_x else 90.0)
				var size: Vector3 = Vector3(4, wall_h, 0.7) if along_x else Vector3(0.7, wall_h, 4)
				_box(body, root, pos + Vector3(0, wall_h * 0.5, 0), size)
			a += 4.0
	for corner: Vector2 in [Vector2(x0, z0)]:
		# Chỉ góc tây bắc có cột cao; các góc phía camera (nam, đông) để thấp
		if room.wall == "full":
			var cp: Vector3 = Vector3(corner.x + (0.35 if corner.x == x0 else -0.35) - cx, T, corner.y + 0.35 - cz)
			_place(wall_g, root, KIT + "wall_pillar.glb", cp)
	_decorate(room, decor_g, root, cx, cz)
	if room.has("yaw"):
		var place: Vector2 = room.place
		root.position = Vector3(place.x, y, place.y)
		root.rotation_degrees.y = room.yaw
	return root


func _decorate(room: Dictionary, g: Node3D, root: Node3D, cx: float, cz: float) -> void:
	var o: Vector3 = Vector3(-cx, T, -cz)
	match str(room.id):
		"room_01_spawn":
			# Cổng tím ở mép tây, player xuất hiện trước cổng, quay mặt về phía đông
			_place(g, root, VORTEX_VISUAL_SCENE, o + Vector3(7, 0, 80), 90.0, "PortalFrame")
			_spawn_point(g, root, o + Vector3(13, 0.2, 80), -90.0)
			for p: Vector3 in [Vector3(8, 0, 71), Vector3(24, 0, 71), Vector3(8, 0, 89)]:
				_place(g, root, KIT + "torch_standing.glb", o + p)
			# Vật liệu dễ cháy
			_place(g, root, KIT + "barrel.glb", o + Vector3(12, 0, 90))
			_place(g, root, KIT + "barrel.glb", o + Vector3(13.2, 0, 88.8))
			_place(g, root, KIT + "crate_stack.glb", o + Vector3(16, 0, 90))
			# Cửa đông rộng 8 m (bằng mặt cầu) mở thẳng ra cầu gạch Nether: hai cột lửa đứng gác hai bên cửa
			for p: Vector3 in [Vector3(26, 0, 74.5), Vector3(26, 0, 85.5)]:
				_place(g, root, KIT + "fire_pillar.glb", o + p)
		"room_02_combat_c2":
			# Phòng chiến đấu C2: mini-boss, có điểm kích hoạt
			_place(g, root, KIT + "altar.glb", o + Vector3(26, 0, 32), 0.0, "TriggerAltar")
			_place(g, root, INFERNO + "bone_004.glb", o + Vector3(30, 0, 36))
		"room_03_combat_treasure":
			# Phòng kho báu / chiến đấu tây bắc: bệ đỏ ở giữa, rương ở các góc, mini-boss
			_place(g, root, KIT + "altar.glb", o + Vector3(42, 0, 16), 0.0, "RedAltar")
			for p: Vector3 in [Vector3(36, 0, 11), Vector3(48, 0, 11), Vector3(36, 0, 21)]:
				_place(g, root, INFERNO + "box_001.glb", o + p)
			_place(g, root, KIT + "chain_hanging_4m.glb", o + Vector3(48, 0, 21))
		"room_04_treasure_north":
			# Kho báu nhiều tầng cao (verticality); trang bị kháng lửa
			_place(g, root, INFERNO + "chest_big_001.glb", o + Vector3(72, 0, 8), 0.0, "Chest")
			_place(g, root, INFERNO + "gold_pile_big_001.glb", o + Vector3(76, 0, 12))
			_place(g, root, KIT + "switch_obelisk.glb", o + Vector3(67, 0, 4), 0.0, "SwitchObelisk")
		"room_05_ambush":
			_place(g, root, KIT + "crate_stack.glb", o + Vector3(59, 0, 35))
			_place(g, root, KIT + "barrel.glb", o + Vector3(65, 0, 35))
			_place(g, root, KIT + "torch_standing.glb", o + Vector3(58, 0, 34))
		"room_06_choke_point":
			_place(g, root, KIT + "torch_standing.glb", o + Vector3(98, 0, 49.5))
			_place(g, root, KIT + "torch_standing.glb", o + Vector3(106, 0, 49.5))
		"room_07_hub":
			# Trụ xanh thử thách cuối ở giữa Hub: FinalTrial thêm bằng text trong _attach_zone_root (FINAL_TRIAL_*)
			for p: Vector3 in [Vector3(115, 0, 39), Vector3(133, 0, 39)]:
				_place(g, root, KIT + "fire_pit.glb", o + p)
			_place(g, root, KIT + "wall_secret_4m.glb", o + Vector3(135.65, 0, 42), 90.0, "CrackedWall")
		"room_08_arena":
			# Khu vực sự kiện (arena): mini-boss, vòng tàn hỏa
			for p: Vector3 in [Vector3(104, 0, 8), Vector3(124, 0, 8), Vector3(104, 0, 20)]:
				_place(g, root, KIT + "fire_pillar.glb", o + p)
			_place(g, root, KIT + "fire_pit.glb", o + Vector3(114, 0, 14), 0.0, "EventCenter")
		"room_09_side_room":
			# Rương giày dung nham (AbilityChest) thêm bằng text trong _attach_zone_root: ROOM9_CHEST_POS
			_place(g, root, KIT + "barrel.glb", o + Vector3(87, 0, 21))
			# Cổng dịch chuyển về Hub (chỉ là hình), để phòng phụ không thành ngõ cụt phải đi bộ ngược
			# Cổng xoáy 9 ↔ 15 (WarpPortal) và bệ lắp đá năng lượng thêm bằng text trong _attach_zone_root: WARP_PORTALS
		"room_10_boss":
			# Phòng boss cuối: cổng ra xuất hiện sau khi hạ boss (logic ẩn/hiện để sau)
			for p: Vector3 in [Vector3(152, 0, 36), Vector3(172, 0, 36), Vector3(152, 0, 56), Vector3(172, 0, 56)]:
				_place(g, root, KIT + "fire_pillar.glb", o + p)
			_place(g, root, INFERNO + "pedestal_big_001.glb", o + Vector3(162, 0, 46), 0.0, "BossDais")
			# Cổng ra (ROOM10_EXIT_PORTAL) chỉ hiện khi hạ boss: thêm bằng text trong _attach_zone_root
		"room_11_treasure_south":
			# Lồng sinh quái + rương (hiện khi dọn xong) thêm bằng text trong _attach_zone_root: ROOM11_*
			_place(g, root, KIT + "switch_obelisk.glb", o + Vector3(76, 0, 72), 0.0, "SwitchObelisk")
		"room_12_drained_lava":
			# Cột dung nham đổ xuống hố giữa phòng
			_place(g, root, KIT + "lavafall_4m.glb", o + Vector3(100, -T - 8.0, 68.6), 0.0)
			_place(g, root, KIT + "lavafall_4m.glb", o + Vector3(100, -T - 4.0, 68.6), 0.0)
			_place(g, root, KIT + "torch_standing.glb", o + Vector3(106, 0, 66))
		"room_13_secret":
			_place(g, root, KIT + "switch_obelisk.glb", o + Vector3(120, 0, 86), 0.0, "SwitchObelisk")
			_place(g, root, INFERNO + "gold_pile_small_001.glb", o + Vector3(116, 0, 89))
		"room_14_crumbling":
			# Góc phục kích, sàn sụp. Lồng sinh quái + rương TNT thêm bằng text trong _attach_zone_root: ROOM14_*
			_place(g, root, KIT + "crate_stack.glb", o + Vector3(136, 0, 77))
		"room_15_ruins_plaza":
			_place(g, root, INFERNO + "column_big_broken_001.glb", o + Vector3(136, 0, 98))
			_place(g, root, INFERNO + "column_big_broken_002.glb", o + Vector3(150, 0, 100))
			_place(g, root, INFERNO + "column_big_001.glb", o + Vector3(140, 0, 101))
			# Cổng dịch chuyển về Hub (chỉ là hình): điểm cuối nhánh 14 → 15
			# Cổng xoáy 15 ↔ 9 thêm bằng text trong _attach_zone_root: WARP_PORTALS


func _spawn_point(g: Node3D, root: Node3D, pos: Vector3, yaw: float) -> void:
	var spawn: Marker3D = Marker3D.new()
	spawn.name = "SpawnStart"
	spawn.set_script(load("res://objects/core/spawn_point/spawn_point.gd"))
	spawn.set("spawn_id", &"start")
	g.add_child(spawn)
	spawn.owner = root
	spawn.position = pos
	spawn.rotation_degrees.y = yaw


func _build_connectors() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Connectors"
	var body: StaticBody3D = _body(root, root)
	var found_g: Node3D = _group(root, root, "Foundation")
	# Lượt 1: trải mọi đường thành ô; lượt 2 mới đặt model, để biết ô nào là ngã ba (có đường khác nhập từ hông)
	var all_paths: Array = []
	var occupied: Dictionary = {}
	for points: Array in CONNECTORS:
		var cells: Array[Dictionary] = _path_cells(points)
		all_paths.append(cells)
		for c: Dictionary in cells:
			occupied[Vector2i(roundi(c.p.x), roundi(c.p.z))] = true
	var ci: int = 0
	for cells: Array[Dictionary] in all_paths:
		ci += 1
		var g: Node3D = _group(root, root, "Path%02d" % ci)
		for i: int in range(cells.size()):
			var c: Dictionary = cells[i]
			var d_in: Vector3 = c.dir if c.dir != Vector3.ZERO else (cells[i + 1].dir if i + 1 < cells.size() else Vector3.FORWARD)
			var d_out: Vector3 = cells[i + 1].dir if i + 1 < cells.size() else d_in
			var p: Vector3 = c.p
			var top_y: float = p.y
			# Cầu chỉ rộng 3 m: ô có đường khác chạm vào từ hông phải là sàn vuông 4 m, nếu không hở khe 0,5 m
			var side: Vector3 = Vector3(-d_in.z, 0.0, d_in.x) * 4.0
			var junction: bool = occupied.has(Vector2i(roundi(p.x + side.x), roundi(p.z + side.z))) or occupied.has(Vector2i(roundi(p.x - side.x), roundi(p.z - side.z)))
			if c.kind == "stair":
				var rise: Vector3 = d_in if c.dy > 0.0 else -d_in
				var base_y: float = p.y if c.dy > 0.0 else p.y + c.dy
				top_y = base_y
				var yaw: float = rad_to_deg(atan2(-rise.x, -rise.z))
				_place(g, root, KIT + "stair_4m.glb", Vector3(p.x, base_y, p.z), yaw)
				var basis: Basis = Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, atan(0.5))
				_box(body, root, Vector3(p.x, base_y + 1.17, p.z), Vector3(3, 0.3, 4.472), basis)
			elif d_in.dot(d_out) < 0.5 or cells.size() == 1 or junction:
				_place(g, root, KIT + "floor_4m.glb", p)
				_box(body, root, p + Vector3(0, T * 0.5, 0), Vector3(4, T, 4))
			else:
				var along_x: bool = absf(d_in.x) > 0.5
				_place(g, root, KIT + "bridge_4m.glb", p, 90.0 if along_x else 0.0)
				_box(body, root, p + Vector3(0, T * 0.5, 0), Vector3(4, T, 3) if along_x else Vector3(3, T, 4))
			_add_rails(g, root, body, c, p, top_y, d_in, junction or d_in.dot(d_out) < 0.5 or cells.size() == 1, occupied)
			# Đường đi trên nền đá liền; đoạn qua hồ dung nham để trống thành cầu
			if not _in_lava(p.x, p.z):
				_stack_foundation(found_g, root, Vector3(p.x, 0, p.z), top_y, top_y)
		if FLOODED_PATH_STARTS.has(cells[0].p):
			_flood_path(g, root, cells)
	return root


## Phủ dung nham lên mặt đường nối (cả bậc thang), thác dung nham đổ xuống hai bên mép tới đáy vực,
## và LavaZone phủ cả đoạn: bước vào mất máu và bị cháy
func _flood_path(g: Node3D, owner_node: Node, cells: Array[Dictionary]) -> void:
	var lava_mat: Material = load("res://assets/materials/map_fire/lava_material.tres")
	var lo: Vector3 = Vector3(INF, INF, INF)
	var hi: Vector3 = -lo
	var fi: int = 0
	for c: Dictionary in cells:
		var p: Vector3 = c.p
		var d: Vector3 = c.dir if c.dir != Vector3.ZERO else cells[1].dir
		var along_x: bool = absf(d.x) > 0.5
		var sheet: MeshInstance3D = MeshInstance3D.new()
		var plane: PlaneMesh = PlaneMesh.new()
		var deck_y: float = p.y + T
		if c.kind == "stair":
			var rise: Vector3 = d if c.dy > 0.0 else -d
			var base_y: float = p.y if c.dy > 0.0 else p.y + c.dy
			var yaw: float = rad_to_deg(atan2(-rise.x, -rise.z))
			plane.size = Vector2(3.4, 4.472)
			sheet.basis = Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, atan(0.5))
			sheet.position = Vector3(p.x, base_y + 1.17 + 0.15 + FLOOD_SHEET_LIFT, p.z)
			deck_y = base_y + 1.0
		else:
			plane.size = Vector2(4.0, 3.4) if along_x else Vector2(3.4, 4.0)
			sheet.position = Vector3(p.x, p.y + T + FLOOD_SHEET_LIFT, p.z)
		sheet.mesh = plane
		sheet.material_override = lava_mat
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fi += 1
		sheet.name = "FloodSheet%02d" % fi
		g.add_child(sheet)
		sheet.owner = owner_node
		# Thác dung nham đổ từ mép cầu xuống đáy vực, hai bên hông (mép song song hướng đi)
		var side: Vector3 = Vector3(-d.z, 0.0, d.x)
		for sgn: float in [-1.0, 1.0]:
			var edge: Vector3 = Vector3(p.x, 0.0, p.z) + side * sgn * 1.85
			var top: float = deck_y
			while top > GROUND_Y + 0.01:
				_place(g, owner_node, KIT + "lavafall_4m.glb", Vector3(edge.x, top - 4.0, edge.z), 90.0 if not along_x else 0.0)
				top -= 4.0
		lo = lo.min(Vector3(p.x - 2.0, p.y - 2.5, p.z - 2.0))
		hi = hi.max(Vector3(p.x + 2.0, p.y + 3.0, p.z + 2.0))
	# Vùng dung nham (LavaZone): bước vào mất máu và bị cháy, đứng trong thì cháy tiếp, tự bước ra được.
	# Chừa 0,6 m ở hai đầu để đứng mép lối đi / cửa phòng không bị đốt oan
	var lava_zone: Node3D = (load(LAVA_ZONE_SCENE) as PackedScene).instantiate()
	lava_zone.name = "FloodLavaZone"
	g.add_child(lava_zone)
	lava_zone.owner = owner_node
	lava_zone.position = (lo + hi) * 0.5
	var along: Vector3 = (cells[1].dir as Vector3).abs()
	lava_zone.set("size", (hi - lo) - along * 1.2 - (Vector3(1, 0, 1) - along) * 0.4)


## Lan can thấp ở mỗi cạnh ô đường nối không giáp chỗ đi được (ô đường khác, phòng, cầu gạch Nether), để player không rơi khỏi map
func _add_rails(g: Node3D, owner_node: Node, body: StaticBody3D, c: Dictionary, p: Vector3, top_y: float, d: Vector3, square: bool, occupied: Dictionary) -> void:
	for n: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var nb: Vector3 = p + n * 4.0
		# Cạnh hông giáp phòng ở cao độ khác (vd. bậc thang xuống hầm chạy sát chân phòng chốt chặn) vẫn phải có lan can
		var side_y: float = top_y if absf(n.dot(d)) < 0.5 else NAN
		if occupied.has(Vector2i(roundi(nb.x), roundi(nb.z))) or _walkable(nb.x, nb.z, side_y):
			continue
		var along_x: bool = absf(n.z) > 0.5  # cạnh bắc/nam chạy dọc trục X
		# Cầu thường rộng 3 m: lan can hai bên sát mép 1,5 m; sàn vuông 4 m thì sát mép 2 m
		var off: float = 2.0 if square or absf(n.dot(d)) > 0.5 else 1.5
		var pos: Vector3 = Vector3(p.x, 0.0, p.z) + n * (off - 0.35)
		var yaw: float = 0.0 if along_x else 90.0
		var size: Vector3 = Vector3(4, 1.25, 0.7) if along_x else Vector3(0.7, 1.25, 4)
		if c.kind == "stair":
			# Lan can bậc thang nghiêng theo dốc (lên 2 m mỗi ô 4 m)
			var base_y: float = p.y if c.dy > 0.0 else p.y + c.dy
			var rise: Vector3 = d if c.dy > 0.0 else -d
			var basis: Basis = Basis(Vector3(-rise.z, 0.0, rise.x), atan(0.5)) * Basis(Vector3.UP, deg_to_rad(yaw))
			var center: Vector3 = pos + Vector3(0, base_y + 1.0 + 0.625, 0)
			_fence_line(g, owner_node, center - basis * Vector3(0, 0.625, 0), basis, 4.0)
			# basis đã gồm góc xoay ngang nên hộp dùng kích thước theo trục cục bộ của model
			_box(body, owner_node, center, Vector3(4, 1.85, 0.7), basis)
		else:
			_fence_line(g, owner_node, pos + Vector3(0, top_y + T, 0), Basis(Vector3.UP, deg_to_rad(yaw)), 4.0)
			_box(body, owner_node, pos + Vector3(0, top_y + T + 0.625, 0), size)


## Điểm (x, z) nằm trong quảng trường đầu cầu, nới (+) hoặc thu (−) biên theo margin
func _in_plaza(x: float, z: float, margin: float) -> bool:
	return x > PLAZA[0] - margin and x < PLAZA[2] + margin and z > PLAZA[1] - margin and z < PLAZA[3] + margin


## Hàng rào dài length (m) có tâm chân ở center, chạy theo trục X của basis: lặp module fence_2m (trụ ở đầu module),
## co đều các module cho vừa chiều dài thay vì kéo dãn một model, rồi thêm một trụ khép ở cuối
func _fence_line(g: Node3D, owner_node: Node, center: Vector3, basis: Basis, length: float) -> void:
	var n: int = maxi(1, ceili(length / FENCE_MODULE - 0.05))
	var m: float = length / float(n)
	for i: int in range(n):
		var x: float = -length * 0.5 + m * (float(i) + 0.5)
		var part: Node3D = _place(g, owner_node, KIT + "fence_2m.glb", Vector3.ZERO)
		part.transform = Transform3D(basis * Basis.from_scale(Vector3(m / FENCE_MODULE, 1.0, 1.0)), center + basis * Vector3(x, 0, 0))
	var cap: Node3D = _place(g, owner_node, KIT + "fence_post.glb", Vector3.ZERO)
	cap.transform = Transform3D(basis, center + basis * Vector3(length * 0.5, 0, 0))


## Một dải hàng rào liền từ a tới b (x, z) ở cao độ cầu, hộp va chạm cùng hướng
func _rail_segment(g: Node3D, owner_node: Node, body: StaticBody3D, a: Vector2, b: Vector2) -> void:
	var length: float = a.distance_to(b)
	if length < 0.05:
		return
	var d: Vector2 = (b - a) / length
	var basis: Basis = Basis(Vector3.UP, atan2(-d.y, d.x))  # trục X cục bộ của model chạy theo a → b
	var c: Vector2 = (a + b) * 0.5
	var center: Vector3 = Vector3(c.x, BRIDGE_Y + T, c.y)
	_fence_line(g, owner_node, center, basis, length)
	# Hộp va chạm dài thêm 0,7 m để hai dải gặp nhau ở góc chồng khít, không hở khe
	_box(body, owner_node, center + Vector3(0, 0.625, 0), Vector3(length + 0.7, 1.25, 0.7), basis)


## Ô (x, z) nằm trên phòng, sân hoặc mặt cầu gạch Nether
## y: cao độ ô cần so (NAN = không so); phòng lệch quá 1,5 m so với ô thì không tính là đi tiếp được
func _walkable(x: float, z: float, y: float = NAN) -> bool:
	for room: Dictionary in ROOMS:
		var rr: Array = room.r
		if not is_nan(y) and absf(float(room.y) - y) > 1.5:
			continue
		if not room.has("yaw") and x > rr[0] and x < rr[2] and z > rr[1] and z < rr[3]:
			return true
	if x > PLAZA[0] and x < PLAZA[2] and z > PLAZA[1] and z < PLAZA[3]:
		return true
	var dir: Vector2 = (BRIDGE_END - BRIDGE_START).normalized()
	var rel: Vector2 = Vector2(x, z) - BRIDGE_START
	var t: float = rel.dot(dir)
	return t > 0.0 and t < BRIDGE_START.distance_to(BRIDGE_END) and absf(rel.cross(dir)) < BRIDGE_WIDTH * 0.5


## Cầu gạch Nether lớn: mặt cầu rộng 8 m đi thẳng từ cửa đông phòng bắt đầu, xoay chéo theo hướng đầu → cuối, sân 8 x 8 m ở đầu cuối,
## lan can thấp, cột lửa hai bên, chân trụ cắm xuống dung nham. Va chạm là hộp xoay cùng mặt cầu.
func _build_grand_bridge() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "NetherBridge"
	var body: StaticBody3D = _body(root, root)
	var found_g: Node3D = _group(root, root, "Foundation")
	# Quảng trường đầu cầu; đầu kia mặt cầu cắm thẳng vào cửa phòng bắt đầu (phần thò vào phòng thấp hơn sàn 2 cm nên bị che)
	var plaza: Node3D = _group(root, root, "Plaza")
	var px0: float = PLAZA[0]; var pz0: float = PLAZA[1]; var px1: float = PLAZA[2]; var pz1: float = PLAZA[3]
	var cx: float = px0 + 2.0
	while cx < px1:
		var cz: float = pz0 + 2.0
		while cz < pz1:
			var p: Vector3 = Vector3(cx, BRIDGE_Y, cz)
			_place(plaza, root, KIT + "floor_4m.glb", p)
			_box(body, root, p + Vector3(0, T * 0.5, 0), Vector3(4, T, 4))
			_stack_foundation(found_g, root, Vector3(p.x, 0, p.z), BRIDGE_Y, BRIDGE_Y)
			cz += 4.0
		cx += 4.0
	# Mặt cầu xoay chéo
	var dir: Vector2 = (BRIDGE_END - BRIDGE_START).normalized()
	var length: float = BRIDGE_START.distance_to(BRIDGE_END)
	var yaw: float = rad_to_deg(atan2(-dir.x, -dir.y))
	var mid: Vector2 = (BRIDGE_START + BRIDGE_END) * 0.5
	var deck: Node3D = _group(root, root, "Deck")
	deck.position = Vector3(mid.x, BRIDGE_Y, mid.y)
	deck.rotation_degrees.y = yaw
	var basis: Basis = Basis(Vector3.UP, deg_to_rad(yaw))
	var rows: int = int(ceil(length / 4.0)) | 1  # số lẻ để có hàng giữa
	var half: int = rows / 2
	var half_w: float = BRIDGE_WIDTH * 0.5
	for k: int in range(-half, half + 1):
		for col: float in [-2.0, 2.0]:
			# Thấp hơn sân một chút: phần mặt cầu chồng dưới sân không bị nhấp nháy
			_place(deck, root, KIT + "floor_4m.glb", Vector3(col, -0.02, k * 4.0))
	_box(body, root, Vector3(mid.x, BRIDGE_Y + T * 0.5 - 0.02, mid.y), Vector3(BRIDGE_WIDTH, T, rows * 4.0), basis)
	# Lan can và cột lửa dọc hai bên mặt cầu
	var rail_x: float = half_w - 0.4
	# Lan can chạy tới sát cửa phòng và sân cuối, không chừa khe để rơi
	for k: int in range(-half + 1, half):
		for side: float in [-1.0, 1.0]:
			var local: Vector3 = Vector3(side * rail_x, T, k * 4.0)
			var world: Vector3 = Vector3(mid.x, BRIDGE_Y, mid.y) + basis * local
			# Cột lửa ở hàng chẵn, bỏ cột rơi vào quảng trường; lan can là đoạn liền dựng riêng bên dưới
			if k % 2 == 0 and not _in_plaza(world.x, world.z, 0.0):
				_place(deck, root, KIT + "fire_pillar.glb", local)
				_box(body, root, world + Vector3(0, 2.0, 0), Vector3(1.2, 4.0, 1.2), basis)
	# Lan can hai bên cầu: một dải liền từ sát cửa phòng tới đúng mép quảng trường, rồi chạy tiếp theo chu vi quảng trường
	var rails_g: Node3D = _group(root, root, "Rails")
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var ends: Array[Vector2] = []
	for side: float in [-1.0, 1.0]:
		# Bắt đầu lùi 0,35 m vào trong bề dày tường phòng để lan can nối khít mép cửa, không hở khe
		var a: Vector2 = BRIDGE_START - dir * 0.35 + perp * side * rail_x
		var t: float = 0.0
		while not _in_plaza(a.x + dir.x * t, a.y + dir.y * t, -0.35):
			t += 0.05
		var b: Vector2 = a + dir * t
		_rail_segment(rails_g, root, body, a, b)
		ends.append(b)
	# Chu vi quảng trường (mép trong lùi 0,35 m), chừa lối vào 3 m cho đường từ chốt chặn (bắc, x = 62) và lối đi hướng tây (đông, z = 54).
	# Góc tây nam là chỗ mặt cầu nhập vào: mép tây dừng ở đầu lan can tây bắc của cầu, mép nam bắt đầu từ đầu lan can đông nam
	var i0: float = PLAZA[0] + 0.35; var j0: float = PLAZA[1] + 0.35; var i1: float = PLAZA[2] - 0.35; var j1: float = PLAZA[3] - 0.35
	var nw: Vector2 = ends[0] if ends[0].x < ends[1].x else ends[1]
	var se: Vector2 = ends[1] if ends[0].x < ends[1].x else ends[0]
	for seg: Array in [
		[Vector2(nw.x, nw.y), Vector2(i0, j0)],
		[Vector2(i0, j0), Vector2(60.5, j0)], [Vector2(63.5, j0), Vector2(i1, j0)],
		[Vector2(i1, 56.0), Vector2(i1, j1)],
		[Vector2(i1, j1), Vector2(se.x, se.y)],
	]:
		_rail_segment(rails_g, root, body, seg[0], seg[1])
	# Bẫy "đứng lâu là bị phun": vùng phủ mặt cầu, player đứng một chỗ quá LINGER_TIME giây thì dung nham phụt đúng chỗ đó
	var trap: Area3D = (load(LINGER_TRAP_SCENE) as PackedScene).instantiate()
	trap.name = "LingerLavaTrap"
	root.add_child(trap)
	trap.owner = root
	trap.position = Vector3(mid.x, BRIDGE_Y + T, mid.y)
	trap.rotation_degrees.y = yaw
	trap.set("floor_y", BRIDGE_Y + T)
	trap.set("linger_time", LINGER_TIME)
	trap.set("follow_interval", BRIDGE_FOLLOW_INTERVAL)
	var zone_shape: CollisionShape3D = trap.get_node("CollisionShape3D")
	var zone_box: BoxShape3D = (zone_shape.shape as BoxShape3D).duplicate() as BoxShape3D
	# Chỉ phủ đoạn cầu ngoài phòng và quảng trường: từ cửa tới mép quảng trường
	zone_box.size = Vector3(BRIDGE_WIDTH - 0.8, 3.0, length - 6.0)
	zone_shape.shape = zone_box
	# Cổng khóa đầu lối đi hướng tây (WEST_GATES) là StoneGate thêm bằng text trong _attach_zone_root: mở khi hạ mini-boss phòng 2
	# Chân trụ dưới mặt cầu, mỗi 8 m, cắm xuống đáy vực
	for k: int in range(-half + 1, half, 2):
		var level: float = -4.0
		while BRIDGE_Y + level >= GROUND_Y - 0.01:
			var bottom: bool = BRIDGE_Y + level - 4.0 < GROUND_Y - 0.01
			_place(deck, root, KIT + ("foundation_edge_4m" if bottom else "foundation_4m") + ".glb", Vector3(0, level, k * 4.0))
			level -= 4.0
	return root


## Mái + tường cao phía camera che hầm phòng 2, 3 và đường nối trong hầm: từ ngoài không nhìn thấy bên trong.
## Mỗi khu (phòng 2, phòng 3, đường trong hầm) có một CutawayZone riêng: player đứng trong khu nào thì chỉ mái và tường
## cao của khu đó ẩn đi (kiểu The Sims), các khu khác vẫn kín. Tường cao có va chạm thật (không nhảy ra được).
func _build_cellar_cover() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "CellarCover"
	var body: StaticBody3D = _body(root, root)
	var cut_scene: PackedScene = load(CUTAWAY_SCENE)
	for sec: Dictionary in CELLAR_SECTIONS:
		var g: Node3D = _group(root, root, str(sec.name))
		var roof: Node3D = _group(g, root, "Roof")
		var walls: Node3D = _group(g, root, "TallWalls")
		if sec.has("room"):
			var room: Dictionary = {}
			for rm: Dictionary in ROOMS:
				if rm.id == sec.room:
					room = rm
			var r: Array = room.r
			var y: float = room.y
			# Mái hai dốc như mái nhà: nóc chạy theo cạnh dài của phòng
			var w: float = float(r[2]) - float(r[0])
			var dz: float = float(r[3]) - float(r[1])
			var rc: Vector3 = Vector3((float(r[0]) + float(r[2])) * 0.5, y + T + CELLAR_WALL_H, (float(r[1]) + float(r[3])) * 0.5)
			_gable_roof(roof, root, rc, maxf(w, dz), minf(w, dz), w >= dz)
			# Tường cao 4 m thay chỗ tường thấp phía nam và đông (phía camera); cửa vẫn chừa trống
			for side: String in ["S", "E"]:
				var gaps: Array[float] = []
				for gp: Variant in (room.exits as Dictionary).get(side, []):
					gaps.append(float(gp))
				var along_x: bool = side == "S"
				var a: float = (float(r[0]) if along_x else float(r[1])) + 2.0
				var a1: float = float(r[2]) if along_x else float(r[3])
				while a < a1:
					if not (a in gaps):
						var wp: Vector3 = Vector3(a, y + T, float(r[3]) - 0.35) if along_x else Vector3(float(r[2]) - 0.35, y + T, a)
						_place(walls, root, KIT + "wall_4m.glb", wp, 0.0 if along_x else 90.0)
						_box(body, root, wp + Vector3(0, 2.0, 0), Vector3(4, 4, 0.7) if along_x else Vector3(0.7, 4, 4))
					a += 4.0
		else:
			# Mái đường nối trong hầm: mỗi ô đường có tâm nằm trong các hộp của khu này
			for points: Array in CONNECTORS:
				var cells: Array[Dictionary] = _path_cells(points)
				for ci: int in range(cells.size()):
					var c: Dictionary = cells[ci]
					var pc: Vector3 = c.p
					var inside: bool = false
					for bi: int in sec.boxes:
						var bx: AABB = DARK_ZONE_BOXES[bi]
						if pc.x > bx.position.x and pc.x < bx.end.x and pc.z > bx.position.z and pc.z < bx.end.z:
							inside = true
					if not inside:
						continue
					var top: float = pc.y
					if c.kind == "stair":
						top = (pc.y if c.dy > 0.0 else pc.y + c.dy) + 2.0
					# Mái nhỏ hai dốc cho từng ô đường, nóc chạy theo hướng đi
					var cdir: Vector3 = c.dir if c.dir != Vector3.ZERO else (cells[ci + 1].dir if ci + 1 < cells.size() else Vector3.FORWARD)
					_gable_roof(roof, root, Vector3(pc.x, top + T + CELLAR_WALL_H, pc.z), 4.0, 4.0, absf(cdir.x) > 0.5)
		var cut: Area3D = cut_scene.instantiate()
		cut.name = "Cutaway"
		g.add_child(cut)
		cut.owner = root
		var bxs: Array[AABB] = []
		for bi: int in (sec.boxes if sec.has("boxes") else [sec.box]):
			bxs.append(DARK_ZONE_BOXES[bi])
		cut.set("boxes", bxs)
		var targets: Array[Node3D] = [roof, walls]
		cut.set("targets", targets)
	return root


## Mái hai dốc (kiểu mái nhà) phủ hình chữ nhật length × span, đáy mái ở base (tâm, cao độ đỉnh tường).
## Nóc chạy theo trục X nếu ridge_along_x, ngược lại theo Z. Lưới dựng bằng SurfaceTool, tô màu đỉnh từng hàng ngói
## xen kẽ đậm nhạt (dùng vật liệu vertex color chung của bộ kit lửa); hai đầu hồi tam giác bằng gạch, nóc có thanh chặn.
func _gable_roof(parent: Node3D, owner_node: Node, base: Vector3, length: float, span: float, ridge_along_x: bool) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_l: float = length * 0.5 + ROOF_OVERHANG
	var half_s: float = span * 0.5
	var slope: float = tan(deg_to_rad(ROOF_PITCH))
	var ridge_h: float = half_s * slope
	var eave: float = half_s + ROOF_OVERHANG
	var eave_y: float = -ROOF_OVERHANG * slope
	# Hệ cục bộ: x theo nóc, z ngang mái, y lên. Đổi sang thế giới bằng _roof_pt
	for side: float in [-1.0, 1.0]:
		var rows: int = maxi(2, int(ceil(eave / ROOF_TILE_ROW)))
		for k: int in range(rows):
			var z0: float = side * eave * (1.0 - float(k) / rows)
			var z1: float = side * eave * (1.0 - float(k + 1) / rows)
			var y0: float = ridge_h - absf(z0) * slope
			var y1: float = ridge_h - absf(z1) * slope
			var col: Color = ROOF_COLOR_A if k % 2 == 0 else ROOF_COLOR_B
			_roof_quad(st, [Vector3(-half_l, y0, z0), Vector3(half_l, y0, z0), Vector3(half_l, y1, z1), Vector3(-half_l, y1, z1)], col, side > 0.0, ridge_along_x)
		# Mép mái dày: dải đứng ở mép dưới để mái không mỏng như tờ giấy
		_roof_quad(st, [Vector3(-half_l, eave_y, side * eave), Vector3(half_l, eave_y, side * eave), Vector3(half_l, eave_y - ROOF_THICK, side * eave), Vector3(-half_l, eave_y - ROOF_THICK, side * eave)], ROOF_EDGE, side < 0.0, ridge_along_x)
	# Hai đầu hồi tam giác (gạch), mặt hướng ra ngoài
	for end: float in [-1.0, 1.0]:
		var x: float = end * length * 0.5
		var tri: Array = [Vector3(x, 0.0, -half_s), Vector3(x, ridge_h, 0.0), Vector3(x, 0.0, half_s)]
		if (end < 0.0) != ridge_along_x:
			tri.reverse()
		for v: Vector3 in tri:
			st.set_color(ROOF_GABLE)
			st.add_vertex(_roof_pt(v, ridge_along_x))
		# Mép dày ở đầu mái
		for sd: float in [-1.0, 1.0]:
			var a: Vector3 = Vector3(end * half_l, ridge_h, 0.0)
			var b: Vector3 = Vector3(end * half_l, eave_y, sd * eave)
			_roof_quad(st, [a, b, b - Vector3(0, ROOF_THICK, 0), a - Vector3(0, ROOF_THICK, 0)], ROOF_EDGE, (end * sd) > 0.0, ridge_along_x)
	# Thanh nóc
	var cap: float = 0.22
	for sd: float in [-1.0, 1.0]:
		_roof_quad(st, [Vector3(-half_l, ridge_h + cap, 0.0), Vector3(half_l, ridge_h + cap, 0.0), Vector3(half_l, ridge_h - cap * slope * 0.5, sd * cap), Vector3(-half_l, ridge_h - cap * slope * 0.5, sd * cap)], ROOF_RIDGE, sd > 0.0, ridge_along_x)
	st.generate_normals()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "GableRoof"
	mi.mesh = st.commit()
	mi.material_override = load(ROOF_MATERIAL)
	parent.add_child(mi, true)
	mi.owner = owner_node
	mi.position = base


## Một tứ giác (2 tam giác) theo thứ tự đỉnh; flip đảo chiều để mặt hướng ra ngoài
func _roof_quad(st: SurfaceTool, quad: Array, col: Color, flip: bool, ridge_along_x: bool) -> void:
	# Đổi trục x <-> z (nóc theo Z) là phép soi gương nên lật chiều quấn tam giác; bù lại để mặt luôn hướng ra ngoài
	var order: Array = [0, 2, 1, 0, 3, 2] if flip == ridge_along_x else [0, 1, 2, 0, 2, 3]
	for i: int in order:
		st.set_color(col)
		st.add_vertex(_roof_pt(quad[i], ridge_along_x))


func _roof_pt(v: Vector3, ridge_along_x: bool) -> Vector3:
	return v if ridge_along_x else Vector3(v.z, v.y, v.x)


## Trải chuỗi điểm thành các ô 4 m: phẳng hoặc bậc thang (mỗi ô lên/xuống 2 m)
func _path_cells(points: Array) -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	var start: Vector3 = points[0]
	cells.append({"p": start, "kind": "flat", "dir": Vector3.ZERO})
	for i: int in range(1, points.size()):
		var a: Vector3 = points[i - 1]
		var b: Vector3 = points[i]
		var flat: Vector3 = Vector3(b.x - a.x, 0, b.z - a.z)
		var n: int = int(round(flat.length() / 4.0))
		if n == 0:
			continue
		var dir: Vector3 = flat.normalized()
		var dy: float = (b.y - a.y) / float(n)
		for k: int in range(1, n + 1):
			var p: Vector3 = a + dir * 4.0 * k
			if absf(dy) > 0.01:
				cells.append({"p": Vector3(p.x, a.y + dy * (k - 1), p.z), "kind": "stair", "dir": dir, "dy": dy})
			else:
				cells.append({"p": Vector3(p.x, a.y, p.z), "kind": "flat", "dir": dir})
	return cells


func _build_level(room_paths: Array[String], conn_path: String) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Level3"
	var lighting: Node = (load(OUT + "lighting/fire_lighting.tscn") as PackedScene).instantiate()
	root.add_child(lighting)
	lighting.owner = root
	var bx0: float = MAP_BOUNDS[0]; var bz0: float = MAP_BOUNDS[1]; var bx1: float = MAP_BOUNDS[2]; var bz1: float = MAP_BOUNDS[3]
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "AbyssGround"
	var gplane: PlaneMesh = PlaneMesh.new()
	gplane.size = Vector2(bx1 - bx0 + 80.0, bz1 - bz0 + 80.0)
	ground.mesh = gplane
	var gmat: StandardMaterial3D = StandardMaterial3D.new()
	gmat.albedo_color = GROUND_COLOR
	# Đáy vực phải đọc là hố tối: không nhận đèn và không bị sương độ cao nhuộm đỏ
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.disable_fog = true
	ground.material_override = gmat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.position = Vector3((bx0 + bx1) * 0.5, GROUND_Y, (bz0 + bz1) * 0.5)
	root.add_child(ground)
	ground.owner = root
	# Biển dung nham phủ toàn bộ đáy vực trong MAP_BOUNDS (một mặt duy nhất: 1 draw call).
	# LAVA_AREAS vẫn dùng để quyết định đoạn đường nào là cầu (không xây móng đá)
	var lava: MeshInstance3D = MeshInstance3D.new()
	lava.name = "LavaSea"
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(bx1 - bx0, bz1 - bz0)
	lava.mesh = plane
	lava.material_override = load("res://assets/materials/map_fire/lava_material.tres")
	lava.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lava.position = Vector3((bx0 + bx1) * 0.5, GROUND_Y + 0.4, (bz0 + bz1) * 0.5)
	root.add_child(lava)
	lava.owner = root
	# Rơi xuống vực (đá hay dung nham) đều chết: vực sâu 8–16 m
	var kill: Node3D = (load("res://objects/core/kill_zone/kill_zone.tscn") as PackedScene).instantiate()
	kill.name = "AbyssKillZone"
	root.add_child(kill)
	kill.owner = root
	kill.position = Vector3((bx0 + bx1) * 0.5, GROUND_Y + 1.0, (bz0 + bz1) * 0.5)
	kill.set("size", Vector3(bx1 - bx0 + 80.0, 2.0, bz1 - bz0 + 80.0))
	kill.set("lethal", true)
	var rooms: Node3D = _group(root, root, "Rooms")
	for path: String in room_paths:
		var inst: Node = (load(path) as PackedScene).instantiate()
		rooms.add_child(inst)
		inst.owner = root
	var conn: Node = (load(conn_path) as PackedScene).instantiate()
	root.add_child(conn)
	conn.owner = root
	return root


## Chế độ -s không nạp autoload nên zone_root.gd không compile được lúc dựng: gắn script bằng cách sửa text
func _attach_zone_root(path: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(path)
	var text: String = FileAccess.get_file_as_string(abs_path)
	var ext: String = '[ext_resource type="Script" path="res://levels/_base/zone_root.gd" id="zone_root_script"]\n'
	var first_sub: int = text.find("[sub_resource")
	text = text.insert(first_sub, ext + "\n")
	var node_line_end: int = text.find("\n", text.find('[node name="Level3"'))
	text = text.insert(node_line_end, '\nscript = ExtResource("zone_root_script")')
	# Góc camera riêng của zone 3 (cùng lý do: zone_camera_view.gd phụ thuộc ZoneRoot nên gắn bằng text)
	var cam_ext: String = '[ext_resource type="Script" path="res://objects/hub/zone_camera_view/zone_camera_view.gd" id="zone_camera_view_script"]
'
	cam_ext += '[ext_resource type="Script" path="res://entities/player/camera/camera_view_data.gd" id="camera_view_data_script"]

'
	text = text.insert(text.find("[sub_resource"), cam_ext)
	var view_sub: String = '[sub_resource type="Resource" id="Zone3CameraView"]
script = ExtResource("camera_view_data_script")
'
	view_sub += "distance = %s
pitch_degrees = %s
fov = %s
yaw_degrees = %s

" % [CAMERA_DISTANCE, CAMERA_PITCH, CAMERA_FOV, CAMERA_YAW]
	text = text.insert(text.find("[node "), view_sub)
	text += '
[node name="ZoneCameraView" type="Node" parent="."]
script = ExtResource("zone_camera_view_script")
view = SubResource("Zone3CameraView")
'
	# Vật có script phụ thuộc autoload (GameState): sách kỹ năng, vật cản đốt được. Thêm bằng text như trên
	text = text.insert(text.find("[sub_resource"), '[ext_resource type="PackedScene" path="%s" id="ability_pickup_scene"]
[ext_resource type="Resource" path="%s" id="flame_breath_data"]
[ext_resource type="PackedScene" path="%s" id="burnable_barrier_scene"]
[ext_resource type="PackedScene" path="%s" id="spawner_cage_scene"]
[ext_resource type="Script" path="%s" id="flag_reveal_script"]
[ext_resource type="PackedScene" path="%s" id="cage_enemy_scene"]

' % [ABILITY_PICKUP_SCENE, FLAME_BREATH_DATA, BURNABLE_BARRIER_SCENE, SPAWNER_CAGE_SCENE, FLAG_REVEAL_SCRIPT, ROOM3_ENEMY_SCENE])
	text += '
[node name="Pickups" type="Node3D" parent="."]
'
	text = text.insert(text.find("[sub_resource"), '[ext_resource type="PackedScene" path="%s" id="fire_checkpoint_scene"]

' % CHECKPOINT_SCENE)
	var kp: Vector3 = PLAZA_CHECKPOINT_POS
	text += '
[node name="PlazaCheckpoint" parent="." instance=ExtResource("fire_checkpoint_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
checkpoint_id = &"level_3.plaza"
' % [kp.x, kp.y, kp.z]
	var k6: Vector3 = ROOM6_CHECKPOINT_POS
	text += '
[node name="Room6Checkpoint" parent="." instance=ExtResource("fire_checkpoint_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
checkpoint_id = &"level_3.room6"
' % [k6.x, k6.y, k6.z]
	var kb: Vector3 = BOSS_CHECKPOINT_POS
	text += '
[node name="BossCheckpoint" parent="." instance=ExtResource("fire_checkpoint_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
checkpoint_id = &"level_3.boss"
' % [kb.x, kb.y, kb.z]
	var cp: Vector3 = ROOM4_CAGE_POS
	text += '
[node name="Room4SpawnerCage" parent="." instance=ExtResource("spawner_cage_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
enemy_scene = ExtResource("cage_enemy_scene")
persistent_id = &"%s"
active_area_size = Vector3(%s, %s, %s)
active_area_offset = Vector3(%s, %s, %s)
' % [cp.x, cp.y, cp.z, ROOM4_CAGE_FLAG, ROOM4_CAGE_AREA_SIZE.x, ROOM4_CAGE_AREA_SIZE.y, ROOM4_CAGE_AREA_SIZE.z, ROOM4_CAGE_AREA_OFFSET.x, ROOM4_CAGE_AREA_OFFSET.y, ROOM4_CAGE_AREA_OFFSET.z]
	text += '
[node name="Room4BookReveal" type="Node3D" parent="Pickups"]
script = ExtResource("flag_reveal_script")
flag = &"%s"
' % ROOM4_CAGE_FLAG
	var bp: Vector3 = FLAME_BOOK_POS
	text += '
[node name="FlameBreathBook" parent="Pickups/Room4BookReveal" instance=ExtResource("ability_pickup_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
ability = ExtResource("flame_breath_data")
persistent_id = &"level_3.flame_breath_book"
' % [bp.x, bp.y, bp.z]
	# Hầm tối phòng 2, 3: vùng tối (tắt nắng / đèn hắt / ánh sáng môi trường) và đuốc thắp bằng Phun lửa
	text = text.insert(text.find("[sub_resource"), '[ext_resource type="PackedScene" path="%s" id="dark_zone_scene"]
[ext_resource type="PackedScene" path="%s" id="brazier_scene"]

' % [DARK_ZONE_SCENE, BRAZIER_SCENE])
	var aabbs: PackedStringArray = []
	for bx: AABB in DARK_ZONE_BOXES:
		aabbs.append("AABB(%s, %s, %s, %s, %s, %s)" % [bx.position.x, bx.position.y, bx.position.z, bx.size.x, bx.size.y, bx.size.z])
	text += '
[node name="CellarDarkZone" parent="." node_paths=PackedStringArray("sun", "bounce_light", "world_environment") instance=ExtResource("dark_zone_scene")]
boxes = Array[AABB]([%s])
sun = NodePath("../FireLighting/SunLight")
bounce_light = NodePath("../FireLighting/LavaBounceLight")
world_environment = NodePath("../FireLighting/Environment")
use_carried_light = false
' % ", ".join(aabbs)
	# Lửa trại lớn giữa phòng 5 và bó gậy: cầm gậy lại gần lửa trại thì thành đuốc soi đường trong hầm
	text = text.insert(text.find("[sub_resource"), '[ext_resource type="PackedScene" path="%s" id="campfire_scene"]
[ext_resource type="PackedScene" path="%s" id="stick_bundle_scene"]

' % [CAMPFIRE_SCENE, STICK_BUNDLE_SCENE])
	text += '
[node name="Room5Campfire" parent="." instance=ExtResource("campfire_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
persistent_id = &"level_3.room5_campfire_lit"
' % [CAMPFIRE_POS.x, CAMPFIRE_POS.y, CAMPFIRE_POS.z]
	text += '
[node name="Room5StickBundle" parent="." instance=ExtResource("stick_bundle_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
' % [STICK_BUNDLE_POS.x, STICK_BUNDLE_POS.y, STICK_BUNDLE_POS.z]
	text += '
[node name="CellarTorches" type="Node3D" parent="."]
'
	var ti: int = 0
	for tp: Vector3 in CELLAR_TORCHES:
		ti += 1
		text += '
[node name="CellarTorch%02d" parent="CellarTorches" instance=ExtResource("brazier_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
persistent_id = &"level_3.cellar_torch_%02d"
' % [ti, tp.x, tp.y, tp.z, ti]
	# Phòng 3: nhóm 4 đuốc góc + đèn phòng; trận quái chờ cờ "đã thắp đủ"; cổng chờ cờ "đã dọn trận"
	text = text.insert(text.find("[sub_resource"), '[ext_resource type="PackedScene" path="%s" id="cellar_gate_scene"]
[ext_resource type="PackedScene" path="%s" id="encounter_scene"]
[ext_resource type="PackedScene" path="%s" id="room3_enemy_scene"]
[ext_resource type="Script" path="%s" id="flag_source_script"]
[ext_resource type="Script" path="%s" id="brazier_group_script"]

' % [CELLAR_GATE_SCENE, ENCOUNTER_SCENE, ROOM3_ENEMY_SCENE, FLAG_SOURCE_SCRIPT, BRAZIER_GROUP_SCRIPT])
	text += '
[node name="Room3" type="Node3D" parent="."]
'
	var light_paths: PackedStringArray = []
	var li: int = 0
	for lp: Vector3 in ROOM3_LIGHTS:
		li += 1
		text += '
[node name="Room3Light%d" type="OmniLight3D" parent="Room3"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
light_color = Color(1, 0.6, 0.3, 1)
light_energy = 0.0
omni_range = 12.0
' % [li, lp.x, lp.y, lp.z]
		light_paths.append('NodePath("../Room3Light%d")' % li)
	var torch_paths: PackedStringArray = []
	for idx: int in ROOM3_TORCHES:
		torch_paths.append('NodePath("../../CellarTorches/CellarTorch%02d")' % idx)
	text += '
[node name="Room3Braziers" type="Node" parent="Room3" node_paths=PackedStringArray("braziers", "lights")]
script = ExtResource("brazier_group_script")
braziers = [%s]
lights = [%s]
lit_energy = 3.5
persistent_id = &"level_3.room3_torches_lit"
' % [", ".join(torch_paths), ", ".join(light_paths)]
	var ep: Vector3 = ROOM3_ENCOUNTER_POS
	text += '
[node name="Room3Encounter" parent="Room3" instance=ExtResource("encounter_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
persistent_id = &"level_3.room3_encounter"
required_flag = &"level_3.room3_torches_lit"
enemies_visible_before_start = false
trigger_size = Vector3(18, 4, 14)
' % [ep.x, ep.y, ep.z]
	var ei: int = 0
	for eo: Vector3 in ROOM3_ENEMIES:
		ei += 1
		text += '
[node name="Enemy%d" parent="Room3/Room3Encounter/Enemies" instance=ExtResource("room3_enemy_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
' % [ei, eo.x, eo.y, eo.z]
	text += '
[node name="Room3ClearedSource" type="Node" parent="Room3"]
script = ExtResource("flag_source_script")
flag = &"level_3.room3_encounter"
'
	text += '
[node name="Room2Gates" type="Node3D" parent="."]
'
	for gd: Dictionary in ROOM2_GATES:
		var gp: Vector3 = gd.p
		var gb: Basis = Basis(Vector3.UP, deg_to_rad(float(gd.yaw)))
		text += '
[node name="%s" parent="Room2Gates" node_paths=PackedStringArray("sources") instance=ExtResource("cellar_gate_scene")]
transform = Transform3D(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
sources = [NodePath("../../Room3/Room3ClearedSource")]
persistent_id = &"level_3.%s"
' % [gd.name, gb.x.x, gb.y.x, gb.z.x, gb.x.y, gb.y.y, gb.z.y, gb.x.z, gb.y.z, gb.z.z, gp.x, gp.y, gp.z, String(gd.name).to_snake_case()]
	# Phòng 2: mini-boss ngủ yên cạnh bệ thờ, chạm bệ thờ (Trigger nhỏ quanh bệ) thì thức dậy
	text = text.insert(text.find("[sub_resource"), '[ext_resource type="Resource" path="%s" id="room2_boss_data"]

' % ROOM2_BOSS_DATA)
	var ap: Vector3 = ROOM2_ALTAR_POS
	var bo: Vector3 = ROOM2_BOSS_POS - ROOM2_ALTAR_POS
	var bs: float = ROOM2_BOSS_SCALE
	text += '
[node name="Room2" type="Node3D" parent="."]

[node name="Room2BossEncounter" parent="Room2" instance=ExtResource("encounter_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
persistent_id = &"%s"
trigger_size = Vector3(%s, %s, %s)
clear_trauma = 0.5

[node name="MiniBoss" parent="Room2/Room2BossEncounter/Enemies" instance=ExtResource("room3_enemy_scene")]
transform = Transform3D(%s, 0, 0, 0, %s, 0, 0, 0, %s, %s, %s, %s)
data = ExtResource("room2_boss_data")

[node name="Room2ClearedSource" type="Node" parent="Room2"]
script = ExtResource("flag_source_script")
flag = &"%s"
' % [ap.x, ap.y, ap.z, ROOM2_BOSS_FLAG, ROOM2_ALTAR_TRIGGER.x, ROOM2_ALTAR_TRIGGER.y, ROOM2_ALTAR_TRIGGER.z, bs, bs, bs, bo.x, bo.y, bo.z, ROOM2_BOSS_FLAG]
	text += '
[node name="WestGates" type="Node3D" parent="."]
'
	for wg: Dictionary in WEST_GATES:
		var wp: Vector3 = wg.p
		var wb: Basis = Basis(Vector3.UP, deg_to_rad(float(wg.yaw)))
		text += '
[node name="%s" parent="WestGates" node_paths=PackedStringArray("sources") instance=ExtResource("cellar_gate_scene")]
transform = Transform3D(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
sources = [NodePath("../../Room2/Room2ClearedSource")]
persistent_id = &"level_3.%s"
' % [wg.name, wb.x.x, wb.y.x, wb.z.x, wb.x.y, wb.y.y, wb.z.y, wb.x.z, wb.y.z, wb.z.z, wp.x, wp.y, wp.z, String(wg.name).to_snake_case()]
	# Phòng 8: 4 lồng bọc rào gỗ (Shield là con của lồng), cổng cửa tây lấy cả 4 lồng làm nguồn (cần đủ cả 4)
	text = text.insert(text.find("[sub_resource"), '[ext_resource type="PackedScene" path="%s" id="cage_shield_scene"]

' % CAGE_SHIELD_SCENE)
	text += '
[node name="Room8" type="Node3D" parent="."]
'
	var cage_paths: PackedStringArray = []
	var qi: int = 0
	for qp: Vector3 in ROOM8_CAGES:
		qi += 1
		var off: Vector3 = ROOM8_CENTER - qp
		text += '
[node name="Room8Cage%d" parent="Room8" node_paths=PackedStringArray("shield") instance=ExtResource("spawner_cage_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
enemy_scene = ExtResource("cage_enemy_scene")
spawn_interval = %s
max_alive = %d
spawn_radius = %s
shield = NodePath("Shield")
persistent_id = &"level_3.room8_cage_%d"
active_area_size = Vector3(%s, %s, %s)
active_area_offset = Vector3(%s, %s, %s)

[node name="Shield" parent="Room8/Room8Cage%d" instance=ExtResource("cage_shield_scene")]
' % [qi, qp.x, qp.y, qp.z, ROOM8_SPAWN_INTERVAL, ROOM8_MAX_ALIVE, ROOM8_SPAWN_RADIUS, qi, ROOM8_AREA_SIZE.x, ROOM8_AREA_SIZE.y, ROOM8_AREA_SIZE.z, off.x, off.y, off.z, qi]
		cage_paths.append('NodePath("../Room8Cage%d")' % qi)
	var rg: Dictionary = ROOM8_GATE
	var rgp: Vector3 = rg.p
	var rgb: Basis = Basis(Vector3.UP, deg_to_rad(float(rg.yaw)))
	text += '
[node name="%s" parent="Room8" node_paths=PackedStringArray("sources") instance=ExtResource("cellar_gate_scene")]
transform = Transform3D(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
sources = [%s]
persistent_id = &"level_3.%s"
' % [rg.name, rgb.x.x, rgb.y.x, rgb.z.x, rgb.x.y, rgb.y.y, rgb.z.y, rgb.x.z, rgb.y.z, rgb.z.z, rgp.x, rgp.y, rgp.z, ", ".join(cage_paths), String(rg.name).to_snake_case()]
	text = text.insert(text.find("[sub_resource"), '[ext_resource type="PackedScene" path="%s" id="lava_boots_chest_scene"]

' % LAVA_BOOTS_CHEST_SCENE)
	var cb: Basis = Basis(Vector3.UP, deg_to_rad(ROOM9_CHEST_YAW))
	var cpos: Vector3 = ROOM9_CHEST_POS
	text += '
[node name="Room9LavaBootsChest" parent="." instance=ExtResource("lava_boots_chest_scene")]
transform = Transform3D(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
' % [cb.x.x, cb.y.x, cb.z.x, cb.x.y, cb.y.y, cb.z.y, cb.x.z, cb.y.z, cb.z.z, cpos.x, cpos.y, cpos.z]
	# Phòng 11: lồng + rương ẩn tới khi dọn xong
	text = text.insert(text.find("[sub_resource"), '[ext_resource type="PackedScene" path="%s" id="treasure_chest_scene"]
[ext_resource type="PackedScene" path="%s" id="hostage_rescue_scene"]

' % [TREASURE_CHEST_SCENE, HOSTAGE_RESCUE_SCENE])
	var r11: Vector3 = ROOM11_CAGE_POS
	var r11off: Vector3 = Vector3(72, 0, 78) - Vector3(r11.x, 0, r11.z)
	var r11c: Vector3 = ROOM11_CHEST_POS
	text += '
[node name="Room11" type="Node3D" parent="."]

[node name="Room11Cage" parent="Room11" instance=ExtResource("spawner_cage_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
enemy_scene = ExtResource("cage_enemy_scene")
persistent_id = &"%s"
active_area_size = Vector3(%s, %s, %s)
active_area_offset = Vector3(%s, %s, %s)

[node name="Room11ChestReveal" type="Node3D" parent="Room11"]
script = ExtResource("flag_reveal_script")
flag = &"%s"

[node name="Room11Chest" parent="Room11/Room11ChestReveal" instance=ExtResource("treasure_chest_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
persistent_id = &"level_3.room11_chest"
' % [r11.x, r11.y, r11.z, ROOM11_FLAG, ROOM11_AREA_SIZE.x, ROOM11_AREA_SIZE.y, ROOM11_AREA_SIZE.z, r11off.x, -0.32, r11off.z, ROOM11_FLAG, r11c.x, r11c.y, r11c.z]
	# Phòng 14: 2 lồng sinh quái, rương TNT hiện khi dọn xong cả 2 (FlagReveal nhiều cờ)
	text = text.insert(text.find("[sub_resource"), '[ext_resource type="PackedScene" path="%s" id="tnt_chest_scene"]

' % TNT_CHEST_SCENE)
	text += '
[node name="Room14" type="Node3D" parent="."]
'
	var r14_flags: PackedStringArray = []
	for cage14: Dictionary in ROOM14_CAGES:
		var c14: Vector3 = cage14.p
		var off14: Vector3 = ROOM14_CENTER - c14
		r14_flags.append('&"%s"' % cage14.flag)
		text += '
[node name="%s" parent="Room14" instance=ExtResource("spawner_cage_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
enemy_scene = ExtResource("cage_enemy_scene")
persistent_id = &"%s"
active_area_size = Vector3(%s, %s, %s)
active_area_offset = Vector3(%s, %s, %s)
' % [cage14.name, c14.x, c14.y, c14.z, cage14.flag, ROOM14_AREA_SIZE.x, ROOM14_AREA_SIZE.y, ROOM14_AREA_SIZE.z, off14.x, -0.32, off14.z]
	var tc: Vector3 = ROOM14_CHEST_POS
	text += '
[node name="Room14ChestReveal" type="Node3D" parent="Room14"]
script = ExtResource("flag_reveal_script")
flag = &"%s"
extra_flags = Array[StringName]([%s])

[node name="TntChest" parent="Room14/Room14ChestReveal" instance=ExtResource("tnt_chest_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
' % [ROOM14_CAGES[0].flag, ", ".join(r14_flags.slice(1)), tc.x, tc.y, tc.z]
	# Phòng 12: con tin treo trên hố dung nham
	var hp12: Vector3 = ROOM12_HOSTAGE_POS
	text += '
[node name="Room12HostageRescue" parent="." node_paths=PackedStringArray("guards") instance=ExtResource("hostage_rescue_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
persistent_id = &"level_3.room12_hostage_rescued"
guards = NodePath("Guards")
lower_time = %s
active_area_size = Vector3(%s, %s, %s)
active_area_offset = Vector3(%s, %s, %s)

[node name="Guards" parent="Room12HostageRescue" instance=ExtResource("encounter_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 2)
persistent_id = &"level_3.room12_guards"
trigger_size = Vector3(%s, %s, %s)
' % [hp12.x, hp12.y, hp12.z, ROOM12_LOWER_TIME, ROOM12_AREA_SIZE.x, ROOM12_AREA_SIZE.y, ROOM12_AREA_SIZE.z, ROOM12_AREA_OFFSET.x, ROOM12_AREA_OFFSET.y, ROOM12_AREA_OFFSET.z, ROOM12_AREA_SIZE.x, ROOM12_AREA_SIZE.y, ROOM12_AREA_SIZE.z]
	var gi: int = 0
	for gp: Vector3 in ROOM12_GUARDS:
		gi += 1
		text += '
[node name="Guard%d" parent="Room12HostageRescue/Guards/Enemies" instance=ExtResource("room3_enemy_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
' % [gi, gp.x, gp.y, gp.z - 2.0]
	# Cổng xoáy 9 ↔ 15 + bệ lắp đá + đá năng lượng (thưởng cứu con tin phòng 12)
	text = text.insert(text.find("[sub_resource"), '[ext_resource type="PackedScene" path="%s" id="warp_portal_scene"]
[ext_resource type="PackedScene" path="%s" id="power_socket_scene"]
[ext_resource type="PackedScene" path="%s" id="energy_stone_scene"]

' % [WARP_PORTAL_SCENE, POWER_SOCKET_SCENE, ENERGY_STONE_SCENE])
	text += '
[node name="WarpPortals" type="Node3D" parent="."]
'
	for wp: Dictionary in WARP_PORTALS:
		var wpp: Vector3 = wp.p
		var wpb: Basis = Basis(Vector3.UP, deg_to_rad(float(wp.yaw)))
		text += '
[node name="%s" parent="WarpPortals" node_paths=PackedStringArray("target") instance=ExtResource("warp_portal_scene")]
transform = Transform3D(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
target = NodePath("../%s")
required_flag = &"%s"
' % [wp.name, wpb.x.x, wpb.y.x, wpb.z.x, wpb.x.y, wpb.y.y, wpb.z.y, wpb.x.z, wpb.y.z, wpb.z.z, wpp.x, wpp.y, wpp.z, wp.target, PORTAL9_POWER_FLAG]
	var sp: Vector3 = PORTAL_SOCKET_LOCAL
	var stp: Vector3 = ROOM12_STONE_POS
	text += '
[node name="PowerSocket" parent="WarpPortals/Room9WarpPortal" instance=ExtResource("power_socket_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
required_item_flag = &"%s"
persistent_id = &"%s"

[node name="Room12StoneReveal" type="Node3D" parent="."]
script = ExtResource("flag_reveal_script")
flag = &"level_3.room12_hostage_rescued"

[node name="EnergyStone" parent="Room12StoneReveal" instance=ExtResource("energy_stone_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
' % [sp.x, sp.y, sp.z, ENERGY_STONE_FLAG, PORTAL9_POWER_FLAG, stp.x, stp.y, stp.z]
	# Quái canh cầu gạch Nether
	var bmid: Vector3 = (BRIDGE_GUARDS[0] + BRIDGE_GUARDS[BRIDGE_GUARDS.size() - 1]) * 0.5
	text += '
[node name="BridgeGuards" parent="." instance=ExtResource("encounter_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
persistent_id = &"level_3.bridge_guards"
trigger_size = Vector3(%s, %s, %s)
' % [bmid.x, bmid.y, bmid.z, BRIDGE_GUARD_TRIGGER.x, BRIDGE_GUARD_TRIGGER.y, BRIDGE_GUARD_TRIGGER.z]
	var bgi: int = 0
	for gpos: Vector3 in BRIDGE_GUARDS:
		bgi += 1
		var gl: Vector3 = gpos - bmid
		text += '
[node name="Guard%d" parent="BridgeGuards/Enemies" instance=ExtResource("room3_enemy_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
' % [bgi, gl.x, gl.y, gl.z]
	# Phòng 10: boss tạm + cổng ra hiện khi hạ boss
	text = text.insert(text.find("[sub_resource"), '[ext_resource type="PackedScene" path="%s" id="boss_fight_scene"]
[ext_resource type="PackedScene" path="%s" id="boss_scene"]
[ext_resource type="PackedScene" path="%s" id="vortex_visual_scene"]

' % [BOSS_FIGHT_SCENE, BOSS_SCENE, VORTEX_VISUAL_SCENE])
	var bf: Vector3 = BOSS_FIGHT_POS
	var bso: Vector3 = BOSS_SPAWN_OFFSET
	var exit_portal: Dictionary = ROOM10_EXIT_PORTAL
	var epp: Vector3 = exit_portal.p
	var epb: Basis = Basis(Vector3.UP, deg_to_rad(float(exit_portal.yaw)))
	text += '
[node name="Room10BossFight" parent="." instance=ExtResource("boss_fight_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
boss_scene = ExtResource("boss_scene")
persistent_id = &"%s"
trigger_size = Vector3(26, 4, 26)

[node name="Spawn" parent="Room10BossFight"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)

[node name="Room10ExitReveal" type="Node3D" parent="."]
script = ExtResource("flag_reveal_script")
flag = &"%s"

[node name="ExitPortal" parent="Room10ExitReveal" instance=ExtResource("vortex_visual_scene")]
transform = Transform3D(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
' % [bf.x, bf.y, bf.z, BOSS_FLAG, bso.x, bso.y, bso.z, BOSS_FLAG, epb.x.x, epb.y.x, epb.z.x, epb.x.y, epb.y.y, epb.z.y, epb.x.z, epb.y.z, epb.z.z, epp.x, epp.y, epp.z]
	# Thử thách cuối + cổng phòng boss
	text = text.insert(text.find("[sub_resource"), '[ext_resource type="PackedScene" path="%s" id="final_trial_scene"]
[ext_resource type="PackedScene" path="%s" id="trial_seal_scene"]

' % [FINAL_TRIAL_SCENE, TRIAL_SEAL_SCENE])
	var ft: Vector3 = FINAL_TRIAL_POS
	text += '
[node name="FinalTrial" parent="." instance=ExtResource("final_trial_scene")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)
unlock_flag = &"level_3.hub_south_gate"
persistent_id = &"level_3.final_trial"
duration = %s
' % [ft.x, ft.y, ft.z, FINAL_TRIAL_DURATION]
	for sd: Dictionary in FINAL_TRIAL_SEALS:
		var sl: Vector3 = (sd.p as Vector3) - ft
		var sb: Basis = Basis(Vector3.UP, deg_to_rad(float(sd.yaw)))
		text += '
[node name="%s" parent="FinalTrial/Seals" instance=ExtResource("trial_seal_scene")]
transform = Transform3D(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
' % [sd.name, sb.x.x, sb.y.x, sb.z.x, sb.x.y, sb.y.y, sb.z.y, sb.x.z, sb.y.z, sb.z.z, sl.x, sl.y, sl.z]
	var bg: Dictionary = BOSS_GATE
	var bgp: Vector3 = bg.p
	var bgb: Basis = Basis(Vector3.UP, deg_to_rad(float(bg.yaw)))
	text += '
[node name="%s" parent="." node_paths=PackedStringArray("sources") instance=ExtResource("cellar_gate_scene")]
transform = Transform3D(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
sources = [NodePath("../FinalTrial")]
persistent_id = &"level_3.boss_gate"
' % [bg.name, bgb.x.x, bgb.y.x, bgb.z.x, bgb.x.y, bgb.y.y, bgb.z.y, bgb.x.z, bgb.y.z, bgb.z.z, bgp.x, bgp.y, bgp.z]
	var hg: Dictionary = HUB_SOUTH_GATE
	var hgp: Vector3 = hg.p
	var hgb: Basis = Basis(Vector3.UP, deg_to_rad(float(hg.yaw)))
	text += '
[node name="%s" parent="." node_paths=PackedStringArray("sources") instance=ExtResource("cellar_gate_scene")]
transform = Transform3D(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
sources = [NodePath("../Room12HostageRescue")]
persistent_id = &"level_3.%s"
' % [hg.name, hgb.x.x, hgb.y.x, hgb.z.x, hgb.x.y, hgb.y.y, hgb.z.y, hgb.x.z, hgb.y.z, hgb.z.z, hgp.x, hgp.y, hgp.z, String(hg.name).to_snake_case()]
	text += '
[node name="BurnableBarriers" type="Node3D" parent="."]
'
	for b: Dictionary in BURNABLE_BARRIERS:
		var bpos: Vector3 = b.p
		var yb: Basis = Basis(Vector3.UP, deg_to_rad(float(b.yaw)))
		# Transform3D trong .tscn ghi theo hàng của basis (x.x, y.x, z.x, ...): mặt trước model (+Z) quay ra phía người chơi tới
		text += '
[node name="%s" parent="BurnableBarriers" instance=ExtResource("burnable_barrier_scene")]
transform = Transform3D(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
persistent_id = &"level_3.%s"
' % [b.name, yb.x.x, yb.y.x, yb.z.x, yb.x.y, yb.y.y, yb.z.y, yb.x.z, yb.y.z, yb.z.z, bpos.x, bpos.y, bpos.z, String(b.name).to_snake_case()]
	text = _add_room_focus(text)
	# Vào map lửa có sẵn kiếm (cầm tay), cung, kỹ năng Gió; chỉ bù phần thiếu (StarterKit phụ thuộc GameState nên gắn bằng text)
	text = text.insert(text.find("[sub_resource"), '[ext_resource type="Script" path="res://objects/core/spawn_point/starter_kit.gd" id="starter_kit_script"]
[ext_resource type="Resource" path="res://resources/combat/weapons/sword.tres" id="kit_sword"]
[ext_resource type="Resource" path="res://resources/combat/weapons/bow.tres" id="kit_bow"]
[ext_resource type="Resource" path="res://abilities/wind_blast/wind_blast.tres" id="kit_wind"]
[ext_resource type="Script" path="res://entities/_base/data/weapon_data.gd" id="kit_weapon_data"]
[ext_resource type="Script" path="res://abilities/ability_data.gd" id="kit_ability_data"]

')
	text += '''
[node name="StarterKit" type="Node" parent="."]
script = ExtResource("starter_kit_script")
weapons = Array[ExtResource("kit_weapon_data")]([ExtResource("kit_sword"), ExtResource("kit_bow")])
abilities = Array[ExtResource("kit_ability_data")]([ExtResource("kit_wind")])
held_weapon = ExtResource("kit_sword")
'''
	var file: FileAccess = FileAccess.open(abs_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Nhìn phòng (RoomFocus + một TierZone mỗi phòng, nhận player và quái): phòng khác tối, quái ngoài phòng ẩn, hạ tường phía camera.
## Script phụ thuộc Player nên gắn bằng text.
## Hộp phòng: hình chữ nhật r của phòng, từ dưới sàn ROOM_ZONE_BELOW tới trên sàn ROOM_ZONE_ABOVE (không chạm biển dung nham)
func _add_room_focus(text: String) -> String:
	text = text.insert(text.find("[sub_resource"), '[ext_resource type="Script" path="res://levels/_base/room_focus.gd" id="room_focus_script"]
[ext_resource type="Script" path="res://levels/_base/tier_zone.gd" id="tier_zone_script"]

')
	var subs: String = ""
	var nodes: String = '
[node name="RoomFocus" type="Node" parent="." node_paths=PackedStringArray("rooms_root")]
script = ExtResource("room_focus_script")
rooms_root = NodePath("../Rooms")
'
	for room: Dictionary in ROOMS:
		var r: Array = room.r
		var size: Vector3 = Vector3(float(r[2]) - float(r[0]), ROOM_ZONE_BELOW + ROOM_ZONE_ABOVE, float(r[3]) - float(r[1]))
		var c: Vector2 = room.get("place", Vector2((float(r[0]) + float(r[2])) * 0.5, (float(r[1]) + float(r[3])) * 0.5))
		var b: Basis = Basis(Vector3.UP, deg_to_rad(float(room.get("yaw", 0.0))))
		var cy: float = float(room.y) + (ROOM_ZONE_ABOVE - ROOM_ZONE_BELOW) * 0.5
		var zid: String = "RoomZone_" + str(room.id)
		subs += '[sub_resource type="BoxShape3D" id="%s"]
size = Vector3(%s, %s, %s)

' % [zid, size.x, size.y, size.z]
		var zname: String = _pascal(str(room.id)) + "Zone"
		nodes += '
[node name="%s" type="Area3D" parent="RoomFocus"]
transform = Transform3D(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
collision_layer = 0
collision_mask = 6
monitorable = false
script = ExtResource("tier_zone_script")

[node name="Shape" type="CollisionShape3D" parent="RoomFocus/%s"]
shape = SubResource("%s")
' % [zname, b.x.x, b.y.x, b.z.x, b.x.y, b.y.y, b.z.y, b.x.z, b.y.z, b.z.z, c.x, cy, c.y, zname, zid]
	text = text.insert(text.find("[node "), subs)
	return text + nodes


func _pascal(id: String) -> String:
	var out: String = ""
	for part: String in id.split("_"):
		out += part.capitalize().replace(" ", "")
	return out
