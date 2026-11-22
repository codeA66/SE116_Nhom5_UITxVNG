extends PyralonAttackState
## Chiêu Phase 2 #2: Resonance Slam & Domino Detonation.
## Nhấc cán rìu cao hơn bình thường rồi giậm mạnh đuôi cán xuống đất, tạo sóng đẩy lùi toàn phòng (0 sát thương)
## và kích nổ domino toàn bộ lông vàng theo thứ tự khoảng cách từ gần Pyralon nhất lan dần ra ngoài.

var _slammed: bool = false
var _total_time: float = 1.70


func enter(previous: StringName) -> void:
	super(previous)
	_slammed = false
	var config := bird.profile
	_total_time = maxf(config.resonance_duration, 0.4) + maxf(config.resonance_post_hold, 0.1)
	if bird.has_target():
		var dir := (bird.target.global_position - bird.global_position).slide(Vector3.UP)
		if dir.length_squared() > 0.01:
			bird.face_instantly(dir.normalized())
	# Bắt đầu ngay từ frame 0 để nhịp nhấc cao cán rìu và giậm mạnh xuống sàn hiển thị trọn vẹn.
	animator.play(PyralonRig.RESONANCE_SLAM, 0.0)
	animator.seek(0.0, true)
	bird.pose.update_bones()


func physics_update(delta: float) -> void:
	stay_in_place(delta)
	elapsed += delta
	var config := bird.profile
	var anim_dur := maxf(config.resonance_duration, 0.25)
	var progress := clampf(elapsed / anim_dur, 0.0, 1.0)
	var clip_len := maxf(animator.current_animation_length, 0.01)
	animator.seek(progress * clip_len, true)
	bird.pose.update_bones()
	if not _slammed and progress >= PyralonRig.RESONANCE_HIT:
		_slammed = true
		var butt_pt := bird.field.floor_at(bird.pose.axe_end())
		var boss_floor := bird.field.floor_at(bird.global_position)
		bird.field.command_pulse(butt_pt)
		bird.field.effect(PyralonFireFx.Kind.RESONANCE_WAVE, boss_floor, Vector3.ZERO, Vector2.ONE * minf(config.resonance_push_radius, 28.0), 0.72)
		bird.field.push_target_outward(boss_floor, config.resonance_push_radius, config.resonance_push_speed)
		bird.field.trigger_domino_all(boss_floor, config.resonance_wave_speed, config.resonance_feather_warn)
		ScreenShake.add_trauma_at(0.55, boss_floor, 16.0, 36.0)
	if elapsed >= _total_time:
		bird.finish_move(skill)
