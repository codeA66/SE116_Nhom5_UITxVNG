extends Node
## Kiểm thử Level 1 sau khi sửa map: đường đi qua làn gió nhịp, rào giữ player, và 4 trận đánh (Encounter).
## Đo hành vi thật: player đi bằng Input Map, quái chạy vật lý thật. Chạy headless:
##   APPDATA/LOCALAPPDATA trỏ vào .godot/lvl_runtime để không đụng save thật.

const LEVEL_SCENE: PackedScene = preload("res://levels/zone_1_wind/level_1/level_1.tscn")
const TICK := 1.0 / 60.0
## Mặt trên các nền (m), lấy từ hộp va chạm trong level
const LANE_TOP := 4.0
const YARD_TOP := 9.0
const BOOK_TOP := 12.0
## Rơi thấp hơn mặt nền chừng này coi như đã rơi khỏi nền
const FALL_MARGIN := 0.6
const MOVE_ACTIONS: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right"]

var _pass: int = 0
var _fail: int = 0
var _level: Node3D
var _player: Player
## Hướng di chuyển thế giới (XZ) ứng với từng action, đo lúc đầu vì phụ thuộc góc camera
var _action_dirs: Dictionary = {}


func _ready() -> void:
	if not OS.get_environment("APPDATA").contains("lvl_runtime"):
		push_error("TestLevel1: đặt APPDATA/LOCALAPPDATA vào .godot/lvl_runtime để bảo vệ save thật.")
		get_tree().quit(1)
		return
	GameState.replace_progress(PlayerProgress.new())
	await _run()
	print("LEVEL1 %s (%d PASS / %d FAIL)" % ["PASSED" if _fail == 0 else "FAILED", _pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _run() -> void:
	await _load_level()
	_check(_player.global_position.distance_to(Vector3(0, 0, 7)) < 1.5, "player xuất hiện ở Start", str(_player.global_position))
	await _calibrate()
	await _t_lane()
	await _t_fences()
	await _t_sword_yard()
	await _t_dock()
	await _t_book()
	await _t_far_shore()
	await _t_persistence()


# ---------- Bản đồ ----------

func _t_lane() -> void:
	# Từ chỗ đáp gió xuôi đi thẳng xuống sân gió đẩy lên, qua vùng gió nhịp
	_teleport(Vector3(11, LANE_TOP + 0.2, -54))
	var min_y := INF
	var reached := false
	_press_toward(Vector3.FORWARD)
	for i in int(14.0 / TICK):
		await get_tree().physics_frame
		min_y = minf(min_y, _player.global_position.y)
		if _player.global_position.z < -80.0:
			reached = true
			break
	_release_all()
	_check(reached, "làn gió nhịp: đi từ chỗ đáp (z -54) tới sân gió đẩy lên (z < -80) trong 14 s", "z = %.2f" % _player.global_position.z)
	_check(min_y > LANE_TOP - FALL_MARGIN, "làn gió nhịp: không rơi khỏi làn", "y thấp nhất %.2f" % min_y)


func _t_fences() -> void:
	# [vị trí đặt, hướng đẩy, hàm kiểm, mô tả]
	var cases: Array = [
		[Vector3(11, LANE_TOP + 0.2, -68), Vector3.RIGHT, func(p: Vector3) -> bool: return p.x < 13.0, "rào đông của làn"],
		[Vector3(11, LANE_TOP + 0.2, -68), Vector3.LEFT, func(p: Vector3) -> bool: return p.x > 9.0, "rào tây của làn"],
		[Vector3(13.5, LANE_TOP + 0.2, -56), Vector3.RIGHT, func(p: Vector3) -> bool: return p.x < 15.0, "mép đông chỗ đáp (lối gió ngược cũ)"],
		[Vector3(14, LANE_TOP + 0.2, -56.5), Vector3.FORWARD, func(p: Vector3) -> bool: return p.z > -58.0, "mép nam chỗ đáp ngoài lối làn"],
		[Vector3(17, LANE_TOP + 0.2, -80), Vector3.BACK, func(p: Vector3) -> bool: return p.z < -78.0, "mép bắc sân ngoài lối làn"],
		[Vector3(19, LANE_TOP + 0.2, -83), Vector3.RIGHT, func(p: Vector3) -> bool: return p.x < 21.0, "mép đông sân (lối gió nhịp cũ)"],
	]
	for c: Array in cases:
		_teleport(c[0])
		_press_toward(c[1])
		await _seconds(2.0)
		_release_all()
		var p := _player.global_position
		var held: bool = (c[2] as Callable).call(p) and p.y > LANE_TOP - FALL_MARGIN
		_check(held, "rào giữ player: " + c[3], str(p.snapped(Vector3.ONE * 0.01)))


# ---------- Trận đánh ----------

func _t_sword_yard() -> void:
	var enc := _encounter("SwordYard")
	_teleport(Vector3(15, YARD_TOP + 0.2, -124))
	await _seconds(0.5)
	_check(_spawned(enc).is_empty(), "sân kiếm: chưa có kiếm thì chưa có quái")
	GameState.set_flag(&"level_1.sword_pickup")
	await _seconds(0.5)
	var enemies := _spawned(enc)
	_check(enemies.size() == 1 and enemies[0].target == _player, "sân kiếm: nhặt kiếm (đứng trong sân) thì quái 1 xuất hiện và nhắm player", str(enemies.size()))
	await _expect_stays_on(enemies, YARD_TOP, 3.0, "sân kiếm")
	await _kill_all(enc, "level_1.enc_sword", "sân kiếm")


func _t_dock() -> void:
	var enc := _encounter("Dock")
	_teleport(Vector3(15, YARD_TOP + 0.2, -172))
	await _seconds(0.5)
	var enemies := _spawned(enc)
	_check(enemies.size() == 1, "bến thuyền: vào sân thì lính khiên xuất hiện", str(enemies.size()))
	await _expect_stays_on(enemies, YARD_TOP, 3.0, "bến thuyền")
	await _kill_all(enc, "level_1.enc_dock", "bến thuyền")


func _t_book() -> void:
	var enc := _encounter("BookPlateau")
	_teleport(Vector3(34, BOOK_TOP + 0.2, -186))
	await _seconds(0.5)
	_check(_spawned(enc).is_empty(), "cao nguyên sách: chưa nhặt sách thì chưa có pháp sư")
	GameState.set_flag(&"level_1.wind_book")
	await _seconds(0.5)
	var enemies := _spawned(enc)
	_check(enemies.size() == 1, "cao nguyên sách: nhặt sách thì pháp sư xuất hiện", str(enemies.size()))
	await _expect_stays_on(enemies, BOOK_TOP, 5.0, "cao nguyên sách")
	if not enemies.is_empty() and is_instance_valid(enemies[0]):
		var p := enemies[0].global_position
		_check(p.x > 27.5 and p.x < 40.5 and p.z > -200.5 and p.z < -181.5, "pháp sư ở trong cao nguyên sau 5 s (kể cả dịch chuyển)", str(p.snapped(Vector3.ONE * 0.01)))
	await _kill_all(enc, "level_1.enc_book", "cao nguyên sách")


func _t_far_shore() -> void:
	var enc := _encounter("FarShore")
	var note := _level.get_node("Area15_Boat/ExitNote") as Node3D
	_check(not note.visible, "bờ xa: lối ra ẩn trước trận cuối")
	_teleport(Vector3(15, YARD_TOP + 0.2, -220))
	await _seconds(1.5)
	var enemies := _spawned(enc)
	_check(enemies.size() == 3, "bờ xa: cả 3 loại quái xuất hiện", str(enemies.size()))
	await _expect_stays_on(enemies, YARD_TOP, 4.0, "bờ xa")
	await _kill_all(enc, "level_1.enc_final", "bờ xa")
	_check(note.visible, "bờ xa: thắng trận cuối thì hiện lối ra")


func _t_persistence() -> void:
	# Tải lại khu khi đã có cờ các trận: không gặp lại trận đã thắng
	await _load_level()
	var leftover := 0
	for enc_name: String in ["SwordYard", "Dock", "BookPlateau", "FarShore"]:
		var enc := _encounter(enc_name)
		var root := enc.get_node_or_null("Enemies")
		if root and is_instance_valid(root) and not root.is_queued_for_deletion():
			leftover += root.get_child_count()
		_teleport(enc.global_position + Vector3.UP * 0.3)
		await _seconds(0.3)
		leftover += _spawned(enc).size()
	_check(leftover == 0, "tải lại khu: các trận đã thắng không xuất hiện lại", "%d quái" % leftover)


# ---------- Tiện ích ----------

func _load_level() -> void:
	if _level:
		_level.queue_free()
		await get_tree().process_frame
	_level = LEVEL_SCENE.instantiate() as Node3D
	add_child(_level)
	await get_tree().physics_frame
	_player = _level.get_node("Player") as Player
	_player.get_node("HurtboxComponent").set_invincible(1.0e6)
	await _seconds(0.2)


## Đo hướng đi thật của từng action (phụ thuộc góc camera)
func _calibrate() -> void:
	for action in MOVE_ACTIONS:
		_teleport(Vector3(0, 0.2, 5))
		Input.action_press(action)
		await _seconds(0.4)
		Input.action_release(action)
		var d := _player.global_position - Vector3(0, 0.2, 5)
		d.y = 0.0
		_action_dirs[action] = d.normalized()
		await _seconds(0.3)


func _press_toward(direction: Vector3) -> void:
	_release_all()
	var best: StringName
	var best_dot := -2.0
	for action: StringName in _action_dirs:
		var dot := (_action_dirs[action] as Vector3).dot(direction)
		if dot > best_dot:
			best_dot = dot
			best = action
	Input.action_press(best)


func _release_all() -> void:
	for action in MOVE_ACTIONS:
		Input.action_release(action)


func _teleport(pos: Vector3) -> void:
	_release_all()
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()


func _encounter(enc_name: String) -> Encounter:
	return _level.get_node("Encounters/" + enc_name) as Encounter


func _spawned(enc: Encounter) -> Array[Enemy]:
	var out: Array[Enemy] = []
	var root := enc.get_node_or_null("Enemies")
	if root == null:
		return out
	for child in root.get_children():
		if child is Enemy and child.is_inside_tree() and not (child as Enemy).is_dead():
			out.append(child as Enemy)
	return out


func _expect_stays_on(enemies: Array[Enemy], top: float, seconds: float, label: String) -> void:
	var lowest := INF
	for i in int(seconds / TICK):
		await get_tree().physics_frame
		for e in enemies:
			if is_instance_valid(e):
				lowest = minf(lowest, e.global_position.y)
	var alive := enemies.filter(func(e: Enemy) -> bool: return is_instance_valid(e) and not e.is_dead()).size()
	_check(alive == enemies.size() and lowest > top - FALL_MARGIN, "%s: quái không rơi khỏi sân trong %.0f s" % [label, seconds], "y thấp nhất %.2f, còn sống %d/%d" % [lowest, alive, enemies.size()])


func _kill_all(enc: Encounter, flag: StringName, label: String) -> void:
	var cleared := [false]
	enc.cleared.connect(func() -> void: cleared[0] = true, CONNECT_ONE_SHOT)
	for e in _spawned(enc):
		e.health.take_damage(e.health.current_health)
	await _seconds(0.3)
	_check(cleared[0] and GameState.has_flag(flag), "%s: giết hết quái thì xong trận và lưu cờ %s" % [label, flag])


func _seconds(duration: float) -> void:
	for i in int(duration / TICK):
		await get_tree().physics_frame


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass += 1
		print("PASS ", label, ("  [%s]" % detail) if detail else "")
	else:
		_fail += 1
		print("FAIL ", label, ("  [%s]" % detail) if detail else "")
