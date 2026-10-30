class_name SkyFerryState
extends State
## State của thuyền bay: có sẵn tham chiếu ferry và tên các state.

const AWAY := &"Away"
const APPROACHING := &"Approaching"
const WAITING := &"Waiting"
const TRAVELLING := &"Travelling"
const ARRIVED := &"Arrived"

var ferry: SkyFerry


func _ready() -> void:
	ferry = owner as SkyFerry
	assert(ferry != null, "SkyFerryState phải nằm trong scene SkyFerry")


## Cơ quan gọi vừa bật. State tự quyết định có phản ứng hay không
func on_called() -> void:
	pass
