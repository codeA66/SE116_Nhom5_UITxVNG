class_name BossStunned
extends BossState
## State bị choáng kiệt sức khi khiên bị vỡ bởi cầu lửa phản lại.

var _stun_timer: float = 0.0


func enter(_previous: StringName) -> void:
	boss.play_anim(&"Orc Idle")
	
	if boss.current_phase == 1:
		_stun_timer = boss.data.stun_duration_phase1
	else:
		_stun_timer = boss.data.stun_duration_phase2


func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	boss.move_toward_direction(Vector3.ZERO, delta)
	
	_stun_timer -= delta
	if _stun_timer <= 0.0:
		state_machine.transition_to(&"Idle")
