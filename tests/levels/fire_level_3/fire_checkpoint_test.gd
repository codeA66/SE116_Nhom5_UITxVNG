extends Node
## Checkpoint miếu Lửa ở quảng trường đầu cầu (va chạm, input và node thật):
## 1. Lúc đầu miếu tắt (không lửa, không đèn).
## 2. Bị thương rồi đi bộ chạm miếu: lưu checkpoint level_3.plaza, hồi đầy máu, miếu sáng.
## 3. Điểm hồi sinh của miếu: đứng vững trên sàn quảng trường, không kẹt trong thân miếu.
## 4. Miếu thứ hai ở phòng 6: chạm thì chuyển checkpoint sang đó, điểm hồi sinh đứng vững.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/fire_checkpoint_test.tscn (-- --capture để chụp ảnh)

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
	# Quái canh cầu (đo riêng ở boss_bridge_test) đuổi tới quảng trường đánh sau lúc hồi máu: coi như đã dọn
	GameState.set_flag(&"level_3.bridge_guards")
	_level = LEVEL.instantiate()
	(_level as ZoneRoot).player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	_run.call_deferred()


func _run() -> void:
	await _frames(30)
	var cp: Checkpoint = _level.get_node("PlazaCheckpoint") as Checkpoint
	var light: OmniLight3D = cp.get_node("FireShrineVisual/Light")
	var flame: Node3D = cp.get_node("FireShrineVisual/Model").find_child("Flame*", true, false) as Node3D
	# 1. Miếu tắt
	_check(not cp.is_active() and not light.visible and flame != null and not flame.visible, "lúc đầu miếu tắt")
	# 2. Bị thương rồi đi tới miếu
	_player.health.take_damage(2)
	var hurt_hp: int = _player.health.current_health
	await _walk_from(Vector3(56, 4.4, 54), cp.global_position)
	await _frames(60)
	_check(GameState.get_checkpoint_spawn_id() == &"level_3.plaza" and cp.is_active(), "chạm miếu: lưu checkpoint %s" % GameState.get_checkpoint_spawn_id())
	_check(_player.health.current_health == _player.health.max_health and hurt_hp < _player.health.max_health, "hồi đầy máu (%d → %d)" % [hurt_hp, _player.health.current_health])
	_check(light.visible and light.light_energy > 2.0 and flame.visible, "miếu sáng: lửa hiện, đèn %.2f" % light.light_energy)
	await _capture("fire_checkpoint_lit.png")
	# 3. Điểm hồi sinh
	var spawn: Node3D = cp.get_node("Spawn")
	_player.teleport(spawn.global_position + Vector3(0, 0.1, 0))
	await _frames(60)
	var p: Vector3 = _player.global_position
	_check(_player.is_on_floor() and absf(p.y - spawn.global_position.y) < 0.3 and Vector2(p.x - spawn.global_position.x, p.z - spawn.global_position.z).length() < 0.3, "điểm hồi sinh đứng vững trên sàn (%.2f, %.2f, %.2f)" % [p.x, p.y, p.z])
	# 4. Checkpoint phòng 6: chạm thì lưu sang level_3.room6, miếu quảng trường tắt, miếu phòng 6 sáng
	var cp6: Checkpoint = _level.get_node("Room6Checkpoint") as Checkpoint
	await _walk_from(Vector3(102, 4.4, 53), cp6.global_position)
	await _frames(60)
	_check(GameState.get_checkpoint_spawn_id() == &"level_3.room6" and cp6.is_active() and not cp.is_active(), "chạm miếu phòng 6: lưu checkpoint level_3.room6, miếu quảng trường tắt")
	var spawn6: Node3D = cp6.get_node("Spawn")
	_player.teleport(spawn6.global_position + Vector3(0, 0.1, 0))
	await _frames(60)
	_check(_player.is_on_floor() and absf(_player.global_position.y - spawn6.global_position.y) < 0.3, "điểm hồi sinh phòng 6 đứng vững trên sàn (y = %.2f)" % _player.global_position.y)
	await _capture("room6_checkpoint.png")
	print("FIRE CHECKPOINT RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


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
