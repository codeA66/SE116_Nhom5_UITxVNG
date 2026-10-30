class_name BoatState
extends State
## State của thuyền: có sẵn tham chiếu boat và tên các state.

const DOCKED := &"Docked"
const SAILING := &"Sailing"
const DRIFTING := &"Drifting"
const ARRIVED := &"Arrived"

var boat: Boat


func _ready() -> void:
	boat = owner as Boat
	assert(boat != null, "BoatState phải nằm trong scene Boat")


## Thuyền bị cú thổi trúng từ phía sau buồm. State tự quyết định có phản ứng hay không
func on_tailwind(_from_on_board: bool) -> void:
	pass
