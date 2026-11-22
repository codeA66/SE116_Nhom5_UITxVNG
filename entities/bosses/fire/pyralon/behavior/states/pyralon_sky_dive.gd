extends PyralonAttackState
## Chiêu Phase 2 #1: Sky Dive Meteor Barrage.
## Thả lỏng 2 tay duỗi cánh bay thẳng lên trời (tạo phản lực gió đẩy lùi gần không sát thương),
## rồi đáp 5 đợt tốc độ cao tạo crater + cột lửa vàng cam (đợt 5 dùng crosshair xoay rộng & rải lông vàng).

enum Phase { LAUNCH, AIR_WAIT, WARN, DROP, LAND_HOLD, REASCENT }

const LAUNCH_DURATION := 2.02
const REASCENT_DURATION := 0.48

var _visual: Node3D
var _blob_shadow: Node3D
var _phase: Phase = Phase.LAUNCH
var _phase_time: float = 0.0
var _dive_index: int = 0
var _wind_pushed: bool = false
var _sky_hidden: bool = false
var _current_radius: float = 3.0
var _target_spot: Vector3 = Vector3.ZERO
var _warning_fx: PyralonFireFx
var _saved_layer: int = 0
var _saved_mask: int = 0


func enter(previous: StringName) -> void:
	super(previous)
	_visual = bird.get_node("Model/Visual") as Node3D
	_blob_shadow = bird.get_node_or_null("BlobShadow") as Node3D
	_saved_layer = bird.collision_layer
	_saved_mask = bird.collision_mask
	_phase = Phase.LAUNCH
	_phase_time = 0.0
	_dive_index = 0
	_wind_pushed = false
	_sky_hidden = false
	_warning_fx = null
	_visual.position = Vector3.ZERO
	animator.play(PyralonRig.SKY_LAUNCH, 0.0)
	animator.seek(0.0, true)
	bird.pose.update_bones()


func exit() -> void:
	_clear_warning()
	_set_sky_hidden(false)
	if is_instance_valid(_visual):
		_visual.position = Vector3.ZERO
	super()


func physics_update(delta: float) -> void:
	_phase_time += delta
	var config := bird.profile
	match _phase:
		Phase.LAUNCH:
			_step_launch(delta, config)
		Phase.AIR_WAIT:
			_step_air_wait(config)
		Phase.WARN:
			_step_warn(delta, config)
		Phase.DROP:
			_step_drop(delta, config)
		Phase.LAND_HOLD:
			_step_land_hold(delta, config)
		Phase.REASCENT:
			_step_reascent(delta, config)


func _step_launch(delta: float, config: PyralonData) -> void:
	tick_pose(delta)
	var blast_time := LAUNCH_DURATION * PyralonRig.SKY_LAUNCH_BLAST
	stay_in_place(delta, bird.pose.displacement().y > 0.14 or _phase_time >= blast_time)
	if not _wind_pushed and _phase_time >= blast_time:
		_wind_pushed = true
		var floor_pt := bird.field.floor_at(bird.global_position)
		bird.field.effect(PyralonFireFx.Kind.WIND_PUSH_RING, floor_pt, Vector3.ZERO, Vector2.ONE * config.sky_launch_wind_radius, 0.56)
		bird.field.push_target_outward(floor_pt, config.sky_launch_wind_radius, config.sky_launch_push_speed)
		ScreenShake.add_trauma_at(0.28, floor_pt, 6.0, 16.0)
	if _phase_time >= blast_time:
		# Đúng khoảnh khắc quất cánh duỗi thẳng xuống -> phóng vọt tốc độ cực cao thẳng lên trời!
		var climb_t := clampf((_phase_time - blast_time) / maxf(LAUNCH_DURATION - blast_time, 0.05), 0.0, 1.0)
		_visual.position.y = pow(climb_t, 1.85) * config.sky_dive_height
	if _phase_time >= LAUNCH_DURATION:
		_set_sky_hidden(true)
		# Thêm delay 1.0s trên trời ở cả lần bay đầu tiên giống các đợt sau để nhịp đáp khó đoán hơn.
		_begin_air_wait(config)


func _begin_air_wait(config: PyralonData) -> void:
	if config.sky_dive_air_delay <= 0.001:
		_begin_warn(config)
		return
	_phase = Phase.AIR_WAIT
	_phase_time = 0.0


func _step_air_wait(config: PyralonData) -> void:
	bird.velocity = Vector3.ZERO
	if _phase_time >= config.sky_dive_air_delay:
		_begin_warn(config)


func _begin_warn(config: PyralonData) -> void:
	_phase = Phase.WARN
	_phase_time = 0.0
	var is_final := _dive_index >= config.sky_dive_count - 1
	var warn_dur := config.sky_dive_final_warn_time if is_final else config.sky_dive_warn_time
	_current_radius = config.sky_dive_final_radius if is_final else config.sky_dive_radius
	_target_spot = _sample_target_floor()
	var fx_kind := PyralonFireFx.Kind.CROSSHAIR_WARNING if is_final else PyralonFireFx.Kind.DIVE_WARNING
	_warning_fx = bird.field.effect(fx_kind, _target_spot, Vector3.ZERO, Vector2.ONE * _current_radius, warn_dur + config.sky_dive_drop_time)


