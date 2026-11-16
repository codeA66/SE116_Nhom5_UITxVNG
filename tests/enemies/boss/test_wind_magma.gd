extends "res://tests/enemies/boss/boss_test_fixture.gd"
## Va chạm thật tại góc cột, đổi thứ tự tạo, xoay và scale luồng gió.

const BLAST_PATH: String = "res://abilities/wind_blast/wind_blast_area.tscn"
const MAGMA_PATH: String = "res://entities/bosses/boss_1/hazards/magma_spike/magma_hazard.tscn"

var _failures: int = 0
var _pushed: int = 0
var _dissipated: int = 0
var _normal_pushes: int = 0
var _selected: WindReceiverComponent
var _baseline: Script


func _ready() -> void:
	if "--baseline" in OS.get_cmdline_user_args():
		_baseline = load("res://.godot/wind_magma_test/baseline.gd") as Script
	call_deferred("_run")


func _run() -> void:
	for reverse: bool in [false, true]:
		for angle: float in [0.0, PI * 0.25, PI * 0.5, PI, PI * 1.5]:
			await _case("corner", reverse, angle, Vector3.ONE, 2.5)
		await _case("front_surface", reverse, 0.0, Vector3.ONE, 2.5)
	for size: Vector3 in [Vector3.ONE * 0.2, Vector3.ONE * 4.0, Vector3(2, 0.5, 3)]:
		await _case("corner", true, PI * 0.25, size, 0.3)
		await _case("front_surface", false, PI * 0.5, size, 8.0)
	await _test_normal_receivers()
	await _test_fireball_reflection()
	await _test_cancel()
	await get_tree().process_frame
	print("WIND_MAGMA_RESULT failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _blast(at: Transform3D) -> Area3D:
	var blast: Area3D = (load(BLAST_PATH) as PackedScene).instantiate() as Area3D
	# Test chọn mục tiêu không cần dựng hình; test wind/reactive chạy scene đầy đủ.
	blast.get_node("WindBlastVfx").free()
	if _baseline != null:
		blast.set_script(_baseline)
	add_child(blast)
	blast.owner = self
	blast.global_transform = at
	blast.connect(&"pushed", _on_push)
	blast.connect(&"dissipated", _on_dissipated)
	return blast


func _spike(at: Transform3D) -> MagmaHazard:
	var spike: MagmaHazard = (load(MAGMA_PATH) as PackedScene).instantiate() as MagmaHazard
	spike.lifetime = 10.0
	add_child(spike)
	spike.start(AttackData.new(), at.origin, at.basis.z.normalized())
	spike.global_transform = at
	return spike


func _case(label: String, reverse: bool, angle: float, size: Vector3, width: float) -> void:
	var frame: Transform3D = Transform3D(Basis(Vector3.UP, angle) * Basis.from_scale(size), Vector3(25, 0, 25))
	var cross: Basis = Basis(Vector3.UP, PI * 0.5)
	var a_pose: Transform3D = Transform3D(cross, Vector3(-3.95, 0, -1.0))
	var x_pose: Transform3D = Transform3D(cross, Vector3(-3.95, 0, 2.5))
	if label == "front_surface":
		a_pose = Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.5))
	var first: MagmaHazard = _spike(frame * (x_pose if reverse else a_pose))
	var second: MagmaHazard = _spike(frame * (a_pose if reverse else x_pose))
	var a: MagmaHazard = second if reverse else first
	var x: MagmaHazard = first if reverse else second
	var blast: Area3D = _blast(frame)
	var data: WindBlastData = WindBlastData.new()
	data.width = width
	data.reach = 7.0
	_pushed = 0
	_dissipated = 0
	_selected = null
	await get_tree().physics_frame
	blast.call(&"activate", data)
	await get_tree().create_timer(0.1).timeout
	var correct: bool = not a.running and x.running and _selected == a.wind_receiver
	_check(correct, "Phá A, giữ X: %s reverse=%s angle=%s scale=%s width=%s" % [label, reverse, angle, size, width])
	_check(_pushed == 1 and _dissipated == 1 and not bool(blast.call(&"is_active")), "Một nhánh, một pushed/dissipated mỗi lượt")
	print("MAGMA_CASE ", label, " reverse=", reverse, " angle=", angle, " scale=", size, " width=", width, " correct=", correct)
	blast.free()
	a.free()
	x.free()
	await get_tree().physics_frame


func _test_normal_receivers() -> void:
	var target: CharacterBody3D = spawn_target(Vector3(0, 0, 3), 0.0)
	var receiver: WindReceiverComponent = WindReceiverComponent.new()
	receiver.collision_layer = 128
	receiver.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	shape.position.y = 0.9
	receiver.add_child(shape)
	target.add_child(receiver)
	receiver.owner = target
	receiver.pushed.connect(_on_normal_push)
	var blast: Area3D = _blast(Transform3D.IDENTITY)
	_normal_pushes = 0
	var data: WindBlastData = WindBlastData.new()
	await get_tree().physics_frame
	blast.call(&"activate", data)
	await get_tree().create_timer(0.1).timeout
	_check(_normal_pushes == 1 and (target.get_node("HealthComponent") as HealthComponent).current_health == 99, "Receiver thường vẫn nhận lực và damage đúng một lần")
	_check(bool(blast.call(&"is_active")), "Receiver thường không làm gió tan")
	blast.call(&"deactivate")
	blast.free()
	target.free()


func _test_cancel() -> void:
	if _baseline != null:
		return
	var spike: MagmaHazard = _spike(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)))
	var blast: Area3D = _blast(Transform3D.IDENTITY)
	var data: WindBlastData = WindBlastData.new()
	blast.call(&"activate", data)
	var selector: WindBlastTargetSelector = blast.get_node("MagmaSelector") as WindBlastTargetSelector
	selector.offer(spike.wind_receiver)
	blast.call(&"deactivate")
	await get_tree().process_frame
	_check(spike.running, "Hủy chiêu vô hiệu hóa batch chọn đang chờ")
	blast.call(&"activate", data)
	await get_tree().create_timer(0.1).timeout
	_check(not spike.running, "Lượt gió tiếp theo không bị batch cũ làm mất lựa chọn")
	blast.free()
	spike.free()


func _test_fireball_reflection() -> void:
	var boss: Boss1 = spawn_boss()
	boss.current_phase = 2
	boss.activate_invulnerable_shield()
	var pool: ObjectPool = boss.get_node("FireballPool") as ObjectPool
	var shot: BossFireball = pool.acquire() as BossFireball
	shot.finished.connect(pool.release)
	shot.launch(Vector3(0, 1.2, 5), Vector3.BACK, boss)
	var blast: Area3D = _blast(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, 6)))
	var data: WindBlastData = WindBlastData.new()
	data.reach = 7.0
	await get_tree().physics_frame
	blast.call(&"activate", data)
	await get_tree().create_timer(0.7).timeout
	_check(not boss.is_shielded and pool.get_active_count() == 0, "Skill gió thật phản cầu lửa về boss, phá khiên và trả pool")
	_check(bool(blast.call(&"is_active")), "Phản cầu lửa không bị xử lý như magma")
	blast.call(&"deactivate")
	blast.free()
	boss.free()


func _on_push(receiver: WindReceiverComponent) -> void:
	_pushed += 1
	_selected = receiver


func _on_dissipated() -> void:
	_dissipated += 1


func _on_normal_push(_impulse: Vector3) -> void:
	_normal_pushes += 1


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + message)
