class_name Pyralon
extends PreviewFireBoss

signal preview_finished

const SLAM := &"axe_slam"
const SLAM_P2 := &"axe_slam_p2"
const REAR := &"axe_sweep"
const BARRAGE := &"wing_barrage"
const BARRAGE_P2 := &"wing_barrage_p2"
const COMMAND := &"axe_command"
const SKY_DIVE := &"sky_dive"
const RESONANCE_SLAM := &"resonance_slam"
const CYCLE := &"pyralon_cycle"
const CYCLE_P2 := &"pyralon_p2_combo"
const MOVE_TITLES := {
	SLAM: "Bổ rìu, vòng lông và khe nứt",
	REAR: "Xoay chém lửa",
	BARRAGE: "Mưa lông",
	COMMAND: "Hiệu lệnh lông vàng",
	SKY_DIVE: "P2 · Oanh kích thiên thạch (5 đợt)",
	RESONANCE_SLAM: "P2 · Giậm rìu chấn động & Domino",
	SLAM_P2: "P2 · Bổ rìu lông đỏ & Cổng Xích",
	BARRAGE_P2: "P2 · Mưa lông đỏ 5s & Bứng lông bắn lại",
	CYCLE_P2: "P2 · Combo Sky Dive -> Resonance",
	CYCLE: "Chạy cả chuỗi chiêu",
}

var profile: PyralonData
var rear_check_pending: bool = false
var encounter_complete: bool = false
var _phase_two_started: bool = false
var _next_move := SLAM
var _preview := &""
var _airborne := false
var _was_invulnerable := false
var _body_home: Vector3
var _hurt_home: Vector3
var _floor_snap: float

@onready var pose: PyralonRig = $RigControl
@onready var field: PyralonField = $Field
@onready var phase: PyralonPhase = $Phase
@onready var _body_shape: CollisionShape3D = $CollisionShape3D
@onready var _hurt_shape: CollisionShape3D = $HurtboxComponent/CollisionShape3D
@onready var _attack_shape: CollisionShape3D = $Model/Hitbox/CollisionShape3D


func _ready() -> void:
	profile = data as PyralonData
	super()
	_body_home = _body_shape.position
	_hurt_home = _hurt_shape.position
	_floor_snap = floor_snap_length
	_attack_shape.shape = _attack_shape.shape.duplicate()
	pose.setup(self)
	field.setup(self)
	phase.transform_duration = profile.transform_duration
	died.connect(_clear_after_death)


func set_air_pose(active: bool) -> void:
	var offset := pose.displacement() if active else Vector3.ZERO
	_body_shape.position = _body_home + global_basis.inverse() * offset
	_hurt_shape.position = _hurt_home + hurtbox.global_basis.inverse() * offset
	if active == _airborne:
		return
	_airborne = active
	if active:
		# Giữ gốc ở sàn; floor snap sẽ kéo gốc xuống nếu collider đã bay lên cùng rig.
		floor_snap_length = 0.0
		_was_invulnerable = hurtbox.invulnerable
		hurtbox.invulnerable = true
	else:
		floor_snap_length = _floor_snap
		hurtbox.invulnerable = _was_invulnerable


func update_axe_hit(strike: FireBossStrike, time: float) -> void:
	strike.update_hitbox(hitbox, time, 1.0)
	if hitbox.is_active():
		_attack_shape.position = hitbox.to_local(pose.axe_edge())


func player_speed() -> float:
	var player := target as Character
	return player.movement.max_speed if player and player.movement else 6.0


func is_phase_two() -> bool:
	return phase != null and phase.is_in_phase_two


func play_move(id: StringName, viewer: Node3D) -> void:
	restore_preview()
	_preview = id
	target = viewer
	_next_move = SKY_DIVE if id == CYCLE_P2 else SLAM
	set_physics_process(true)
	if id in [SKY_DIVE, RESONANCE_SLAM, SLAM_P2, BARRAGE_P2, CYCLE_P2] and phase:
		phase.show_phase_two_form(true)
	if id == COMMAND and field.gold_count() == 0:
		for landing: Vector3 in field.gold_spots(6):
			field.drop_gold(global_position + Vector3.UP * 2.3, landing)
	elif id == RESONANCE_SLAM and field.gold_count() == 0:
		field.scatter_gold_ring(global_position, profile.sky_dive_final_gold_count)
	if id != REAR:
		face_instantly((viewer.global_position - global_position).slide(Vector3.UP).normalized())
	var first_id := id
	if id == CYCLE:
		first_id = SLAM
	elif id == CYCLE_P2:
		first_id = SKY_DIVE
	elif id == SLAM_P2:
		first_id = SLAM
	elif id == BARRAGE_P2:
		first_id = BARRAGE
	begin_skill(_get_move(first_id))


func is_previewing() -> bool:
	return not _preview.is_empty()


