class_name FlagSource
extends Node
## Nguồn kích hoạt theo cờ tiến trình: bật khi GameState có cờ flag (ví dụ trận đánh xong, boss chết).
## Có signal activated + is_active() nên gán được vào ô Sources của cổng (StoneGate...) hay PowerConduit,
## để cửa mở theo một sự kiện bất kỳ mà không phải sửa code cổng.

signal activated

## Cờ cần có, ví dụ persistent_id của một Encounter
@export var flag: StringName

var _active: bool = false


func _ready() -> void:
	if flag.is_empty():
		push_error("%s chưa đặt cờ, nguồn không bao giờ bật" % get_path())
		return
	if GameState.has_flag(flag):
		_active = true
		return
	GameState.progress_changed.connect(_on_progress_changed)


func is_active() -> bool:
	return _active


func _on_progress_changed() -> void:
	if _active or not GameState.has_flag(flag):
		return
	_active = true
	GameState.progress_changed.disconnect(_on_progress_changed)
	activated.emit()
