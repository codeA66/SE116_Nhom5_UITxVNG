extends Node
## Chạy scene này bằng Godot để kiểm tra luồng 5 → 5.1 (rơi qua hố) → 5.2 → 5.3 (tuỳ chọn) → 6 với bản đồ thật.

const WindTrial := preload("res://levels/zone_1_wind/level_1/rooms/tier_1/wind_trial/room_05_2_wind_trial.gd")
const WindChallenge := preload("res://levels/zone_1_wind/level_1/rooms/tier_1/wind_trial/challenge/room_05_3_wind_challenge.gd")
const CHARM: CharmData = preload("res://resources/player/items/charms/challenge_charm.tres")
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
var _walk_gate: StoneGate
var _challenge: WindChallenge
var _challenge_gate: TrialGrille


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
	_check(not _walk_gate.is_open, "TC00 chưa học Gió thì cầu thang lên 5.1 bị chặn")
	if not await _collect_book():
		_finish()
		return

	# UC01: từ ban công 5.1 rơi qua hố xuống giữa 5.2, các lối ra khóa.
	var checkpoint_before: StringName = GameState.get_checkpoint_spawn_id()
	_check(not _exit_gate.is_open and not _old_gate.is_open and not _challenge_gate.is_open,
		"TC01 lối lên phòng 6 và cửa sang 5.3 bị chặn trước trận")
	_check(_walk_gate.is_open, "TC02 học Gió xong thì cầu thang từ phòng 9 lên 5.1 mở")
	_check(not _path_is_clear(Vector3(6, 6.25, -62), Vector3(6, 6.25, -66)), "TC03 cầu thang cũ chặn đường đi tắt")
	_check(_player.global_position.y > 7.5 and _trial.current_wave == 0, "TC04 đứng trên ban công 5.1, chưa có quái")
	await _move_until(&"move_right", func() -> bool: return _player.global_position.x >= 34.9)
	await _move_until(&"move_forward", func() -> bool: return _trial.current_wave == 1)
	await _until(func() -> bool: return _player.is_on_floor(), 120)
	await _frames(3)
	_check(_player.global_position.y < 4.0 and GameState.get_checkpoint_spawn_id() == checkpoint_before,
		"TC04 rơi qua hố xuống sàn 5.2, không đổi checkpoint")
	_check(_trial.current_wave == 1 and _enemy_count(_first) == 1, "TC05 đáp xuống 5.2, xuất hiện đúng một Bọ")
	_check(not (_challenge_gate.get_node(^"CollisionShape3D") as CollisionShape3D).disabled, "TC06 cửa sang 5.3 vẫn khóa")
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
	_check(_trial.is_active() and _exit_gate.is_open and _old_gate.is_open, "TC13 hạ Bọ cuối mới mở lối lên phòng 6")
	await _frames(30)
	_check(_challenge_gate.is_open and (_challenge_gate.get_node(^"CollisionShape3D") as CollisionShape3D).disabled,
		"TC13 hạ Bọ cuối mở cửa sang 5.3")

	# UC04: thử thách 5.3 tuỳ chọn, ba đợt, không rơi Soul Jade, thưởng bùa.
	await _run_challenge()

	# Đi tiếp: từ 5.2 lên dốc sang phòng 6.
	_player.teleport(Vector3(34.5, 3.65, -74), Vector3.LEFT)
	await _frames(6)
	await _move_until(&"move_left", func() -> bool: return _player.global_position.x < 23.8)
	_check(_player.global_position.x < 24.5 and is_equal_approx(snappedf(_player.global_position.y, 0.1), 5.4),
		"TC14 đi thật lên dốc, qua cửa và sang sàn phòng 6")
	_check(GameState.get_checkpoint_spawn_id() == checkpoint_before, "TC15 vào phòng 6 không đổi checkpoint")

	# UC03: hồ sơ cũ vẫn nạp được hai vị trí checkpoint đã bỏ.
	var legacy_entry := SpawnPoint.find_in(_level, LEGACY_ENTRY)
	_check(is_instance_valid(legacy_entry) and legacy_entry.global_position.distance_to(Vector3(24.8, 3.6, -58)) < 0.1,
		"TC16 save cũ ở 5.1 xuất hiện ở chân cầu thang")
	var saved := SaveManager.to_dict(GameState.progress)
	saved["checkpoint"] = {"zone": LEVEL, "spawn": String(LEGACY_EXIT)}
	GameState.replace_progress(SaveManager.from_dict(saved))
	SceneManager.go_to_last_checkpoint()
	await _bind_loaded_level()
	_check(_player.global_position.distance_to(Vector3(23.8, 5.4, -74.9)) < 0.3,
		"TC17 nạp save cũ đưa Foxy về Phòng 6")
	_check(_trial.is_active() and _exit_gate.is_open and _old_gate.is_open and _challenge_gate.is_open,
		"TC18 nạp lại vẫn mở lối lên phòng 6 và cửa sang 5.3")
	_check(not is_instance_valid(_first) and not is_instance_valid(_second), "TC19 nạp lại không tái sinh Bọ")
	await _frames(3)
	_check(_challenge.is_active() and _challenge.get_node_or_null(^"Waves/Wave1") == null
		and _challenge.get_node_or_null(^"RewardCharm") == null and _challenge.get_node(^"EntryGate").is_open,
		"TC27 nạp lại: 5.3 trống quái, bùa đã nhặt không hiện lại, cửa mở")
	_finish()


