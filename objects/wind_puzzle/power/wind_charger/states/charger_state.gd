class_name ChargerState
extends State
## State của trụ quạt: có sẵn tham chiếu charger và tên các state.

const IDLE := &"Idle"
const CHARGING := &"Charging"
const FULL := &"Full"
const DRAINING := &"Draining"

var charger: WindCharger


func _ready() -> void:
	charger = owner as WindCharger
	assert(charger != null, "ChargerState phải nằm trong scene WindCharger")


## Cánh quạt bị Wind Blast thổi trúng. State tự quyết định có phản ứng hay không
func on_blown() -> void:
	pass
