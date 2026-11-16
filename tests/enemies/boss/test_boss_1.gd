extends "res://tests/enemies/boss/boss_test_fixture.gd"
## Hồi quy khóa máu, sát thương, hủy hazard và cấu hình lệch trên node thật.

var _failures: int = 0
var _deaths: int = 0
var _finishes: int = 0
var _applied: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	spawn_box(Vector3(200, 0.2, 200), Vector3(0, -0.1, 0))
	for maximum: int in [1, 50, 5000]:
		_test_gates(maximum)
	_test_resource_isolation()
	_test_target_replacement()
	await _test_shared_hitbox()
	await _test_minions()
	await _test_auto_magma()
	await _test_moveset_damage()
	await _test_magma_lifecycle()
	await _test_fast_fireball()
	await _test_death_cleanup()
	await _test_configuration()
	await get_tree().process_frame
	await get_tree().process_frame
	print("BOSS_CLEANUP_RESULT failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)

func _hit(amount: int) -> DamageInfo:
	var info: DamageInfo = DamageInfo.new(amount, DamageInfo.Type.PHYSICAL, Vector3.ZERO, null)
	info.ignores_invincibility = true
	return info

func _test_gates(maximum: int) -> void:
	var boss: Boss1 = spawn_boss(maximum)
	_deaths = 0
	boss.boss_defeated.connect(_on_death)
	_check(boss.hurtbox.receive_hit(_hit(100000)), "Đòn quá HP được xử lý")
	_check(boss.current_phase == 2 and boss.is_shielded, "Vào phase 2 trước khi chết " + str(maximum))
	_check(boss.health.current_health == maxi(int(maximum * 0.5), 1) and _deaths == 0, "Khóa 50%, không phát chết")
	var before: int = boss.health.current_health
	_check(not boss.hurtbox.receive_hit(_hit(100000)), "Khiên từ chối đòn xuyên i-frame")
	boss.health.take_damage(100000)
	_check(boss.health.current_health == before and _deaths == 0, "Khiên chặn cả sát thương trực tiếp")
	boss.on_explosion_hit(null)
	_check(boss.state_machine.current_state.name == &"Idle", "Phá khiên về Idle")
	boss.hurtbox.receive_hit(_hit(100000))
	_check(boss.current_phase == 3 and boss.shield_stacks == 2, "Vào phase 3, hai khiên")
	_check(boss.health.current_health == maxi(int(maximum * 0.4), 1) and _deaths == 0, "Hồi 40%, không phát chết sớm")
	boss.on_explosion_hit(null)
	_check(boss.is_shielded and boss.shield_stacks == 1, "Phá đúng một lớp khiên")
	boss.on_explosion_hit(null)
	boss.hurtbox.receive_hit(_hit(100000))
	boss.health.take_damage(100000)
	boss.on_death()
	_check(boss.health.is_dead() and _deaths == 1, "Chỉ chết một lần sau khi hết các mốc")
	boss.free()

func _test_resource_isolation() -> void:
	var first: Boss1 = spawn_boss()
	var second: Boss1 = spawn_boss()
	var charge: BossCharge = first.get_node("StateMachine/Charge") as BossCharge
	var base: int = first.melee_attack_data.damage
	var charge_base: int = charge.data.attack.damage
	var attack: AttackData = first.get_attack_data(charge.data.attack)
	for factor: int in [0, 2, 7]:
		first.data.damage_multiplier_phase3 = factor
		first.current_phase = 3
		_check(first.melee_attack_data.damage == base * factor, "Hệ số melee " + str(factor))
		_check(attack.damage == charge_base * factor, "Hệ số Charge " + str(factor))
		_check(second.melee_attack_data.damage == base and charge.data.attack.damage == charge_base, "Không đổi Resource nguồn hoặc boss khác")
	first.current_phase = 1
	_check(first.melee_attack_data.damage == base, "Đổi phase debug không nhân damage dồn")
	_check(first.movement != second.movement, "Movement riêng mỗi boss")
	_check(first.shield_sphere.material_override != second.shield_sphere.material_override, "Material khiên riêng mỗi boss")
	first.free()
	second.free()

func _test_target_replacement() -> void:
	var boss: Boss1 = spawn_boss()
	var old: Marker3D = Marker3D.new()
	var replacement: Marker3D = Marker3D.new()
	add_child(old)
	add_child(replacement)
	boss.set_target_player(old)
	boss.set_target_player(replacement)
	old.free()
	_check(boss.target_player == replacement, "Player cũ rời scene không xóa target mới")
	replacement.free()
	_check(boss.target_player == null, "Target hiện tại rời scene được dọn")
	boss.free()

func _test_shared_hitbox() -> void:
	var hitbox: HitboxComponent = HitboxComponent.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.shape = BoxShape3D.new()
	hitbox.add_child(shape)
	add_child(hitbox)
	var target: CharacterBody3D = spawn_target(Vector3(50, 0, 0))
	var hurtbox: HurtboxComponent = target.get_node("HurtboxComponent") as HurtboxComponent
	var health: HealthComponent = target.get_node("HealthComponent") as HealthComponent
	var attack: AttackData = AttackData.new()
	attack.damage = 3
	hitbox.hit_applied.connect(_on_applied)
	_applied = 0
	hurtbox.set_invincible(0.05)
	hitbox.activate(attack)
	_check(not hitbox.try_hit(hurtbox) and _applied == 0 and health.current_health == 100, "Đòn bị i-frame chặn không phát hit_applied")
	hitbox.deactivate()
	await get_tree().create_timer(0.1).timeout
	hitbox.activate(attack)
	_check(hitbox.try_hit(hurtbox) and _applied == 1 and health.current_health == 97, "Hitbox thường giữ sát thương và i-frame")
	_check(not hitbox.try_hit(hurtbox) and _applied == 1, "Mỗi mục tiêu chỉ trúng một lần")
	hitbox.free()
	target.free()

func _test_minions() -> void:
	var boss: Boss1 = spawn_boss()
	boss.minions.phase2_grunt_count = 1
	boss.minions.phase2_shield_count = 1
	boss.minions.phase2_caster_count = 1
	boss.hurtbox.receive_hit(_hit(100000))
	_check(boss.minions.get_spawned_count() == 3, "Triệu hồi đúng ba loại minion")
	boss.minions.clear()
	_check(boss.minions.get_spawned_count() == 0, "Thu dọn minion khỏi danh sách sở hữu")
	await get_tree().create_timer(0.1).timeout
	boss.free()

func _test_auto_magma() -> void:
	var spike: MagmaHazard = (load("res://entities/bosses/boss_1/hazards/magma_spike/magma_hazard.tscn") as PackedScene).instantiate() as MagmaHazard
	spike.manual_hitbox = false
	spike.lifetime = 0.4
	add_child(spike)
	var attack: AttackData = AttackData.new()
	attack.damage = 1
	spike.start(attack, Vector3(70, 0, 0), Vector3.BACK)
	await get_tree().create_timer(0.5).timeout
	_check(not spike.running and not spike.hitbox.is_active(), "Magma tự dựng collider kết thúc an toàn")
	spike.free()

func _on_applied(_hurtbox: HurtboxComponent) -> void:
	_applied += 1

func _test_moveset_damage() -> void:
	for phase: int in [1, 3]:
		var boss: Boss1 = spawn_boss()
		boss.current_phase = phase
		var factor: int = boss.get_damage_multiplier()
		var target: CharacterBody3D = spawn_target(Vector3(0, 0, 1.5), 0.0)
		var health: HealthComponent = target.get_node("HealthComponent") as HealthComponent
		var hurtbox: HurtboxComponent = target.get_node("HurtboxComponent") as HurtboxComponent
		boss.set_melee_hitbox_active(true, 0.2)
		await get_tree().create_timer(0.1).timeout
		_check(100 - health.current_health == factor, "Va chạm melee phase " + str(phase))
		boss.set_melee_hitbox_active(false)
		health.heal_full()
		target.position = Vector3(0, 0, 5)
		await get_tree().physics_frame
		boss.target_player = target
		boss.spawn_fireball()
		await get_tree().create_timer(0.8).timeout
		_check(100 - health.current_health == factor, "Cầu lửa chạm player có hệ số phase " + str(phase))
		(boss.get_node("FireballPool") as ObjectPool).release_all()
		health.heal_full()
		target.position = Vector3(0, 0, 3.5)
		await get_tree().physics_frame
		boss.trigger_ground_slam()
		await get_tree().create_timer(0.7).timeout
		_check(100 - health.current_health == boss.shockwave_data.damage, "Sóng dậm chạm thật phase " + str(phase))
		boss.shockwave.stop()
		health.heal_full()
		hurtbox.invincibility_time = 0.6
		target.position = Vector3(0, 0, 3.5)
		await get_tree().physics_frame
		boss.trigger_magma_stomp()
		await get_tree().create_timer(0.2).timeout
		_check(100 - health.current_health == boss.magma_attack_data.damage, "Magma chạm thật phase " + str(phase))
		_check(target.velocity.y > 0.0 and hurtbox.is_invincible(), "Hất tung vẫn hoạt động sau khi cấp i-frame")
		boss.radial_magma_hazard.cancel()
		boss.free()
		target.free()
		await get_tree().physics_frame

func _test_magma_lifecycle() -> void:
	var boss: Boss1 = spawn_boss()
	var radial: RadialMagmaHazard = boss.radial_magma_hazard as RadialMagmaHazard
	radial.finished.connect(_on_finished)
	_finishes = 0
	radial.launch(Vector3.ZERO, boss.magma_attack_data)
	radial.cancel()
	radial.cancel()
	_check(_finishes == 1 and not radial.is_active(), "Hủy nhiều lần chỉ hoàn tất một lần")
	for count: int in [1, 24, 0]:
		radial.spoke_count = count
		await get_tree().process_frame
		await get_tree().process_frame
		_check(radial.get_spoke_count() == maxi(count, 1), "Đổi số nhánh rebuild an toàn " + str(count))
		radial.show_telegraph(Vector3.ZERO, 0.1)
		radial.launch(Vector3.ZERO, boss.magma_attack_data)
		radial.cancel()
	var materials: Dictionary = {}
	for mesh: Node in radial.find_children("*", "MeshInstance3D", true, false):
		if mesh.name in [&"WedgeFill", &"WedgeLine"]:
			materials[mesh.get("material_override")] = true
	_check(materials.size() == 2, "Các nhánh chỉ dùng hai material chỉ thị")
	print("MAGMA_TELEGRAPH materials=", materials.size(), " spokes=", radial.get_spoke_count())
	boss.free()

func _test_fast_fireball() -> void:
	for with_wall: bool in [false, true]:
		var boss: Boss1 = spawn_boss()
		boss.position.x = 40.0
		var pool: ObjectPool = boss.get_node("FireballPool") as ObjectPool
		var target: CharacterBody3D = spawn_target(Vector3(40, 0, 5), 0.0)
		var health: HealthComponent = target.get_node("HealthComponent") as HealthComponent
		var wall: StaticBody3D
		if with_wall:
			wall = spawn_box(Vector3(4, 4, 0.05), Vector3(40, 2, 3))
		await get_tree().physics_frame
		await get_tree().physics_frame
		var shot: BossFireball = pool.acquire() as BossFireball
		shot.speed = 600.0
		shot.finished.connect(pool.release)
		shot.launch(Vector3(40, 0.9, 0), Vector3.BACK, boss)
		await get_tree().create_timer(0.1).timeout
		print("FAST_FIREBALL wall=", with_wall, " active=", pool.get_active_count(), " hp=", health.current_health)
		_check(pool.get_active_count() == 0, "Đạn nhanh không xuyên qua player/tường mỏng")
		_check(health.current_health == (100 if with_wall else 99), "Tường chặn sát thương đạn nhanh")
		boss.free()
		target.free()
		if wall:
			wall.free()

func _test_death_cleanup() -> void:
	var boss: Boss1 = spawn_boss()
	boss.current_phase = 3
	boss.trigger_magma_stomp()
	boss.trigger_ground_slam()
	boss.spawn_fireball()
	var pool: ObjectPool = boss.get_node("FireballPool") as ObjectPool
	_check(pool.get_active_count() == 1 and boss.radial_magma_hazard.is_active(), "Có đạn và hazard trước khi chết")
	boss.health.take_damage(100000)
	await get_tree().physics_frame
	_check(pool.get_active_count() == 0 and not boss.radial_magma_hazard.is_active() and not boss.shockwave.is_active(), "Chết dọn toàn bộ đạn, magma và sóng")
	_check(not (boss.shockwave.get_node("Dust") as GPUParticles3D).visible, "Chết dọn cả bụi của sóng kích")
	for spike: Node in boss.radial_magma_hazard.get_children():
		if spike is MagmaHazard:
			_check(not spike.visible and not (spike as MagmaHazard).hitbox.is_active(), "Magma hết hình và sát thương")
	boss.spawn_fireball()
	_check(pool.get_active_count() == 0, "Boss chết không bắn lại")
	boss.free()

func _test_configuration() -> void:
	var boss: Boss1 = spawn_boss()
	var jump: BossJumpSlam = boss.get_node("StateMachine/JumpSlam") as BossJumpSlam
	var target: Marker3D = Marker3D.new()
	add_child(target)
	target.position.z = 4.0
	boss.target_player = target
	jump.windup_time = 0.0
	jump.impact_time = 0.0
	boss.data.anim_speed_phase1 = 0.0
	boss.state_machine.transition_to(&"JumpSlam")
	boss.set_physics_process(true)
	await get_tree().create_timer(0.08).timeout
	_check(boss.velocity.is_finite() and boss.position.is_finite(), "Thời gian và tốc độ animation bằng 0 không tạo NaN")
	boss.set_physics_process(false)
	boss.state_machine.transition_to(&"Idle")
	var indicator: AoeCircleIndicator = boss.aoe_indicator as AoeCircleIndicator
	indicator.show_indicator(Vector3.ZERO, 0.01, 0.3)
	await get_tree().create_timer(0.1).timeout
	var fill: Node3D = indicator.get_node("Fill") as Node3D
	var before: float = fill.scale.x
	for i: int in range(4):
		indicator.update_target(Vector3(float(i), 0, 0))
		await get_tree().physics_frame
	_check(fill.scale.x > before, "Cập nhật mục tiêu không reset tiến trình chỉ thị")
	boss.free()
	target.free()

func _on_death() -> void:
	_deaths += 1

func _on_finished() -> void:
	_finishes += 1

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + message)