func _run_challenge() -> void:
	var waves: Array[Encounter] = []
	for wave: Node in _challenge.get_node(^"Waves").get_children():
		waves.append(wave as Encounter)
	_check(waves.size() == 3, "TC20 phòng thử thách có 3 đợt")
	var stripped := true
	for wave: Encounter in waves:
		for source: Variant in wave.get_shader_warmup_sources():
			var enemy := source as Node
			var loot := enemy.get_node_or_null(^"LootDropComponent") as LootDropComponent if enemy else null
			if loot and loot.drop_table != null:
				stripped = false
	_check(stripped, "TC21 quái trong 5.3 không có bảng rơi Soul Jade")
	var totals: Array[int] = []
	for wave: Encounter in waves:
		totals.append(wave.get_shader_warmup_sources().size())
	_player.teleport(Vector3(34, 3.65, -61.2), Vector3.BACK)
	await _frames(6)
	await _move_until(&"move_back", func() -> bool: return _challenge.current_wave == 0)
	await _frames(30)
	_check(_challenge.current_wave == 0 and not _challenge.get_node(^"EntryGate").is_open,
		"TC22 đi thật qua hành lang vào 5.3 thì cửa khóa, bắt đầu đợt 1")
	for index: int in range(waves.size()):
		await _until(func() -> bool: return _challenge.current_wave == index and _enemy_count(waves[index]) > 0, 240)
		var reward_hidden: bool = not (_challenge.get_node(^"RewardCharm") as Node3D).visible
		var defeated: Array[int] = [0]
		waves[index].enemy_died.connect(func(_enemy: Enemy) -> void: defeated[0] += 1)
		# Quái xuất hiện lệch nhịp: hạ dần từng con đã vào cây tới khi đợt xong
		var done: Callable = func() -> bool: return _challenge.current_wave > index or _challenge.is_active()
		for _frame: int in 600:
			if done.call():
				break
			for enemy: Node in waves[index].get_node(^"Enemies").get_children():
				if enemy is Enemy and not (enemy as Enemy).is_dead():
					(enemy as Enemy).health.take_damage(999)
			await get_tree().physics_frame
			reward_hidden = reward_hidden and (_challenge.is_active() or not (_challenge.get_node(^"RewardCharm") as Node3D).visible)
		_check(defeated[0] == totals[index], "TC23 đợt %d: xuất hiện và hạ đủ %d/%d quái" % [index + 1, defeated[0], totals[index]])
		if index < waves.size() - 1:
			_check(reward_hidden and _challenge.current_wave == index + 1 and not _challenge.get_node(^"EntryGate").is_open,
				"TC24 xong đợt %d: sang đợt sau, bùa chưa hiện, cửa vẫn khóa" % [index + 1])
	await _until(func() -> bool: return _challenge.is_active(), 120)
	var charm := _challenge.get_node_or_null(^"RewardCharm") as CharmPickup
	_check(_challenge.is_active() and is_instance_valid(charm) and charm.visible and _challenge.get_node(^"EntryGate").is_open,
		"TC25 xong đợt 3: cửa mở, bùa hiện giữa phòng")
	if is_instance_valid(charm):
		_player.teleport(charm.global_position + Vector3(0, 0.05, 1.0), Vector3.FORWARD)
		await _frames(12)
		await _press(&"interact")
		await _frames(10)
	_check(GameState.owns_charm(CHARM.id), "TC26 nhặt bùa thưởng, bùa có trong trang Bùa")


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
	_walk_gate = tier.get_node(^"TrialWalkGate") as StoneGate
	_challenge = tier.get_node(^"Room053WindChallenge") as WindChallenge
	_challenge_gate = _trial.get_node(^"ChallengeGate") as TrialGrille
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
