extends Node
## Kiểm tra lan can zone 3: đặt player trên đường nối / cầu rồi giữ phím đẩy ra mép trong vài giây,
## đạt khi player vẫn đứng trên sàn (không rơi, không chết).
## Chạy: godot --headless --path . res://tests/levels/fire_level_3/level_3_rail_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")

## Điểm đứng (x, y sàn, z) và hướng đẩy ra mép (x, z)
const CASES: Array[Dictionary] = [
	# Cổng khóa phòng 6 phải chặn thật
	{"name": "locked_gate_west_corridor", "p": Vector3(58, 4, 50), "push": Vector2(1, 0), "max_x": 64.0},
	{"name": "locked_gate_west_corridor_2", "p": Vector3(58, 4, 55), "push": Vector2(1, 0), "max_x": 64.0},
	{"name": "wide_corridor_north", "p": Vector3(80, 4, 50), "push": Vector2(0, -1)},
	{"name": "west_corridor_north", "p": Vector3(70, 4, 54), "push": Vector2(0, -1)},
	{"name": "west_corridor_south", "p": Vector3(82, 4, 54), "push": Vector2(0, 1)},
	{"name": "c2_path_west", "p": Vector3(22, 0, 18), "push": Vector2(-1, 0)},
	{"name": "ignite_stair_east", "p": Vector3(54, 1, 34), "push": Vector2(1, 0)},
	{"name": "hub_boss_north", "p": Vector3(142, 4, 50), "push": Vector2(0, -1)},
	{"name": "bridge_mid_nw", "p": Vector3(42, 4, 68), "push": Vector2(-1, -1)},
	{"name": "bridge_mid_se", "p": Vector3(42, 4, 68), "push": Vector2(1, 1)},
	# Cạnh cột lửa (lệch 2 m dọc cầu so với cột giữa): chỗ trước đây hở giữa cột và lan can
	{"name": "bridge_beside_pillar_nw", "p": Vector3(43.4, 4, 66.6), "push": Vector2(-1, -1)},
	{"name": "bridge_beside_pillar_se", "p": Vector3(43.4, 4, 66.6), "push": Vector2(1, 1)},
	{"name": "bridge_beside_pillar2_nw", "p": Vector3(36.9, 4, 73.1), "push": Vector2(-1, -1)},
	{"name": "bridge_beside_pillar2_se", "p": Vector3(48.1, 4, 61.9), "push": Vector2(1, 1)},
	# Sát cửa phòng bắt đầu (cách cửa ~1 m dọc cầu): chỗ trước đây lan can chưa bắt đầu
	{"name": "bridge_at_door_nw", "p": Vector3(28.7, 4, 81.3), "push": Vector2(-1, -1)},
	{"name": "bridge_at_door_se", "p": Vector3(28.7, 4, 81.3), "push": Vector2(1, 1)},
	{"name": "bridge_door_end_nw", "p": Vector3(31, 4, 79), "push": Vector2(-1, -1)},
	{"name": "bridge_door_end_se", "p": Vector3(31, 4, 79), "push": Vector2(1, 1)},
	{"name": "plaza_north_west", "p": Vector3(54, 4, 50), "push": Vector2(0, -1)},
	{"name": "plaza_east_north", "p": Vector3(62, 4, 50), "push": Vector2(1, 0)},
	{"name": "plaza_east_south", "p": Vector3(62, 4, 58), "push": Vector2(1, 0)},
	{"name": "plaza_south", "p": Vector3(60, 4, 58), "push": Vector2(0, 1)},
	{"name": "plaza_west", "p": Vector3(54, 4, 50), "push": Vector2(-1, 0)},
	{"name": "plaza_bridge_corner_nw", "p": Vector3(54, 4, 54), "push": Vector2(-1, -1)},
	{"name": "plaza_bridge_corner_se", "p": Vector3(57, 4, 58), "push": Vector2(1, 1)},
	{"name": "bridge_landing_north", "p": Vector3(56, 4, 54), "push": Vector2(0, -1)},
	{"name": "bridge_landing_west", "p": Vector3(56, 4, 54), "push": Vector2(-1, 0)},
]

## Thời gian giữ phím đẩy ra mép (giây)
@export var push_seconds: float = 2.5

var _player: Player


func _ready() -> void:
	# Không đọc / ghi save thật: save có cờ mở cổng thì các điểm đo cổng khoá sẽ sai
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
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
	for c: Dictionary in CASES:
		if not is_instance_valid(_player):
			push_error("Player đã bị xóa (chết ở ca trước)")
			failed += 1
			break
		_release()
		var start: Vector3 = c.p
		# Đứng ép vào lan can trên cầu sẽ bị bẫy dung nham phun: hồi máu mỗi ca để chỉ đo việc rơi
		_player.health.heal_full()
		_player.global_position = start + Vector3(0.0, 0.5, 0.0)
		_player.velocity = Vector3.ZERO
		for _i: int in range(20):
			await get_tree().physics_frame
		var push: Vector2 = c.push
		var t: float = 0.0
		while t < push_seconds:
			_press_towards(Vector3(push.x, 0.0, push.y).normalized())
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
		_release()
		for _i: int in range(20):
			await get_tree().physics_frame
		var pos: Vector3 = _player.global_position
		var ok: bool = pos.y > start.y - 1.0 and not _player.health.is_dead() and pos.x < float(c.get("max_x", INF))
		if not ok:
			failed += 1
		print("%s %s  dừng tại %s" % ["OK  " if ok else "FAIL", c.name, pos.snapped(Vector3.ONE * 0.1)])
	print("RAIL RESULT: %d/%d OK" % [CASES.size() - failed, CASES.size()])
	get_tree().quit(0 if failed == 0 else 1)


## Quy đổi hướng thế giới ra input theo camera, giống level_3_walk_test
func _press_towards(world_dir: Vector3) -> void:
	var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
	var forward: Vector3 = Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
	var right: Vector3 = Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
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
