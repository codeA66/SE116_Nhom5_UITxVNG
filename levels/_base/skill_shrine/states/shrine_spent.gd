extends SkillShrineState
## Học xong: phòng rút màu và phủ sương (nơi này đã cạn sức mạnh), đèn tắt dần, rồi dịch chuyển sang phòng kế tiếp.
## Khoá điều khiển suốt đoạn này (không cho bỏ qua, không cho đi lạc giữa lúc dịch chuyển).

var _run: int = 0


func enter(_previous: StringName) -> void:
	_run += 1
	var run := _run
	var player := shrine.player
	if is_instance_valid(player):
		player.set_controls_enabled(false)
	shrine.set_presence(0.0, 0.0, 0.0, false, shrine.spent_time)
	shrine.set_mood(shrine.approach_dim * 0.6, shrine.spent_desaturate, shrine.spent_fog, shrine.spent_time * 0.7)
	await get_tree().create_timer(shrine.spent_time).timeout
	if run != _run:
		return
	# Màn tối của dịch chuyển che lúc trả không khí về bình thường
	shrine.set_mood(0.0, 0.0, 0.0, SceneManager.fade_duration * 2.0)
	await shrine.warp_to_arrival()
	if is_instance_valid(player):
		player.set_controls_enabled(true)
	if run == _run:
		state_machine.transition_to(&"Dormant")


func exit() -> void:
	_run += 1
