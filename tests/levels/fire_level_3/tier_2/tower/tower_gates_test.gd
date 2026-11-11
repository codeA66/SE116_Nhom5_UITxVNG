extends Node
## Test giai đoạn 2 của tháp tier 2 map Lửa (docs/zone_3_fire/tier_2_tower_design.md mục 4), đo bằng đi bộ thật:
## 1. Mới vào: cổng tháp (cửa bắc 02) và 5 cổng tầng đều đóng, đi bộ tới đâu cũng bị chặn.
## 2. Cổng tháp cần ĐỦ 3 sách kỹ năng: có 2 sách vẫn đóng, đủ 3 mới mở.
## 3. Mỗi cổng tầng chỉ theo cờ trận quái của tầng đó (đặt ngoài thứ tự: tầng 3 xong trước thì chỉ cổng 3 mở).
## 4. Mở rồi thì đi qua được từng cổng.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/tier_2/tower/tower_gates_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")
const SHARDS: Array[StringName] = [&"level_3.t2_shard_north", &"level_3.t2_shard_east", &"level_3.t2_shard_south"]
const TOWER_FLAG: StringName = &"level_3.t2_tower_unlocked"
## Mỗi cổng: tên node, điểm đứng cách cổng ~4 m phía trước, hướng đi, trục đo (x hoặc z), mốc của cổng, chiều qua cổng (+1 / -1)
const GATES: Array[Dictionary] = [
	{"name": "TowerGate", "from": Vector3(250, 4.42, 49), "dir": Vector3.FORWARD, "axis": "z", "at": 44.35, "sign": -1.0},
	{"name": "FloorGate1", "from": Vector3(254, 8.42, 30), "dir": Vector3.LEFT, "axis": "x", "at": 248.35, "sign": -1.0, "flag": &"level_3.t2_t1_cleared"},
	{"name": "FloorGate2", "from": Vector3(232, 12.42, 30), "dir": Vector3.LEFT, "axis": "x", "at": 224.35, "sign": -1.0, "flag": &"level_3.t2_t2_cleared"},
	{"name": "FloorGate3", "from": Vector3(210, 16.42, 30), "dir": Vector3.FORWARD, "axis": "z", "at": 24.35, "sign": -1.0, "flag": &"level_3.t2_t3_cleared"},
	{"name": "FloorGate4", "from": Vector3(208, 20.42, 6), "dir": Vector3.RIGHT, "axis": "x", "at": 215.65, "sign": 1.0, "flag": &"level_3.t2_t4_cleared"},
	{"name": "FloorGate5", "from": Vector3(232, 24.42, 6), "dir": Vector3.RIGHT, "axis": "x", "at": 239.65, "sign": 1.0, "flag": &"level_3.t2_t5_cleared"},
]

var _player: Player
var _level: ZoneRoot
var _fights: Node3D
var _failed: int = 0
var _checks: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	get_tree().create_timer(200.0, true, true).timeout.connect(func() -> void:
		print("TOWER GATES RESULT: TIMEOUT")
		get_tree().quit(2))
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_flag(&"level_3.boss_defeated")
	_level = LEVEL.instantiate()
	_level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	await _frames(30)
	# Quái các tầng thức khi người chơi vào phòng và tự lưu cờ khi hạ: gỡ để chỉ đo cổng (quái đo ở fights_test)
	for child: Node in _level.get_node(^"Tier2Fights").get_children():
		if String(child.name).begins_with("TowerT"):
			child.free()
	_player.health.max_health = 9999
	_player.health.heal_full()
	_fights = _level.get_node(^"Tier2Fights") as Node3D
	await _t_closed()
	await _t_tower_gate_books()
	await _t_floor_gates_out_of_order()
	await _t_pass_through()
	print("TOWER GATES RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


func _t_closed() -> void:
	for g: Dictionary in GATES:
		var gate := _fights.get_node(NodePath(String(g.name))) as StoneGate
		_check(gate != null and not gate.is_open, "%s: mới vào thì đóng" % g.name)
		var pos := await _walk(g.from, g.dir, 150)
		_check(_progress(g, pos) < 0.0, "%s: đi bộ vào cổng bị chặn (%s = %.2f, cổng ở %.2f)" % [g.name, g.axis, _axis(g, pos), g.at])


func _t_tower_gate_books() -> void:
	var gate := _fights.get_node(^"TowerGate") as StoneGate
	for flag: StringName in SHARDS:
		GameState.set_flag(flag)
	await _frames(int(1.8 * 60.0))
	_check(not gate.is_open, "cổng tháp: đủ 3 mảnh vỡ vẫn đóng (bản 2 vào tháp bằng truyền tống)")
	GameState.set_flag(TOWER_FLAG)
	await _frames(int(1.8 * 60.0))
	_check(gate.is_open, "cổng tháp: có cờ tháp mở thì mở")


func _t_floor_gates_out_of_order() -> void:
	GameState.set_flag(GATES[3].flag)
	await _frames(int(1.8 * 60.0))
	var states: Array[bool] = []
	for i: int in range(1, GATES.size()):
		states.append((_fights.get_node(NodePath(String(GATES[i].name))) as StoneGate).is_open)
	_check(states == [false, false, true, false, false], "chỉ tầng 3 xong: chỉ cổng 3 mở (%s)" % str(states))


func _t_pass_through() -> void:
	for i: int in range(1, GATES.size()):
		GameState.set_flag(GATES[i].flag)
	await _frames(int(1.8 * 60.0))
	for g: Dictionary in GATES:
		var gate := _fights.get_node(NodePath(String(g.name))) as StoneGate
		_check(gate.is_open, "%s: mở" % g.name)
		var pos := await _walk(g.from, g.dir, 150)
		_check(_progress(g, pos) > 0.5, "%s: mở rồi đi bộ qua được (%s = %.2f)" % [g.name, g.axis, _axis(g, pos)])


## Đã đi quá cổng bao nhiêu mét (âm = còn ở phía trước cổng)
func _progress(g: Dictionary, pos: Vector3) -> float:
	return (_axis(g, pos) - float(g.at)) * float(g.sign)


func _axis(g: Dictionary, pos: Vector3) -> float:
	return pos.x if g.axis == "x" else pos.z


func _walk(start: Vector3, dir: Vector3, n: int) -> Vector3:
	_teleport(start, dir)
	await _frames(15)
	for _i: int in range(n):
		_press_towards(dir)
		await get_tree().physics_frame
	_release()
	await _frames(5)
	return _player.global_position


func _teleport(pos: Vector3, facing: Vector3) -> void:
	_player.teleport(pos, facing)
	(_player.get_node("CameraRig") as CameraRig).snap()


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


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_failed += 1
