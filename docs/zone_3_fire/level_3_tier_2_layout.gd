extends RefCounted
## Bố cục tier 2 map Lửa: "Lò Rèn Lòng Núi". Chỉ có dữ liệu; build_level_3.gd đọc và dựng giống tier 1
## (cùng quy tắc: biên phòng bội số 4, cửa ở tâm ô 4k + 2, mặt đi lại = y + 0,32, tầng 0 / +4 / +8).
## Khu riêng phía đông tier 1 (x 200 → 356), cách tier 1 một dải vực dung nham. Vào từ cổng xoáy phòng boss 10 của tier 1.
##
## Luồng chơi (thiết kế: tier_2_tower_design.md):
##   01 Cổng đáp → 02 Sảnh chân tháp (cửa tháp đóng) → 03 Hub; 3 khu làm theo thứ tự nào cũng được, mỗi khu một trận rồi một sách kỹ năng:
##   bắc (+8): 04 Xưởng gỗ → 05 Sảnh Slime (Khiên xỉ) → tường nứt → S Hang băng (bí mật)
##   đông (+4): 06 Xưởng tối → 07 Phòng tối om (Lốc Lửa)
##   nam (0): 08 Sân đấu → 09 Sảnh ma trơi (Móc kéo)
##   đủ 3 sách: cửa tháp (cửa bắc 02) mở → T1 → T2 → T3 → T4 → T5 → tầng boss (6 phòng ở góc tây bắc, cao dần) → khung cổng lên tier 3.

# Phòng: x0,z0,x1,z1 (biên, bội số 4), y sàn, cửa {cạnh: [tọa độ tâm ô 4k+2]}, kiểu tường. Cùng khóa với ROOMS tier 1
const ROOMS: Array[Dictionary] = [
	{"id": "t2_01_arrival", "r": [200, 44, 216, 60], "y": 4, "exits": {"E": [50]}, "wall": "full"},
	{"id": "t2_02_hammer_hall", "r": [224, 44, 256, 60], "y": 4, "exits": {"W": [50], "E": [50], "N": [250]}, "wall": "full"},
	{"id": "t2_03_forge_hub", "r": [264, 36, 292, 64], "y": 4, "exits": {"W": [50], "N": [278], "E": [50], "S": [278]}, "wall": "low"},
	# Rãnh vực ngang giữa phòng (hàng ô z 18, trừ gờ đá x 270 phía tây): qua bằng cầu treo hoặc gờ đá
	{"id": "t2_04_timber_works", "r": [268, 4, 288, 24], "y": 8, "exits": {"S": [278], "E": [14]}, "wall": "full",
		"holes": [[274, 18], [278, 18], [282, 18], [286, 18]]},
	{"id": "t2_05_slime_hall", "r": [296, 0, 320, 24], "y": 8, "exits": {"W": [14], "E": [14]}, "wall": "full"},
	{"id": "t2_06_dark_forge", "r": [300, 40, 320, 60], "y": 4, "exits": {"W": [50], "E": [50]}, "wall": "full"},
	# Phòng tối om: chỉ còn bệ vào (cột x 330) và bệ cuối (x 344..356, z 36..44); còn lại là vực, qua bằng ô sàn sụp
	{"id": "t2_07_blackout", "r": [328, 36, 356, 64], "y": 4, "exits": {"W": [50]}, "wall": "full",
		"keep": [[330, 46], [330, 50], [330, 54], [346, 38], [346, 42], [350, 38], [350, 42], [354, 38], [354, 42]]},
	{"id": "t2_08_lava_tide", "r": [264, 76, 292, 100], "y": 0, "exits": {"N": [278], "E": [86]}, "wall": "low"},
	{"id": "t2_09_wisp_hall", "r": [300, 76, 324, 100], "y": 0, "exits": {"W": [86]}, "wall": "full"},
	# Tháp xoắn ngang (thiết kế: docs/zone_3_fire/tier_2_tower_design.md): sáu phòng ở góc tây bắc, ngược chiều kim đồng hồ,
	# mỗi phòng cao hơn phòng trước 4 m. Boss ở phòng cao nhất (t2_t6_summit). Phòng 12 cũ đã bỏ.
	{"id": "t2_t1_forge", "r": [248, 24, 260, 36], "y": 8, "exits": {"S": [250], "W": [30]}, "wall": "full"},
	{"id": "t2_t2_anvil", "r": [224, 24, 240, 36], "y": 12, "exits": {"E": [30], "W": [30]}, "wall": "full"},
	{"id": "t2_t3_crucible", "r": [200, 24, 216, 36], "y": 16, "exits": {"E": [30], "N": [210]}, "wall": "full"},
	{"id": "t2_t4_chain", "r": [200, 0, 216, 16], "y": 20, "exits": {"S": [210], "E": [6]}, "wall": "full"},
	{"id": "t2_t5_smelter", "r": [224, 0, 240, 16], "y": 24, "exits": {"W": [6], "E": [6]}, "wall": "full"},
	{"id": "t2_t6_summit", "r": [248, 0, 264, 16], "y": 28, "exits": {"W": [6]}, "wall": "full"},
	{"id": "t2_s_ice_cave", "r": [328, 4, 348, 24], "y": 8, "exits": {"W": [14]}, "wall": "full"},
]

