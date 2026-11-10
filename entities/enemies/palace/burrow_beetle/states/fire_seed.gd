extends EnemyState

var _elapsed: float
var _shot: bool
var _length: float
@onready var _beetle := owner as BurrowBeetle


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	_shot = false
	_length = _beetle.clip_length(&"Attack")
	_beetle.face_instantly(_beetle.direction_to_target())
	_beetle.play_action(&"Attack", 1.0, 0.0)


func physics_update(delta: float) -> void:
	_beetle.apply_gravity(delta)
	if _beetle.distance_to_target() <= _beetle.burrow_distance:
		state_machine.transition_to(&"Burrow")
		return
	_elapsed += delta
	if not _shot:
		var direction := _beetle.direction_to_target()
		_beetle.face_direction(direction, delta)
		if _elapsed >= clampf(_beetle.shot_time, 0.0, _length):
			_shot = true
			_beetle.face_instantly(direction)
			_beetle.fire_seed()
	if _elapsed >= _length:
		state_machine.transition_to(IDLE)


func exit() -> void:
	_beetle.start_attack_cooldown()
