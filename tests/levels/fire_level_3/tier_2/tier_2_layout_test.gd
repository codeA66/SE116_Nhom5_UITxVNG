extends Node
## Kiểm tra blockout tier 2 map Lửa ("Lò Rèn Lòng Núi") bằng va chạm và input thật:
## 1. Cấu trúc: phòng tier 1 / tier 2 nằm ở Rooms/Tier1, Rooms/Tier2; đủ 16 phòng tier 2 (9 phòng + Hang băng + 6 phòng tháp).
## 2. Đứng được: đặt player vào từng phòng / đoạn nối, đo đứng trên sàn.
## 3. Tự đi: bấm hướng di chuyển thật qua mọi tuyến (cửa, cầu, bậc thang lên +8 / xuống 0, tháp lên +24).
## 4. Lan can: giữ phím đẩy ra mép đường nối / bậc thang vài giây, không rơi.
## 5. Nối tier: cổng phòng boss 10 tắt khi chưa hạ boss; có cờ boss thì bước vào sang cổng đáp tier 2 và đi ngược lại được.
##    Vào tier 2 thì tier 1 ẩn hình (TierZone), ra lại thì hiện.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/tier_2/tier_2_layout_test.tscn
## (bỏ --headless, thêm "-- --capture" để chụp ảnh từng phòng + toàn cảnh có tên phòng vào output/fire_level_3/tier_2/)

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")
const BOSS_FLAG: StringName = &"level_3.boss_defeated"
const TIER_2_ROOM_COUNT: int = 16

## Điểm đứng (x, y sàn, z)
const SPOTS: Array[Dictionary] = [
	{"name": "t2_01_arrival", "p": Vector3(208, 4, 50)},
	{"name": "t2_02_hammer_hall", "p": Vector3(236, 4, 52)},
	{"name": "t2_03_forge_hub", "p": Vector3(270, 4, 44)},
	{"name": "t2_04_timber_works", "p": Vector3(274, 8, 14)},
	{"name": "t2_05_slime_hall", "p": Vector3(308, 8, 14)},
	{"name": "t2_06_dark_forge", "p": Vector3(310, 4, 50)},
	# Phòng 07 chỉ còn bệ vào và bệ cuối (đường ô sàn sụp đo ở blackout_test)
	{"name": "t2_07_blackout", "p": Vector3(330, 4, 50)},
	{"name": "t2_07_blackout_end", "p": Vector3(350, 4, 40)},
	{"name": "t2_08_lava_tide", "p": Vector3(278, 0, 88)},
	{"name": "t2_09_wisp_hall", "p": Vector3(306, 0, 82)},
	# Tháp xoắn ngang: sáu phòng cao dần 8 / 12 / 16 / 20 / 24 / 28
	{"name": "t2_t1_forge", "p": Vector3(254, 8, 30)},
	{"name": "t2_t2_anvil", "p": Vector3(232, 12, 30)},
	{"name": "t2_t3_crucible", "p": Vector3(208, 16, 30)},
	{"name": "t2_t4_chain", "p": Vector3(208, 20, 8)},
	{"name": "t2_t5_smelter", "p": Vector3(232, 24, 8)},
	{"name": "t2_t6_summit", "p": Vector3(252, 28, 6)},
	{"name": "t2_s_ice_cave", "p": Vector3(342, 8, 12)},
	{"name": "path_hub_timber_stair", "p": Vector3(278, 5, 30)},
	# Hai ô cầu thang mỗi khe 8 m: ô đầu (y thấp) và ô sau (y cao)
	{"name": "path_tower_stair_foyer_a", "p": Vector3(250, 5, 42)},
	{"name": "path_tower_stair_foyer_b", "p": Vector3(250, 7, 38)},
	{"name": "path_tower_stair_t1_t2", "p": Vector3(246, 9, 30)},
	{"name": "path_tower_stair_t2_t3", "p": Vector3(222, 13, 30)},
	{"name": "path_tower_stair_t3_t4", "p": Vector3(210, 17, 22)},
	{"name": "path_tower_stair_t4_t5", "p": Vector3(218, 21, 6)},
	{"name": "path_tower_stair_t5_t6", "p": Vector3(242, 25, 6)},
]

