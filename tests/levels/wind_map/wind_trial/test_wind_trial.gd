extends Node
## Chạy scene này bằng Godot để kiểm tra luồng 5 → 5.1 → 5.2 → 6 với bản đồ thật.

const WindTrial := preload("res://levels/zone_1_wind/level_1/rooms/tier_1/wind_trial/room_05_2_wind_trial.gd")
const TrialGrille := preload("res://levels/zone_1_wind/level_1/rooms/tier_1/wind_trial/grille/trial_grille.gd")
const LEVEL := "res://levels/zone_1_wind/level_1/level_1.tscn"
const TIER := ^"Rooms/Tier1"
const LEGACY_ENTRY := &"level_1.wind_trial_entry"
const LEGACY_EXIT := &"level_1.wind_trial_exit"
const WIND: WindBlastData = preload("res://abilities/wind_blast/wind_blast.tres")
const SWORD: WeaponData = preload("res://resources/combat/weapons/sword.tres")

var _fails: int
var _level: ZoneRoot
var _player: Player
var _trial: WindTrial
var _first: Encounter
var _second: Encounter
var _exit_gate: TrialGrille
var _old_gate: StoneGate


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# Giữ node test sống khi SceneManager đổi sang Level 1 thật.
	get_tree().current_scene = null
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_weapon(SWORD)
	await _load_level()
	if not await _collect_book():
		_finish()
		return

	# UC01: đi qua hành lang và khóa cửa khi qua ngưỡng 5.2.
	var checkpoint_before: StringName = GameState.get_checkpoint_spawn_id()
	_check(not _exit_gate.is_open and not _old_gate.is_open, "TC01 hai lối vào phòng 6 bị chặn trước trận")
	_check(_path_is_clear(Vector3(21.5, 4.35, -58), Vector3(26, 4.35, -58)), "TC02 save cũ có lối từ cầu thang sang 5.1")
	_check(not _path_is_clear(Vector3(6, 6.25, -62), Vector3(6, 6.25, -66)), "TC03 cầu thang cũ chặn đường đi tắt")
	await _move_until(&"move_right", func() -> bool: return _player.global_position.x >= 33.85)
	_check(GameState.get_checkpoint_spawn_id() == checkpoint_before and _trial.current_wave == 0,
		"TC04 đi qua 5.1 không đổi checkpoint, chưa có quái")
	await _move_until(&"move_forward", func() -> bool: return _trial.current_wave == 1)
	await _frames(3)
	_check(_trial.current_wave == 1 and _enemy_count(_first) == 1, "TC05 vượt ngưỡng 5.2, xuất hiện đúng một Bọ")
	_check(not (_trial.get_node(^"EntryGate/CollisionShape3D") as CollisionShape3D).disabled, "TC06 cửa vào khóa sau khi Foxy qua")
	if _enemy_count(_first) != 1:
		_finish()
		return

	# UC02: phản đạn, nạp lại năng lượng và hạ đủ hai đợt.
	await _reflect(_first.get_node(^"Enemies/BurrowBeetle1") as BurrowBeetle, Vector3(34, 3.65, -62.25))
	_check(_trial.current_wave == 1 and not _exit_gate.is_open, "TC07 hạ Bọ đầu vẫn khóa cửa")
	await _frames(60)
	_check(_trial.current_wave == 1 and _enemy_count(_second) == 0, "TC08 có khoảng nghỉ giữa hai đợt")
	await _until(func() -> bool: return _trial.current_wave == 2, 160)
	_check(_trial.current_wave == 2 and _enemy_count(_second) == 1, "TC09 đợt hai chỉ đưa một Bọ ra trước")
	if _enemy_count(_second) != 1:
		_finish()
		return
	var left: BurrowBeetle = _second.get_node(^"Enemies/BurrowBeetle1")
	var shot_frames: Array[int] = []
	var on_first_shot := func(_seed: StoneSeed) -> void: shot_frames.append(Engine.get_physics_frames())
	left.seed_fired.connect(on_first_shot, CONNECT_ONE_SHOT)
	await _until(func() -> bool: return _enemy_count(_second) == 2, 120)
	_check(_enemy_count(_second) == 2, "TC10 Bọ thứ hai xuất hiện sau")
	if _enemy_count(_second) != 2:
		_finish()
		return
	var right: BurrowBeetle = _second.get_node(^"Enemies/BurrowBeetle2")
	right.seed_fired.connect(on_first_shot, CONNECT_ONE_SHOT)
	await _until(func() -> bool: return shot_frames.size() == 2, 100)
	_check(shot_frames.size() == 2 and shot_frames[1] - shot_frames[0] >= 30, "TC10 hai phát đầu cách nhau ít nhất nửa giây")

	_player.energy.set_current(0)
	_player.teleport(Vector3(43.3, 3.65, -63.9), Vector3.BACK)
	await _frames(10)
	_aim_at(Vector3(43.3, 3.6, -62.25))
	await _press(&"attack")
	await _frames(55)
	_check(_player.energy.current > 0, "TC11 chém hình nộm nạp lại gió từ 0")
	_player.energy.set_current(3)
	await _reflect(left, Vector3(34, 3.65, -62.25))
	_check(not _exit_gate.is_open and not _old_gate.is_open, "TC12 còn một Bọ thì cửa vẫn khóa")
	await _reflect(right, Vector3(39.4, 3.65, -62.25))
	_check(_trial.is_active() and _exit_gate.is_open and _old_gate.is_open, "TC13 hạ Bọ cuối mới mở các cửa")
	await _frames(15)
	_player.teleport(Vector3(34.5, 3.65, -74), Vector3.LEFT)
	await _frames(6)
	await _move_until(&"move_left", func() -> bool: return _player.global_position.x < 23.8)
	_check(_player.global_position.x < 24.5 and is_equal_approx(snappedf(_player.global_position.y, 0.1), 5.4),
		"TC14 đi thật lên dốc, qua cửa và sang sàn phòng 6")
	_check(GameState.get_checkpoint_spawn_id() == checkpoint_before, "TC15 vào phòng 6 không đổi checkpoint")

	# UC03: hồ sơ cũ vẫn nạp được hai vị trí checkpoint đã bỏ.
	var legacy_entry := SpawnPoint.find_in(_level, LEGACY_ENTRY)
	_check(is_instance_valid(legacy_entry) and legacy_entry.global_position.distance_to(Vector3(28.7, 3.6, -57.4)) < 0.1,
		"TC16 save cũ ở 5.1 vẫn có điểm xuất hiện")
	var saved := SaveManager.to_dict(GameState.progress)
	saved["checkpoint"] = {"zone": LEVEL, "spawn": String(LEGACY_EXIT)}
	GameState.replace_progress(SaveManager.from_dict(saved))
	SceneManager.go_to_last_checkpoint()
	await _bind_loaded_level()
	_check(_player.global_position.distance_to(Vector3(23.8, 5.4, -74.9)) < 0.3,
		"TC17 nạp save cũ đưa Foxy về Phòng 6")
	_check(_trial.is_active() and _exit_gate.is_open and _old_gate.is_open, "TC18 nạp lại vẫn mở hai lối vào phòng 6")
	_check(not is_instance_valid(_first) and not is_instance_valid(_second), "TC19 nạp lại không tái sinh Bọ")
	_finish()


