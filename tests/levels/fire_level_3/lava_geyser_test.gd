extends Node
## Kiểm tra bẫy lửa đuổi theo trên cầu gạch Nether, đo bằng va chạm và input thật:
## 1. Vừa chạm cầu: cảnh báo ngay (không chờ), lửa phụt đúng chỗ, mất máu và bị hất ra.
## 2. Đi liên tục từ đầu cầu tới quảng trường: lửa đuổi theo nhịp follow_interval, vẫn qua được cầu.
## 3. Đứng yên trên quảng trường (ngoài vùng bẫy): không bị phun.
## Chạy: godot --headless --path . res://tests/levels/fire_level_3/lava_geyser_test.tscn  (thêm -- --capture để chụp ảnh lúc phụt)

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")
const BRIDGE_MID: Vector3 = Vector3(42, 4, 68)
const PLAZA_SPOT: Vector3 = Vector3(58, 4, 52)

## Thời gian tối đa chờ một lượt phun khi đứng yên (giây)
@export var max_wait: float = 4.0

var _player: Player
var _trap: LingerLavaTrap
var _failed: int = 0
var _triggers: int = 0


func _ready() -> void:
	var level: ZoneRoot = LEVEL.instantiate()
	level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(level)
	_run.call_deferred(level)


func _run(level: Node) -> void:
	for _i: int in range(30):
		await get_tree().physics_frame
	_trap = level.find_children("LingerLavaTrap", "Area3D", true, false).front() as LingerLavaTrap
	_check(_trap != null, "có bẫy trên cầu")
	_trap.geyser_triggered.connect(func(_at: Vector3) -> void: _triggers += 1)
	var capture: bool = "--capture" in OS.get_cmdline_user_args()
	# 1. Đứng yên giữa cầu
	_teleport(BRIDGE_MID)
	var hp: int = _player.health.current_health
	var t: float = 0.0
	var first_trigger: float = -1.0
	var shot: bool = false
	while t < max_wait and _player.health.current_health == hp:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if _triggers > 0 and first_trigger < 0.0:
			first_trigger = t
		if capture and not shot and first_trigger > 0.0 and t > first_trigger + 0.5:
			shot = true
			await _save("lava_geyser_warning.png")
	var hit_at: float = t
	for _i: int in range(10):
		await get_tree().physics_frame
	if capture:
		await _save("lava_geyser_burst.png")
	var pushed: float = Vector2(_player.global_position.x - BRIDGE_MID.x, _player.global_position.z - BRIDGE_MID.z).length()
	_check(first_trigger > 0.0 and first_trigger <= 0.2, "kích hoạt ngay khi chạm cầu (%.2f s)" % first_trigger)
	_check(_player.health.current_health < hp, "bị phun trúng lúc %.2f s, máu %d → %d" % [hit_at, hp, _player.health.current_health])
	_check(pushed > 0.5, "bị hất khỏi chỗ đứng (%.1f m)" % pushed)
	# Chờ mạch nghỉ xong cho sạch trạng thái
	for _i: int in range(200):
		await get_tree().physics_frame
	# 2. Đi liên tục qua cầu
	_player.health.heal_full()
	_teleport(Vector3(29.5, 4, 80.5))
	for _i: int in range(5):
		await get_tree().physics_frame
	_triggers = 0
	hp = _player.health.current_health
	var target: Vector3 = Vector3(56, 4, 54)
	t = 0.0
	while t < 15.0:
		var flat: Vector2 = Vector2(target.x - _player.global_position.x, target.z - _player.global_position.z)
		if flat.length() < 0.8:
			break
		_press_towards(Vector3(flat.x, 0.0, flat.y).normalized())
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_release()
	var arrived: bool = Vector2(target.x - _player.global_position.x, target.z - _player.global_position.z).length() < 0.8
	_check(_triggers >= 1 and arrived and _player.health.current_health > 0, "đi liên tục qua cầu (%.1f s): lửa đuổi %d lượt, tới quảng trường, máu %d → %d" % [t, _triggers, hp, _player.health.current_health])
	# 3. Đứng yên trên quảng trường
	_teleport(PLAZA_SPOT)
	_triggers = 0
	for _i: int in range(180):
		await get_tree().physics_frame
	_check(_triggers == 0, "đứng 3 s trên quảng trường không bị phun")
	print("GEYSER RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


func _save(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/fire_level_3/qa/" + file)


func _teleport(p: Vector3) -> void:
	_player.global_position = p + Vector3(0.0, 0.3, 0.0)
	_player.velocity = Vector3.ZERO


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	print("%s %s" % ["OK  " if ok else "FAIL", what])


## Quy đổi hướng thế giới ra input theo camera, giống level_3_walk_test
func _press_towards(world_dir: Vector3) -> void:
	var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
	var forward: Vector3 = Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
	var right: Vector3 = Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
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
