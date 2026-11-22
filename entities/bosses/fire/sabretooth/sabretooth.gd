class_name FireSabretooth
extends PreviewFireBoss
## Dùng rig và combat hiện có, bổ sung các state săn và chọn đòn theo vị trí player.

var profile: SabretoothData
var last_skill: StringName
var recovering_skill: SabretoothSkill
var manual_skill: bool
var maneuver_clip: StringName
var maneuver_direction: Vector3
var maneuver_distance: float
var dodge_left: float
var threat_left: float
var circle_side: float = 1.0
var evasion_count: int
var phase_one_wait: float = 0.0
var phase_one_stand_left: float = 0.0
var phase_one_turn_pending: bool = false
var phase_one_reaction_used: bool = false
var phase_one_reaction_pending: bool = false
var phase_one_prepared: bool = false
var phase_two_chain: bool = false
var phase_two_special_wait: float = 0.0
var phase_two_next_state: StringName = &"TigerFireBeam"
var encounter_complete: bool = false
var _phase_two_started: bool = false
var _recent_attack_left: float = 0.0
var _attack_serial: int
var _last_used: Dictionary[StringName, int] = {}
var _path_query := PhysicsRayQueryParameters3D.new()

@onready var motion: SabretoothMotion = $Motion
@onready var phase: SabretoothPhase = $Phase
@onready var fire_vfx: SabretoothFireVfx = $FireVfx
@onready var p2_combat: SabretoothP2Combat = $P2Combat
@onready var finale_blast: ExplosionComponent = $FinaleBlast
@onready var _body_shape: CollisionShape3D = $CollisionShape3D
@onready var _hurt_shape: CollisionShape3D = $HurtboxComponent/CollisionShape3D


func _ready() -> void:
	data = data.duplicate(true) as SabretoothData
	profile = data as SabretoothData
	super()
	motion.setup(self)
	hurtbox.hurt.connect(_noticed_hit)
	phase.finished.connect(_sync_phase_behavior)
	_sync_phase_behavior()
	circle_side = -1.0 if _rng.randf() < 0.5 else 1.0
	_path_query.collision_mask = 1
	_path_query.exclude = [get_rid()]


func _pre_state_update(delta: float) -> void:
	super(delta)
	dodge_left = maxf(0.0, dodge_left - delta)
	threat_left = maxf(0.0, threat_left - delta)
	_recent_attack_left = maxf(0.0, _recent_attack_left - delta)
	if not manual_skill:
		phase_one_wait = maxf(0.0, phase_one_wait - delta)
		if phase.is_in_phase_two and state_machine.current_state and state_machine.current_state.name == chase_state:
			phase_two_special_wait = maxf(0.0, phase_two_special_wait - delta)


func pace() -> float:
	return profile.phase_two_pace if phase.is_in_phase_two else 1.0


func face_direction(direction: Vector3, delta: float) -> void:
	super(direction, delta)
	set_body_yaw(model.rotation.y)


func face_instantly(direction: Vector3) -> void:
	super(direction)
	set_body_yaw(model.rotation.y)


func set_body_yaw(angle: float) -> void:
	model.rotation.y = angle
	_body_shape.rotation.y = angle
	_hurt_shape.rotation.y = angle


func resists_knockback() -> bool:
	return true


func target_angle() -> float:
	var toward := direction_to_target()
	return wrapf(atan2(toward.x, toward.z) - model.rotation.y, -PI, PI)


func choose_skill() -> EnemySkillData:
	var angle := target_angle()
	var dist := distance_to_target()
	var selected: EnemySkillData
	var best := -INF
	for entry: EnemySkillData in wildlife.skills:
		var skill := entry as SabretoothSkill
		if skill.phase_one_only:
			continue
		if skill.phase_two_only:
			if not phase.is_in_phase_two or entry.skill_id not in [&"fang_snap", &"cross_claw"]:
				continue
		if entry.skill_id == last_skill or not skill_ready(entry):
			continue
		var score := float(_attack_serial - _last_used.get(entry.skill_id, -4))
		if entry.skill_id == &"left_swat" and angle < -0.25:
			score += 3.0
		if entry.skill_id == &"paw_sweep" and absf(angle) > 0.48:
			score += 2.0
		if entry.skill_id == &"pounce" and dist >= 4.8:
			score += 6.0
		if entry.skill_id == &"fang_snap":
			score += 5.5 if dist >= 4.2 else 2.5
		if entry.skill_id == &"cross_claw":
			score += 5.5 if dist <= 9.5 else 2.0
		if score > best:
			selected = entry
			best = score
	return selected