# Đường nối: chuỗi điểm (x, y, z) tâm ô 4 m, như CONNECTORS tier 1
const CONNECTORS: Array = [
	# 01 Cổng đáp → 02 Búa nện
	[Vector3(218, 4, 50), Vector3(222, 4, 50)],
	# 02 → 03 Hub
	[Vector3(258, 4, 50), Vector3(262, 4, 50)],
	# Hub → 04 Xưởng gỗ (lên +8)
	[Vector3(278, 4, 34), Vector3(278, 8, 26)],
	# 04 → 05 Sảnh Slime
	[Vector3(290, 8, 14), Vector3(294, 8, 14)],
	# 05 → Hang băng (sau tường nứt)
	[Vector3(322, 8, 14), Vector3(326, 8, 14)],
	# Hub → 06 Xưởng tối
	[Vector3(294, 4, 50), Vector3(298, 4, 50)],
	# 06 → 07 Phòng tối om
	[Vector3(322, 4, 50), Vector3(326, 4, 50)],
	# Hub → 08 Thủy triều (xuống 0)
	[Vector3(278, 4, 66), Vector3(278, 0, 74)],
	# 08 → 09 Sảnh ma trơi
	[Vector3(294, 0, 86), Vector3(298, 0, 86)],
	# Tháp: khe giữa hai phòng rộng 8 m = hai ô cầu thang (điểm đầu "S" = ô đầu đã là cầu thang, xem _path_cells)
	# 02 cửa bắc → T1
	["S", Vector3(250, 4, 42), Vector3(250, 8, 38)],
	# T1 → T2 → T3
	["S", Vector3(246, 8, 30), Vector3(242, 12, 30)],
	["S", Vector3(222, 12, 30), Vector3(218, 16, 30)],
	# T3 → T4 (đi lên phía bắc)
	["S", Vector3(210, 16, 22), Vector3(210, 20, 18)],
	# T4 → T5 → Boss
	["S", Vector3(218, 20, 6), Vector3(222, 24, 6)],
	["S", Vector3(242, 24, 6), Vector3(246, 28, 6)],
]

