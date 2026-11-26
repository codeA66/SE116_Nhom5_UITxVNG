extends RefCounted
## UC1: Khinh Bộ cộng tốc chạy trong sân, chồng đúng với nền chậm và gỡ được ở checkpoint.
## UC2: Tro Ghìm chỉ tác động khi Mưa Hỏa Tiễn có dải cháy. Quái rời dải, dải hết và pool dọn đều gỡ chậm.
## UC3: Từng bùa cũ giữ chi phí và hiệu ứng khi đeo cùng hai bùa mới.
##
## TC1: Catalog có hai bùa thường 1 khắc, sân có hai vật nhặt và sách Lửa.
## TC2: Tốc thực đo với/không bùa là 1,05 lần; nền chậm vẫn áp dụng; tháo bùa trả tốc độ.
## TC3: Level 1 bấm Q không làm chậm; level 2 không bùa vẫn không chậm.
## TC4: Trong dải chậm 10%; hai nguồn không nhân dồn; rời, vào lại, hết dải và nhả pool đều được kiểm tra.
## TC5: Thử mọi cặp hợp lệ và so hiệu ứng nhìn được với bùa cũ đeo riêng.
## TC6: Ghép với Ưng Nhãn, Hỏa Tiễn hoặc Phẫn Nộ rồi bắn hoặc nhận sát thương thật.
## TC7: Resource bị chỉnh về 0 hoặc rất lớn vẫn giữ hệ số trong giới hạn.

const ASH: StringName = &"ash_bind_charm"
const STEP: StringName = &"light_step_charm"
const FLAME: SkillData = preload("res://abilities/flame_breath/flame_breath.tres")
const RAIN: PackedScene = preload("res://abilities/flame_breath/fire_rain/fire_rain.tscn")
const RAIN_DATA: FireRainData = preload("res://abilities/flame_breath/fire_rain/fire_rain.tres")
const ASH_POINT: Vector3 = Vector3(-13, 0, 1)
const RUN_POINT: Vector3 = Vector3(10, 0, -8)
const OUTSIDE: Vector3 = Vector3(-17, 0, 1)
const LINE_START: Vector3 = Vector3(-13, 0, 4)
const MOTION_ACTION: StringName = &"move_right"

var _failures: int = 0
var _zone: ZoneRoot
var _player: Player
var _target_enemy: Enemy
var _tested: int = 0
var _arrows_fired: int = 0


func run(zone: ZoneRoot) -> void:
	_zone = zone
	_player = zone.get_node(^"Player") as Player
	_player.bow_projectile_fired.connect(_count_arrow)
	_target_enemy = zone.get_node_or_null(^"AshSlowTarget") as Enemy
	for charm_id: StringName in [ASH, STEP]:
		var charm: CharmData = GameState.ITEMS.get_charm(charm_id)
		_check(charm != null and charm.rarity == null and charm.notch_cost == 1,
			"TC1 catalog bùa thường 1 khắc: %s" % charm_id)
		if charm != null:
			GameState.add_charm(charm)
	_check(zone.has_node(^"AshBindCharm") and zone.has_node(^"LightStepCharm"), "TC1 hai vật nhặt")
	_check(zone.has_node(^"FireRainBook"), "TC1 sách nâng cấp Lửa trong sân")
	_check(_target_enemy != null, "TC1 có quái thường đo tốc độ")
	if _failures > 0:
		_finish()
		return

	for other: Node in zone.get_children():
		if other is Enemy:
			other.set_physics_process(false)
	_target_enemy.health.max_health = 200
	_target_enemy.health.heal_full()
	await _wear([])
	var hero_base: float = await _run_speed()
	await _wear([STEP])
	var hero_buffed: float = await _run_speed()
	_ratio(hero_buffed, hero_base, 1.05, "TC2 Khinh Bộ +5%")
	_player.set_terrain_speed(_zone, 0.6)
	_ratio(await _run_speed(), hero_buffed, 0.6, "TC2 Khinh Bộ vẫn chịu nền chậm")
	_player.set_terrain_speed(_zone, 1.0)
	await _wear([])
	_ratio(await _run_speed(), hero_base, 1.0, "TC2 tháo bùa trả tốc")

	await _wear([ASH])
	var enemy_base: float = await _enemy_speed(ASH_POINT)
	_player.teleport(Vector3(-14, 0, 4), Vector3.FORWARD)
	_player.energy.set_current(_player.energy.get_max())
	await _frames(3)
	Input.action_press(&"skill_fire")
	await _frames(2)
	_check(_player.state_machine.current_state.name == &"FlameBreath", "TC3 Phun Lửa cấp 1")
	Input.action_release(&"skill_fire")
	_ratio(await _enemy_speed(ASH_POINT), enemy_base, 1.0, "TC3 Phun Lửa không làm chậm")
	GameState.grant_ability_level(FLAME, 2)
	_check(_player.get_skill_form(FLAME).id == RAIN_DATA.id, "TC3 Lửa cấp 2 là Mưa Hỏa Tiễn")

	await _wear([])
	var uncharmed: FireRain = await _begin_rain()
	_ratio(await _enemy_speed(ASH_POINT), enemy_base, 1.0, "TC3 Mưa không bùa không làm chậm")
	uncharmed.queue_free()
	await _frames(3)

	await _wear([ASH, STEP])
	var first: FireRain = await _begin_rain()
	_ratio(await _enemy_speed(ASH_POINT), enemy_base, 0.9, "TC4 trong dải giảm 10%")
	var second: FireRain = await _begin_rain()
	_ratio(await _enemy_speed(ASH_POINT), enemy_base, 0.9, "TC4 hai dải cũng chỉ giảm 10%")
	_ratio(await _enemy_speed(OUTSIDE), enemy_base, 1.0, "TC4 ra dải hết chậm")
	_ratio(await _enemy_speed(ASH_POINT), enemy_base, 0.9, "TC4 vào lại bị chậm")
	first.queue_free()
	await _frames(3)
	_ratio(await _enemy_speed(ASH_POINT), enemy_base, 0.9, "TC4 hủy một nguồn, nguồn kia còn")
	second.pool_released()
	await _frames(3)
	_ratio(await _enemy_speed(ASH_POINT), enemy_base, 1.0, "TC4 trả pool gỡ chậm")
	second.queue_free()

	var unequipped_rain: FireRain = await _begin_rain()
	await _wear([STEP])
	_ratio(await _enemy_speed(ASH_POINT), enemy_base, 1.0, "TC4 tháo Tro Ghìm giữa dải gỡ chậm")
	unequipped_rain.queue_free()
	await _frames(3)
	await _wear([ASH, STEP])
	var expiring: FireRain = await _begin_rain(0.8)
	await expiring.burn_ended
	_ratio(await _enemy_speed(ASH_POINT), enemy_base, 1.0, "TC4 hết dải gỡ chậm trước khi vết than tắt")
	await _compatibility(hero_base)
	await _combat_combinations()
	await _extreme_factors(hero_base, enemy_base)
	_player.bow_projectile_fired.disconnect(_count_arrow)
	_finish()


