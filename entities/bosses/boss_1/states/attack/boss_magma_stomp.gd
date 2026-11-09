class_name BossMagmaStomp
extends BossState
## Đòn giậm đất giải phóng 8 nhánh đá Magma tỏa tròn 360 độ (Magma Stomp).

@export var telegraph_duration: float = 0.75
@export var impact_time: float = 0.85
@export var anim_speed_mult: float = 1.0

var _timer: float = 0.0
var _slammed: bool = false
var _effective_telegraph: float = 0.75
var _effective_impact: float = 0.85


func enter(_previous: StringName) -> void:
	_timer = 0.0
	_slammed = false
	
	var anim_speed: float = boss.get_current_anim_speed() * anim_speed_mult
	_effective_telegraph = telegraph_duration / anim_speed
	_effective_impact = impact_time / anim_speed
	
	boss.play_action(&"Taunt", anim_speed)
	boss.start_magma_stomp_cooldown()
	boss.show_magma_indicators(_effective_impact)


func exit() -> void:
	boss.hide_magma_indicators()


func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	boss.move_toward_direction(Vector3.ZERO, delta)
	
	_timer += delta
	
	# Trong giai đoạn lấy đà: xoay người hướng về phía người chơi
	if _timer <= _effective_telegraph and is_instance_valid(boss.target_player):
		var to_player: Vector3 = boss.target_player.global_position - boss.global_position
		to_player.y = 0.0
		boss.face_direction(to_player.normalized(), delta)
	
	# Thời điểm dậm đất: kích hoạt tỏa 8 nhánh cột đá magma
	if _timer >= _effective_impact and not _slammed:
		_slammed = true
		boss.trigger_magma_stomp()
	
	if boss.is_anim_finished():
		state_machine.transition_to(&"Idle")
