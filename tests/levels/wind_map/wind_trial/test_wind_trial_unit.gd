extends Node
## Kiểm tra bộ điều phối hai đợt trong phòng riêng, không nạp bản đồ Level 1.

const WindTrial := preload("res://levels/zone_1_wind/level_1/rooms/tier_1/wind_trial/room_05_2_wind_trial.gd")
const TrialGrille := preload("res://levels/zone_1_wind/level_1/rooms/tier_1/wind_trial/grille/trial_grille.gd")
const ARENA := preload("res://levels/zone_1_wind/level_1/rooms/tier_1/wind_trial/room_05_2_wind_trial.tscn")
const BEETLE := preload("res://entities/enemies/palace/burrow_beetle/burrow_beetle.tscn")
const SEED := preload("res://objects/combat/projectiles/stone_seed/stone_seed.tscn")
const WIND: WindBlastData = preload("res://abilities/wind_blast/wind_blast.tres")

var _fails: int


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState.replace_progress(PlayerProgress.new())
	var arena: WindTrial = ARENA.instantiate() as WindTrial
	arena.wave_break = 0.0
	add_child(arena)
	var entry: Area3D = arena.get_node(^"EntryTrigger")
	var entry_left: Node3D = arena.get_node(^"ChallengeGate/Left")
	var entry_right: Node3D = arena.get_node(^"ChallengeGate/Right")
	var entry_shape: CollisionShape3D = arena.get_node(^"ChallengeGate/CollisionShape3D")
	var exit_shape: CollisionShape3D = arena.get_node(^"ExitGate/CollisionShape3D")
	var gate: TrialGrille = arena.get_node(^"ExitGate")
	var first: Encounter = arena.get_node(^"FirstWave")
	var second: Encounter = arena.get_node(^"SecondWave")
	var player := Player.new()
	entry.body_entered.emit(player)
	_check(arena.current_wave == 0 and not gate.is_open, "UT01 thiếu kỹ năng gió thì trận chưa bắt đầu")
	GameState.unlock_ability(WIND)
	entry.body_entered.emit(arena)
	_check(arena.current_wave == 0, "UT02 chỉ Foxy kích hoạt trận")
	entry.body_entered.emit(player)
	await _frames(3)
	_check(arena.current_wave == 1 and first.is_running(), "UT03 bắt đầu ở đợt một")
	_check(is_equal_approx(entry_right.position.x - entry_left.position.x, 2.07) and not entry_shape.disabled,
		"UT08 cửa sang 5.3 đóng sẵn từ đầu, hai cánh khép giữa")
	first.cleared.emit()
	await _until(func() -> bool: return second.is_running(), 15)
	_check(arena.current_wave == 2 and not gate.is_open, "UT04 đợt hai bắt đầu khi thời gian nghỉ bằng 0")
	var waiting := second.get_shader_warmup_sources()
	second.cleared.emit()
	_check(arena.is_active() and gate.is_open and not exit_shape.disabled,
		"UT05 tín hiệu hết đợt cuối bắt đầu mở cổng, va chạm giữ tới khi cánh trượt xong")
	await _until(func() -> bool: return exit_shape.disabled, 45)
	_check(entry_shape.disabled and exit_shape.disabled, "UT10 cả lối lên phòng 6 và cửa sang 5.3 thông sau khi cánh trượt xong")
	player.free()
	arena.queue_free()
	await _frames(3)
	_check(waiting.size() == 1 and not is_instance_valid(waiting[0]), "UT06 rời phòng giữa đợt dọn cả Bọ chưa xuất hiện")

	var cleared: WindTrial = ARENA.instantiate() as WindTrial
	add_child(cleared)
	await _frames(3)
	var cleared_gate: TrialGrille = cleared.get_node(^"ExitGate")
	var cleared_challenge: TrialGrille = cleared.get_node(^"ChallengeGate")
	var cleared_entry: Area3D = cleared.get_node(^"EntryTrigger")
	_check(cleared_gate.is_open and cleared_challenge.is_open and not cleared_entry.monitoring and not cleared.has_node(^"FirstWave")
		and not cleared.has_node(^"SecondWave"), "UT07 phòng đã thắng mở cả hai cửa và bỏ qua cả hai đợt")
	_test_beetle_facing()
	await _test_projectile_impulse()
	print("WIND_TRIAL UNIT RESULT fails=", _fails)
	get_tree().quit(_fails)


func _test_beetle_facing() -> void:
	var beetle: BurrowBeetle = BEETLE.instantiate()
	add_child(beetle)
	for heading: float in [0.0, 180.0]:
		beetle.rotation_degrees.y = heading
		var direction := Vector3(0.8, 0.0, 0.6)
		beetle.face_instantly(direction)
		_check(beetle.model.global_basis.z.normalized().dot(direction) > 0.999,
			"UT11 Bọ xoay đúng khi góc đặt là %.0f°" % heading)
		var other_side := Vector3(-0.6, 0.0, 0.8)
		beetle.face_direction(other_side, 1.0)
		_check(beetle.model.global_basis.z.normalized().dot(other_side) > 0.99,
			"UT12 Bọ bám đúng hướng khi Foxy đổi bên, góc đặt %.0f°" % heading)
	beetle.queue_free()


func _test_projectile_impulse() -> void:
	var seed: StoneSeed = SEED.instantiate()
	add_child(seed)
	var receiver: WindReceiverComponent = seed.get_node(^"WindReceiverComponent")
	var origin := Vector3(40.0, 3.0, 40.0)
	for direction: Vector3 in [Vector3.BACK, Vector3(0.6, 0.0, 0.8)]:
		seed.launch(origin, origin + Vector3.FORWARD, null)
		var impulse := direction * 12.0
		receiver.push(impulse)
		await _frames(4)
		var expected := Vector3.FORWARD * seed.speed + impulse * seed.wind_response
		var displacement := seed.global_position - origin
		_check(seed.is_reflected() and displacement.normalized().dot(expected.normalized()) > 0.999,
			"UT13 đạn bay theo tổng vận tốc khi cú gió có hướng %s" % direction)
		if direction.x > 0.0:
			_check(displacement.x > 0.1, "UT14 thổi chéo làm đạn lệch khỏi đường về Bọ")
	seed.queue_free()


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
