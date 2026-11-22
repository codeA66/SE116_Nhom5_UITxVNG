extends EnemyState
## Chuyển pha Pyralon Phase 1 -> Phase 2 (Fakeout Sky Dive dramatic):
## 1. Hết máu Phase 1 -> giữ form Phase 1, trở về dáng mặc định 1 nhịp mượt đồng thời tạo sóng gió phản lực đẩy lùi player.
## 2. Bay vút lên trời dùng đúng animation bay đầu tiên (SkyLaunch).
## 3. Ẩn trên trời 3.0s cho player tưởng đã hạ gục.
## 4. Hiện vòng cảnh báo đòn Sky Dive cuối (Crosshair) dưới chân player và chờ 1.0s.
## 5. Lao xuống đòn cuối Sky Dive có Impact Frame nhưng KHÔNG tỏa lông vàng.
## 6. Vừa kết thúc Impact Frame -> zoom camera vào Pyralon + slow-motion 0.5x và nhấc người đứng dậy từ từ uy lực (SkyDiveRise).
## 7. Đứng thẳng hoàn toàn -> trả game về 1.0x nhưng VẪN GIỮ zoom vào Pyralon và chạy animation biến hình Phase 2!
## 8. Biến hình xong -> bay thẳng lên trời chạy Sky Dive Phase 2 ngay lập tức (không đi bộ, không xoay).

enum Stage { PREPARE_LAUNCH, LAUNCH, AIR_FAKEOUT, WARN, DROP, IMPACT_FRAMES, SLOWMO_ZOOM_LAND, TRANSFORM }

const LAUNCH_DURATION := 2.02

var _bird: Pyralon
var _visual: Node3D
var _blob_shadow: Node3D
var _stage: Stage = Stage.PREPARE_LAUNCH
var _timer: float = 0.0
var _real_wait: float = 0.0
var _wind_pushed: bool = false
var _sky_hidden: bool = false
var _done: bool = false
var _target_spot: Vector3 = Vector3.ZERO
var _warning_fx: PyralonFireFx
var _saved_layer: int = 0
var _saved_mask: int = 0


func _ready() -> void:
	super()
	_bird = enemy as Pyralon
	(_bird.get_node("Phase") as PyralonPhase).finished.connect(_on_transformed)


func enter(_previous: StringName) -> void:
	_visual = _bird.get_node("Model/Visual") as Node3D
	_blob_shadow = _bird.get_node_or_null("BlobShadow") as Node3D
	_saved_layer = _bird.collision_layer
	_saved_mask = _bird.collision_mask
	_stage = Stage.PREPARE_LAUNCH
	_timer = 0.0
	_real_wait = 0.0
	_wind_pushed = false
	_sky_hidden = false
	_done = false
	_warning_fx = null
	_bird.hitbox.cancel()
	_bird.field.clear()
	_bird.velocity = Vector3.ZERO
	_bird.hurtbox.invulnerable = true
	_bird.set_air_pose(false)
	_visual.position = Vector3.ZERO
	if _bird.phase:
		_bird.phase.show_phase_two_form(false)
	# Trở về dáng đứng mặc định 1 nhịp mượt để tránh giựt hình khi vừa bị đánh hết máu, đồng thời phát phản lực đẩy player ra!
	var anim := _bird.animation_player()
	anim.speed_scale = 1.0
	var idle_clip := &"Idle1" if anim.has_animation(&"Idle1") else &"Idle"
	anim.play(idle_clip, 0.22)
	_bird.pose.update_bones()
	_trigger_wind_push(_bird.profile)


func exit() -> void:
	_clear_warning()
	_set_sky_hidden(false)
	HitStop.end_cinematic(self)
	if is_instance_valid(_visual):
		_visual.position = Vector3.ZERO
	_bird.hurtbox.invulnerable = false
	_bird.animation_player().speed_scale = 1.0
	if _stage in [Stage.SLOWMO_ZOOM_LAND, Stage.TRANSFORM] and not _done:
		_bird.phase.cancel_preview()


func physics_update(delta: float) -> void:
	_timer += delta
	var config := _bird.profile
	match _stage:
		Stage.PREPARE_LAUNCH:
			_step_prepare_launch(delta, config)
		Stage.LAUNCH:
			_step_launch(delta, config)
		Stage.AIR_FAKEOUT:
			_bird.velocity = Vector3.ZERO
			if _timer >= maxf(config.phase_two_fakeout_wait, 0.2):
				_begin_warn(config)
		Stage.WARN:
			_step_warn(delta, config)
		Stage.DROP:
			_step_drop(config)
		Stage.IMPACT_FRAMES:
			_step_impact_frames(delta, config)
		Stage.SLOWMO_ZOOM_LAND:
			_step_slowmo_zoom_land(delta, config)
		Stage.TRANSFORM:
			_bird.apply_gravity(delta)
			_bird.velocity.x = 0.0
			_bird.velocity.z = 0.0
			_bird.pose.update_bones()
			if _done:
				_bird.hurtbox.invulnerable = false
				_bird.begin_immediate_sky_dive()


