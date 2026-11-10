extends EnemyState

var _dive_left: float
@onready var _beetle := owner as BurrowBeetle


func enter(_previous: StringName) -> void:
	_beetle.set_exposed(false)
	_beetle.play_action(&"Burrow", 1.0, 0.0)
	_dive_left = _beetle.clip_length(&"Burrow")


func physics_update(delta: float) -> void:
	_beetle.apply_gravity(delta)
	if _dive_left > 0.0:
		_dive_left -= delta
		if _dive_left > 0.0:
			return
		_beetle.play_action(&"Hidden", 1.0, 0.0)
	if _beetle.distance_to_target() >= maxf(_beetle.rise_distance, _beetle.burrow_distance + 0.1):
		state_machine.transition_to(IDLE)
