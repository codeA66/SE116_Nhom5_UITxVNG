extends EnemyState
var _bomber: BananaBomber
func enter(_previous: StringName) -> void:
	_bomber = enemy as BananaBomber
	_bomber.arm()
	_bomber.play_anim(ANIM_RUN)
func physics_update(delta: float) -> void:
	_bomber.apply_gravity(delta)
	_bomber.move_toward_direction(_bomber.direction_to_target() if _bomber.has_target() else Vector3.ZERO,delta)
