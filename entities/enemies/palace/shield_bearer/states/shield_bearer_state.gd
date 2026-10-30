class_name ShieldBearerState
extends EnemyState
## Lớp cơ sở cho state của Hộ Vệ Khiên: có sẵn tham chiếu bearer (đã ép kiểu) và tên state riêng.

const SHIELD_ADVANCE := &"ShieldAdvance"
const SHIELD_BLOCK := &"ShieldBlock"
const SHIELD_SLAM := &"ShieldSlam"

## Tên clip animation riêng
const ANIM_GUARD_BLOCK := &"GuardBlock"

var bearer: ShieldBearer


func _ready() -> void:
	super()
	bearer = enemy as ShieldBearer
	assert(bearer != null, "ShieldBearerState phải nằm trong scene ShieldBearer")


## Về đuổi nếu còn mục tiêu, không thì đứng chờ
func _leave_to_default() -> void:
	state_machine.transition_to(enemy.chase_state if enemy.has_target() else IDLE)
