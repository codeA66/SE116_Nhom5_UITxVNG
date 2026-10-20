extends RubbleJamState
## Đá đang chèn, đứng yên. Đủ nguồn thì bắt đầu vỡ.


func on_unlocked() -> void:
	state_machine.transition_to(BURSTING)
