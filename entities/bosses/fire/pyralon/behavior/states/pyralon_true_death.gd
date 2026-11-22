extends EnemyState
## Chết thật của Pyralon Phase 2 (zoom gần boss + slow-motion 0.5x để nhìn rõ boss gục xuống):
## Tan dần lớp hiệu ứng Phase 2 từ đỉnh mào lửa trên đầu xuống bàn chân ĐỒNG THỜI trong lúc ngã gục từ từ (pyralon/Collapse),
## sau khi gục hẳn thì trả thời gian về 1.0x, trượt camera về player, tắt va chạm và phát signal died.

enum Stage { DYING, SETTLE_HOLD, SETTLED }

const SETTLE_PAUSE := 0.28

var _bird: Pyralon
var _death_framing: CameraCutscene
var _death_shot_offset: Vector3 = Vector3(3.3, 2.6, 4.3)
var _stage: Stage = Stage.DYING
var _timer: float = 0.0
var _clip_len: float = 2.55


func _ready() -> void:
	super()
	_bird = enemy as Pyralon
	_death_framing = _bird.get_node_or_null("DeathFraming") as CameraCutscene
	if _death_framing and _death_framing.data:
		_death_shot_offset = _death_framing.data.shot_offset


func enter(_previous: StringName) -> void:
	_stage = Stage.DYING
	_timer = 0.0
	_bird.encounter_complete = true
	_bird.hitbox.cancel()
	_bird.field.clear()
	_bird.velocity = Vector3.ZERO
	_bird.hurtbox.invulnerable = true
	_bird.hurtbox.set_deferred(&"monitorable", false)
	_bird.external_forces_enabled = false
	_bird.set_air_pose(false)
	var visual := _bird.get_node_or_null("Model/Visual") as Node3D
	if visual:
		visual.position = Vector3.ZERO
	_bird.model.show()
	var anim := _bird.animation_player()
	anim.speed_scale = 1.0
	anim.play(PyralonRig.COLLAPSE, 0.14)
	_clip_len = maxf(anim.get_animation(PyralonRig.COLLAPSE).length, 1.0)
	if _bird.phase and _bird.phase.is_in_phase_two:
		_bird.phase.begin_revert_top_down()
	HitStop.begin_cinematic(self, clampf(_bird.profile.true_death_time_scale, 0.15, 1.0))
	_start_death_zoom()


func exit() -> void:
	HitStop.end_cinematic(self)
	if _death_framing and _death_framing.is_processing():
		_death_framing.cancel_playback()
	_bird.animation_player().speed_scale = 1.0


func physics_update(delta: float) -> void:
	_bird.apply_gravity(delta)
	_bird.velocity.x = 0.0
	_bird.velocity.z = 0.0
	if _stage == Stage.SETTLED:
		return
	_timer += delta
	_bird.pose.update_bones()
	if _stage == Stage.DYING:
		if _bird.phase and _bird.phase.is_reverting():
			var rev_dur := maxf(_bird.profile.death_revert_duration, 0.25)
			_bird.phase.set_revert_progress(clampf(_timer / rev_dur, 0.0, 1.0))
		var anim := _bird.animation_player()
		if _timer >= _clip_len or not anim.is_playing():
			_stage = Stage.SETTLE_HOLD
			_timer = 0.0
			if _bird.phase:
				_bird.phase.show_phase_two_form(false)
			anim.seek(_clip_len, true)
			anim.pause()
			_bird.pose.update_bones()
	elif _stage == Stage.SETTLE_HOLD:
		if _timer >= SETTLE_PAUSE:
			_finish_settled()


func _start_death_zoom() -> void:
	if _death_framing == null or _death_framing.data == null or get_viewport().get_camera_3d() == null:
		return
	var viewer := _bird.target as Player
	if viewer == null:
		viewer = get_tree().get_first_node_in_group(&"player") as Player
	if viewer == null:
		return
	var forward := _bird.model.global_basis.z.slide(Vector3.UP)
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
	HitStop.end_cinematic(self)
	if _death_framing and _death_framing.is_processing():
		_death_framing.release_hold()
	if _bird.phase:
		_bird.phase.show_phase_two_form(false)
	var anim := _bird.animation_player()
	anim.seek(_clip_len, true)
	anim.pause()
	_bird.pose.update_bones()
	_bird.body_set_collision(false)
	_bird.set_physics_process(false)
	_bird.set_dormant(true)
	_bird.died.emit(_bird)
