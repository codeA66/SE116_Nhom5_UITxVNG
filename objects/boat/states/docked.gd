extends BoatState
## Đứng yên (ở bến đầu, hoặc dừng giữa đường sau khi bị đẩy từ bờ). Buồm cụp.


func enter(_previous: StringName) -> void:
	boat.speed = 0.0


## Người trên thuyền thổi thì chạy hết tuyến; thổi từ bờ thì trôi một đoạn
func on_tailwind(from_on_board: bool) -> void:
	state_machine.transition_to(SAILING if from_on_board else DRIFTING)