# Vật trang trí / mốc blockout theo phòng: [file (tương đối thư mục kit: "kit:" hoặc "inferno:"), vị trí thế giới (mặt sàn),
# yaw, tên node ("" = tự đặt)]. Mốc có tên là chỗ cắm cơ chế ở đợt sau
const DECOR: Dictionary = {
	"t2_01_arrival": [
		["kit:torch_standing", Vector3(214, 0, 46), 0.0, ""],
		["kit:torch_standing", Vector3(214, 0, 58), 0.0, ""],
	],
	"t2_02_hammer_hall": [
		["kit:chain_hanging_4m", Vector3(236, 0, 57), 0.0, ""],
	],
	"t2_03_forge_hub": [
		# Lò cao ở góc tây bắc Hub: cột mốc nhìn thấy từ xa; camera nhìn từ đông nam nên góc này không che player
		["inferno:tower_big_001", Vector3(268, 0, 40), 0.0, "ForgeFurnace"],
		["kit:fire_pit", Vector3(267, 0, 39), 0.0, ""],
	],
	"t2_04_timber_works": [
		["kit:crate_stack", Vector3(271, 0, 7), 0.0, ""],
		["kit:barrel", Vector3(285, 0, 7), 0.0, ""],
		["kit:barrel", Vector3(284, 0, 9), 0.0, ""],
	],
	"t2_05_slime_hall": [
		["inferno:pedestal_001", Vector3(312, 0, 4), 0.0, "SkillPedestalNorth"],
		["inferno:rock_mid_002", Vector3(301, 0, 20), 0.0, ""],
	],
	"t2_06_dark_forge": [
		["inferno:brazier_002", Vector3(303, 0, 43), 0.0, "ForgeLamp1"],
		["inferno:brazier_002", Vector3(317, 0, 43), 0.0, "ForgeLamp2"],
		["inferno:brazier_002", Vector3(303, 0, 57), 0.0, "ForgeLamp3"],
		["inferno:brazier_002", Vector3(317, 0, 57), 0.0, "ForgeLamp4"],
	],
	"t2_07_blackout": [
		["inferno:pedestal_001", Vector3(348, 0, 41), 0.0, "SkillPedestalEast"],
	],
	"t2_08_lava_tide": [
		["kit:lavafall_4m", Vector3(266, -8.32, 98), 0.0, ""],
	],
	"t2_09_wisp_hall": [
		["kit:torch_standing", Vector3(302, 0, 78), 0.0, ""],
		["inferno:pedestal_001", Vector3(316, 0, 92), 0.0, "SkillPedestalSouth"],
	],
	"t2_t1_forge": [
		["kit:torch_standing", Vector3(250, 0, 26), 0.0, ""],
		["kit:torch_standing", Vector3(258, 0, 26), 0.0, ""],
	],
	"t2_t2_anvil": [
		["kit:torch_standing", Vector3(226, 0, 26), 0.0, ""],
		["kit:torch_standing", Vector3(238, 0, 26), 0.0, ""],
	],
	"t2_t3_crucible": [
		["kit:torch_standing", Vector3(202, 0, 26), 0.0, ""],
		["kit:torch_standing", Vector3(214, 0, 26), 0.0, ""],
	],
	"t2_t4_chain": [
		["kit:torch_standing", Vector3(202, 0, 2), 0.0, ""],
		["kit:torch_standing", Vector3(214, 0, 2), 0.0, ""],
	],
	"t2_t5_smelter": [
		["kit:torch_standing", Vector3(226, 0, 2), 0.0, ""],
		["kit:torch_standing", Vector3(238, 0, 2), 0.0, ""],
	],
	"t2_t6_summit": [
		["kit:fire_pillar", Vector3(252, 0, 4), 0.0, ""],
		["kit:fire_pillar", Vector3(260, 0, 4), 0.0, ""],
		["kit:fire_pillar", Vector3(252, 0, 12), 0.0, ""],
		["kit:fire_pillar", Vector3(260, 0, 12), 0.0, ""],
		["inferno:pedestal_big_001", Vector3(256, 0, 9), 0.0, "BossDais"],
	],
	"t2_s_ice_cave": [
		["inferno:crag_001", Vector3(340, 0, 8), 0.0, ""],
		["inferno:rock_big_003", Vector3(344, 0, 20), 0.0, ""],
		["kit:campfire_big", Vector3(334, 0, 14), 0.0, "WarmCampfire"],
	],
}

