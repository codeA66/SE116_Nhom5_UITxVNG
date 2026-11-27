class_name ArenaGate
extends Node3D
## Song sắt ở cửa phòng đánh: mở sẵn; trận bắt đầu (hoặc sắp chiếu cắt cảnh mở màn) thì sập xuống chặn lối,
## thắng trận thì kéo lên lại. Nghe signal của encounter được gán (BossFight, Encounter...), không kiểm tra mỗi frame.
## Encounter đã thắng từ trước (is_active() đúng) thì mở luôn. Nhiều cổng trong một map: mỗi cổng gán encounter riêng.

signal closed
signal opened

## Trận điều khiển cổng: cần các signal trong close_signals / open_signal; có is_active() thì đọc trạng thái đã thắng
@export var encounter: Node
## Phát một trong các signal này thì sập (signal có tham số vẫn được)
@export var close_signals: Array[StringName] = [&"intro_requested", &"started"]
@export var open_signal: StringName = &"defeated"
## Song kéo lên cao bấy nhiêu mét khi mở
@export var open_height: float = 4.6
@export_range(0.05, 3.0, 0.05) var close_time: float = 0.35
@export_range(0.05, 3.0, 0.05) var open_time: float = 1.2
@export_range(0.0, 1.0, 0.01) var close_trauma: float = 0.25

var _closed: bool = false
var _door: Node3D
var _door_closed_y: float = 0.0
var _tween: Tween

@onready var _door_shape: CollisionShape3D = $DoorBody/CollisionShape3D


func _ready() -> void:
	_door = find_child("Door", true, false) as Node3D
	if _door:
		_door_closed_y = _door.position.y
	_set_door(false, true)
	if encounter == null:
		push_error("%s: chưa gán encounter" % get_path())
		return
	if encounter.has_method(&"is_active") and encounter.call(&"is_active"):
		return
	for signal_name: StringName in close_signals:
		_listen(signal_name, close)
	_listen(open_signal, open)


func is_closed() -> bool:
	return _closed


func close() -> void:
	if _closed:
		return
	_set_door(true, false)
	if close_trauma > 0.0:
		ScreenShake.add_trauma(close_trauma)
	closed.emit()


func open() -> void:
	if not _closed:
		return
	_set_door(false, false)
	opened.emit()


func _set_door(shut: bool, instant: bool) -> void:
	_closed = shut
	_door_shape.set_deferred(&"disabled", not shut)
	if _door == null:
		return
	var target_y := _door_closed_y if shut else _door_closed_y + open_height
	if _tween:
		_tween.kill()
	if instant:
		_door.position.y = target_y
		return
	_tween = create_tween()
	_tween.tween_property(_door, ^"position:y", target_y, close_time if shut else open_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN if shut else Tween.EASE_OUT)


## Nối signal bất kể số tham số: bỏ tham số rồi gọi action
func _listen(signal_name: StringName, action: Callable) -> void:
	if signal_name.is_empty():
		return
	if not encounter.has_signal(signal_name):
		push_error("%s: encounter không có signal '%s'" % [get_path(), signal_name])
		return
	for info: Dictionary in encounter.get_signal_list():
		if info.name == signal_name:
			var arg_count: int = (info.args as Array).size()
			encounter.connect(signal_name, action.unbind(arg_count) if arg_count > 0 else action)
			return