func _compatibility(hero_base: float) -> void:
	var old_charms: Array[CharmData] = GameState.ITEMS.charms.duplicate()
	for old_charm: CharmData in old_charms:
		if old_charm.id in [ASH, STEP]:
			continue
		GameState.add_charm(old_charm)
		await _wear([old_charm.id])
		var before: Array = _observable_effects()
		for new_id: StringName in [ASH, STEP]:
			if old_charm.notch_cost + 1 > GameState.get_charm_notches():
				_check(not GameState.equip_charm(new_id), "TC5 %s giữ giới hạn ô khắc với %s" % [old_charm.id, new_id])
				continue
			await _wear([old_charm.id, new_id])
			_check(_observable_effects() == before, "TC5 %s giữ tác dụng khi ghép %s" % [old_charm.id, new_id])
			_check(GameState.get_used_notches() == old_charm.notch_cost + 1, "TC5 %s + %s đúng số khắc" % [old_charm.id, new_id])
			var expected: float = 1.05 if new_id == STEP else 1.0
			_ratio(await _run_speed(), hero_base, expected, "TC5 %s + %s tốc chạy" % [old_charm.id, new_id])
			await _wear([old_charm.id])
	await _wear([])


func _observable_effects() -> Array:
	return [_player.health.max_health, _player.energy.get_max(), _player.get_bow_projectile_count(),
		_player.stats.get_multiplier(&"melee_attack_speed"), _player.stats.get_bonus(&"sword_combo_loop_length"),
		_player.get_bow_imbue(), _player.get_skill_form(FLAME).id]


func _combat_combinations() -> void:
	for new_id: StringName in [ASH, STEP]:
		await _wear([new_id, &"keen_eye_charm", &"fire_arrow_charm"])
		_player.teleport(RUN_POINT, Vector3.FORWARD)
		await _frames(4)
		_player.energy.set_current(_player.energy.get_max())
		var energy_before: int = _player.energy.current
		var shots_before: int = _arrows_fired
		_player.shoot_bow(1.0)
		await _frames(32)
		_check(_arrows_fired - shots_before == 2 and energy_before - _player.energy.current == 1,
			"TC6 Ưng Nhãn ghép %s: ra hai tên, tốn một linh lực" % new_id)
		var imbue: FusionData = _player.get_bow_imbue()
		_check(imbue != null and imbue.element != null and imbue.element.id == &"fire",
			"TC6 Hỏa Tiễn ghép %s: cung còn truyền lửa" % new_id)

		await _wear([new_id, &"wrath_charm"])
		var hit: DamageInfo = DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3.ZERO, null)
		hit.ignores_invincibility = true
		hit.staggers = false
		var hurtbox: HurtboxComponent = _player.get_node(^"HurtboxComponent") as HurtboxComponent
		var received: bool = hurtbox.receive_hit(hit)
		var sword: WeaponData = _player.get_weapon()
		_check(received and _player.get_weapon_damage_bonus(_player.hitbox, sword.combo[0]) == 1,
			"TC6 Phẫn Nộ ghép %s: trúng đòn vẫn cộng một sát thương kiếm" % new_id)
		_player.health.heal_full()
	await _wear([])


