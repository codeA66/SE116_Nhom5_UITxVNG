extends RubbleJamState
## Đá đã văng hết: ẩn mảnh, tắt xử lý mỗi frame.


func enter(_previous: StringName) -> void:
	jam.pieces.visible = false
	jam.set_process(false)
