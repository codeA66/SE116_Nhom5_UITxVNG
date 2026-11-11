extends Node
## Cửa tây phòng 5 (lối vào ô trước rào gỗ đường bậc thang): đi bộ thật từ sàn phòng vào ô trước rào rồi đi ngược ra,
## không kẹt ở khe giữa ô đường nối (cầu 3 m) và sàn phòng (lỗi cũ: lọt khe 0,5 m tại x ~55,75, kẹt không bước ra được).
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/room5_doorway_walk_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")

var _player: Player
var _failed: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_flag(&"level_3.bridge_guards")
	var level: Node = LEVEL.instantiate()
	(level as ZoneRoot).player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(level)
	_run.call_deferred()


func _run() -> void:
	for _i: int in range(30):
		await get_tree().physics_frame
	# Vào ô trước rào (rào gỗ ở z 40,3): đi thẳng qua cửa phòng 5 (x 56) theo làn z 41,8
	_player.teleport(Vector3(60, 4.4, 41.8))
	await _frames(10)
	await _walk(Vector3(54.2, 4.4, 41.8))
	_check(_player.global_position.x < 54.8, "đi từ sàn phòng 5 qua cửa tây vào ô trước rào (x = %.2f)" % _player.global_position.x)
	_check(_player.is_on_floor() and _player.global_position.y > 4.3, "đứng trên mặt sàn, không lọt khe (y = %.3f)" % _player.global_position.y)
	await _walk(Vector3(60, 4.4, 41.8))
	_check(_player.global_position.x > 59.0, "đi ngược ra sàn phòng 5 (x = %.2f)" % _player.global_position.x)
	print("ROOM5 DOORWAY RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


func _walk(target: Vector3) -> void:
	var t: float = 0.0
	while t < 5.0:
		var flat: Vector2 = Vector2(target.x - _player.global_position.x, target.z - _player.global_position.z)
		if flat.length() < 0.5:
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


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	print("%s %s" % ["OK  " if ok else "FAIL", what])
