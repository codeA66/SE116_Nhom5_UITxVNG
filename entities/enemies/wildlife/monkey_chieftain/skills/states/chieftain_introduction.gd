extends EnemyState
## Chỉ diễn giới thiệu; FSM giữ nguyên trạng thái này tới khi camera trả về player.
var _actor: MonkeyChieftain

func enter(_previous: StringName) -> void:
	_actor = enemy as MonkeyChieftain
	_actor.velocity = Vector3.ZERO
	_actor.play_action(_actor.wildlife.alert_animation,1.0,0.08)
	_actor.animation_player().animation_finished.connect(_animation_done)

func physics_update(delta: float) -> void:
	_actor.apply_gravity(delta)
	_actor.move_toward_direction(Vector3.ZERO,delta)

func exit() -> void:
	if _actor.animation_player().animation_finished.is_connected(_animation_done):
		_actor.animation_player().animation_finished.disconnect(_animation_done)

func _animation_done(_clip: StringName) -> void:
	_actor.play_anim(ANIM_IDLE)
