extends Node
## Cầu dung nham ngập (bậc thang cửa bắc phòng 11 ↔ lối đi hướng tây), va chạm và input thật:
## 1. Mặt cầu phủ dung nham, hai bên có thác dung nham đổ xuống, có LavaZone.
## 2. Đứng sát mép lối đi / trong phòng 11 (ngoài cầu): không bị đốt.
## 3. Đi từ lối đi xuống cầu: mất 1 máu ngay, bị cháy, không chết.
## 4. Đứng trong dung nham: cháy tiếp, mất thêm máu theo nhịp của BurnData.
## 5. Bước ra: cháy nốt rồi tắt, không mất máu nữa.
## 6. Còn 1 máu bước vào: chết (hết máu mới chết).
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/flooded_bridge_test.tscn (-- --capture để chụp ảnh)

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
	var lava: LavaZone = _level.find_child("FloodLavaZone", true, false) as LavaZone
	var sheets: Array[Node] = _level.find_children("FloodSheet*", "MeshInstance3D", true, false)
	var falls: Array[Node] = lava.get_parent().find_children("lavafall_4m*", "", false, false) if lava else []
	_check(lava != null and sheets.size() == 3 and falls.size() > 0, "cầu có dung nham phủ (%d tấm), thác đổ hai bên (%d), vùng dung nham" % [sheets.size(), falls.size()])
	var burn: BurnableComponent = _player.get_node("BurnableComponent") as BurnableComponent
	var hp: HealthComponent = _player.health
	# 2. Mép ngoài cầu
	_player.teleport(Vector3(74, 4.4, 55.2))
	await _frames(40)
	_player.teleport(Vector3(74, 0.4, 69.0))
	await _frames(40)
	_check(hp.current_health == hp.max_health and not burn.is_burning(), "đứng sát hai đầu cầu: không bị đốt")
	await _capture_overview()
	# 3. Bước vào
	var full: int = hp.current_health
	await _walk_from(Vector3(74, 4.4, 53), Vector3(74, 4, 59))
	await _frames(5)
	_check(hp.current_health == full - 1 and burn.is_burning() and not hp.is_dead(), "bước vào dung nham: mất 1 máu (%d → %d), bị cháy, không chết" % [full, hp.current_health])
	await _capture("lava_burning.png")
	# 4. Đứng trong 1,2 s (hồi đầy trước để không chết giữa chừng): số tick theo tick_interval của BurnData
	var interval: float = burn.data.tick_interval
	hp.heal_full()
	var before: int = hp.current_health
	await _seconds(1.2)
	var lost_inside: int = before - hp.current_health
	var expect: int = int(floor(1.2 / interval))
	_check(absi(lost_inside - expect) <= 1 and burn.is_burning(), "đứng trong dung nham 1,2 s: mất %d máu (nhịp %.2f s, mong khoảng %d), vẫn cháy" % [lost_inside, interval, expect])
	# 5. Bước ra, đứng ngoài 4 s: cháy nốt rồi tắt
	hp.heal_full()
	await _walk_from(_player.global_position, Vector3(74, 4, 52))
	var out_hp: int = hp.current_health
	await _seconds(4.0)
	var lost: int = out_hp - hp.current_health
	_check(not burn.is_burning() and not hp.is_dead(), "bước ra: cháy nốt (mất %d máu) rồi tắt" % lost)
	var settled: int = hp.current_health
	await _seconds(2.0)
	_check(hp.current_health == settled, "tắt lửa: không mất máu nữa")
	# 6. Còn 1 máu bước vào: chết. Chết là game chuyển cảnh hồi sinh (gỡ test khỏi cây): chốt kết quả ngay khi chết
	hp.set_current_health(1)
	_player.health.died.connect(_on_died)
	await _walk_from(Vector3(74, 4.4, 53), Vector3(74, 4, 59))
	await _frames(30)
	if is_inside_tree():
		_check(false, "còn 1 máu bước vào dung nham: chết")
		_finish()


func _seconds(s: float) -> void:
	await get_tree().create_timer(s, false, true).timeout


func _on_died() -> void:
	_check(true, "còn 1 máu bước vào dung nham: chết (z = %.2f)" % _player.global_position.z)
	_finish()


func _finish() -> void:
	print("FLOODED BRIDGE RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


func _capture_overview() -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	var game_cam: Camera3D = get_viewport().get_camera_3d()
	var cam: Camera3D = Camera3D.new()
	add_child(cam)
	cam.global_position = Vector3(86, 18, 74)
	cam.look_at(Vector3(74, 1, 62))
	cam.current = true
	await _frames(5)
	await _capture("flooded_bridge.png")
	cam.queue_free()
	game_cam.current = true


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
