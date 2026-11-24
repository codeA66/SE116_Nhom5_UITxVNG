extends Node
## Sách Phun Lửa phòng 4 (tier 1 map Lửa) rơi kiểu map Gió và dùng được ngay sau khi học:
## 1. Trước khi dọn lồng: chưa có sách Phun Lửa nào trong khu.
## 2. Phá lồng + hạ hết quái: sách rơi đúng chỗ con quái cuối gục (lệch tối đa DROP_RADIUS m), có cột sáng.
## 3. Nhặt sách bằng interact thật, đóng bảng nhận kỹ năng bằng phím xác nhận thật (ui_accept).
## 4. Ngay khi điều khiển trở lại: bấm Q (skill_fire) một lần thì Phun Lửa ra trong USE_WINDOW giây.
## 5. Nạp lại khu khi đã dọn mà chưa nhặt: sách nằm sẵn ở giữa phòng (vị trí node rơi).
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/flame_book_drop_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/tier_1/tier_1.tscn")
const ROOM4_CENTER: Vector3 = Vector3(72, 8.32, 10)
const DROP_RADIUS: float = 1.0
const USE_WINDOW: float = 0.3
## Thời gian người chơi bấm Q sau khi bấm đóng bảng giới thiệu kỹ năng (s)
const REACTION: float = 0.3

var _player: Player
var _level: Node
var _failed: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
	_run.call_deferred()


func _run() -> void:
	await _load_level()
	_player.get_node("HurtboxComponent").set_invincible(9999.0)
	var cage: SpawnerCage = _level.get_node("Room4SpawnerCage") as SpawnerCage
	# 1
	_check(_books().is_empty(), "trước khi dọn lồng: chưa có sách Phun Lửa trong khu")
	# 2. Vào phòng cho lồng sinh quái, phá lồng, hạ từng con
	_teleport(ROOM4_CENTER)
	var t: float = 0.0
	while cage.alive_count() < 2 and t < 15.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_check(cage.alive_count() >= 2, "vào phòng 4: lồng sinh quái (%d con)" % cage.alive_count())
	_teleport(ROOM4_CENTER + Vector3(0, 0, 4))
	(cage.get_node("HealthComponent") as HealthComponent).take_damage(9999)
	await _frames(5)
	var last_death := Vector3.ZERO
	for e: Node in cage.get_node("Enemies").get_children():
		var enemy := e as Enemy
		if enemy == null or enemy.is_dead():
			continue
		last_death = enemy.global_position
		enemy.health.take_damage(9999)
		await _frames(20)
	await _frames(60)
	var books: Array[AbilityPickup] = _books()
	_check(books.size() == 1, "dọn xong lồng: có đúng 1 sách Phun Lửa (%d)" % books.size())
	if books.size() == 1:
		var at: Vector3 = books[0].global_position
		var off: float = Vector2(at.x - last_death.x, at.z - last_death.z).length()
		_check(off <= DROP_RADIUS, "sách rơi chỗ con quái cuối gục %s (sách ở %s, lệch %.2f m)" % [_fmt(last_death), _fmt(at), off])
	# 3. Nhặt sách, đóng bảng bằng phím thật
	if books.is_empty():
		_finish()
		return
	var book: AbilityPickup = books[0]
	var acquire: Node = book.get_node_or_null("AbilityAcquireVfx")
	var reveal: Array[bool] = [false]
	if acquire != null:
		acquire.connect(&"phase_started", func(phase: StringName) -> void:
			if phase == &"Reveal":
				reveal[0] = true)
	_player.teleport(book.global_position + Vector3(0, 0.1, 1.2), Vector3.FORWARD)
	await _frames(15)
	await _press(&"interact")
	var start_ms: int = Time.get_ticks_msec()
	while not (_player.has_ability(&"flame_breath") and reveal[0]) and _since(start_ms) < 20.0:
		await _real_frame()
	t = _since(start_ms)
	_check(_player.has_ability(&"flame_breath") and reveal[0], "nhặt sách → có Phun Lửa, hiện bảng giới thiệu (%.1f s)" % t)
	# Bảng hiện xong thì người chơi bấm xác nhận một lần (thế giới đang dừng: đếm bằng frame vẽ)
	# Bấm xác nhận tới khi bảng thật sự đóng (lần đầu có thể chỉ tua hết phần chữ đang hiện)
	var closing: Array[bool] = [false]
	var ui: Node = acquire.get_node_or_null("Ui") if acquire != null else null
	if ui != null:
		ui.connect(&"transfer_started", func() -> void: closing[0] = true)
	start_ms = Time.get_ticks_msec()
	while not closing[0] and _since(start_ms) < 5.0:
		await _wait_real(0.3)
		_send_action(&"ui_accept")
		await _real_frame()
	_check(closing[0], "bấm xác nhận → bảng giới thiệu đóng (%.1f s)" % _since(start_ms))
	# 4. Người chơi bấm Q ngay khi bảng vừa tắt (phản xạ REACTION giây), không chờ icon bay xong
	await _wait_real(REACTION)
	var used: Array[bool] = [false]
	_player.skill_cooldown_started.connect(func(id: StringName, _d: float) -> void:
		if id == &"flame_breath":
			used[0] = true)
	await _press(&"skill_fire")
	t = 0.0
	while not used[0] and t < USE_WINDOW:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_check(used[0], "đóng bảng rồi bấm Q sau %.2f s: Phun Lửa ra (điều khiển %s, dừng hình %s, năng lượng %d/%d, trạng thái %s)" % [
		REACTION, _player.controls_enabled, get_tree().paused, _player.energy.current, _player.energy.get_max(), _state_name()])
	# Chờ màn nhận kỹ năng dọn xong hẳn trước khi nạp lại khu
	start_ms = Time.get_ticks_msec()
	while not (_player.controls_enabled and not get_tree().paused) and _since(start_ms) < 5.0:
		await _real_frame()
	# 5. Nạp lại khi đã dọn mà chưa nhặt
	_level.queue_free()
	await _frames(5)
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_flag(cage.persistent_id if is_instance_valid(cage) else &"level_3.room4_cage_cleared")
	await _load_level()
	books = _books()
	_check(books.size() == 1, "nạp lại (đã dọn, chưa nhặt): sách nằm sẵn trong phòng 4 (%d sách)" % books.size())
	if books.size() == 1:
		var room: AABB = AABB(Vector3(64, 7, 0), Vector3(16, 4, 20))
		_check(room.has_point(books[0].global_position), "sách nằm trong phòng 4 (%s)" % _fmt(books[0].global_position))
	_finish()