func _step_prepare_launch(delta: float, config: PyralonData) -> void:
	_bird.apply_gravity(delta)
	_bird.velocity.x = 0.0
	_bird.velocity.z = 0.0
	_bird.pose.update_bones()
	if _timer >= maxf(config.phase_two_launch_prep, 0.15):
		_begin_launch()


func _begin_launch() -> void:
	_stage = Stage.LAUNCH
	_timer = 0.0
	_wind_pushed = false
	var anim := _bird.animation_player()
	anim.speed_scale = 1.0
	anim.play(PyralonRig.SKY_LAUNCH, 0.12)
	_bird.pose.update_bones()


func _step_launch(delta: float, config: PyralonData) -> void:
	_bird.apply_gravity(delta)
	_bird.velocity.x = 0.0
	_bird.velocity.z = 0.0
	_bird.pose.update_bones()
	var blast_time := LAUNCH_DURATION * PyralonRig.SKY_LAUNCH_BLAST
	var airborne := _bird.pose.displacement().y > 0.14 or _timer >= blast_time
	_bird.set_air_pose(airborne)
	if not _wind_pushed and _timer >= blast_time:
		_wind_pushed = true
		_trigger_wind_push(config)
	if _timer >= blast_time:
		var climb_t := clampf((_timer - blast_time) / maxf(LAUNCH_DURATION - blast_time, 0.05), 0.0, 1.0)
		_visual.position.y = pow(climb_t, 1.85) * config.sky_dive_height
	if _timer >= LAUNCH_DURATION:
		_set_sky_hidden(true)
		_stage = Stage.AIR_FAKEOUT
		_timer = 0.0


func _trigger_wind_push(config: PyralonData) -> void:
	var floor_pt := _bird.field.floor_at(_bird.global_position)
	_bird.field.effect(PyralonFireFx.Kind.WIND_PUSH_RING, floor_pt, Vector3.ZERO, Vector2.ONE * config.sky_launch_wind_radius, 0.56)
	_bird.field.push_target_outward(floor_pt, config.sky_launch_wind_radius, config.sky_launch_push_speed)
	ScreenShake.add_trauma_at(0.28, floor_pt, 6.0, 16.0)


func _begin_warn(config: PyralonData) -> void:
	_stage = Stage.WARN
	_timer = 0.0
	var warn_dur := maxf(config.sky_dive_final_warn_time, 0.2)
	_target_spot = _sample_target_floor()
	_warning_fx = _bird.field.effect(
		PyralonFireFx.Kind.CROSSHAIR_WARNING,
		_target_spot,
		Vector3.ZERO,
		Vector2.ONE * config.sky_dive_final_radius,
		warn_dur + config.sky_dive_drop_time
	)


func _step_warn(delta: float, config: PyralonData) -> void:
	_bird.velocity = Vector3.ZERO
	var warn_dur := maxf(config.sky_dive_final_warn_time, 0.2)
	if _timer <= config.sky_dive_track_time and _bird.has_target():
		var goal := _sample_target_floor()
		var next_xz := _target_spot.slide(Vector3.UP).move_toward(goal.slide(Vector3.UP), config.sky_dive_track_speed * delta)
		var candidate := _bird.field.floor_at(Vector3(next_xz.x, _target_spot.y, next_xz.z))
		if _bird.field.wall_between(_target_spot + Vector3.UP * 0.6, candidate + Vector3.UP * 0.6).is_empty():
			_target_spot = candidate
		if is_instance_valid(_warning_fx) and _warning_fx.visible:
			_warning_fx.set_pose(_target_spot + Vector3.UP * 0.045, Vector3.ZERO)
	if _timer >= warn_dur:
		_begin_drop(config)


func _begin_drop(config: PyralonData) -> void:
	_stage = Stage.DROP
	_timer = 0.0
	_bird.global_position = _target_spot
	if _bird.has_target():
		var look_dir := (_bird.target.global_position - _target_spot).slide(Vector3.UP)
		if look_dir.length_squared() > 0.01:
			_bird.face_instantly(look_dir.normalized())
	_bird.reset_physics_interpolation()
	_set_sky_hidden(false)
	_bird.set_air_pose(true)
	_visual.position = Vector3(0.0, config.sky_dive_height, 0.0)
	var anim := _bird.animation_player()
	anim.play(PyralonRig.SKY_DIVE_LAND, 0.0)
	anim.seek(0.0, true)
	anim.pause()
	_bird.pose.update_bones()


