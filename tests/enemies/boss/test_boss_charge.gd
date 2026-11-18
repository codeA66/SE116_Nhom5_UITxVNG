extends Node3D
## Chạy va chạm thật, kiểm tra đường tông và vòng đời chiêu thay vì chỉ đọc cấu hình.

const BOSS_PATH: String = "res://entities/bosses/boss_1/boss_1.tscn"
const FIREBALL_PATH: String = "res://objects/combat/projectiles/boss_fireball/boss_fireball.tscn"

@export var capture_review: bool = false

var _failures: int = 0
var _case_elapsed: float = 0.0
var _started_at: float = -1.0
var _hit_count: int = 0
var _last_impulse: Vector3 = Vector3.ZERO
var _reason: StringName
var _shot_returned: int = 0
var _boss_broken: bool = false
var _floor: StaticBody3D

func _ready() -> void:
	capture_review = capture_review or "--capture" in OS.get_cmdline_user_args()
	call_deferred("_run")

func _run() -> void:
	_floor = _box(Vector3(120, 0.2, 120), Vector3(0, -0.1, 0))
	await _case("default", {})
	await _case("fast_sweep", {"speed": 600.0, "distance": 16.0, "warning_duration": 0.12, "recovery_duration": 0.1})
	await _case("tiny_distance", {"distance": 0.01, "warning_duration": 0.02, "recovery_duration": 0.02, "target_z": 0.01})
	await _case("slow_wide", {"speed": 3.0, "distance": 1.0, "hitbox_size": Vector3(8, 3, 0.2), "warning_duration": 0.1, "recovery_duration": 0.1, "target_z": 1.0})
	await _case("thin_long", {"distance": 20.0, "hitbox_size": Vector3(0.3, 3, 2), "warning_duration": 0.12, "recovery_duration": 0.1})
	await _case("dodge_after_lock", {"dodge": true, "warning_duration": 0.12, "recovery_duration": 0.1})
	await _case("diagonal_tracking", {"move_warning": true, "warning_duration": 0.3, "recovery_duration": 0.1})
	await _case("stop_on_hit", {"stop_on_player_hit": true, "warning_duration": 0.12, "recovery_duration": 0.1})
	await _case("wall", {"wall": true, "warning_duration": 0.12, "recovery_duration": 0.1})
	await _case("behind_wall", {"wall": true, "target_z": 4.3, "warning_duration": 0.12, "recovery_duration": 0.1})
	await _case("ledge", {"ledge": true, "warning_duration": 0.12, "recovery_duration": 0.1})
	await _case("cancel_warning", {"cancel": true})
	await _case("cancel_rush", {"cancel_rush": true, "warning_duration": 0.12})
	await _case("small_phase3", {"size": 0.5, "phase": 3, "warning_duration": 0.12, "recovery_duration": 0.1})
	await _case("large_phase3", {"size": 2.0, "phase": 3, "warning_duration": 0.12, "recovery_duration": 0.1})
	await _test_selection()
	await _test_fireball()
	if capture_review:
		await _capture_review()
	_floor.queue_free()
	print("BOSS_CHARGE_RESULT failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)

func _case(label: String, settings: Dictionary) -> void:
	var boss: Boss1 = (load(BOSS_PATH) as PackedScene).instantiate() as Boss1
	var controller: BossChargeController = boss.get_node("ChargeController") as BossChargeController
	controller.enabled = false
	var charge: BossCharge = boss.get_node("StateMachine/Charge") as BossCharge
	var skeleton: Skeleton3D = boss.get_node("Model/Visual/BossModel/Armature/Skeleton3D") as Skeleton3D
	var leg: int = skeleton.find_bone("mixamorig_RightLeg")
	charge.data = charge.data.duplicate(true) as BossChargeData
	for key: String in settings:
		if key in ["speed", "distance", "hitbox_size", "warning_duration", "recovery_duration", "stop_on_player_hit"]:
			charge.data.set(key, settings[key])
	var size: UniformScaleComponent = boss.get_node("Size") as UniformScaleComponent
	size.multiplier = float(settings.get("size", 1.25))
	add_child(boss)
	boss.current_phase = int(settings.get("phase", 1))
	_check(boss.scale.is_equal_approx(Vector3.ONE * size.multiplier), "Boss áp dụng multiplier " + label)
	var original_marker: Vector3 = boss.get_node("Model/FireballSpawn").position
	_check((boss.get_node("Model/FireballSpawn") as Node3D).global_position.is_equal_approx(original_marker * size.multiplier), "Điểm phóng theo kích thước boss")
	var health: HealthComponent = HealthComponent.new()
	health.max_health = 20
	add_child(health)
	var target: HurtboxComponent = HurtboxComponent.new()
	target.health = health
	target.collision_layer = 2
	target.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.4, 0.4, 0.4)
	shape.shape = box
	target.add_child(shape)
	add_child(target)
	target.position = Vector3(0, 1.2, float(settings.get("target_z", 6.0)))
	health.damaged.connect(_on_damage)
	target.hurt.connect(_on_hurt)
	var wall: StaticBody3D
	var platform: StaticBody3D
	if bool(settings.get("wall", false)):
		wall = _box(Vector3(12, 6, 0.3), Vector3(0, 3, 4))
	if bool(settings.get("ledge", false)):
		_floor.collision_layer = 0
		platform = _box(Vector3(8, 0.2, 4), Vector3(0, -0.1, -1))
	for frame: int in range(5):
		await get_tree().physics_frame
	boss.target_player = target
	_case_elapsed = 0.0
	_started_at = -1.0
	_hit_count = 0
	_last_impulse = Vector3.ZERO
	_reason = &""
	charge.charge_started.connect(_on_started)
	charge.charge_finished.connect(_on_finished)
	boss.state_machine.transition_to(&"Charge")
	var origin: Vector3 = boss.global_position
	var dodged: bool = false
	var warning_moved: bool = false
	var cancelled: bool = false
	var first_rush_pose: Quaternion = Quaternion.IDENTITY
	var has_rush_pose: bool = false
	var leg_motion: float = 0.0
	var maximum_time: float = charge.data.warning_duration + charge.data.distance / maxf(charge.data.speed, 0.01) + charge.data.recovery_duration + 1.0
	while _case_elapsed < maximum_time:
		await get_tree().physics_frame
		_case_elapsed += get_physics_process_delta_time()
		if charge.is_rushing():
			var pose: Quaternion = skeleton.get_bone_pose_rotation(leg)
			if not has_rush_pose:
				first_rush_pose = pose
				has_rush_pose = true
			leg_motion = maxf(leg_motion, first_rush_pose.angle_to(pose))
		if _started_at < 0.0:
			_check(origin.distance_to(boss.global_position) < 0.03, "Không lao trước khi hết cảnh báo " + label)
			_check(_hit_count == 0, "Cảnh báo chưa gây sát thương " + label)
		if charge.indicator.visible:
			_check(absf(charge.indicator.displayed_width - charge.hitbox.get_box_size().x * boss.scale.x) < 0.001, "Chỉ thị khớp chiều rộng hitbox " + label)
			var actual_depth: float = charge.hitbox.get_box_size().z * boss.scale.z
			_check(charge.indicator.displayed_length >= charge.get_planned_distance() + actual_depth - 0.001, "Chỉ thị bao cả khoảng quét của hitbox " + label)
		if bool(settings.get("cancel", false)) and _case_elapsed > 0.15:
			boss.state_machine.transition_to(&"Idle")
			cancelled = true
			break
		if bool(settings.get("cancel_rush", false)) and charge.is_rushing() and boss.position.z > 0.2:
			boss.state_machine.transition_to(&"Idle")
			cancelled = true
			break
		if bool(settings.get("dodge", false)) and charge.is_rushing() and not dodged:
			target.position.x = 8.0
			dodged = true
		if bool(settings.get("move_warning", false)) and not warning_moved and _case_elapsed > 0.05:
			target.position.x = 4.0
			warning_moved = true
		if boss.state_machine.current_state != charge:
			break
	boss.set_physics_process(false)
	_check(boss.state_machine.current_state != charge, "Chiêu tự kết thúc " + label)
	_check(not charge.hitbox.is_active() and not charge.hitbox.is_physics_processing(), "Tắt hitbox và sweep khi hết chiêu " + label)
	_check(not charge.indicator.visible, "Tắt chỉ thị khi kết thúc " + label)
	_check(not charge.effect.is_processing(), "Tắt VFX sau chiêu " + label)
	_check(not charge.animation_player.has_section(), "Trả lại toàn bộ clip cho các state tiếp theo " + label)
	if label == "default":
		_check(leg_motion > 0.1, "Chân boss thực sự chạy animation trong lúc tông")
		print("CHARGE_ANIMATION leg_motion_radians=", leg_motion)
	if cancelled:
		if bool(settings.get("cancel", false)):
			_check(_started_at < 0.0 and _hit_count == 0, "Ngắt trước khi tông không gây damage")
			_check(controller.get_cooldown_remaining() == 0.0, "Ngắt cảnh báo chưa tiêu hồi chiêu")
		else:
			_check(_started_at >= 0.0 and controller.get_cooldown_remaining() > 0.0, "Ngắt lúc tông vẫn giữ hồi chiêu")
	elif bool(settings.get("wall", false)):
		_check(boss.global_position.z < 4.0 and _hit_count == 0, "Dừng trước tường, không đánh xuyên tường")
	elif bool(settings.get("ledge", false)):
		_check(_reason == &"ledge" and boss.position.z < 1.01 and boss.position.y > -0.05, "Dừng trước khi rơi khỏi mép sàn")
	elif bool(settings.get("stop_on_player_hit", false)):
		_check(_reason == &"player" and _hit_count == 1 and boss.position.z < target.position.z, "Tùy chọn dừng ngay khi tông trúng")
	else:
		var expected: Vector3 = Vector3(4, 0, 6).normalized() * charge.data.distance if warning_moved else Vector3(0, 0, charge.data.distance)
		_check(boss.global_position.distance_to(expected) < 0.05, "Đi đúng quãng đường và hướng đã khóa " + label)
		_check(absf(_started_at - charge.data.warning_duration) < 0.06, "Cảnh báo đủ thời gian " + label)
		_check(_hit_count == (0 if dodged else 1), "Số lần trúng thật " + label)
		_check(health.current_health == 20 - (0 if dodged else charge.data.attack.damage * boss.get_damage_multiplier()), "Sát thương thật " + label)
		if not dodged:
			_check(_last_impulse.normalized().dot(charge.get_locked_direction()) > 0.999, "Đẩy đúng hướng kể cả khi quét đã vượt player " + label)
		_check(controller.get_cooldown_remaining() <= charge.data.get_cooldown(boss.current_phase), "Cooldown đúng phase")
	print("CHARGE_CASE ", label, " launch=", _started_at, " end=", boss.global_position, " hits=", _hit_count, " reason=", _reason)
	boss.target_player = null
	boss.queue_free()
	target.queue_free()
	health.queue_free()
	if wall != null:
		wall.queue_free()
	if platform != null:
		platform.queue_free()
		_floor.collision_layer = 1
	await get_tree().physics_frame
	await get_tree().physics_frame

