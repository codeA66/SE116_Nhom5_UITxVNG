class_name ProgressWatcher
extends Node
## Báo khi tiến trình người chơi đổi (nhặt chìa, phá khu, nạp save khác). Cổng / dấu / cửa nghe signal này
## thay vì kiểm tra mỗi frame. Chỉ nối GameState khi đang trong cây: scene cũ rời cây lúc đổi khu thì ngắt ngay.

signal changed


func _enter_tree() -> void:
	if not GameState.progress_changed.is_connected(_emit_changed):
		GameState.progress_changed.connect(_emit_changed)
	if not GameState.progress_replaced.is_connected(_emit_changed):
		GameState.progress_replaced.connect(_emit_changed)


func _exit_tree() -> void:
	if GameState.progress_changed.is_connected(_emit_changed):
		GameState.progress_changed.disconnect(_emit_changed)
	if GameState.progress_replaced.is_connected(_emit_changed):
		GameState.progress_replaced.disconnect(_emit_changed)


func _emit_changed() -> void:
	changed.emit()