func _load_level() -> void:
	SceneManager.change_zone(LEVEL, &"start")
	await _bind_loaded_level()


func _bind_loaded_level() -> void:
	await SceneManager.zone_changed
	_level = get_tree().current_scene as ZoneRoot
	_player = _level.get_node(^"Player") as Player
	var tier: Node = _level.get_node(TIER)
	_trial = tier.get_node(^"Room052WindTrial") as WindTrial
	_first = _trial.get_node_or_null(^"FirstWave") as Encounter
	_second = _trial.get_node_or_null(^"SecondWave") as Encounter
	_exit_gate = _trial.get_node(^"ExitGate") as TrialGrille
	_old_gate = tier.get_node(^"OldStairTrialGate") as StoneGate
	await _frames(3)


func _collect_book() -> bool:
	var shrine: SkillShrine = _level.get_node(TIER).get_node(^"Room05InnerGarden/WindShrine")
	var book: AbilityPickup = shrine.book
	var fx: AbilityAcquireVfx = book.get_node(^"AbilityAcquireVfx")
	var landing: Vector3 = shrine.global_position + Vector3(0, 0.05, 1.05)
	_player.teleport(landing, Vector3.FORWARD)
	await _frames(12)
	if not _check(_player.interactor.current == book.get_node(^"InteractableComponent"), "TC00 Foxy chọn đúng sách gió ở phòng 5"):
		return false
	await _press(&"interact")
	await _until(func() -> bool: return GameState.has_ability(WIND.id), 500)
	_check(GameState.has_ability(WIND.id), "TC00 nhấn F học được kỹ năng gió")
	var arrival := SpawnPoint.find_in(_level, shrine.arrival_spawn_id)
	for frame: int in 600:
		if _player.global_position.distance_to(arrival.global_position) < 0.35 and _player.controls_enabled:
			break
		if is_instance_valid(fx) and frame % 12 == 0:
			fx.close_reveal()
		await get_tree().physics_frame
	return _check(_player.global_position.distance_to(arrival.global_position) < 0.35 and arrival.name == &"BookArrival",
		"TC00 nghi thức tự dịch chuyển Foxy vào phòng 5.1")


