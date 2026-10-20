class_name RubbleJamState
extends State
## State của đống đá vụn: có sẵn tham chiếu jam và tên các state.

const JAMMED := &"Jammed"
const BURSTING := &"Bursting"
const CLEARED := &"Cleared"

var jam: RubbleJam


func _ready() -> void:
	jam = owner as RubbleJam
	assert(jam != null, "RubbleJamState phải nằm trong scene RubbleJam")


## Tất cả nguồn đã bật
func on_unlocked() -> void:
	pass
