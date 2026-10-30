class_name WindBoulderState
extends State
## State của đá trượt gió: có sẵn tham chiếu boulder và tên các state.

const IDLE := &"Idle"
const SLIDING := &"Sliding"
const SEATED := &"Seated"

var boulder: WindBoulder


func _ready() -> void:
	boulder = owner as WindBoulder
	assert(boulder != null, "WindBoulderState phải nằm trong scene WindBoulder")


## Bị thổi theo hướng chính dir (có thể là 0 nếu thổi thẳng đứng)
func on_blown(_dir: Vector3) -> void:
	pass


## Ổ đá gọi khi đá dừng đúng chỗ: khoá đá vào tâm ổ
func on_seated(_socket_position: Vector3) -> void:
	pass