func _test_selection() -> void:
	var boss: Boss1 = (load(BOSS_PATH) as PackedScene).instantiate() as Boss1
	var controller: BossChargeController = boss.get_node("ChargeController") as BossChargeController
	controller.enabled = false
	var charge: BossCharge = boss.get_node("StateMachine/Charge") as BossCharge
	charge.data = charge.data.duplicate(true) as BossChargeData
	charge.data.selection_chance = 1.0
	add_child(boss)
	var target: Marker3D = Marker3D.new()
	add_child(target)
	target.position.z = 6.0
	for frame: int in range(5):
		await get_tree().physics_frame
	boss.target_player = target
	controller.enabled = true
	_check(controller.request_charge(), "Bộ chọn thêm Charge khi đủ điều kiện")
	boss.state_machine.transition_to(&"Idle")
	boss.is_shielded = true
	_check(not controller.request_charge(true), "Ưu tiên cơ chế khiên và cầu lửa")
	boss.is_shielded = false
	charge.data.selection_chance = 0.0
	_check(not controller.request_charge(), "Tắt xác suất chọn bằng Resource")
	_check(controller.request_charge(true), "Debug ép chọn có thể bỏ qua xác suất")
	charge.data.selection_chance = 1.0
	boss.state_machine.transition_to(&"Idle")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(boss.state_machine.current_state == charge, "Sự kiện vào Idle tự chọn Charge trong AI thật")
	controller.enabled = false
	boss.state_machine.transition_to(&"Idle")
	boss.queue_free()
	target.queue_free()
	await get_tree().physics_frame

