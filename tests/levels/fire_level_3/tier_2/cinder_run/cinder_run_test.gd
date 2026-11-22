extends Node
## Test phòng 10 tự chọn (sau phòng 7, tier 2 map Lửa) bằng phím, va chạm và node thật:
## 1. Có đủ 29 ô sàn sụp; cổng về Hub của phòng 7 đã dời khỏi lối đi tiếp (bệ cuối phòng 7 có cửa đông).
## 2. Đi bộ thật từ bệ cuối phòng 7 qua cửa đông, hết đường ô sàn sụp tới bệ cuối phòng 10; vào phòng 10 thì tối (DarkZone).
## 3. Ô đã đi qua rơi hẳn (6 s sau vẫn không hiện lại).
## 4. Cổng ở bệ cuối phòng 10 luôn bật; bước vào thì về Hub.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/tier_2/cinder_run/cinder_run_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/tier_2/tier_2.tscn")
const TILE_COUNT: int = 29

var _player: Player
var _level: ZoneRoot
var _failed: int = 0
var _checks: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_flag(&"level_3.boss_defeated")
	_level = LEVEL.instantiate()
	_level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	await _frames(30)
	_player.health.max_health = 9999
	_player.health.heal_full()
	await _t_layout()
	await _t_path()
	await _t_portal()
	print("CINDER RUN RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


func _t_layout() -> void:
	var tiles := _level.get_node(^"Tier2Mechanics/Room10CinderRun/Path").get_children()
	_check(tiles.size() == TILE_COUNT, "đường phòng 10 có %d ô sàn sụp (cần %d)" % [tiles.size(), TILE_COUNT])
	var old_portal := _level.get_node(^"Tier2Mechanics/Room07Blackout/Portals/BlackoutReturnPortal") as Node3D
	var door := Vector3(150, 0, -8.6)
	_check(Vector2(old_portal.global_position.x - door.x, old_portal.global_position.z - door.z).length() > 5.0, "cổng phòng 7 dời khỏi lối đi tiếp (cách cửa đông %.1f m)" % Vector2(old_portal.global_position.x - door.x, old_portal.global_position.z - door.z).length())


func _t_path() -> void:
	var tiles := _level.get_node(^"Tier2Mechanics/Room10CinderRun/Path").get_children()
	var dark := _level.get_node(^"Tier2Mechanics/Room07Blackout/DarkZone") as DarkZone
	var fell := {"n": 0}
	for t: Node in tiles:
		(t as CrumblingFloor).crumbled.connect(func() -> void: fell["n"] = int(fell["n"]) + 1)
	# Bệ cuối phòng 7 (bố cục 350, 42) -> cửa đông -> cầu ô -> bệ vào phòng 10 -> đường vòng -> bệ cuối phòng 10
	_teleport(Vector3(144, 0.1, -8.6), Vector3.RIGHT)
	await _frames(20)
	var route: Array[Vector3] = [Vector3(150, 0, -8.6), Vector3(160, 0, -8.6), Vector3(171, 0, -8.6), Vector3(171, 0, 1.4),
		Vector3(163, 0, 1.4), Vector3(163, 0, 13.4), Vector3(174, 0, 13.4), Vector3(178, 0, 13.4)]
	var ok := true
	var was_dark := false
	var sun := _level.get_node(^"FireLighting/SunLight") as DirectionalLight3D
	var lit_spots: Array[String] = []
	# Ghi ánh sáng mỗi frame vật lý: qua cửa đông phòng 7 (x 150) được 1 s (cho tối dần) thì phải tối suốt
	var since_door := {"t": 0.0}
	var watch := func() -> void:
		if _player.global_position.x < 150.0:
			return
		since_door["t"] = float(since_door["t"]) + get_physics_process_delta_time()
		if float(since_door["t"]) > 1.0 and sun.light_energy > 0.05 and lit_spots.size() < 5:
			lit_spots.append("%s nắng %.2f" % [_player.global_position.snapped(Vector3.ONE * 0.1), sun.light_energy])
	get_tree().physics_frame.connect(watch)
	for p: Vector3 in route:
		ok = ok and await _run_to(p, 300)
		was_dark = was_dark or dark.is_dark
		if _player.global_position.y < -1.32:
			ok = false
			break
	get_tree().physics_frame.disconnect(watch)
	_check(ok and _player.global_position.y > -0.32, "đi bộ hết đường ô sàn sụp tới bệ cuối phòng 10 (%s)" % _player.global_position.snapped(Vector3.ONE * 0.1))
	_check(was_dark and lit_spots.is_empty(), "từ cửa đông phòng 7 tới bệ cuối phòng 10 tối suốt (chỗ còn sáng: %s)" % [lit_spots])
	await _frames(int(6.0 * 60))
	var restored := 0
	for t: Node in tiles:
		if (t.get_node("CollisionShape3D") as CollisionShape3D).disabled == false:
			restored += 1
	_check(int(fell["n"]) >= tiles.size() - 1 and restored <= 1, "ô đã đi qua rơi hẳn: %d / %d ô rơi, 6 s sau %d ô còn va chạm" % [fell["n"], tiles.size(), restored])


func _t_portal() -> void:
	var portal := _level.get_node(^"Tier2Mechanics/Room10CinderRun/Portals/CinderReturnPortal") as WarpPortal
	_check(portal.is_active(), "cổng bệ cuối phòng 10 luôn bật (chưa nhặt mảnh Đông)")
	for _i: int in range(240):
		var to := portal.global_position - _player.global_position
		to.y = 0.0
		if to.length() < 0.3 or _player.global_position.x < 94.0:
			break
		_press_towards(to.normalized())
		await get_tree().physics_frame
	_release()
	await _wait_until(func() -> bool: return _player.global_position.x < 94.0, 180)
	await _frames(30)
	var pos := _player.global_position
	_check(pos.x > 58.0 and pos.x < 86.0 and pos.z > -14.6 and pos.z < 13.4 and _player.is_on_floor(), "bước vào cổng phòng 10: về Hub (%s)" % pos.snapped(Vector3.ONE * 0.1))
func _run_to(target: Vector3, max_frames: int) -> bool:
	for _i: int in range(max_frames):
		var pos := _player.global_position
		var flat := Vector2(target.x - pos.x, target.z - pos.z)
		if flat.length() <= 0.5:
			_release()
			return true
		if pos.y < target.y - 2.0:
			_release()
			return false
		_press_towards(Vector3(flat.x, 0, flat.y).normalized())
		await get_tree().physics_frame
	_release()
	return false


func _teleport(pos: Vector3, facing: Vector3) -> void:
	_player.teleport(pos, facing)
	(_player.get_node("CameraRig") as CameraRig).snap()


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(1)


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
	for a: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back", &"aim", &"attack"]:
		Input.action_release(a)


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

