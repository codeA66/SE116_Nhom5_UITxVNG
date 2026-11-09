class_name FlagReveal
extends Node3D
## Giấu các node con (vật phẩm, rương, sách kỹ năng...) cho tới khi GameState có cờ flag (và mọi extra_flags) thì mới đưa vào cây.
## Lúc giấu, con được gỡ khỏi cây: không vẽ, không va chạm, không xử lý.
## Hiệu năng: nghe GameState.progress_changed tới khi có cờ rồi ngắt, không có _process.

signal revealed

@export var flag: StringName
## Cờ cần có thêm (tất cả phải có, cùng với flag), ví dụ dọn xong nhiều lồng trong một phòng
@export var extra_flags: Array[StringName] = []

var _hidden: Array[Node] = []


func _ready() -> void:
	if is_revealed():
		return
	for child: Node in get_children():
		_hidden.append(child)
		remove_child(child)
	GameState.progress_changed.connect(_on_progress_changed)


func _exit_tree() -> void:
	# Con chưa kịp hiện không có cha: tự giải phóng để không rò bộ nhớ
	for child: Node in _hidden:
		if is_instance_valid(child) and child.get_parent() == null:
			child.free()
	_hidden.clear()


func is_revealed() -> bool:
	if not flag.is_empty() and not GameState.has_flag(flag):
		return false
	for extra: StringName in extra_flags:
		if not GameState.has_flag(extra):
			return false
	return true


func _on_progress_changed() -> void:
	if not is_revealed():
		return
	GameState.progress_changed.disconnect(_on_progress_changed)
	for child: Node in _hidden:
		if is_instance_valid(child):
			add_child(child)
	_hidden.clear()
	revealed.emit()