func _reflect(beetle: BurrowBeetle, position_: Vector3) -> void:
	if not is_instance_valid(beetle):
		_check(false, "Thiếu Bọ để kiểm tra phản đạn")
		return
	var target: Vector3 = beetle.global_position
	var direction: Vector3 = target - position_
	direction.y = 0.0
	_player.teleport(position_, direction.normalized())
	var shots: Array[StoneSeed] = []
	var on_shot := func(seed: StoneSeed) -> void:
		var muzzle_offset := seed.global_position - beetle.global_position
		muzzle_offset.y = 0.0
		_check(muzzle_offset.normalized().dot(beetle.direction_to_target()) > 0.75,
			"%s quay đầu và nhả đạn về phía Foxy" % beetle.name)
		shots.append(seed)
	beetle.seed_fired.connect(on_shot)
	await _until(func() -> bool: return not shots.is_empty(), 310)
	_check(not shots.is_empty(), "%s đã bắn đạn" % beetle.get_parent().get_parent().name)
	if not shots.is_empty():
		_aim_at(target)
		await _press(&"skill")
		await _until(beetle.is_dead, 100)
		_check(beetle.is_dead(), "%s bị hạ bằng một viên phản đạn" % beetle.name)
	if is_instance_valid(beetle):
		beetle.seed_fired.disconnect(on_shot)
	await _frames(42)


func _aim_at(point: Vector3) -> void:
	var direction := point - _player.global_position
	direction.y = 0.0
	_player.face_instantly(direction.normalized())
	if DisplayServer.get_name() != "headless":
		var screen := _player.get_viewport().get_camera_3d().unproject_position(Vector3(point.x, _player.global_position.y, point.z))
		_player.get_viewport().warp_mouse(screen)


func _path_is_clear(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _enemy_count(wave: Encounter) -> int:
	return wave.get_node(^"Enemies").get_child_count()


func _move_until(action: StringName, done: Callable) -> void:
	Input.action_press(action)
	await _until(done, 220)
	Input.action_release(action)
	await _frames(4)


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _until(done: Callable, max_frames: int) -> void:
	for _frame: int in max_frames:
		if done.call():
			return
		await get_tree().physics_frame


func _frames(count: int) -> void:
	for _frame: int in count:
		await get_tree().physics_frame


func _check(passed: bool, label: String) -> bool:
	print("PASS " if passed else "FAIL ", label)
	if not passed:
		_fails += 1
	return passed


func _finish() -> void:
	print("WIND_TRIAL RESULT fails=", _fails)
	get_tree().quit(_fails)