## Tuyến tự đi: chuỗi điểm (x, y sàn, z)
const LEGS: Array[Dictionary] = [
	{"name": "arrival_foyer_hub", "points": [Vector3(208, 4, 52), Vector3(216, 4, 50), Vector3(240, 4, 50), Vector3(262, 4, 50), Vector3(268, 4, 50)]},
	{"name": "hub_timber_slime_ice (lên +8)", "points": [Vector3(278, 4, 40), Vector3(278, 4, 34), Vector3(278, 8, 26), Vector3(278, 8, 12), Vector3(286, 8, 14), Vector3(310, 8, 14), Vector3(330, 8, 14), Vector3(340, 8, 18)]},
	{"name": "hub_dark_blackout", "points": [Vector3(288, 4, 52), Vector3(294, 4, 50), Vector3(326, 4, 50), Vector3(330, 4, 50)]},
	{"name": "hub_tide_wisp (xuống 0)", "points": [Vector3(278, 4, 58), Vector3(278, 4, 66), Vector3(278, 0, 74), Vector3(278, 0, 82), Vector3(294, 0, 86), Vector3(306, 0, 86)]},
	# Cổng tháp và cổng tầng đã mở nhờ cờ đặt ở _ready; đi bộ thật từ sảnh chân tháp lên tầng boss, không nhảy
	{"name": "foyer_to_summit (tháp, lên +24, không nhảy)", "points": [Vector3(250, 4, 50), Vector3(250, 4, 42), Vector3(250, 8, 34),
			Vector3(250, 8, 30), Vector3(246, 8, 30), Vector3(238, 12, 30), Vector3(226, 12, 30), Vector3(222, 12, 30),
			Vector3(214, 16, 30), Vector3(210, 16, 28), Vector3(210, 16, 22), Vector3(210, 20, 14), Vector3(210, 20, 6),
			Vector3(218, 20, 6), Vector3(228, 24, 6), Vector3(238, 24, 6), Vector3(242, 24, 6), Vector3(252, 28, 6)]},
]

## Đẩy ra mép: điểm đứng và hướng đẩy (x, z)
const RAILS: Array[Dictionary] = [
	{"name": "arrival_path_north", "p": Vector3(220, 4, 50), "push": Vector2(0, -1)},
	{"name": "arrival_path_south", "p": Vector3(220, 4, 50), "push": Vector2(0, 1)},
	{"name": "hub_dark_path_south", "p": Vector3(296, 4, 50), "push": Vector2(0, 1)},
	{"name": "timber_stair_east", "p": Vector3(278, 5, 30), "push": Vector2(1, 0)},
	{"name": "timber_stair_west", "p": Vector3(278, 5, 30), "push": Vector2(-1, 0)},
	{"name": "tide_stair_west", "p": Vector3(278, 3, 70), "push": Vector2(-1, 0)},
	{"name": "wisp_path_north", "p": Vector3(296, 0, 86), "push": Vector2(0, -1)},
	{"name": "tower_stair_foyer_east", "p": Vector3(250, 5, 42), "push": Vector2(1, 0)},
	{"name": "tower_stair_foyer_west", "p": Vector3(250, 7, 38), "push": Vector2(-1, 0)},
	{"name": "tower_stair_t1_t2_north", "p": Vector3(246, 9, 30), "push": Vector2(0, -1)},
	{"name": "tower_stair_t1_t2_south", "p": Vector3(246, 9, 30), "push": Vector2(0, 1)},
	{"name": "tower_stair_t3_t4_east", "p": Vector3(210, 17, 22), "push": Vector2(1, 0)},
	{"name": "tower_stair_t4_t5_south", "p": Vector3(218, 21, 6), "push": Vector2(0, 1)},
	{"name": "ice_path_south", "p": Vector3(324, 8, 14), "push": Vector2(0, 1)},
]

