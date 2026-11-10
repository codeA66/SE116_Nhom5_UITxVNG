extends Node
## Cho player TỰ ĐI bằng input thật (move_*) qua các tuyến của blockout zone 3: qua cửa phòng, cầu, cầu thang.
## Mỗi chặng bắt đầu bằng cách đặt player ở điểm đầu, sau đó chỉ bấm hướng di chuyển tới từng điểm.
## Lỗi khi: không tới được điểm trong thời gian cho phép (kẹt tường / bậc), hoặc rơi / chết.
## Chạy: godot --path . res://tests/levels/fire_level_3/level_3_walk_test.tscn  (thêm "-- --capture" để chụp lúc lỗi)

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")

## Mỗi chặng: điểm (x, y sàn, z). y chỉ dùng để phát hiện rơi.
const LEGS: Array[Dictionary] = [
	{"name": "c2_nw (hầm tầng 0)", "points": [Vector3(22, 0, 30), Vector3(22, 0, 22), Vector3(22, 0, 14), Vector3(34, 0, 14), Vector3(46, 0, 18)]},
	{"name": "nw_ignite_chain_ambush_treasure", "points": [Vector3(46, 0, 18), Vector3(50, 0, 22), Vector3(50, 0, 30), Vector3(54, 0, 30), Vector3(54, 4, 42), Vector3(62, 4, 42), Vector3(66, 4, 34), Vector3(66, 8, 22), Vector3(70, 8, 14)]},
	{"name": "spawn_nether_bridge_corridor_hub (cầu chéo 45°)", "points": [Vector3(15, 4, 95), Vector3(19.5, 4, 90.5), Vector3(28, 4, 82), Vector3(56, 4, 54), Vector3(60, 4, 54)]},
	# Cổng khóa đầu lối đi hướng tây có va chạm thật: đi từ sau cổng, giữa lối đi rộng, vào Hub
	{"name": "west_corridor_wide_hub", "points": [Vector3(68, 4, 52), Vector3(94, 4, 50), Vector3(110, 4, 54), Vector3(118, 4, 54)]},
	# Cổng khóa ở lối tây phòng 6 có va chạm thật: đi từ trong phòng 6 vào Hub
	{"name": "choke_point_hub", "points": [Vector3(100, 4, 54), Vector3(110, 4, 54), Vector3(118, 4, 54)]},
	{"name": "c2_east_loop_to_ambush", "points": [Vector3(26, 0, 30), Vector3(38, 0, 30), Vector3(50, 0, 30), Vector3(54, 0, 30), Vector3(54, 4, 42), Vector3(62, 4, 42)]},
	{"name": "ambush_to_plaza", "points": [Vector3(62, 4, 40), Vector3(62, 4, 54), Vector3(58, 4, 54)]},
	# Phòng 8 có 4 lồng bọc rào ở 4 góc: đi vòng qua giữa phòng (tâm 114, 14)
	{"name": "hub_arena_side_room (lên +8)", "points": [Vector3(122, 4, 42), Vector3(122, 4, 34), Vector3(122, 8, 22), Vector3(114, 8, 22), Vector3(114, 8, 14), Vector3(98, 8, 14), Vector3(90, 8, 14)]},
	{"name": "hub_to_boss", "points": [Vector3(126, 4, 50), Vector3(146, 4, 50), Vector3(160, 4, 50)]},
	# Phòng 12: tời cứu con tin ở (100, 78.5) và giàn gỗ phía bắc hố: đi vòng phía nam tời
	{"name": "south_treasure_lava_secret_hub", "points": [Vector3(74, 0, 74), Vector3(74, 0, 78), Vector3(90, 0, 78), Vector3(94, 0, 78), Vector3(94, 0, 81), Vector3(106, 0, 81), Vector3(106, 0, 78), Vector3(118, 0, 78), Vector3(122, 0, 74), Vector3(122, 4, 62), Vector3(120, 4, 56)]},
	# Lối Hub → 14 đã chặn: phòng 14 chỉ vào từ quảng trường tàn tích 15 (lên +4)
	{"name": "ruins_to_crumbling (lên 4)", "points": [Vector3(142, 0, 98), Vector3(146, 0, 94), Vector3(146, 4, 82), Vector3(146, 4, 74), Vector3(140, 4, 72)]},
]

