class_name BossMelee
extends BossState
## Đòn quét tay cận chiến (Normal_Attack_1 hoặc Normal_Attack_2).

@export var telegraph_duration: float = 0.7
@export var active_start: float = 0.8
@export var active_end: float = 1.35

var _timer: float = 0.0
var _attack_type: int = 1
var _hitbox_activated: bool = false
var _effective_telegraph: float = 0.7
var _effective_start: float = 0.8
var _effective_end: float = 1.35


func enter(_previous: StringName) -> void:
	_timer = 0.0
	_hitbox_activated = false
	_attack_type = 1 if randf() > 0.5 else 2
	
	var anim_speed: float = boss.get_current_anim_speed()
	_effective_telegraph = telegraph_duration / anim_speed
	_effective_start = active_start / anim_speed
	_effective_end = active_end / anim_speed
	
	var anim_name: StringName = &"Normal_Attack_1" if _attack_type == 1 else &"Normal_Attack_2"
	boss.play_action(anim_name, anim_speed)
	boss.start_melee_cooldown()


func exit() -> void:
	boss.set_melee_hitbox_active(false)


func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	boss.move_toward_direction(Vector3.ZERO, delta)
	
	_timer += delta
	
	# Trong giai đoạn telegraph tự nhiên của đòn cào: quay mặt theo người chơi
	if _timer <= _effective_telegraph and is_instance_valid(boss.target_player):
		var to_player: Vector3 = boss.target_player.global_position - boss.global_position
		to_player.y = 0.0
		boss.face_direction(to_player.normalized(), delta)
	
	# Bật hitbox trong active frames
	if _timer >= _effective_start and _timer <= _effective_end:
		if not _hitbox_activated:
			_hitbox_activated = true
			boss.set_melee_hitbox_active(true)
	else:
		if _hitbox_activated:
			_hitbox_activated = false
			boss.set_melee_hitbox_active(false)
	
	if boss.is_anim_finished():
		state_machine.transition_to(&"Idle")