func _test_fireball() -> void:
	var boss: Boss1 = (load(BOSS_PATH) as PackedScene).instantiate() as Boss1
	(boss.get_node("ChargeController") as BossChargeController).enabled = false
	add_child(boss)
	boss.set_physics_process(false)
	var pool: ObjectPool = boss.get_node("FireballPool") as ObjectPool
	for iteration: int in range(4):
		var shot: BossFireball = pool.acquire() as BossFireball
		_check(shot.global_basis.get_scale().is_equal_approx(Vector3.ONE * 1.5), "Cầu lửa lớn độc lập scale boss và không tăng dồn")
		pool.release(shot)
	var shot: BossFireball = pool.acquire() as BossFireball
	var size: UniformScaleComponent = shot.get_node("Size") as UniformScaleComponent
	for value: float in [0.1, 4.0, 1.5]:
		size.multiplier = value
		_check(shot.global_basis.get_scale().is_equal_approx(Vector3.ONE * value), "Debug kích thước cầu lửa " + str(value))
	var health: HealthComponent = HealthComponent.new()
	health.max_health = 10
	add_child(health)
	var target: HurtboxComponent = HurtboxComponent.new()
	target.health = health
	target.collision_layer = 2
	target.collision_mask = 0
	var target_shape: CollisionShape3D = CollisionShape3D.new()
	var target_sphere: SphereShape3D = SphereShape3D.new()
	target_sphere.radius = 0.05
	target_shape.shape = target_sphere
	target.add_child(target_shape)
	add_child(target)
	target.position.y = 1.2
	shot.launch(Vector3(0.55, 1.2, 4), Vector3.FORWARD, boss)
	var hit_elapsed: float = 0.0
	while hit_elapsed < 0.7 and health.current_health == 10:
		await get_tree().physics_frame
		hit_elapsed += get_physics_process_delta_time()
	_check(health.current_health == 9, "Vùng va chạm cầu lửa thực sự rộng hơn ở mép 0,55 m")
	pool.release(shot)
	target.queue_free()
	health.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	shot = pool.acquire() as BossFireball
	boss.current_phase = 2
	boss.activate_invulnerable_shield()
	_boss_broken = false
	boss.shield_broken.connect(_on_shield_broken)
	shot.finished.connect(_on_shot_finished)
	shot.launch(Vector3(0, 1.2, 5), Vector3.FORWARD, boss)
	var receiver: WindReceiverComponent = shot.get_node("WindReceiverComponent") as WindReceiverComponent
	receiver.push(Vector3.FORWARD * 10.0)
	var elapsed: float = 0.0
	while elapsed < 1.0 and not _boss_broken:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	_check(_boss_broken, "Cầu lửa lớn phản gió và va chạm phá khiên thật")
	_check(_shot_returned == 1, "Cầu lửa báo hoàn tất một lần khi phá khiên")
	pool.release(shot)
	boss.queue_free()
	await get_tree().physics_frame