## Cổng xoáy nối tier: cổng ra phòng boss 10 (tier 1) ↔ cổng đáp tier 2. Hoạt động khi đã hạ boss tier 1
const ARRIVAL_PORTAL: Dictionary = {"name": "Tier2ArrivalPortal", "p": Vector3(203, 4.32, 52), "yaw": 90.0}
## Miếu checkpoint ngay cổng đáp
const ARRIVAL_CHECKPOINT: Vector3 = Vector3(212, 4.32, 57)
const ARRIVAL_CHECKPOINT_ID: String = "level_3.t2_arrival"
## Miếu thêm ở Hub, sảnh chân tháp và giữa tháp (T3). Lưng miếu (trụ đèn) ở -Z; yaw 90 quay lưng về phía tây
const TOWER_CHECKPOINTS: Array[Dictionary] = [
	{"name": "HubCheckpoint", "p": Vector3(273, 4.32, 60.5), "yaw": 0.0, "id": "level_3.t2_hub"},
	{"name": "FoyerCheckpoint", "p": Vector3(252.5, 4.32, 57), "yaw": 0.0, "id": "level_3.t2_foyer"},
	{"name": "TowerMidCheckpoint", "p": Vector3(203.5, 16.32, 30), "yaw": 90.0, "id": "level_3.t2_tower_mid"},
]

## Vùng tier (TierZone): ẩn hình tier kia khi player ở trong, hiện tên khu. x0, z0, x1, z1, y dưới, y trên
# Trần y 40: sàn tầng boss y 28 + 9 m trên sàn
const TIER_ZONE: Array = [196, -4, 364, 104, -4.0, 40.0]
const AREA_TITLE: String = "res://resources/world/zones/areas/fire/tier_2.tres"

# ---------- Đợt 2: cơ chế phòng ----------
## (Búa nện phòng 02, lõi lò + ống dẫn Hub + cửa lõi phòng 08, thủy triều phòng 08, mini-boss phòng 10, phòng 11 và lối tắt
## đã bỏ ở giai đoạn 5 của tháp; file object trong objects/ vẫn còn để dùng lại.)

## Phòng 04 (Xưởng gỗ, ý tưởng Thịnh): đồ dễ cháy, lửa lan sang vật cạnh nhau.
## Đường 1: đốt màn dây leo đầu cầu rồi chạy qua cầu treo trước khi lửa lan làm cầu sập.
## Đường 2: đốt chồng thùng chắn gờ đá phía tây (thùng dầu cạnh đó sẽ nổ: đứng xa).
## Dây leo chắn cửa ra phía đông: đốt một lần là nhớ. Các vật khác dựng lại khi player rời phòng.
## Mỗi phần tử: loại (vines / crate / oil / bridge), tên, vị trí, yaw, cờ (rỗng = dựng lại được)
const ROOM4_FLAMMABLES: Array = [
	["bridge", "RopeBridge", Vector3(278, 8.32, 18), 0.0, ""],
	["vines", "BridgeVines", Vector3(278, 8.32, 15.6), 0.0, ""],
	["crate", "LedgeCrates", Vector3(270, 8.32, 18), 0.0, ""],
	["oil", "LedgeOilBarrel", Vector3(271.2, 8.32, 20.6), 0.0, ""],
	["vines", "ExitVines", Vector3(287.65, 8.32, 14), 90.0, "level_3.t2_exit_vines"],
]
const ROOM4_ZONE: String = "RoomFocus/T204TimberWorksZone"
## Phòng 05: tường nứt chắn lối sang Hang băng, chỉ vỡ khi bị nổ
const CRACKED_WALL: Dictionary = {"name": "IceCaveWall", "p": Vector3(319.65, 8.32, 14), "yaw": 90.0, "id": "level_3.t2_ice_cave_wall"}