func _load_level() -> void:
	_level = LEVEL.instantiate()
	(_level as ZoneRoot).player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	await _frames(30)


## Mọi sách Phun Lửa đang nằm trong cây của khu
func _books() -> Array[AbilityPickup]:
	var out: Array[AbilityPickup] = []
	for n: Node in _level.find_children("*", "AbilityPickup", true, false):
		var p := n as AbilityPickup
		if p.ability != null and p.ability.id == &"flame_breath" and p.is_inside_tree():
			out.append(p)
	return out


func _state_name() -> String:
	var sm: Node = _player.get_node_or_null("StateMachine")
	var current: Variant = sm.get(&"current_state") if sm else null
	return String((current as Node).name) if current is Node else "?"


func _finish() -> void:
	print("FLAME BOOK DROP RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


## Phím thật qua hàng đợi input (đi qua _input của UI như người chơi bấm)
func _send_action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	ev = InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)


func _teleport(p: Vector3) -> void:
	_player.global_position = p + Vector3(0.0, 0.3, 0.0)
	_player.velocity = Vector3.ZERO


func _fmt(p: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]


## Frame vẽ: vẫn chạy khi cây đang dừng (màn nhận kỹ năng dừng thế giới)
func _real_frame() -> void:
	await get_tree().process_frame


## Chờ theo đồng hồ thật: headless vẽ frame nhanh hơn 60 fps nên không đếm frame
func _wait_real(seconds: float) -> void:
	var start_ms: int = Time.get_ticks_msec()
	while _since(start_ms) < seconds:
		await _real_frame()


func _since(start_ms: int) -> float:
	return (Time.get_ticks_msec() - start_ms) / 1000.0


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	print("%s %s" % ["OK  " if ok else "FAIL", what])
