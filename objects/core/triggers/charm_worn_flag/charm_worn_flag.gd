class_name CharmWornFlag
extends Node
## Bật cờ flag ngay lần đầu player đeo bùa charm_id; bật rồi giữ luôn (tháo bùa không tắt).
## Dùng với FlagReveal để mở cổng / lối đi "khi đeo đúng bùa". Mỗi cặp bùa + cờ một node, không phát tin chung.
## Hiệu năng: chỉ nghe GameState.charms_changed tới khi bật cờ rồi ngắt, không có _process.

## Vừa bật cờ (lần đầu đeo bùa)
signal triggered

@export var charm_id: StringName
@export var flag: StringName


func _ready() -> void:
	if charm_id.is_empty() or flag.is_empty():
		push_error("%s: chưa gán charm_id / flag" % get_path())
		return
	if GameState.has_flag(flag):
		return
	GameState.charms_changed.connect(_on_charms_changed)
	_on_charms_changed()


func _on_charms_changed() -> void:
	if not GameState.is_charm_equipped(charm_id):
		return
	GameState.charms_changed.disconnect(_on_charms_changed)
	GameState.set_flag(flag)
	triggered.emit()
