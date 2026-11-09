extends Node
## Cổng xoáy năng lượng + đá năng lượng (va chạm, input và node thật):
## 1. Map Lửa không còn cổng tím: cổng phòng 1, 9, 15 là cổng xoáy có bệ đỡ; cổng ra phòng 10 ẩn tới khi hạ boss.
## 2. Cổng 9 chưa có năng lượng: xoáy tắt, bước vào không dịch chuyển; bấm interact ở ổ trên bệ cổng thì hộp thoại
##    báo thiếu năng lượng, không lắp được.
## 3. Cứu con tin phòng 12 (đặt cờ, luồng cứu có test riêng): đá hiện trên sàn gỗ, bấm interact nhặt được.
## 4. Lắp đá vào bệ: cổng 9 và 15 cùng sáng.
## 5. Bước vào cổng 9: xuất hiện trước cổng 15; bước vào cổng 15: về trước cổng 9.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/warp_portal_test.tscn (-- --capture để chụp ảnh)

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
	_player.get_node("HurtboxComponent").set_invincible(9999.0)
	# 1. Không còn cổng tím
	var visuals: Array[Node] = _level.find_children("*", "VortexPortalVisual", true, false)
	var old: Array[Node] = _level.find_children("portal_frame*", "", true, false)
	var pedestals: int = visuals.filter(func(v: Node) -> bool: return v.get_node_or_null("Pedestal") != null).size()
	var exit_reveal: FlagReveal = _level.get_node("Room10ExitReveal") as FlagReveal
	_check(visuals.size() == 3 and pedestals == 3 and old.is_empty() and exit_reveal.get_child_count() == 0, "3 cổng xoáy có bệ đỡ, không còn cổng tím, cổng ra phòng 10 ẩn (%d / %d / %d)" % [visuals.size(), pedestals, old.size()])
	# 2. Cổng 9 tắt
	var p9: WarpPortal = _level.get_node("WarpPortals/Room9WarpPortal") as WarpPortal
	var p15: WarpPortal = _level.get_node("WarpPortals/Room15WarpPortal") as WarpPortal
	var socket: PowerSocket = _level.get_node("WarpPortals/Room9WarpPortal/PowerSocket") as PowerSocket
	var dialog: DialogBox = socket.get_node("DialogBox") as DialogBox
	var prompt: InteractableComponent = socket.get_node("InteractableComponent") as InteractableComponent
	_check(not p9.is_open and not p15.is_open, "chưa có năng lượng: cổng 9 và 15 tắt")
	await _walk_from(p9.get_arrival().global_position + Vector3(0, 0.3, 0), p9.global_position)
	await _frames(60)
	_check(_player.global_position.distance_to(p9.global_position) < 4.0, "bước vào cổng 9 đang tắt: không dịch chuyển")
	_player.teleport(socket.global_position + p9.global_basis.z * 1.1 + Vector3(0, -0.7, 0), -p9.global_basis.z)
	await _frames(10)
	await _press(&"interact")
	await _frames(10)
	_check(not socket.is_powered and dialog.is_open and dialog.get_node("Panel/Margin/VBox/Text").text.contains("thiếu năng lượng"), "chưa có đá: bấm ổ trên bệ cổng → hộp thoại báo thiếu năng lượng, không lắp được")
	await _capture("portal9_missing.png")
	await _frames(20)
	await _press(&"interact")
	await _frames(20)
	# 3. Cứu con tin → đá hiện
	var reveal: FlagReveal = _level.get_node("Room12StoneReveal") as FlagReveal
	_check(reveal.get_child_count() == 0, "chưa cứu con tin: chưa có đá")
	GameState.set_flag(&"level_3.room12_hostage_rescued")
	await _frames(5)
	var stone: Node3D = reveal.get_node_or_null("EnergyStone") as Node3D
	_check(stone != null, "cứu con tin: đá năng lượng hiện trên sàn gỗ phòng 12")
	if stone:
		_player.teleport(stone.global_position + Vector3(0.9, 0.1, 0), Vector3.LEFT)
		await _frames(10)
		await _capture("energy_stone.png")
		await _press(&"interact")
		await _frames(10)
	_check(GameState.has_flag(&"level_3.energy_stone"), "bấm interact: nhặt được đá năng lượng")
	# 4. Lắp đá
	_player.teleport(socket.global_position + p9.global_basis.z * 1.1 + Vector3(0, -0.7, 0), -p9.global_basis.z)
	await _frames(10)
	_check(prompt.prompt_text == socket.ready_prompt, "có đá: bệ nhắc \"%s\"" % prompt.prompt_text)
	await _press(&"interact")
	await _frames(60)
	_check(socket.is_powered and p9.is_open and p15.is_open, "lắp đá: cổng 9 và 15 cùng sáng")
	await _capture("portal9_active.png")
	# 5. Dịch chuyển hai chiều
	await _walk_from(p9.get_arrival().global_position + Vector3(0, 0.3, 0), p9.global_position)
	await _seconds(1.5)
	_check(_player.global_position.distance_to(p15.get_arrival().global_position) < 1.0, "bước vào cổng 9: ra trước cổng 15 (cách %.2f m)" % _player.global_position.distance_to(p15.get_arrival().global_position))
	await _capture("portal15_arrival.png")
	await _seconds(0.5)
	await _walk_from(p15.get_arrival().global_position + Vector3(0, 0.3, 0), p15.global_position)
	await _seconds(1.5)
	_check(_player.global_position.distance_to(p9.get_arrival().global_position) < 1.0, "bước vào cổng 15: về trước cổng 9 (cách %.2f m)" % _player.global_position.distance_to(p9.get_arrival().global_position))
	print("WARP PORTAL RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


## Bấm phím qua hàng đợi input (hộp thoại đọc _unhandled_input, không đọc trạng thái Input)
func _press(action: StringName) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	var up: InputEventAction = InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(1)


func _seconds(s: float) -> void:
	await get_tree().create_timer(s, false, true).timeout


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