## Nhãn tên phòng cho ảnh toàn cảnh (x, z)
const LABELS: Array[Dictionary] = [
	{"text": "01 Cổng đáp", "p": Vector2(208, 52)},
	{"text": "02 Sảnh chân tháp", "p": Vector2(240, 52)},
	{"text": "03 HUB LÒ CAO", "p": Vector2(278, 44)},
	{"text": "04 Xưởng gỗ", "p": Vector2(278, 12)},
	{"text": "05 Sảnh Slime", "p": Vector2(308, 12)},
	{"text": "S Hang băng\n(bí mật)", "p": Vector2(338, 14)},
	{"text": "06 Xưởng tối", "p": Vector2(310, 50)},
	{"text": "07 Phòng tối om", "p": Vector2(342, 50)},
	{"text": "08 Sân đấu", "p": Vector2(278, 88)},
	{"text": "09 Sảnh ma trơi", "p": Vector2(312, 88)},
	{"text": "T1 (y8)", "p": Vector2(254, 30)},
	{"text": "T2 (y12)", "p": Vector2(232, 30)},
	{"text": "T3 (y16)", "p": Vector2(208, 30)},
	{"text": "T4 (y20)", "p": Vector2(208, 8)},
	{"text": "T5 (y24)", "p": Vector2(232, 8)},
	{"text": "BOSS (y28)", "p": Vector2(256, 8)},
]

@export var settle_frames: int = 45
@export var reach_distance: float = 0.8
@export var seconds_per_meter: float = 0.6
@export var segment_padding: float = 3.0
@export var push_seconds: float = 2.5
@export_dir var capture_dir: String = "res://output/fire_level_3/tier_2/"

var _player: Player
var _level: ZoneRoot
var _failed: int = 0
var _checks: int = 0
var _capture: bool = false


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
	# Coi như đã hạ boss tier 1 từ trước khi vào map (như save thật): bật cờ lúc chạy thì trận boss phòng 10 vẫn khởi động
	GameState.set_flag(BOSS_FLAG)
	# Bài này đo đường đi của map: coi như đã đốt dây leo cửa ra phòng 04, phá tường nứt phòng 05, mở cửa lõi lò phòng 08,
	# dập xong ma trơi phòng 09 (không sinh quái chắn đường)
	# (cơ chế đo riêng ở flammables_test)
	# Đợt 4: trận quái đã thắng (quái không chắn / cắn lúc tự đi), đã hạ Slime Mẹ (mở cổng boss + lối tắt)
	for flag: StringName in [&"level_3.t2_exit_vines", &"level_3.t2_ice_cave_wall", &"level_3.t2_wisps_cleared",
			&"level_3.t2_hub_ambush", &"level_3.t2_timber_caster", &"level_3.t2_slime_hall", &"level_3.t2_dark_forge_pack",
			# Tháp: đã mở (bản 2: cờ thử thách u tối) và đã hạ trận từng tầng (mở cổng tầng); cổng đo riêng ở tower_gates_test
			&"level_3.t2_tower_unlocked",
			&"level_3.t2_t1_cleared", &"level_3.t2_t2_cleared", &"level_3.t2_t3_cleared", &"level_3.t2_t4_cleared", &"level_3.t2_t5_cleared"]:
		GameState.set_flag(flag)
	_level = LEVEL.instantiate()
	_level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	_run.call_deferred()


