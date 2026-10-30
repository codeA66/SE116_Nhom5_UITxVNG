class_name CrumblingFloorState
extends State
## State của ô sàn sụp: có sẵn tham chiếu floor và tên các state.

const SOLID := &"Solid"
const CRACKING := &"Cracking"
const FALLEN := &"Fallen"

var floor_tile: CrumblingFloor


func _ready() -> void:
	floor_tile = owner as CrumblingFloor
	assert(floor_tile != null, "CrumblingFloorState phải nằm trong scene CrumblingFloor")


## Có người bước lên ô
func on_stepped() -> void:
	pass
