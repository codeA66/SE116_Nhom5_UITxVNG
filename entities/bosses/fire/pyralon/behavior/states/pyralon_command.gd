extends PyralonAttackState

var _beat: float
var _struck: bool
var _beats_left: int


func enter(previous: StringName) -> void:
	super(previous)
	_beat = 0.0
	_struck = false
	_beats_left = bird.field.reserve_gold()
	# Chuyển thẳng sang frame 0 của AxeSignal (không blend từ Idle) để nhịp đầu chạy đủ giậm rìu phía trước.
	animator.play(skill.animation, 0.0)
	animator.seek(0.0, true)
	bird.pose.update_bones()


func physics_update(delta: float) -> void:
	stay_in_place(delta)
	if _beats_left > 0 or _struck:
		_step_axe(delta)
	if bird.field.gold_count() == 0:
		bird.finish_move(skill)


func _step_axe(delta: float) -> void:
	_beat += delta / maxf(bird.profile.command_interval, 0.12)
	var progress := minf(_beat, 1.0)
	var clip_len := maxf(animator.current_animation_length, 0.01)
	animator.seek(progress * clip_len, true)
	bird.pose.update_bones()
	if not _struck and progress >= PyralonRig.COMMAND_HIT:
		_struck = true
		_beats_left -= 1
		if bird.field.send_next_gold():
			var point := bird.field.floor_at(bird.pose.axe_end())
			bird.field.command_pulse(point)
	if progress >= 1.0:
		_beat -= 1.0
		_struck = false
		if _beats_left == 0:
			bird.play_anim(ANIM_IDLE)
			animator.advance(0.0)