func _step_warn(delta: float, config: PyralonData) -> void:
	bird.velocity = Vector3.ZERO
	var is_final := _dive_index >= config.sky_dive_count - 1
	var warn_dur := config.sky_dive_final_warn_time if is_final else config.sky_dive_warn_time
	# Bám nhẹ vị trí player trong 0.4s đầu rồi khóa cố định phần cuối để người chơi đọc và dash né.
	if _phase_time <= config.sky_dive_track_time and bird.has_target():
		var goal := _sample_target_floor()
		var next_xz := _target_spot.slide(Vector3.UP).move_toward(goal.slide(Vector3.UP), config.sky_dive_track_speed * delta)
		var candidate := bird.field.floor_at(Vector3(next_xz.x, _target_spot.y, next_xz.z))
		if bird.field.wall_between(_target_spot + Vector3.UP * 0.6, candidate + Vector3.UP * 0.6).is_empty():
			_target_spot = candidate
		if is_instance_valid(_warning_fx) and _warning_fx.visible:
			_warning_fx.set_pose(_target_spot + Vector3.UP * 0.045, Vector3.ZERO)
	if _phase_time >= warn_dur:
		_begin_drop(config)


func _begin_drop(config: PyralonData) -> void:
	_phase = Phase.DROP
	_phase_time = 0.0
	bird.global_position = _target_spot
	if bird.has_target():
		var look_dir := (bird.target.global_position - _target_spot).slide(Vector3.UP)
		if look_dir.length_squared() > 0.01:
			bird.face_instantly(look_dir.normalized())
	bird.reset_physics_interpolation()
	_set_sky_hidden(false)
	bird.set_air_pose(true)
	_visual.position = Vector3(0.0, config.sky_dive_height, 0.0)
	animator.play(PyralonRig.SKY_DIVE_LAND, 0.0)
	animator.seek(0.0, true)
	bird.pose.update_bones()


func _step_drop(_delta: float, config: PyralonData) -> void:
	bird.velocity = Vector3.ZERO
	var drop_dur := maxf(config.sky_dive_drop_time, 0.05)
	var t := clampf(_phase_time / drop_dur, 0.0, 1.0)
	_visual.position.y = lerpf(config.sky_dive_height, 0.0, pow(t, 1.70))
	animator.seek(t * 0.16, true)
	bird.pose.update_bones()
	if _phase_time >= drop_dur:
		_visual.position = Vector3.ZERO
		_clear_warning()
		_begin_land_hold(config)


func _begin_land_hold(config: PyralonData) -> void:
	_phase = Phase.LAND_HOLD
	_phase_time = 0.0
	bird.set_air_pose(false)
	animator.seek(0.24, true)
	bird.pose.update_bones()
	var is_final := _dive_index >= config.sky_dive_count - 1
	var damage := config.sky_dive_final_damage if is_final else config.sky_dive_damage
	var floor_pt := bird.field.floor_at(_target_spot)
	bird.field.sky_crater(floor_pt, _current_radius, damage, is_final)
	ScreenShake.add_trauma_at(0.74 if is_final else 0.44, floor_pt, _current_radius * 0.9, _current_radius * 2.8)
	if is_final:
		if config.sky_dive_impact_frame_duration > 0.01:
			ImpactFrame.play_at(
				floor_pt + Vector3.UP * 1.15,
				config.sky_dive_impact_frame_duration,
				config.sky_dive_impact_hitstop
			)
		bird.field.scatter_gold_ring(floor_pt, config.sky_dive_final_gold_count)


func _step_land_hold(delta: float, config: PyralonData) -> void:
	stay_in_place(delta, false)
	animator.advance(delta)
	bird.pose.update_bones()
	var is_final := _dive_index >= config.sky_dive_count - 1
	var hold_len := config.sky_dive_final_hold if is_final else config.sky_dive_land_hold
	if _phase_time >= hold_len:
		if is_final:
			bird.finish_move(skill)
		else:
			_dive_index += 1
			_begin_reascent()


func _begin_reascent() -> void:
	_phase = Phase.REASCENT
	_phase_time = 0.0
	bird.set_air_pose(true)
	animator.play(PyralonRig.SKY_REASCENT, 0.0)
	animator.seek(0.0, true)
	bird.pose.update_bones()


func _step_reascent(delta: float, config: PyralonData) -> void:
	bird.velocity = Vector3.ZERO
	animator.advance(delta)
	bird.pose.update_bones()
	var blast_time := REASCENT_DURATION * PyralonRig.SKY_REASCENT_BLAST
	if _phase_time < blast_time:
		# Dang cánh rộng lấy đà trước khi quất xuống phóng vọt.
		var lift_t := clampf(_phase_time / maxf(blast_time, 0.05), 0.0, 1.0)
		_visual.position.y = lift_t * 1.15
	else:
		var climb_t := clampf((_phase_time - blast_time) / maxf(REASCENT_DURATION - blast_time, 0.05), 0.0, 1.0)
		_visual.position.y = lerpf(1.15, config.sky_dive_height, pow(climb_t, 1.75))
	if _phase_time >= REASCENT_DURATION:
		_set_sky_hidden(true)
		_begin_air_wait(config)


func _sample_target_floor() -> Vector3:
	var raw := bird.target.global_position if bird.has_target() else bird.global_position
	return bird.field.floor_at(raw)


func _set_sky_hidden(hidden: bool) -> void:
	if _sky_hidden == hidden:
		return
	_sky_hidden = hidden
	bird.model.visible = not hidden
	if is_instance_valid(_blob_shadow):
		_blob_shadow.visible = not hidden
	if bird.phase:
		bird.phase.set_sky_hidden(hidden)
	if hidden:
		bird.set_air_pose(true)
		bird.collision_layer = 0
		bird.collision_mask = 0
	else:
		bird.collision_layer = _saved_layer
		bird.collision_mask = _saved_mask


func _clear_warning() -> void:
	if is_instance_valid(_warning_fx) and _warning_fx.visible:
		bird.field.release_effect(_warning_fx)
	_warning_fx = null