func is_phase_one() -> bool:
	return not phase.is_in_phase_two


func start_phase_one_cycle() -> void:
	phase_one_wait = profile.attack_interval
	phase_one_stand_left = profile.stand_pause
	phase_one_turn_pending = false
	phase_one_reaction_used = false
	phase_one_reaction_pending = false
	phase_one_prepared = false


func select_side_skill() -> SabretoothSkill:
	if not has_target():
		return null
	var distance := distance_to_target()
	var angle := target_angle()
	if distance < profile.side_attack_range.x or distance > profile.side_attack_range.y:
		return null
	var abs_angle := absf(angle)
	if abs_angle < deg_to_rad(profile.side_angle) or abs_angle > deg_to_rad(profile.rear_angle):
		return null
	var id: StringName = &"left_swat" if angle > 0.0 else &"right_swat"
	for entry: EnemySkillData in wildlife.skills:
		if entry.skill_id == id:
			return entry as SabretoothSkill
	return null


func phase_one_can_prepare() -> bool:
	if not has_target():
		return false
	var distance := distance_to_target()
	return distance <= profile.near_pounce_range or (last_skill != &"pounce" and distance >= profile.far_pounce_range.x and distance <= profile.far_pounce_range.y)


func select_phase_one_skill() -> SabretoothSkill:
	var side_skill := select_side_skill()
	if side_skill:
		return side_skill
	var distance := distance_to_target()
	var id: StringName
	if distance <= profile.close_range:
		var player := target as Player
		var attacking := _recent_attack_left > 0.0 or (player != null and player.hitbox.is_active())
		var close_attacks: Array[StringName] = [&"paw_sweep", &"bite", &"snap"]
		id = close_attacks[_rng.randi_range(0, close_attacks.size() - 1)] if attacking else &"raged"
	elif distance <= profile.near_pounce_range:
		id = &"double_claw"
	elif last_skill != &"pounce" and distance >= profile.far_pounce_range.x and distance <= profile.far_pounce_range.y:
		id = &"pounce"
	else:
		return null
	for entry: EnemySkillData in wildlife.skills:
		if entry.skill_id == id:
			return entry as SabretoothSkill
	return null


func pick_turn_clip(angle: float) -> StringName:
	var selected: StringName
	var count := 0
	var large := absf(angle) >= deg_to_rad(profile.rear_angle)
	for clip: StringName in profile.turn_clips:
		var authored := motion.turn_angle(clip)
		if signf(authored) != signf(angle) or (absf(authored) >= deg_to_rad(profile.rear_angle)) != large:
			continue
		count += 1
		if _rng.randi_range(1, count) == 1:
			selected = clip
	if selected.is_empty():
		selected = (&"Slow180" if angle > 0.0 else &"180RIght") if large else (&"TurnLeft" if angle > 0.0 else &"TurnRight")
	return selected


func begin_skill(skill: EnemySkillData) -> void:
	# Mỗi lần bay có thời lượng riêng, không sửa Resource dùng chung hoặc chiêu phase 2.
	if skill.skill_id == &"pounce":
		super(skill.duplicate() as SabretoothSkill)
	else:
		super(skill)


func preview_skill(skill: SabretoothSkill, viewer: Node3D) -> void:
	restore_preview()
	manual_skill = true
	phase_two_chain = skill.skill_id == &"phase_two_sequence"
	if skill.phase_two_only and not phase_two_chain:
		phase.show_flame_form()
	target = viewer
	set_physics_process(true)
	begin_skill(skill)


func finish_attack(completed: bool) -> void:
	var skill := recovering_skill if recovering_skill else pending_skill as SabretoothSkill
	recovering_skill = null
	if skill == null:
		return
	last_skill = skill.skill_id
	_attack_serial += 1
	_last_used[skill.skill_id] = _attack_serial
	if manual_skill:
		manual_skill = false
		pending_skill = null
		skill_finished.emit(skill, completed)
	else:
		complete_skill(skill, completed)


func stop_preview_skill() -> void:
	if not manual_skill:
		return
	state_machine.transition_to(&"Idle")
	manual_skill = false
	recovering_skill = null
	pending_skill = null
	hitbox.cancel()
	velocity = Vector3.ZERO
	fire_vfx.cancel()
	if p2_combat:
		p2_combat.cancel()
	model.rotation.x = 0.0
	(get_node("Model/Visual") as Node3D).position = Vector3.ZERO
	restore_preview()


