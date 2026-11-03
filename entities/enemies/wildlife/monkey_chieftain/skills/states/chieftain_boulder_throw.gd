extends WildSkillAttack
## Cùng đồng hồ animation với lúc đá rời tay; ngừng xoay và khóa điểm rơi khi ném.
var _throw: BoulderThrowSkillData
var _launcher: ChieftainBoulderEmitter
var _released: bool = false

func enter(previous: StringName) -> void:
	super(previous)
	_throw = _skill as BoulderThrowSkillData
	_launcher = _actor.get_node("BoulderEmitter") as ChieftainBoulderEmitter
	_released = false
	_launcher.prepare(_throw)

func physics_update(delta: float) -> void:
	if not _released:
		_launcher.track_target()
		if _elapsed + delta * _speed_scale >= _throw.release_time:
			_released = true
			_launcher.release_boulder()
	super(delta)

func exit() -> void:
	_launcher.cancel()
	super()

func _apply_motion(_previous: float, _delta: float) -> void:
	_actor.velocity.x = 0.0
	_actor.velocity.z = 0.0