func _step_drop(config: PyralonData) -> void:
	_bird.velocity = Vector3.ZERO
	var drop_dur := maxf(config.sky_dive_drop_time, 0.05)
	var t := clampf(_timer / drop_dur, 0.0, 1.0)
	_visual.position.y = lerpf(config.sky_dive_height, 0.0, pow(t, 1.70))
	_bird.animation_player().seek(t * 0.16, true)
	_bird.pose.update_bones()
	if _timer >= drop_dur:
		_visual.position = Vector3.ZERO
		_clear_warning()
		_begin_impact_frames(config)


func _begin_impact_frames(config: PyralonData) -> void:
	_stage = Stage.IMPACT_FRAMES
	_timer = 0.0
	_real_wait = 0.0
	_bird.set_air_pose(false)
	var anim := _bird.animation_player()
	anim.seek(0.24, true)
	anim.pause()
	_bird.pose.update_bones()
	var floor_pt := _bird.field.floor_at(_target_spot)
	# Đòn cuối giả chết có crater lớn + Impact Frame nhưng KHÔNG tỏa lông vàng!
	_bird.field.sky_crater(floor_pt, config.sky_dive_final_radius, config.sky_dive_final_damage, true)
	ScreenShake.add_trauma_at(0.76, floor_pt, config.sky_dive_final_radius * 0.9, config.sky_dive_final_radius * 2.8)
	if config.sky_dive_impact_frame_duration > 0.01:
		ImpactFrame.play_at(
			floor_pt + Vector3.UP * 1.15,
			config.sky_dive_impact_frame_duration,
			config.sky_dive_impact_hitstop
		)


func _step_impact_frames(delta: float, config: PyralonData) -> void:
	_bird.apply_gravity(delta)
	_bird.velocity.x = 0.0
	_bird.velocity.z = 0.0
	var real_step := delta / maxf(Engine.time_scale, 0.05)
	_real_wait += minf(real_step, 0.05)
	if not ImpactFrame.is_active() or _real_wait >= config.sky_dive_impact_frame_duration + 0.15:
		_begin_slowmo_zoom_land(config)


func _begin_slowmo_zoom_land(config: PyralonData) -> void:
	_stage = Stage.SLOWMO_ZOOM_LAND
	_timer = 0.0
	# Ngay sau khi hết Impact Frame -> zoom camera vào Pyralon, chạy slow-motion 0.5x và nhấc người dậy từ từ đầy uy lực!
	HitStop.begin_cinematic(self, clampf(config.phase_two_slowmo_scale, 0.15, 1.0))
	var rise_len := maxf(config.phase_two_rise_duration, 0.45)
	var anim := _bird.animation_player()
	anim.speed_scale = PyralonRig.SKY_DIVE_RISE_LENGTH / rise_len
	anim.play(PyralonRig.SKY_DIVE_RISE, 0.08)
	_bird.pose.update_bones()
	var viewer := _bird.target as Player
	if viewer == null:
		viewer = get_tree().get_first_node_in_group(&"player") as Player
	if _bird.phase:
		_bird.phase.begin_held_zoom(viewer)


func _step_slowmo_zoom_land(delta: float, config: PyralonData) -> void:
	_bird.apply_gravity(delta)
	_bird.velocity.x = 0.0
	_bird.velocity.z = 0.0
	_bird.pose.update_bones()
	var rise_len := maxf(config.phase_two_rise_duration, 0.45)
	if _timer >= rise_len:
		# Pyralon đã nhấc người đứng thẳng hoàn toàn -> trả game về 1.0x, VẪN GIỮ camera đang zoom và chạy biến hình Phase 2!
		_stage = Stage.TRANSFORM
		_timer = 0.0
		_bird.animation_player().speed_scale = 1.0
		HitStop.end_cinematic(self)
		if _bird.phase:
			_bird.phase.start_transform_while_zoomed()
		else:
			_done = true


func _sample_target_floor() -> Vector3:
	var raw := _bird.target.global_position if _bird.has_target() else _bird.global_position
	return _bird.field.floor_at(raw)


func _set_sky_hidden(hidden: bool) -> void:
	if _sky_hidden == hidden:
		return
	_sky_hidden = hidden
	_bird.model.visible = not hidden
	if is_instance_valid(_blob_shadow):
		_blob_shadow.visible = not hidden
	if _bird.phase:
		_bird.phase.set_sky_hidden(hidden)
	if hidden:
		_bird.set_air_pose(true)
		_bird.collision_layer = 0
		_bird.collision_mask = 0
	else:
		_bird.collision_layer = _saved_layer
		_bird.collision_mask = _saved_mask


func _clear_warning() -> void:
	if is_instance_valid(_warning_fx) and _warning_fx.visible:
		_bird.field.release_effect(_warning_fx)
	_warning_fx = null


func _on_transformed() -> void:
	if state_machine.current_state == self and _stage == Stage.TRANSFORM:
		_done = true
