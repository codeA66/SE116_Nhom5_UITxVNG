extends Node
## Giày dung nham ở phòng 9 + cổng chặn cửa nam Hub (va chạm, input và node thật):
## 1. Cổng cửa nam Hub (xuống khu bí mật 13) chặn đường.
## 2. Rương phòng 9 lúc đầu đóng, giày ẩn trong rương.
## 3. Bấm interact ở rương: nắp mở, giày bay lên; bấm interact lần nữa: nhận Giày Dung Nham.
## 4. Có giày, đi vào cầu ngập dung nham: không mất máu, không bị cháy.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/lava_boots_test.tscn (-- --capture để chụp ảnh)

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")

var _player: Player
var _level: Node
var _failed: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
	_level = LEVEL.instantiate()
	(_level as ZoneRoot).player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	_run.call_deferred()


func _run() -> void:
	await _frames(30)
	# 1. Cổng nam Hub
	var gate: StoneGate = _level.get_node("HubSouthGate") as StoneGate
	await _walk_from(Vector3(122, 4.4, 56), Vector3(122, 4, 66))
	_check(not gate.is_open and _player.global_position.z < 60.0, "cổng cửa nam Hub chặn (z = %.2f)" % _player.global_position.z)
	# 2. Rương đóng
	var chest: AbilityChest = _level.get_node("Room9LavaBootsChest") as AbilityChest
	var reward: Node3D = chest.get_node("Reward") as Node3D
	var lid: Node3D = chest.get_node(chest.lid_path) as Node3D
	_check(not chest.is_opened and not reward.visible and absf(lid.rotation.x) < 0.01, "rương phòng 9 đóng, giày ẩn")
	# 3. Mở rương rồi nhận giày
	_player.teleport(chest.global_position + Vector3(1.3, 0.1, 0), Vector3.LEFT)
	await _frames(15)
	await _press(&"interact")
	await _frames(70)
	_check(chest.is_opened and reward.visible and lid.rotation.x < -1.0, "bấm interact: nắp mở (%.0f độ), giày bay lên" % rad_to_deg(lid.rotation.x))
	await _capture("lava_boots_chest_open.png")
	await _press(&"interact")
	var t: float = 0.0
	while not _player.has_ability(&"lava_boots") and t < 8.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_check(_player.has_ability(&"lava_boots"), "bấm interact lần nữa: nhận Giày Dung Nham (%.1f s)" % t)
	var acquire: Node = reward.get_node_or_null("AbilityAcquireVfx") if is_instance_valid(reward) else null
	t = 0.0
	while not _player.controls_enabled and t < 10.0:
		if is_instance_valid(acquire):
			acquire.call(&"close_reveal")
		await _frames(10)
		t += 10.0 / 60.0
	_check(_player.controls_enabled, "đóng bảng nhận: điều khiển lại được")
	# 4. Đi vào dung nham
	var burn: BurnableComponent = _player.get_node("BurnableComponent") as BurnableComponent
	_player.health.heal_full()
	var full: int = _player.health.current_health
	await _walk_from(Vector3(74, 4.4, 53), Vector3(74, 2, 63))
	await _frames(90)
	_check(_player.global_position.z > 58.0 and _player.health.current_health == full and not burn.is_burning(), "có giày: đi trên dung nham (z = %.1f) không mất máu, không cháy" % _player.global_position.z)
	print("LAVA BOOTS RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _walk_from(start: Vector3, target: Vector3) -> void:
	_player.teleport(start)
	await _frames(10)
	var t: float = 0.0
	while t < 3.0:
		var flat: Vector2 = Vector2(target.x - _player.global_position.x, target.z - _player.global_position.z)
		if flat.length() < 0.6:
			break
		var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
		var right: Vector3 = Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
		var forward: Vector3 = Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
		var d: Vector3 = Vector3(flat.x, 0.0, flat.y).normalized()
		_axis(&"move_right", &"move_left", d.dot(right))
		_axis(&"move_back", &"move_forward", -d.dot(forward))
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	for a: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		Input.action_release(a)


func _axis(positive: StringName, negative: StringName, value: float) -> void:
	if value > 0.05:
		Input.action_press(positive, clampf(value, 0.0, 1.0))
		Input.action_release(negative)
	elif value < -0.05:
		Input.action_press(negative, clampf(-value, 0.0, 1.0))
		Input.action_release(positive)
	else:
		Input.action_release(positive)
		Input.action_release(negative)


func _capture(file: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/fire_level_3/qa/" + file)


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	print("%s %s" % ["OK  " if ok else "FAIL", what])