## Khoảng cách (m, mặt phẳng XZ) coi như đã tới điểm
@export var reach_distance: float = 0.8
## Thời gian tối đa cho mỗi đoạn, tính theo độ dài đoạn (giây / m) cộng thêm phần đệm
@export var seconds_per_meter: float = 0.6
@export var segment_padding: float = 3.0
@export_dir var capture_dir: String = "res://output/fire_level_3/qa/"

var _player: Player


func _ready() -> void:
	# Bài này đo đường đi của map: coi như đã đốt rào gỗ và mở cửa phòng 2 (luồng Phun lửa đo riêng ở flame_breath_flow_test).
	# Không ghi save thật
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	for flag: StringName in [&"level_3.ignite_chain_barrier", &"level_3.room_2_east_gate", &"level_3.room_2_north_gate", &"level_3.room_3_west_gate", &"level_3.west_gate_south", &"level_3.west_gate_north", &"level_3.room8_west_gate", &"level_3.hub_south_gate", &"level_3.boss_gate", &"level_3.room11_cage_cleared", &"level_3.room12_hostage_rescued", &"level_3.room12_guards", &"level_3.room8_cage_1", &"level_3.room8_cage_2", &"level_3.room8_cage_3", &"level_3.room8_cage_4", &"level_3.room14_cage_west", &"level_3.room14_cage_east", &"level_3.bridge_guards", &"level_3.boss_defeated"]:
		GameState.set_flag(flag)
	var level: ZoneRoot = LEVEL.instantiate()
	level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(level)
	_run.call_deferred()


func _run() -> void:
	for _i: int in range(30):
		await get_tree().physics_frame
	if _player == null:
		push_error("Player không xuất hiện")
		get_tree().quit(1)
		return
	var failed: int = 0
	for leg: Dictionary in LEGS:
		var ok: bool = await _walk_leg(leg)
		if not ok:
			failed += 1
	_release()
	print("WALK RESULT: %d/%d chặng OK" % [LEGS.size() - failed, LEGS.size()])
	get_tree().quit(0 if failed == 0 else 1)


func _walk_leg(leg: Dictionary) -> bool:
	var points: Array = leg.points
	var start: Vector3 = points[0]
	_release()
	_player.global_position = start + Vector3(0.0, 0.5, 0.0)
	_player.velocity = Vector3.ZERO
	for _i: int in range(20):
		await get_tree().physics_frame
	var elapsed_total: float = 0.0
	for i: int in range(1, points.size()):
		var target: Vector3 = points[i]
		var from: Vector3 = _player.global_position
		var limit: float = Vector2(target.x - from.x, target.z - from.z).length() * seconds_per_meter + segment_padding
		var t: float = 0.0
		var lowest_floor: float = minf(points[i - 1].y, target.y)
		while true:
			var pos: Vector3 = _player.global_position
			var flat: Vector2 = Vector2(target.x - pos.x, target.z - pos.z)
			if flat.length() <= reach_distance:
				break
			if pos.y < lowest_floor - 1.5 or _player.health.is_dead():
				return await _fail(leg, i, "rơi/chết tại %s" % pos.snapped(Vector3.ONE * 0.1))
			if t > limit:
				return await _fail(leg, i, "kẹt tại %s (đích %s)" % [pos.snapped(Vector3.ONE * 0.1), target])
			_press_towards(Vector3(flat.x, 0.0, flat.y).normalized())
			await get_tree().physics_frame
			var dt: float = get_physics_process_delta_time()
			t += dt
			elapsed_total += dt
	_release()
	print("OK   %s  (%.1f s)" % [leg.name, elapsed_total])
	return true


func _fail(leg: Dictionary, index: int, reason: String) -> bool:
	_release()
	print("FAIL %s  đoạn %d: %s" % [leg.name, index, reason])
	if "--capture" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dir))
		await RenderingServer.frame_post_draw
		var file: String = "walk_fail_%s.png" % String(leg.name).get_slice(" ", 0)
		get_viewport().get_texture().get_image().save_png(capture_dir.path_join(file))
	return false


## Quy đổi hướng thế giới ra input theo camera, giống cách player.get_move_direction() đọc input
func _press_towards(world_dir: Vector3) -> void:
	var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
	var forward: Vector3 = Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
	var right: Vector3 = Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	var x: float = world_dir.dot(right)
	var y: float = -world_dir.dot(forward)
	_set_axis(&"move_right", &"move_left", x)
	_set_axis(&"move_back", &"move_forward", y)


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
	for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		Input.action_release(action)
