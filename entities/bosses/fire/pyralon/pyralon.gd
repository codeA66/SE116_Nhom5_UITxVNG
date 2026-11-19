class_name Pyralon
extends PreviewFireBoss

signal preview_finished

const SLAM := &"axe_slam"
const REAR := &"axe_sweep"
const BARRAGE := &"wing_barrage"
const COMMAND := &"axe_command"
const CYCLE := &"pyralon_cycle"
const MOVE_TITLES := {
	SLAM: "Bổ rìu, vòng lông và khe nứt",
	REAR: "Xoay chém lửa",
	BARRAGE: "Mưa lông",
	COMMAND: "Hiệu lệnh lông vàng",
	CYCLE: "Chạy cả chuỗi chiêu",
}

var profile: PyralonData
var _next_move := SLAM
var _preview := &""
var _airborne := false
var _was_invulnerable := false
var _body_home: Vector3
var _hurt_home: Vector3
var _floor_snap: float

@onready var pose: PyralonRig = $RigControl
@onready var field: PyralonField = $Field
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


func play_move(id: StringName, viewer: Node3D) -> void:
	_preview = id
	target = viewer
	_next_move = SLAM
	set_physics_process(true)
	if id == COMMAND and field.gold_count() == 0:
		for landing: Vector3 in field.gold_spots(6):
			field.drop_gold(global_position + Vector3.UP * 2.3, landing)
	if id != REAR:
		face_instantly((viewer.global_position - global_position).slide(Vector3.UP).normalized())
	begin_skill(_get_move(SLAM if id == CYCLE else id))


func is_previewing() -> bool:
	return not _preview.is_empty()


func reset_combat() -> void:
	var was_previewing := is_previewing()
	_preview = &""
	_next_move = SLAM
	if was_previewing or pending_skill:
		state_machine.transition_to(&"Idle")
	pending_skill = null
	for skill: EnemySkillData in wildlife.skills:
		_cooldowns[skill.skill_id] = 0.0
	field.clear()


func try_next_move() -> bool:
	if not has_target():
		return false
	if _next_move == COMMAND and field.gold_count() == 0:
		_next_move = SLAM
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
	if is_previewing() and (_preview != CYCLE or skill.skill_id == COMMAND):
		_end_preview()
		return
	match skill.skill_id:
		SLAM:
			_next_move = BARRAGE
			if _target_behind():
				begin_skill(_get_move(REAR))
				return
		REAR:
			_next_move = BARRAGE
		BARRAGE:
			_next_move = COMMAND
		COMMAND:
			_next_move = SLAM
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
	return to_target.length() <= profile.rear_range and (-get_facing_direction()).dot(to_target.normalized()) >= cos(deg_to_rad(profile.rear_half_angle))


func _end_preview() -> void:
	_preview = &""
	state_machine.transition_to(&"Idle")
	preview_finished.emit()


func _clear_after_death(_enemy: Enemy) -> void:
	field.clear()
