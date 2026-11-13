extends Node
## Chìa của cổng tây khi nạp lại màn (node thật):
## 1. Đã hạ mini-boss phòng 2 mà chưa nhặt chìa: nạp màn thì chìa nằm sẵn ở phòng 2, cổng và ổ khóa vẫn khóa.
## 2. Ổ khóa chưa mở trông là màu khóa; ô tương tác hiện "CỔNG KHÓA", có chìa thì đổi thành "MỞ KHÓA".
## 3. Đã mở khóa từ lần chơi trước (cờ ổ khóa): nạp màn thì ổ sáng mở và hai cổng mở sẵn.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/west_gate_key_test.tscn (-- --capture để chụp ảnh)

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")

var _level: Node
var _player: Player
var _failed: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_run.call_deferred()


func _load(flags: Array[StringName]) -> void:
	if is_instance_valid(_level):
		_level.queue_free()
		await get_tree().process_frame
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_flag(&"level_3.bridge_guards")
	for f: StringName in flags:
		GameState.set_flag(f)
	_level = LEVEL.instantiate()
	(_level as ZoneRoot).player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	for _i: int in range(30):
		await get_tree().physics_frame


func _run() -> void:
	# 1 + 2. Đã hạ mini-boss, chưa nhặt chìa
	await _load([&"level_3.room2_miniboss"])
	var lock: KeyLock = _level.get_node("WestGates/WestKeyLock") as KeyLock
	var gates: Array[StoneGate] = [_level.get_node("WestGates/WestGateSouth") as StoneGate, _level.get_node("WestGates/WestGateNorth") as StoneGate]
	var key: KeyPickup = null
	for c: Node in _level.get_node("Room2").get_children():
		if c is KeyPickup:
			key = c as KeyPickup
	_check(key != null and key.key_id == &"level_3.west_key" and key.global_position.distance_to(_level.get_node("Room2/WestKeyDrop").global_position) < 0.1, "đã hạ mini-boss chưa nhặt chìa: chìa nằm sẵn ở phòng 2")
	_check(not lock.is_active() and not gates[0].is_open and not gates[1].is_open, "ổ khóa và hai cổng tây vẫn khóa")
	var interact: InteractableComponent = lock.get_node("InteractableComponent") as InteractableComponent
	_check(interact.prompt_text == "CỔNG KHÓA", "chưa chìa: gợi ý \"%s\"" % interact.prompt_text)
	_player.teleport(lock.global_transform * Vector3(0, 0.1, 2.6), -lock.global_basis.z)
	await _frames(20)
	await _capture("west_gate_key_lock_locked.png")
	GameState.set_flag(&"level_3.west_key")
	await _frames(5)
	_check(interact.prompt_text == "MỞ KHÓA", "có chìa: gợi ý đổi thành \"%s\"" % interact.prompt_text)
	# 3. Đã mở khóa từ lần chơi trước
	await _load([&"level_3.west_key", &"level_3.west_gate_unlocked", &"level_3.west_gate_south", &"level_3.west_gate_north"])
	lock = _level.get_node("WestGates/WestKeyLock") as KeyLock
	gates = [_level.get_node("WestGates/WestGateSouth") as StoneGate, _level.get_node("WestGates/WestGateNorth") as StoneGate]
	_check(lock.is_active() and not (lock.get_node("InteractableComponent") as InteractableComponent).enabled, "đã mở khóa từ trước: ổ mở sẵn, không còn tương tác")
	_check(gates[0].is_open and gates[1].is_open, "hai cổng tây mở sẵn")
	_player.teleport(lock.global_transform * Vector3(0, 0.1, 2.6), -lock.global_basis.z)
	await _frames(20)
	await _capture("west_gate_key_lock_open.png")
	print("WEST GATE KEY RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


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
