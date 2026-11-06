class_name SkillData
extends AbilityData
## Kỹ năng chủ động có phím riêng (Thổi Gió = E, Phun Lửa = Q...). Player đọc input_action để biết phím,
## vào state FSM tên state khi dùng. Thêm kỹ năng mới = lớp con + .tres + state mới, không sửa code player.

## Action trong Input Map bấm để dùng kỹ năng
@export var input_action: StringName
## Tên node state trong StateMachine của player
@export var state: StringName
## Bấm kỹ năng này lúc đang đánh thường thì hủy phần thu đòn để ra chiêu (cùng mốc cancel_start với dash).
## Tắt cho chiêu nặng không nên chen ngang combo
@export var cancels_attack: bool = true


## Thời gian khoá kỹ năng tính từ lúc bấm (ra đòn + hồi chiêu). Lớp con ghi đè theo thông số riêng
func get_lockout() -> float:
	return 0.0
