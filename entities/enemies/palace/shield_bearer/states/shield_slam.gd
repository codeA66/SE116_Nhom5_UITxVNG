extends ShieldBearerState
## Đập khiên, 3 pha theo AttackData: tụ lực (0 → active_start, hạ khiên chặn, telegraph + vòng báo phạm vi),
## đập (active_start → active_end, bật hitbox cận chiến + phát sóng kích), hồi (đứng yên, khiên vẫn hở).
## Hướng chốt lúc bắt đầu tụ lực, không xoay theo player giữa chừng. Quái có giáp nên không bị chém hủy đòn.

## Chống chia cho 0 khi active_start = 0
const MIN_CHARGE_TIME := 0.001

var _elapsed: float = 0.0
var _impact_done: bool = false
var _attack: AttackData


func enter(_previous: StringName) -> void:
	_attack = enemy.data.attack
	_elapsed = 0.0
	_impact_done = false
	var direction := enemy.direction_to_target()
	if direction.is_zero_approx():
		direction = enemy.get_facing_direction()
	enemy.face_instantly(direction)
	enemy.velocity.x = 0.0
	enemy.velocity.z = 0.0
	bearer.set_guard(false)
	enemy.set_telegraph(true)
	bearer.show_slam_preview(true)
	enemy.play_action(_attack.animation, _attack.anim_speed)


func exit() -> void:
	bearer.set_guard(true)
	enemy.set_telegraph(false)
	bearer.show_slam_preview(false)
	enemy.hitbox.deactivate()
	enemy.start_attack_cooldown()
	# Không dừng sóng ở đây: sóng đã phóng thì chạy hết kể cả khi quái chết / bị gián đoạn


func physics_update(delta: float) -> void:
	_elapsed += delta
	enemy.apply_gravity(delta)
	enemy.move_toward_direction(Vector3.ZERO, delta)

	if not _impact_done:
		bearer.update_slam_preview(clampf(_elapsed / maxf(_attack.active_start, MIN_CHARGE_TIME), 0.0, 1.0))
		if _elapsed >= _attack.active_start:
			_impact_done = true
			enemy.set_telegraph(false)
			bearer.show_slam_preview(false)
			enemy.hitbox.activate(_attack)
			bearer.launch_shockwave()
	if _elapsed >= _attack.active_end and enemy.hitbox.is_active():
		enemy.hitbox.deactivate()
	if _elapsed >= _attack.duration:
		_leave_to_default()