func _capture_review() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().size = Vector2i(1440, 1000)
	var environment: WorldEnvironment = WorldEnvironment.new()
	add_child(environment)
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.05, 0.065, 0.085)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.7, 0.8, 1.0)
	environment.environment.ambient_light_energy = 0.6
	var light: DirectionalLight3D = DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.light_energy = 1.25
	light.shadow_enabled = true
	var floor_visual: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_visual.mesh = plane
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.075, 0.09, 0.11)
	material.roughness = 0.95
	floor_visual.material_override = material
	add_child(floor_visual)
	var fox: Node3D = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Node3D
	add_child(fox)
	fox.set_physics_process(false)
	fox.position = Vector3(0, 0, 3)
	var boss: Boss1 = (load(BOSS_PATH) as PackedScene).instantiate() as Boss1
	(boss.get_node("ChargeController") as BossChargeController).enabled = false
	add_child(boss)
	boss.position = Vector3(0, 0, -5)
	boss.target_player = fox
	var camera: Camera3D = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(12, 16, 16)
	camera.look_at(Vector3(0, 0.7, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 19.0
	camera.current = true
	for frame: int in range(4):
		await get_tree().physics_frame
	var charge: BossCharge = boss.get_node("StateMachine/Charge") as BossCharge
	boss.state_machine.transition_to(&"Charge")
	await get_tree().create_timer(0.5).timeout
	await _save_review("charge_warning")
	while not charge.is_rushing():
		await get_tree().physics_frame
	for frame: int in range(3):
		await get_tree().physics_frame
	await _save_review("charge_rush")
	await get_tree().create_timer(0.18).timeout
	await _save_review("charge_rush_mid")
	boss.state_machine.transition_to(&"Idle")
	boss.set_physics_process(false)
	var shot: BossFireball = (boss.get_node("FireballPool") as ObjectPool).acquire() as BossFireball
	shot.launch(boss.global_position + Vector3(2.5, 2, 1), Vector3.ZERO, boss)
	await _save_review("boss_and_fireball_size")
	boss.queue_free()
	fox.queue_free()

func _save_review(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/boss_charge_test/" + label + ".png")

func _on_started(_direction: Vector3) -> void:
	_started_at = _case_elapsed

func _on_finished(reason: StringName) -> void:
	_reason = reason

func _on_damage(_amount: int) -> void:
	_hit_count += 1

func _on_hurt(info: DamageInfo, _damage: int) -> void:
	_last_impulse = info.knockback

func _on_shield_broken() -> void:
	_boss_broken = true

func _on_shot_finished(_shot: BossFireball) -> void:
	_shot_returned += 1

func _box(size: Vector3, center: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	body.position = center
	return body

func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		if _failures <= 12:
			push_error("FAIL: " + description)