## Phòng 07 (Phòng tối om, ý tưởng Thắng): tối hẳn, không quầng sáng. Hình nộm ở bệ vào để chém nạp năng lượng
## (cung tốn năng lượng mỗi phát: năng lượng = số tên). Bắn Cung Lửa để lại đốm lửa sáng 15 s soi đường.
## Đường đi là các ô sàn sụp 2 x 2 m bắc qua vực: dẫm lên 0,9 s thì rơi hẳn, không hiện lại (không quay về nạp được).
## Các điểm gãy của đường ô (x, z); ô đặt cách nhau 2 m dọc theo đường
## Ô cuối (345, 44) chồng lên mép bệ cuối 1 m: ô vừa sụp thì chân player đã ở trên bệ
const BLACKOUT_PATH: Array[Vector2] = [Vector2(333, 50), Vector2(339, 50), Vector2(339, 56), Vector2(345, 56), Vector2(345, 44)]
const BLACKOUT_Y: float = 4.32
const BLACKOUT_DUMMY: Vector3 = Vector3(330, 4.32, 45.6)
## Vùng tối của phòng (AABB thế giới)
const BLACKOUT_DARK_BOX: AABB = AABB(Vector3(328, -2, 36), Vector3(28, 12, 28))
## Cổng xoáy về Hub ở bệ cuối (mở khi đã nhặt sách Lốc Lửa ở bệ cuối) và cổng tương ứng ở Hub
const BLACKOUT_PORTALS: Array[Dictionary] = [
	{"name": "BlackoutReturnPortal", "p": Vector3(355, 4.32, 40), "yaw": -90.0, "target": "HubEastPortal"},
	# Cổng Hub dựa tường bắc, quay mặt về nam (vào trong Hub): điểm đáp nằm trước mặt cổng
	{"name": "HubEastPortal", "p": Vector3(286, 4.32, 37.6), "yaw": 0.0, "target": "BlackoutReturnPortal"},
]
const BLACKOUT_PORTAL_FLAG: String = "level_3.t2_shard_east"

## Phòng 09 (Sảnh ma trơi, ý tưởng Thắng): 6 ma trơi bay quanh tâm phòng, chỉ tên Cung Gió dập được.
## Quái sinh theo đợt khi player trong phòng; dập hết ma trơi thì ngừng sinh và hiện rương.
const WISP_CENTER: Vector3 = Vector3(312, 0.32, 88)
const WISP_FLAG: String = "level_3.t2_wisps_cleared"
## Mỗi ma trơi: bán trục (x, z), vòng / giây, góc xuất phát (0..1)
const WISPS: Array = [
	[Vector2(3.0, 2.0), 0.10, 0.0], [Vector2(3.0, 2.0), 0.10, 0.5],
	[Vector2(6.0, 4.5), -0.07, 0.15], [Vector2(6.0, 4.5), -0.07, 0.65],
	[Vector2(9.0, 8.0), 0.05, 0.35], [Vector2(9.0, 8.0), 0.05, 0.85],
]
## Quái sinh theo đợt (Sói Bóng, từ đợt 4) và chỗ sinh
const WAVE_ENEMY_SCENE: String = "res://entities/enemies/volcano/shadow_wolf/shadow_wolf.tscn"
const WAVE_POINTS: Array[Vector3] = [Vector3(303, 0.32, 79), Vector3(321, 0.32, 79), Vector3(321, 0.32, 97)]
const WAVE_PER_WAVE: int = 3
const WISP_ZONE: String = "RoomFocus/T209WispHallZone"
const WISP_CHEST: Vector3 = Vector3(320, 0.32, 96)

