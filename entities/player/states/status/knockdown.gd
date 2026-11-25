extends PlayerState
## Bị hất ngã (kiểu Death's Door): trúng đòn mạnh hoặc trúng hai đòn liền nhau thì cáo bị hất bay lùi, ngã ngửa,
## nằm một nhịp rồi đứng dậy. Cú hất kéo cáo ra khỏi chỗ bị vây đánh; bất tử suốt lúc ngã và thêm một chút sau khi
## đứng dậy để quái quanh đó đánh hụt. Không điều khiển được trong lúc này (không lăn để dậy sớm).
## Ngã = clip ngã (Death) phát nhanh; đứng dậy = chính clip đó chạy ngược, không cần clip riêng.

@export_group("Khi nào ngã")
## Đòn có lực đẩy từ mức này trở lên (m/s) tính là đòn mạnh, kể cả khi đòn không đánh dấu knocks_down
@export var strong_knockback: float = 12.0
## Trúng đòn thứ hai trong bấy nhiêu giây sau đòn trước thì ngã (phải dài hơn bất tử sau đòn của HurtboxComponent)
@export var combo_window: float = 1.5

@export_group("Hất bay")
## Tốc độ bị hất lùi lúc đầu (m/s) và độ hãm (m/s mỗi giây)
@export var knockback_speed: float = 9.0
@export var knockback_friction: float = 18.0

@export_group("Nhịp")
## Thời gian ngã xuống (s) và tốc độ phát clip ngã cho vừa thời gian đó
@export var fall_time: float = 0.3
@export var fall_anim_speed: float = 3.0
## Nằm yên (s)
@export var lie_time: float = 0.2
## Tốc độ chạy ngược clip ngã để đứng dậy và thời gian chờ cho xong động tác (s)
@export var get_up_speed: float = 2.4
@export var get_up_time: float = 0.42
## Bất tử thêm sau khi đứng dậy (s), cáo nhấp nháy
@export var after_invincibility: float = 0.5

var _elapsed: float = 0.0
var _getting_up: bool = false


## Player hỏi trước khi chuyển state: đòn này có làm ngã không
func should_knock_down(info: DamageInfo, seconds_since_last_hit: float) -> bool:
	if info == null:
		return false
	if info.attack and info.attack.knocks_down:
		return true
	if info.knockback.length() >= strong_knockback:
		return true
	return seconds_since_last_hit <= combo_window


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	_getting_up = false
	var push := Vector3.ZERO
	if player.last_hit:
		push = player.last_hit.direction if not player.last_hit.direction.is_zero_approx() else player.last_hit.knockback
	push.y = 0.0
	if push.is_zero_approx():
		push = -player.get_facing_direction()
	push = push.normalized()
	player.velocity.x = push.x * knockback_speed
	player.velocity.z = push.z * knockback_speed
	# Quay mặt về phía bị đánh tới: ngã ngửa ra sau theo hướng bị hất
	player.face_instantly(-push)
	player.play_action(Player.ANIM_DEATH, fall_anim_speed)
	# Bất tử suốt cú ngã (không nhấp nháy lúc đang ngã: chớp đỏ khi trúng đòn đã đủ báo)
	player.grant_invincibility(fall_time + lie_time + get_up_time, false)


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.apply_gravity(delta)
	var horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z).move_toward(Vector3.ZERO, knockback_friction * delta)
	player.velocity.x = horizontal.x
	player.velocity.z = horizontal.z
	if not _getting_up and _elapsed >= fall_time + lie_time:
		_getting_up = true
		player.play_action_reversed(Player.ANIM_DEATH, get_up_speed)
	if _elapsed < fall_time + lie_time + get_up_time:
		return
	player.grant_invincibility(after_invincibility)
	if not player.is_on_floor():
		state_machine.transition_to(FALL)
	elif player.get_move_direction().is_zero_approx():
		state_machine.transition_to(IDLE)
	else:
		state_machine.transition_to(RUN)