func reset_combat() -> void:
	var was_previewing := is_previewing()
	_preview = &""
	_next_move = SLAM
	rear_check_pending = false
	if phase:
		phase.cancel_preview()
	restore_preview()
	if was_previewing or pending_skill:
		state_machine.transition_to(&"Idle")
	pending_skill = null
	for skill: EnemySkillData in wildlife.skills:
		_cooldowns[skill.skill_id] = 0.0
	field.clear()


func body_set_collision(active: bool) -> void:
	_body_shape.set_deferred(&"disabled", not active)
	hurtbox.set_deferred(&"monitorable", active)


func restore_preview() -> void:
	var death_framing := get_node_or_null("DeathFraming") as CameraCutscene
	if death_framing and death_framing.is_processing():
		death_framing.cancel_playback()
	animation_player().speed_scale = 1.0
	set_air_pose(false)
	var visual := get_node_or_null("Model/Visual") as Node3D
	if visual:
		visual.position = Vector3.ZERO
	body_set_collision(true)
	if not encounter_complete:
		return
	encounter_complete = false
	_phase_two_started = phase != null and phase.is_in_phase_two
	set_dormant(false)
	hurtbox.invulnerable = false
	model.show()
	health.max_health = profile.phase_two_health if (phase and phase.is_in_phase_two) else profile.max_health
	health.heal_full()
	external_forces_enabled = true
	set_physics_process(true)
	state_machine.transition_to(&"Idle")


func try_rear_slash() -> bool:
	if not has_target() or not _target_behind():
		return false
	begin_skill(_get_move(REAR))
	return true


func begin_immediate_sky_dive() -> void:
	# Ngay sau khi chuyển Phase 2: bay thẳng lên trời dùng Sky Dive không đi bộ, không xoay người!
	_next_move = SKY_DIVE
	rear_check_pending = false
	var sky_skill := _get_move(SKY_DIVE)
	if sky_skill:
		begin_skill(sky_skill)
	else:
		state_machine.transition_to(chase_state)


func try_next_move() -> bool:
	if not has_target():
		return false
	if _next_move == COMMAND and field.gold_count() == 0:
		_next_move = SKY_DIVE if (phase and phase.is_in_phase_two) else SLAM
		if _preview == CYCLE:
			_end_preview()
			return true
	var skill := _get_move(_next_move)
	if not is_previewing() and not skill_ready(skill):
		return false
	face_instantly((target.global_position - global_position).slide(Vector3.UP).normalized())
	begin_skill(skill)
	return true


func finish_move(skill: EnemySkillData) -> void:
	complete_skill(skill, true)
	if is_previewing():
		var cycle_done := (_preview == CYCLE and skill.skill_id == COMMAND) or (_preview == CYCLE_P2 and skill.skill_id == RESONANCE_SLAM)
		if (_preview != CYCLE and _preview != CYCLE_P2) or cycle_done:
			_end_preview()
			return
	# Vòng lặp Phase 2: chạy combo mới (SKY_DIVE -> RESONANCE_SLAM) rồi chạy trọn bộ chiêu cũ (SLAM -> BARRAGE -> COMMAND) rồi lặp lại combo mới!
	match skill.skill_id:
		SKY_DIVE:
			_next_move = RESONANCE_SLAM
			rear_check_pending = false
		RESONANCE_SLAM:
			_next_move = SLAM
			rear_check_pending = true
		SLAM:
			_next_move = BARRAGE
			rear_check_pending = true
		REAR:
			rear_check_pending = false
		BARRAGE:
			_next_move = COMMAND
			rear_check_pending = true
		COMMAND:
			_next_move = SKY_DIVE if (phase and phase.is_in_phase_two) else SLAM
			rear_check_pending = true
	state_machine.transition_to(chase_state)


func _get_move(id: StringName) -> EnemySkillData:
	for skill: EnemySkillData in wildlife.skills:
		if skill.skill_id == id:
			return skill
	return null


func _target_behind() -> bool:
	if not has_target():
		return false
	var to_target := (target.global_position - global_position).slide(Vector3.UP)
	var back := -get_facing_direction().slide(Vector3.UP).normalized()
	var right := Vector3.UP.cross(back).normalized()
	# Vùng hộp chữ nhật dài & rộng phía sau lưng giúp Pyralon vẫn phát hiện để xoay chém kể cả khi player đứng xa hoặc lệch sang 2 bên.
	var behind_dist := to_target.dot(back)
	var side_dist := absf(to_target.dot(right))
	return behind_dist >= profile.rear_min_back_offset and behind_dist <= profile.rear_detect_length and side_dist <= profile.rear_detect_half_width


func _end_preview() -> void:
	_preview = &""
	state_machine.transition_to(&"Idle")
	preview_finished.emit()


func _on_died() -> void:
	if not _phase_two_started and phase and not phase.is_in_phase_two:
		_phase_two_started = true
		_next_move = SKY_DIVE
		rear_check_pending = false
		field.clear()
		health.max_health = profile.phase_two_health
		health.heal_full()
		state_machine.transition_to(&"PyralonTransformation")
		return
	state_machine.transition_to(&"PyralonTrueDeath")


func _clear_after_death(_enemy: Enemy) -> void:
	field.clear()
