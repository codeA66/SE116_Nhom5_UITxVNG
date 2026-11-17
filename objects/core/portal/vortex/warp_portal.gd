class_name WarpPortal
extends Node3D
## Cổng xoáy dịch chuyển trong cùng khu (không tải scene): player bước vào thì tối màn, xuất hiện ở Arrival
## của cổng target (SceneManager.warp_player). Cổng hai chiều = hai WarpPortal trỏ target vào nhau.
## Có required_flag thì cổng tắt (xoáy mờ, không dịch chuyển) tới khi GameState có cờ đó (ví dụ đã lắp đá năng lượng).
## Arrival đặt trước mặt cổng (trục +Z cục bộ) ngoài vùng Trigger để tới nơi không bị dịch chuyển ngược.
## Hình cổng: node bất kỳ có set_active(value, instant) (xoáy, đĩa dịch chuyển...); không có hình thì chỉ là điểm đáp.
## Hiệu năng: chỉ nghe body_entered và progress_changed (tới khi có cờ), không có _process.

signal warped(body: Node3D)
signal activated

@export var target: WarpPortal
## Cờ cần có để cổng hoạt động. Trống = luôn bật
@export var required_flag: StringName
## Cờ cần có thêm (tất cả phải có, cùng required_flag), ví dụ phá đủ nhiều lồng / tượng trong một phòng
@export var extra_flags: Array[StringName] = []
## Hình cổng (cần hàm set_active(value: bool, instant: bool)). Trống = node con VortexPortalVisual nếu có
@export var visual: Node3D

var is_open: bool = false

@onready var _trigger: Area3D = $Trigger
@onready var _arrival: Marker3D = $Arrival
@onready var _visual: Node3D = visual if visual else get_node_or_null(^"VortexPortalVisual") as Node3D


func _ready() -> void:
	_trigger.body_entered.connect(_on_body_entered)
	if _flags_met():
		_open(true)
		return
	_set_visual(false, true)
	GameState.progress_changed.connect(_on_progress_changed)


func is_active() -> bool:
	return is_open


func get_arrival() -> Marker3D:
	return _arrival


func _on_progress_changed() -> void:
	if _flags_met():
		GameState.progress_changed.disconnect(_on_progress_changed)
		_open(false)


func _flags_met() -> bool:
	if not required_flag.is_empty() and not GameState.has_flag(required_flag):
		return false
	for extra: StringName in extra_flags:
		if not GameState.has_flag(extra):
			return false
	return true


func _open(instant: bool) -> void:
	is_open = true
	_set_visual(true, instant)
	if not instant:
		activated.emit()


func _on_body_entered(body: Node3D) -> void:
	if not is_open or target == null or not body is Player or SceneManager.is_busy():
		return
	var arrival: Marker3D = target.get_arrival()
	# Quay mặt ra khỏi cổng đích (trục +Z của cổng đích)
	SceneManager.warp_player(body as Player, arrival.global_position, target.global_basis.z)
	warped.emit(body)


func _set_visual(value: bool, instant: bool) -> void:
	if _visual != null and _visual.has_method(&"set_active"):
		_visual.call(&"set_active", value, instant)
