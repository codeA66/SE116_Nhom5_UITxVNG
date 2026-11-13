extends EnemyState
## Đuổi bằng các bước nảy (chase_state của Slime Dung Nham): mỗi bước dài hop_interval giây, chỉ dịch chuyển
## trong phần "bay" [hop_air_start, hop_air_end] của bước, đứng yên lúc nén / đáp. Player vào trong attack_range
## thì sang châm ngòi; mục tiêu ra quá xa thì bỏ đuổi.

var slime: LavaSlime
var _elapsed: float = 0.0


func _ready() -> void:
	super()
	slime = owner as LavaSlime
	assert(slime != null, "SlimeHop chỉ dùng cho LavaSlime")


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	slime.play_action(ANIM_WALK, _clip_speed())


func physics_update(delta: float) -> void:
	slime.apply_gravity(delta)
	if slime.should_give_up_chase():
		slime.forget_target()
		state_machine.transition_to(PATROL)
		return
	# can_attack: trong tầm và hết hồi chiêu (Slime Mẹ có hồi chiêu giữa hai cú dậm; slime thường hồi chiêu 0)
	if slime.can_attack():
		state_machine.transition_to(slime.attack_state)
		return
	var data := slime.slime_data
	_elapsed += delta
	if _elapsed >= data.hop_interval:
		_elapsed -= data.hop_interval
		slime.play_action(ANIM_WALK, _clip_speed(), 0.0)
	var phase := _elapsed / data.hop_interval
	var direction := slime.direction_to_target()
	slime.face_direction(direction, delta)
	var air := maxf(data.hop_air_end - data.hop_air_start, 0.01) * data.hop_interval
	if phase >= data.hop_air_start and phase < data.hop_air_end:
		# Bay: tốc độ cố định để mỗi bước đi đúng hop_distance
		var speed := data.hop_distance / air
		slime.velocity.x = direction.x * speed
		slime.velocity.z = direction.z * speed
	else:
		slime.velocity.x = 0.0
		slime.velocity.z = 0.0


## Clip Walk (một bước nảy) chạy khớp hop_interval
func _clip_speed() -> float:
	var length := slime.get_animation_length(ANIM_WALK)
	return length / slime.slime_data.hop_interval if length > 0.0 else 1.0