func restore_preview() -> void:
	var death_framing := get_node_or_null("DeathFraming") as CameraCutscene
	if death_framing and death_framing.is_processing():
		death_framing.cancel_playback()
	if p2_combat:
		p2_combat.cancel()
	animation_player().speed_scale = 1.0
	model.rotation.x = 0.0
	(get_node("Model/Visual") as Node3D).position = Vector3.ZERO
	phase.set_portal_clip(false)
	phase.dissolve_finale(0.0)
	phase.set_reform_progress(1.0)
	body_set_collision(true)
	if not encounter_complete:
		return
	encounter_complete = false
	_phase_two_started = phase.is_in_phase_two
	set_dormant(false)
	hurtbox.invulnerable = false
	phase.set_ambient_active(true)
	model.show()
	_body_shape.set_deferred(&"disabled", false)
	hurtbox.set_deferred(&"monitorable", true)
	health.max_health = profile.phase_two_health if phase.is_in_phase_two else profile.max_health
	health.heal_full()
	external_forces_enabled = true
	set_physics_process(true)
	state_machine.transition_to(&"Idle")


func body_set_collision(active: bool) -> void:
	_body_shape.set_deferred(&"disabled", not active)
	hurtbox.set_deferred(&"monitorable", active)


func resume_combat() -> void:
	phase_two_chain = phase.is_in_phase_two
	phase_two_next_state = &"TigerFireBeam"
	_sync_phase_behavior()


func rest_then_phase_two(next_state: StringName) -> void:
	phase_two_next_state = next_state
	state_machine.transition_to(&"TigerPhaseTwoRest")


func finish_phase_two() -> void:
	encounter_complete = true
	health.set_current_health(0)
	phase.set_ambient_active(false)
	fire_vfx.stop_beam()
	model.hide()
	_body_shape.set_deferred(&"disabled", true)
	hurtbox.set_deferred(&"monitorable", false)
	hitbox.cancel()
	velocity = Vector3.ZERO
	external_forces_enabled = false
	set_physics_process(false)
	set_dormant(true)
	if manual_skill:
		var skill := pending_skill
		manual_skill = false
		pending_skill = null
		skill_finished.emit(skill, true)
	else:
		died.emit(self)


func finish_phase_two_move() -> void:
	var skill := pending_skill
	manual_skill = false
	pending_skill = null
	state_machine.transition_to(&"Idle")
	skill_finished.emit(skill, true)


func _on_died() -> void:
	if not _phase_two_started and is_phase_one():
		_phase_two_started = true
		phase_two_chain = true
		health.max_health = profile.phase_two_health
		health.heal_full()
		state_machine.transition_to(&"TigerTransformation")
		return
	state_machine.transition_to(&"TigerTrueDeath")


func walk(direction: Vector3, speed: float, delta: float, face_target: bool = false) -> void:
	# BackUp giữ mắt hướng về player trong khi chuyển động thực lùi lại.
	var yaw := model.rotation.y
	super.move_toward_direction(direction * clampf(speed / movement.max_speed, 0.0, 1.0), delta)
	if face_target:
		model.rotation.y = yaw
		face_direction(direction_to_target(), delta)


func clear_path(direction: Vector3, distance: float) -> bool:
	if direction.is_zero_approx():
		return false
	var travel := direction.normalized() * maxf(distance, 0.05)
	if test_move(global_transform, travel, null, profile.clearance):
		return false
	var arrival := global_position + travel
	_path_query.from = arrival + Vector3.UP * 0.55
	_path_query.to = arrival - Vector3.UP * 1.2
	return not get_world_3d().direct_space_state.intersect_ray(_path_query).is_empty()


func start_maneuver(clip: StringName, direction: Vector3 = Vector3.ZERO, distance: float = 0.0) -> void:
	maneuver_clip = clip
	maneuver_direction = direction
	maneuver_distance = distance
	state_machine.transition_to(&"TigerManeuver")


func _noticed_hit(_info: DamageInfo, damage: int) -> void:
	threat_left = 0.7
	if damage <= 0 or is_dead():
		return
	_recent_attack_left = profile.recent_attack_time
	if is_phase_one() and not manual_skill and not phase_one_turn_pending and not phase_one_reaction_used and state_machine.current_state.name == &"TigerPhaseOneHunt":
		phase_one_reaction_pending = true


func _sync_phase_behavior() -> void:
	chase_state = &"TigerPhaseOneHunt" if is_phase_one() else &"TigerHunt"
	if not is_phase_one() and not _phase_two_started:
		_phase_two_started = true
		health.max_health = profile.phase_two_health
		health.heal_full()
