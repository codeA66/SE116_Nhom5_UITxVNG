class_name VaneBridgeState
extends State
## State của cầu chong chóng: có sẵn tham chiếu bridge và tên các state.

const IDLE := &"Idle"
const TURNING := &"Turning"

var bridge: VaneBridge


func _ready() -> void:
	bridge = owner as VaneBridge
	assert(bridge != null, "VaneBridgeState phải nằm trong scene VaneBridge")


## Chong chóng bị Wind Blast thổi trúng
func on_blown() -> void:
	pass
