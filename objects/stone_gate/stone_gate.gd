@tool
class_name StoneGate
extends StaticBody3D
## Cổng đá: chìm xuống đất khi TẤT CẢ nguồn kích hoạt gán ở ô Sources đã bật.
## Nguồn là node bất kỳ có signal "activated" và hàm is_active() (ổ đá, sau này thêm loại khác không sửa file này).
## Chỉ nghe đúng các nguồn được gán, nên map có nhiều cổng không ảnh hưởng nhau.
## Mở một lần rồi giữ nguyên; có persistent_id thì nhớ qua lần chơi sau.

signal opened

@export var sources: Array[Node] = []:
	set(value):
		sources = value
		update_configuration_warnings()
## Cờ lưu trạng thái đã mở. Để trống = mỗi lần vào khu cổng lại đóng
@export var persistent_id: StringName
@export_range(0.1, 5.0, 0.05) var open_time: float = 1.2
## Cổng chìm xuống bấy nhiêu mét (thường bằng chiều cao cổng)
@export var sink_depth: float = 3.2
@export_range(0.0, 1.0) var open_trauma: float = 0.2

var is_open: bool = false

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		_finish_open(true)
		return
	for source in sources:
		if source == null or not source.has_signal(&"activated") or not source.has_method(&"is_active"):
			push_error("%s: nguồn %s không có signal activated / hàm is_active()" % [get_path(), source])
			continue
		source.connect(&"activated", _refresh)
	_refresh()


func _get_configuration_warnings() -> PackedStringArray:
	if sources.is_empty():
		return ["Chưa gán nguồn ở ô Sources: cổng sẽ không bao giờ mở."]
	return []


func _refresh() -> void:
	if is_open or sources.is_empty():
		return
	for source in sources:
		if source == null or not source.call(&"is_active"):
			return
	is_open = true
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	if open_trauma > 0.0:
		ScreenShake.add_trauma(open_trauma)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_visual, "position:y", _visual.position.y - sink_depth, open_time)
	tween.finished.connect(_finish_open.bind(false))
	# Mở lối ngay khi bắt đầu chìm: không bắt người chơi đứng chờ hết animation
	_collision.set_deferred(&"disabled", true)
	opened.emit()


func _finish_open(instant: bool) -> void:
	is_open = true
	_collision.set_deferred(&"disabled", true)
	if instant:
		_visual.position.y -= sink_depth
	_visual.visible = false