## Hang băng (bí mật, ý tưởng Thịnh): vùng lạnh phủ cả phòng; ở trong mà không được sưởi thì chậm và mất máu dần
## tới còn 1. Sưởi bằng lửa trại giữa hang (vùng ấm bán kính 3 m), đuốc cháy, hoặc kiếm ghép Lửa. Rương thưởng cuối hang.
const ICE_COLD_BOX: AABB = AABB(Vector3(328, 4, 4), Vector3(20, 14, 20))
const ICE_WARM: Vector3 = Vector3(334, 8.32, 14)
const ICE_WARM_RADIUS: float = 3.0
const ICE_CHEST: Vector3 = Vector3(345, 8.32, 7)

## Kỹ năng lò rèn gắn vào player (bộ gắn state); bản 2 không còn sách trao kỹ năng trong tier 2
const FORGE_SKILL_FILES: Array[String] = [
	"res://abilities/forge/fire_cyclone/fire_cyclone.tres",
	"res://abilities/forge/grapple/grapple.tres",
	"res://abilities/forge/slag_shield/slag_shield.tres",
]
## Bản 2 (tier_2_tower_design.md mục 0): mỗi khu một mảnh vỡ thay sách, hiện ra khi hạ xong trận của khu (FlagReveal).
## Bệ đá (DECOR "SkillPedestal*") ở cùng x, z; mảnh cao hơn sàn phòng 0,86 m. [vị trí, tên node, cờ mảnh, cờ trận của khu]
## Cờ mảnh phải khớp resources/world/puzzles/forge_shards.tres
const FORGE_SHARD_DATA: String = "res://resources/world/puzzles/forge_shards.tres"
## Bệ công tắc (bản 2 giai đoạn 2): lệch bắc tâm Hub 4 m; vòng truyền tống giai đoạn 4 mở ở tâm Hub (278, 50), trước mặt bệ
const FORGE_SHARD_ALTAR: Vector3 = Vector3(278, 4.32, 46)
## Thử thách u tối (bản 2 giai đoạn 3): trụ, đồng hồ, vùng tối nằm trong .tres; vùng tối phòng 07 tạm tắt lúc chạy
const DARK_TRIAL_DATA: String = "res://resources/world/puzzles/dark_trial.tres"
const FORGE_SHARDS: Array = [
	[Vector3(312, 8.86, 4), "NorthShard", "level_3.t2_shard_north", "level_3.t2_slime_hall"],
	[Vector3(348, 4.86, 41), "EastShard", "level_3.t2_shard_east", "level_3.t2_dark_forge_pack"],
	[Vector3(316, 0.86, 92), "SouthShard", "level_3.t2_shard_south", "level_3.t2_wisps_cleared"],
]
## Vòng móc: phòng 04 treo trên bờ nam của hào (móc từ bờ bắc bay qua hào)
const GRAPPLE_RINGS: Array = [
	["Room4Ring", Vector3(284, 11.6, 22)],
]

