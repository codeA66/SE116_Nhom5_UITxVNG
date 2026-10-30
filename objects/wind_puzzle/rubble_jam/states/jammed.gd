extends RubbleJamState
## Đá đang chèn, đứng yên. Đủ nguồn thì bắt đầu vỡ.


func on_unlocked() -> void:
	# Có gán nguồn chờ (camera cắt cảnh) thì đợi tín hiệu rồi mới vỡ, để người chơi kịp nhìn
	state_machine.transition_to(WAITING if jam.wait_source else BURSTING)