func _run() -> void:
	for _i: int in range(30):
		await get_tree().physics_frame
	if _player == null:
		push_error("Player không xuất hiện")
		get_tree().quit(1)
		return
	_player.health.max_health = 9999
	_player.health.heal_full()
	_capture = "--capture" in OS.get_cmdline_user_args()
	if _capture:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dir))
	# Màn dây leo đầu cầu phòng 04 không có cờ (dựng lại khi rời phòng): gỡ hẳn để đo đường qua cầu
	_level.get_node(^"Tier2Mechanics/Room04Flammables/BridgeVines").free()
	_t_structure()
	await _t_portal()
	await _t_spots()
	for leg: Dictionary in LEGS:
		await _walk_leg(leg)
	for c: Dictionary in RAILS:
		await _push_rail(c)
	if _capture:
		await _capture_overview()
	_release()
	print("TIER 2 LAYOUT RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


# ---------- Các mục ----------

func _t_structure() -> void:
	var tier_1: Node = _level.get_node_or_null(^"Rooms/Tier1")
	var tier_2: Node = _level.get_node_or_null(^"Rooms/Tier2")
	var rooms_2: int = 0
	if tier_2:
		for child: Node in tier_2.get_children():
			if String(child.name).begins_with("T2"):
				rooms_2 += 1
	_check(tier_1 != null and tier_1.get_node_or_null(^"Room10Boss") != null and tier_1.get_node_or_null(^"CellarCover") != null,
			"tier 1 nằm ở Rooms/Tier1 (có Room10Boss, CellarCover)")
	_check(rooms_2 == TIER_2_ROOM_COUNT and tier_2.get_node_or_null(^"Connectors") != null,
			"tier 2 nằm ở Rooms/Tier2: %d phòng + đường nối" % rooms_2)


func _t_portal() -> void:
	var reveal: FlagReveal = _level.get_node(^"Room10ExitReveal") as FlagReveal
	var arrival: WarpPortal = _level.get_node(^"Tier2Links/Tier2ArrivalPortal") as WarpPortal
	var tier_1: Node3D = _level.get_node(^"Rooms/Tier1") as Node3D
	var tier_2: Node3D = _level.get_node(^"Rooms/Tier2") as Node3D
	var exit: WarpPortal = reveal.get_node(^"ExitPortal") as WarpPortal
	# Chưa hạ boss thì cả hai cổng tắt và cổng phòng 10 bị FlagReveal giấu: cùng một cờ
	_check(reveal.flag == BOSS_FLAG and exit.required_flag == BOSS_FLAG and arrival.required_flag == BOSS_FLAG
			and exit.target == arrival and arrival.target == exit, "hai cổng trỏ vào nhau, chỉ mở khi có cờ hạ boss tier 1")
	# Đi từ điểm đáp (lệch sang bên) vào tâm cổng, tránh bệ đá ngay trước tâm cổng
	_teleport(exit.get_arrival().global_position + Vector3(0, 0.3, 0))
	await _frames(20)
	await _walk_into(exit, 120)
	await _wait_until(func() -> bool: return _player.global_position.x > 196.0, 180)
	await _frames(40)
	var pos := _player.global_position
	_check(exit.is_active() and pos.x > 200.0 and pos.x < 216.0 and absf(pos.y - 4.32) < 0.6 and _player.is_on_floor(),
			"hạ boss: bước vào cổng phòng 10 sang cổng đáp tier 2 (%s)" % pos.snapped(Vector3.ONE * 0.1))
	_check(not tier_1.is_visible_in_tree() and tier_2.is_visible_in_tree(), "ở tier 2: tier 1 ẩn hình, tier 2 hiện")
	if _capture:
		await _shot("portal_arrival.png")
	# Đi ngược về
	_teleport(arrival.get_arrival().global_position + Vector3(0, 0.3, 0))
	await _frames(20)
	await _walk_into(arrival, 120)
	await _wait_until(func() -> bool: return _player.global_position.x < 190.0, 180)
	await _frames(40)
	pos = _player.global_position
	_check(pos.x > 160.0 and pos.x < 176.0 and _player.is_on_floor(), "cổng đáp tier 2 đưa về phòng boss 10 (%s)" % pos.snapped(Vector3.ONE * 0.1))
	_check(tier_1.is_visible_in_tree() and not tier_2.is_visible_in_tree(), "về tier 1: tier 2 ẩn hình, tier 1 hiện")


func _t_spots() -> void:
	for spot: Dictionary in SPOTS:
		var target: Vector3 = spot.p
		_teleport(target + Vector3(0, 1.5, 0))
		await _frames(settle_frames)
		var pos := _player.global_position
		_check(_player.is_on_floor() and pos.y > target.y - 1.0, "đứng được: %s (y %.2f)" % [spot.name, pos.y])
		if _capture and String(spot.name).begins_with("t2_"):
			await _shot("room_%s.png" % spot.name)


func _walk_leg(leg: Dictionary) -> void:
	var points: Array = leg.points
	_release()
	_teleport((points[0] as Vector3) + Vector3(0, 0.5, 0))
	await _frames(20)
	for i: int in range(1, points.size()):
		var target: Vector3 = points[i]
		var from := _player.global_position
		var limit: float = Vector2(target.x - from.x, target.z - from.z).length() * seconds_per_meter + segment_padding
		var lowest: float = minf((points[i - 1] as Vector3).y, target.y)
		var t := 0.0
		while true:
			var pos := _player.global_position
			var flat := Vector2(target.x - pos.x, target.z - pos.z)
			if flat.length() <= reach_distance:
				break
			if pos.y < lowest - 1.5 or _player.health.is_dead():
				_release()
				_check(false, "tự đi %s: rơi tại %s (đoạn %d)" % [leg.name, pos.snapped(Vector3.ONE * 0.1), i])
				return
			if t > limit:
				_release()
				_check(false, "tự đi %s: kẹt tại %s (đích %s)" % [leg.name, pos.snapped(Vector3.ONE * 0.1), target])
				return
			_press_towards(Vector3(flat.x, 0, flat.y).normalized())
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
	_release()
	_check(true, "tự đi: %s" % leg.name)


func _push_rail(c: Dictionary) -> void:
	var p: Vector3 = c.p
	_teleport(p + Vector3(0, 0.6, 0))
	await _frames(20)
	var push: Vector2 = c.push
	var dir := Vector3(push.x, 0, push.y).normalized()
	var frames := int(push_seconds * 60.0)
	var fell := false
	for _i: int in range(frames):
		_press_towards(dir)
		await get_tree().physics_frame
		if _player.global_position.y < p.y - 2.0:
			fell = true
			break
	_release()
	await _frames(10)
	_check(not fell and _player.is_on_floor(), "lan can giữ: %s (y %.2f)" % [c.name, _player.global_position.y])


# ---------- Tiện ích ----------

func _teleport(pos: Vector3) -> void:
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	(_player.get_node("CameraRig") as CameraRig).snap()


## Bấm đi thẳng vào cổng tới khi bị dịch chuyển (hoặc hết số frame)
func _walk_into(portal: Node3D, max_frames: int) -> void:
	var start := _player.global_position
	for _i: int in range(max_frames):
		var to := portal.global_position - _player.global_position
		to.y = 0.0
		if to.length() < 0.3 or _player.global_position.distance_to(start) > 20.0:
			break
		_press_towards(to.normalized())
		await get_tree().physics_frame
	_release()


func _wait_until(pred: Callable, max_frames: int) -> bool:
	for _i: int in range(max_frames):
		if pred.call():
			return true
		await get_tree().physics_frame
	return pred.call()


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_failed += 1


## Quy đổi hướng thế giới ra input theo camera, giống player.get_move_direction()
func _press_towards(world_dir: Vector3) -> void:
	var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
	var forward := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
	var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	_set_axis(&"move_right", &"move_left", world_dir.dot(right))
	_set_axis(&"move_back", &"move_forward", -world_dir.dot(forward))


func _set_axis(positive: StringName, negative: StringName, value: float) -> void:
	if value > 0.05:
		Input.action_press(positive, clampf(value, 0.0, 1.0))
		Input.action_release(negative)
	elif value < -0.05:
		Input.action_press(negative, clampf(-value, 0.0, 1.0))
		Input.action_release(positive)
	else:
		Input.action_release(positive)
		Input.action_release(negative)


func _release() -> void:
	for a: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		Input.action_release(a)


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(capture_dir.path_join(file))


## Toàn cảnh tier 2 nhìn chéo và từ trên xuống, có tên phòng
func _capture_overview() -> void:
	_teleport(Vector3(278, 5, 44))
	await _frames(30)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.far = 400.0
	_level.add_child(cam)
	var center := Vector3(280.0, 0.0, 50.0)
	var basis := Basis.from_euler(Vector3(deg_to_rad(-60.0), deg_to_rad(20.0), 0.0))
	cam.global_transform = Transform3D(basis, center + basis.z * 150.0)
	cam.size = 130.0
	cam.current = true
	await _frames(10)
	await _shot("overview.png")
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-90.0), 0.0, 0.0)), center + Vector3(0, 120, 0))
	cam.size = 175.0
	await _frames(5)
	await _shot("top_down.png")
	for entry: Dictionary in LABELS:
		var label := Label3D.new()
		label.text = str(entry.text)
		label.position = Vector3(entry.p.x, 30.0, entry.p.y)
		label.rotation_degrees.x = -90.0
		label.pixel_size = 0.04
		label.font_size = 56
		label.outline_size = 16
		label.modulate = Color(1.0, 0.95, 0.6)
		label.no_depth_test = true
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_level.add_child(label)
	await _frames(5)
	await _shot("top_down_labeled.png")
