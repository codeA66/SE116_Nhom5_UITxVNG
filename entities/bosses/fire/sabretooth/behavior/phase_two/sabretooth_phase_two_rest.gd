extends EnemyState
## Khoảng nghỉ 2 giây giữa các chiêu Phase 2 của Hổ Răng Kiếm:
## Chạy animation lùi lại (BackUp) hướng mặt về phía player để người chơi định hình và có cửa sổ tấn công,
## hết giờ tự chuyển sang chiêu kế tiếp trong vòng lặp Phase 2 cố định.

var _actor: FireSabretooth
var _timer: float = 0.0
var _clip: StringName = &""


func _ready() -> void:
	super()
	_actor = enemy as FireSabretooth


func enter(_previous: StringName) -> void:
	_timer = 0.0
	_clip = &""
	_actor.hitbox.cancel()
	_actor.velocity = Vector3.ZERO
	_actor.hurtbox.invulnerable = false
	_actor.body_set_collision(true)
	_actor.phase.show_flame_form()
	_actor.phase.set_ambient_active(true)
	_actor.model.show()
	_actor.model.rotation.x = 0.0
	(_actor.get_node("Model/Visual") as Node3D).position = Vector3.ZERO
	if _actor.has_target():
		_actor.face_direction(_actor.direction_to_target(), 0.25)


func exit() -> void:
	_actor.velocity.x = 0.0
	_actor.velocity.z = 0.0


func physics_update(delta: float) -> void:
	_actor.apply_gravity(delta)
	if not _actor.manual_skill and _actor.should_give_up_chase():
		_actor.forget_target()
		state_machine.transition_to(IDLE)
		return

	_timer += delta
	var away := -_actor.direction_to_target() if _actor.has_target() else -_actor.get_facing_direction()
	away = away.slide(Vector3.UP)
	if away.length_squared() > 0.001:
		away = away.normalized()

	var can_back := away.length_squared() > 0.01 and _actor.clear_path(away, 0.85)
	if can_back:
		_actor.walk(away, _actor.profile.phase_two_rest_speed, delta, true)
		_play_clip(&"BackUp")
	else:
		_actor.velocity.x = move_toward(_actor.velocity.x, 0.0, 14.0 * delta)
		_actor.velocity.z = move_toward(_actor.velocity.z, 0.0, 14.0 * delta)
		if _actor.has_target():
			_actor.face_direction(_actor.direction_to_target(), delta)
		_play_clip(&"Growling")

	if _timer >= maxf(_actor.profile.phase_two_skill_gap, 0.0):
		var next_state := _actor.phase_two_next_state
		if next_state.is_empty():
			next_state = &"TigerFireBeam"
		state_machine.transition_to(next_state)


func _play_clip(clip: StringName) -> void:
	if _clip == clip:
		return
	_clip = clip
	_actor.motion.play(clip, _actor.profile.bridge_duration, true)
	_actor.animation_player().speed_scale = 1.0
