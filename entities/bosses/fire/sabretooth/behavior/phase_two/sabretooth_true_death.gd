extends EnemyState
## Chết thật sự của Hổ Phase 2 (zoom gần boss + slow-motion 0.5x để nhìn rõ boss gục xuống):
## Tan dần hiệu ứng lửa Phase 2 từ đỉnh đầu xuống bàn chân ĐỒNG THỜI trong lúc chạy animation Collapse chậm dramatic,
## sau khi gục hẳn thì trả thời gian về 1.0x, trượt camera về player, tắt va chạm và phát signal died.

enum Stage { DYING, SETTLE_HOLD, SETTLED }

const SETTLE_PAUSE := 0.28

var _actor: FireSabretooth
var _skeleton: Skeleton3D
var _death_framing: CameraCutscene
var _death_shot_offset: Vector3 = Vector3(4.9, 3.1, 5.4)
var _head_bone: int = -1
var _stage: Stage = Stage.DYING
var _timer: float = 0.0
var _reverting: bool = false


func _ready() -> void:
	super()
	_actor = enemy as FireSabretooth
	_skeleton = _actor.get_node("Model/Visual/Rig").find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton:
		_head_bone = _skeleton.find_bone(&"Sabrecat_Head_jaw_")
	_death_framing = _actor.get_node_or_null("DeathFraming") as CameraCutscene
	if _death_framing and _death_framing.data:
		_death_shot_offset = _death_framing.data.shot_offset


func enter(_previous: StringName) -> void:
	_stage = Stage.DYING
	_timer = 0.0
	_actor.encounter_complete = true
	_actor.hitbox.cancel()
	_actor.fire_vfx.cancel()
	if _actor.p2_combat:
		_actor.p2_combat.cancel()
	_actor.velocity = Vector3.ZERO
	_actor.hurtbox.invulnerable = true
	_actor.hurtbox.set_deferred(&"monitorable", false)
	_actor.external_forces_enabled = false
	_actor.model.rotation.x = 0.0
	(_actor.get_node("Model/Visual") as Node3D).position = Vector3.ZERO
	_actor.phase.set_portal_clip(false)
	_actor.phase.dissolve_finale(0.0)
	_actor.phase.set_reform_progress(1.0)
	_actor.model.show()
	_actor.animation_player().speed_scale = 1.0
	_actor.motion.play(&"Collapse", 0.14)
	_reverting = _actor.phase.is_in_phase_two
	if _reverting:
		_actor.phase.begin_revert_to_phase_one()
	HitStop.begin_cinematic(self, clampf(_actor.profile.true_death_time_scale, 0.15, 1.0))
	_start_death_zoom()


func exit() -> void:
	HitStop.end_cinematic(self)
	if _death_framing and _death_framing.is_processing():
		_death_framing.cancel_playback()
	_actor.animation_player().speed_scale = 1.0


func physics_update(delta: float) -> void:
	_actor.apply_gravity(delta)
	_actor.velocity.x = 0.0
	_actor.velocity.z = 0.0
	if _stage == Stage.SETTLED:
		return
	_timer += delta
	if _stage == Stage.DYING:
		if _reverting:
			var rev_dur := maxf(_actor.profile.death_revert_duration, 0.25)
			var p := clampf(_timer / rev_dur, 0.0, 1.0)
			var head_world := _actor.global_position + Vector3.UP * 1.4
			if _skeleton and _head_bone >= 0:
				_skeleton.force_update_all_bone_transforms()
				head_world = _skeleton.to_global(_skeleton.get_bone_global_pose(_head_bone).origin) + Vector3.UP * 0.28
			_actor.phase.set_revert_progress(p, head_world)
			if p >= 1.0:
				_reverting = false
		if _actor.motion.finished():
			_stage = Stage.SETTLE_HOLD
			_timer = 0.0
			_reverting = false
			_actor.phase.show_phase_one_form()
			_actor.animation_player().pause()
	elif _stage == Stage.SETTLE_HOLD:
		if _timer >= SETTLE_PAUSE:
			_finish_settled()


func _start_death_zoom() -> void:
	if _death_framing == null or _death_framing.data == null or get_viewport().get_camera_3d() == null:
		return
	var viewer := _actor.target as Player
	if viewer == null:
		viewer = get_tree().get_first_node_in_group(&"player") as Player
	if viewer == null:
		return
	var forward := _actor.model.global_basis.z.slide(Vector3.UP)
	if forward.length_squared() < 0.01:
		forward = Vector3.BACK
	else:
		forward = forward.normalized()
	var right := Vector3.UP.cross(forward).normalized()
	_death_framing.data.shot_offset = right * _death_shot_offset.x + Vector3.UP * _death_shot_offset.y + forward * _death_shot_offset.z
	_death_framing.unscaled_time = true
	_death_framing.hold_indefinitely = true
	_death_framing.play_for(viewer)


func _finish_settled() -> void:
	_stage = Stage.SETTLED
	_reverting = false
	HitStop.end_cinematic(self)
	if _death_framing and _death_framing.is_processing():
		_death_framing.release_hold()
	_actor.phase.show_phase_one_form()
	_actor.animation_player().pause()
	_actor.body_set_collision(false)
	_actor.set_physics_process(false)
	_actor.set_dormant(true)
	if _actor.manual_skill:
		var skill := _actor.pending_skill
		_actor.manual_skill = false
		_actor.pending_skill = null
		_actor.skill_finished.emit(skill, true)
	else:
		_actor.died.emit(_actor)
