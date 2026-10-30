class_name WindLiftState
extends State
## State của bệ nâng: có sẵn tham chiếu lift và tên các state.

const LOWERED := &"Lowered"
const RISING := &"Rising"
const RAISED := &"Raised"
const FALLING := &"Falling"

var lift: WindLift


func _ready() -> void:
	lift = owner as WindLift
	assert(lift != null, "WindLiftState phải nằm trong scene WindLift")


## Trụ quạt vừa sáng đủ đèn
func on_charger_full() -> void:
	pass


## Đèn cuối của trụ quạt vừa tắt
func on_charger_discharged() -> void:
	pass