## Đợt 4: quái Lửa thật. Mỗi trận là một Encounter: quái ngủ sẵn trong phòng, player bước vào vùng trigger thì thức,
## hạ hết thì lưu cờ id (vào lại không gặp nữa). Sói trong cùng trận đi chung một bầy (WolfPack: mỗi lúc một con vồ).
## Loại quái: khóa của ENEMY_SCENES. Vị trí là chỗ đứng (mặt sàn)
const ENEMY_SCENES: Dictionary = {
	"caster": "res://entities/enemies/volcano/fire_caster/fire_caster.tscn",
	"wolf": "res://entities/enemies/volcano/shadow_wolf/shadow_wolf.tscn",
	"slime": "res://entities/enemies/volcano/lava_slime/lava_slime.tscn",
}
const ENCOUNTERS: Array[Dictionary] = [
	# Hub: trận mở màn, 2 Quỷ Xương Lửa đứng xa + 2 sói áp sát
	{"name": "T2HubAmbush", "p": Vector3(278, 4.32, 50), "trigger": Vector3(26, 4, 26), "id": "level_3.t2_hub_ambush",
		"enemies": [["caster", Vector3(270, 4.32, 58)], ["caster", Vector3(288, 4.32, 42)],
			["wolf", Vector3(284, 4.32, 56)], ["wolf", Vector3(272, 4.32, 46)]]},
	# Xưởng gỗ: Quỷ Xương Lửa góc tây nam (không chắn cửa vào x 278 / chỗ đáp vòng móc x 284) bắn qua hào lúc player qua cầu
	{"name": "T2TimberCaster", "p": Vector3(278, 8.32, 14), "trigger": Vector3(20, 4, 20), "id": "level_3.t2_timber_caster",
		"enemies": [["caster", Vector3(271, 8.32, 22.5)]]},
	# Sảnh Slime: 4 slime; slime nổ cạnh tường nứt phía đông là gợi ý mở Hang băng
	{"name": "T2SlimeHall", "p": Vector3(308, 8.32, 12), "trigger": Vector3(24, 4, 24), "id": "level_3.t2_slime_hall",
		"enemies": [["slime", Vector3(302, 8.32, 8)], ["slime", Vector3(314, 8.32, 8)],
			["slime", Vector3(304, 8.32, 18)], ["slime", Vector3(316, 8.32, 17)]]},
	# Xưởng tối: bầy 3 sói
	{"name": "T2DarkForgePack", "p": Vector3(310, 4.32, 50), "trigger": Vector3(20, 4, 20), "id": "level_3.t2_dark_forge_pack",
		"enemies": [["wolf", Vector3(306, 4.32, 46)], ["wolf", Vector3(314, 4.32, 46)], ["wolf", Vector3(310, 4.32, 55)]]},
	# Tháp (thiết kế tier_2_tower_design.md mục 5): mỗi tầng một trận, id = cờ mở cổng tầng (FloorGate). T4 là Slime Mẹ (TOWER_MOTHER).
	# Phòng nhỏ (12 x 12 đến 16 x 16) nên ít quái; chừa ô cửa (tâm ô 4k + 2) và đường vào / ra
	{"name": "TowerT1Wolves", "p": Vector3(254, 8.32, 30), "trigger": Vector3(11, 4, 11), "id": "level_3.t2_t1_cleared",
		"enemies": [["wolf", Vector3(254, 8.32, 27)], ["wolf", Vector3(257.5, 8.32, 31)], ["wolf", Vector3(251.5, 8.32, 32)],
			["wolf", Vector3(257, 8.32, 34)]]},
	{"name": "TowerT2Casters", "p": Vector3(232, 12.32, 30), "trigger": Vector3(15, 4, 11), "id": "level_3.t2_t2_cleared",
		"enemies": [["caster", Vector3(228, 12.32, 26.5)],
			["slime", Vector3(235, 12.32, 27)], ["slime", Vector3(235, 12.32, 33)], ["slime", Vector3(231, 12.32, 30)]]},
	{"name": "TowerT3Slimes", "p": Vector3(208, 16.32, 30), "trigger": Vector3(15, 4, 11), "id": "level_3.t2_t3_cleared",
		"enemies": [["slime", Vector3(208, 16.32, 34)], ["slime", Vector3(212, 16.32, 34.5)], ["slime", Vector3(213, 16.32, 26.5)],
			["slime", Vector3(207.5, 16.32, 27)], ["slime", Vector3(209, 16.32, 30.5)],
			["wolf", Vector3(214, 16.32, 32)], ["wolf", Vector3(206, 16.32, 34.5)], ["wolf", Vector3(211, 16.32, 28.5)]]},
	{"name": "TowerT5Mixed", "p": Vector3(232, 24.32, 8), "trigger": Vector3(15, 4, 15), "id": "level_3.t2_t5_cleared",
		"enemies": [["caster", Vector3(236.5, 24.32, 3)], ["caster", Vector3(236.5, 24.32, 13)],
			["wolf", Vector3(229.5, 24.32, 3.5)], ["wolf", Vector3(229.5, 24.32, 12.5)], ["wolf", Vector3(233, 24.32, 8)]]},
]

