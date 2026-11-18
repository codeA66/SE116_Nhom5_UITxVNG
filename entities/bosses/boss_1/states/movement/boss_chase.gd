class_name BossChase
extends BossState
## State di chuyển tiếp cận người chơi của Boss.

@export var max_chase_duration: float = 3.5

var _chase_timer: float = 0.0


func enter(_previous: StringName) -> void:
	boss.play_anim(&"Walk")
	boss.movement.max_speed = boss.get_current_walk_speed()
	_chase_timer = max_chase_duration


func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	
	var player: Node3D = boss.target_player
	if not is_instance_valid(player):
		state_machine.transition_to(&"Idle")
		return
	
	var to_player: Vector3 = player.global_position - boss.global_position
	to_player.y = 0.0
	var direction: Vector3 = to_player.normalized()
	
	boss.move_toward_direction(direction, delta)
	
	_chase_timer -= delta
	
	if boss.action_selector.try_select():
		return
	
	# Hết thời gian rượt đuổi -> tạm dừng Idle đổi nhịp
	if _chase_timer <= 0.0:
		state_machine.transition_to(&"Idle")