func _count_arrow(_primary: bool) -> void:
	_arrows_fired += 1


func _extreme_factors(hero_base: float, enemy_base: float) -> void:
	var source_id: StringName = &"test_extreme_mobility"
	_player.stats.set_multiplier(&"charm_walk_speed", source_id, 0.0)
	_ratio(await _run_speed(), hero_base, 0.1, "TC7 hệ số bước 0 kẹp ở 0,1")
	_player.stats.set_multiplier(&"charm_walk_speed", source_id, 500.0)
	_player.teleport(RUN_POINT, Vector3.FORWARD)
	await _frames(5)
	_player.move_toward_direction(Vector3.RIGHT, 2.0)
	_player.move_and_slide()
	_ratio(Vector2(_player.velocity.x, _player.velocity.z).length(), hero_base, 5.0,
		"TC7 hệ số bước 500 kẹp ở 5")
	_player.stats.remove_multiplier(&"charm_walk_speed", source_id)

	_player.stats.set_multiplier(&"fire_rain_enemy_slow", source_id, 0.0)
	var strong_rain: FireRain = await _begin_rain()
	_ratio(await _enemy_speed(ASH_POINT), enemy_base, 0.1, "TC7 hệ số tro 0 kẹp ở 0,1")
	strong_rain.queue_free()
	await _frames(3)
	_player.stats.set_multiplier(&"fire_rain_enemy_slow", source_id, 500.0)
	var weak_rain: FireRain = await _begin_rain()
	_ratio(await _enemy_speed(ASH_POINT), enemy_base, 1.0, "TC7 hệ số tro 500 không làm quái chạy nhanh")
	weak_rain.queue_free()
	_player.stats.remove_multiplier(&"fire_rain_enemy_slow", source_id)


func _wear(ids: Array[StringName]) -> void:
	var checkpoint: Node3D = _zone.get_node(^"CharmCheckpoint") as Node3D
	_player.teleport(checkpoint.global_position, Vector3.FORWARD)
	await _frames(5)
	if not GameState.can_change_charms():
		_check(false, "Đứng ở checkpoint cho phép đổi bùa")
		return
	for worn: StringName in GameState.progress.equipped_charms.duplicate():
		_check(GameState.unequip_charm(worn), "Tháo %s tại checkpoint" % worn)
	for charm_id: StringName in ids:
		_check(GameState.equip_charm(charm_id), "Đeo %s tại checkpoint" % charm_id)


func _run_speed() -> float:
	_player.teleport(RUN_POINT, Vector3.FORWARD)
	await _frames(5)
	Input.action_press(MOTION_ACTION)
	await _frames(24)
	var speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	Input.action_release(MOTION_ACTION)
	return speed


func _enemy_speed(at: Vector3) -> float:
	_target_enemy.teleport(at, Vector3.FORWARD)
	await _frames(4)
	_target_enemy.move_toward_direction(Vector3.FORWARD, 1.0)
	_target_enemy.move_and_slide()
	var speed: float = Vector2(_target_enemy.velocity.x, _target_enemy.velocity.z).length()
	_target_enemy.velocity = Vector3.ZERO
	return speed


func _begin_rain(burn_seconds: float = 6.0) -> FireRain:
	var cast_data: FireRainData = RAIN_DATA.duplicate() as FireRainData
	cast_data.impact_count = 1
	cast_data.first_impact_delay = 0.1
	cast_data.burn_lifetime = burn_seconds
	cast_data.impact_shake = 0.0
	var rain: FireRain = RAIN.instantiate() as FireRain
	_zone.add_child(rain)
	await _frames(1)
	rain.launch(_player, cast_data, LINE_START, Vector3.FORWARD)
	await rain.burn_started
	await _frames(4)
	return rain


func _frames(frame_count: int) -> void:
	for frame_index: int in frame_count:
		await _zone.get_tree().physics_frame


func _ratio(actual: float, baseline: float, expected: float, label: String) -> void:
	_check(baseline > 0.1 and absf(actual - baseline * expected) < 0.04,
		"%s (%.3f / %.3f m/s)" % [label, actual, baseline])


func _check(ok: bool, label: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", label])
	_tested += 1
	if not ok:
		_failures += 1


func _finish() -> void:
	print("MOBILITY RESULT checks=%d fails=%d" % [_tested, _failures])
	_zone.get_tree().quit(1 if _failures > 0 else 0)