## T4 của tháp: Slime Mẹ, id = cờ mở FloorGate4. Phòng 16 x 16 nên giữ thông số mặc định
## (tối đa 4 con); thiết kế ban đầu muốn rút còn 2 con, bỏ vì cần tạo biến thể scene + resource, xem lại sau khi đo
const TOWER_MOTHER: Dictionary = {"name": "TowerT4MotherFight", "p": Vector3(208, 20.32, 8), "trigger": Vector3(14, 4, 14),
	"spawn": Vector3(206, 20.32, 4), "scene": "res://entities/enemies/volcano/lava_slime/mother/slime_mother.tscn",
	"scene_id": "t2_mother_scene", "id": "level_3.t2_t4_cleared"}
## Boss tier 2 phòng 12 (tạm: boss tier 1 nhiều máu hơn). Hạ xong hiện khung cổng lên tier 3 (chưa nối đi đâu)
const BOSS: Dictionary = {"name": "T2BossFight", "p": Vector3(256, 28.32, 9), "trigger": Vector3(14, 4, 14),
	"spawn": Vector3(256, 28.32, 5), "scene": "res://entities/bosses/forge_boss/forge_boss.tscn",
	"scene_id": "t2_boss_scene", "id": "level_3.t2_boss_defeated"}
const TIER_3_PORTAL: Dictionary = {"name": "Tier3PortalFrame", "p": Vector3(256, 28.32, 1.5), "yaw": 180.0}
## Cổng đá mở theo cờ ("flag" một cờ, hoặc "flags" nhiều cờ: mở khi TẤT CẢ đã bật).
## Tháp (thiết kế tier_2_tower_design.md mục 4): TowerGate (cửa bắc 02) mở khi có cả 3 sách kỹ năng; mỗi tầng T1..T5 có cổng ở cửa ra,
## mở khi hạ hết trận quái tầng đó (cờ level_3.t2_tN_cleared do Encounter của tầng lưu: Encounter đặt ở giai đoạn 3).
## Cổng nằm trong phòng, cách tường 0,35 m, yaw 0 cho cửa bắc/nam, 90 cho cửa đông/tây
const T2_FLAG_GATES: Array[Dictionary] = [
	{"name": "TowerGate", "p": Vector3(250, 4.32, 44.35), "yaw": 0.0,
		# Bản 2: lối 02 → T1 đóng tới khi tháp mở (cờ do thử thách u tối đặt, giai đoạn 3-4); vào tháp bằng truyền tống giữa Hub
		"flags": ["level_3.t2_tower_unlocked"], "id": "level_3.t2_tower_gate"},
	{"name": "FloorGate1", "p": Vector3(248.35, 8.32, 30), "yaw": 90.0, "flag": "level_3.t2_t1_cleared", "id": "level_3.t2_floor_gate_1"},
	{"name": "FloorGate2", "p": Vector3(224.35, 12.32, 30), "yaw": 90.0, "flag": "level_3.t2_t2_cleared", "id": "level_3.t2_floor_gate_2"},
	{"name": "FloorGate3", "p": Vector3(210, 16.32, 24.35), "yaw": 0.0, "flag": "level_3.t2_t3_cleared", "id": "level_3.t2_floor_gate_3"},
	{"name": "FloorGate4", "p": Vector3(215.65, 20.32, 6), "yaw": 90.0, "flag": "level_3.t2_t4_cleared", "id": "level_3.t2_floor_gate_4"},
	{"name": "FloorGate5", "p": Vector3(239.65, 24.32, 6), "yaw": 90.0, "flag": "level_3.t2_t5_cleared", "id": "level_3.t2_floor_gate_5"},
]
