extends EnemyState

var _rise_left: float
@onready var _beetle := owner as BurrowBeetle


func enter(previous: StringName) -> void:
	_rise_left = 0.0
	if previous == ATTACK:
		_beetle.play_anim(ANIM_IDLE)
		return
	_beetle.set_exposed(false)
	_beetle.play_action(&"Rise", 1.0, 0.0)
	_rise_left = _beetle.clip_length(&"Rise")


func physics_update(delta: float) -> void:
	_beetle.apply_gravity(delta)
	_beetle.reacquire_target()
	_beetle.face_direction(_beetle.direction_to_target(), delta)
	if _rise_left > 0.0:
		_rise_left -= delta
		if _rise_left > 0.0:
			return
		_beetle.set_exposed(true)
		_beetle.play_anim(ANIM_IDLE)
	if _beetle.distance_to_target() <= _beetle.burrow_distance:
		state_machine.transition_to(&"Burrow")
		return
	if _beetle.can_attack():
		state_machine.transition_to(ATTACK)
