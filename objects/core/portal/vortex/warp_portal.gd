class_name WarpPortal
extends Node3D
## Cổng xoáy dịch chuyển trong cùng khu (không tải scene): player bước vào thì tối màn, xuất hiện ở Arrival
## của cổng target (SceneManager.warp_player). Cổng hai chiều = hai WarpPortal trỏ target vào nhau.
## Có required_flag thì cổng tắt (xoáy mờ, không dịch chuyển) tới khi GameState có cờ đó (ví dụ đã lắp đá năng lượng).
## Arrival đặt trước mặt cổng (trục +Z cục bộ) ngoài vùng Trigger để tới nơi không bị dịch chuyển ngược.
## Hiệu năng: chỉ nghe body_entered và progress_changed (tới khi có cờ), không có _process.

signal warped(body: Node3D)
signal activated

@export var target: WarpPortal
## Cờ cần có để cổng hoạt động. Trống = luôn bật
@export var required_flag: StringName

var is_open: bool = false

@onready var _trigger: Area3D = $Trigger
@onready var _arrival: Marker3D = $Arrival
@onready var _visual: VortexPortalVisual = $VortexPortalVisual


func _ready() -> void:
	_trigger.body_entered.connect(_on_body_entered)
	if required_flag.is_empty() or GameState.has_flag(required_flag):
		_open(true)
		return
	_visual.set_active(false, true)
	GameState.progress_changed.connect(_on_progress_changed)


func is_active() -> bool:
	return is_open


func get_arrival() -> Marker3D:
	return _arrival


func _on_progress_changed() -> void:
	if GameState.has_flag(required_flag):
		GameState.progress_changed.disconnect(_on_progress_changed)
		_open(false)


func _open(instant: bool) -> void:
	is_open = true
	_visual.set_active(true, instant)
	if not instant:
		activated.emit()


func _on_body_entered(body: Node3D) -> void:
	if not is_open or target == null or not body is Player or SceneManager.is_busy():
		return
	var arrival: Marker3D = target.get_arrival()
	# Quay mặt ra khỏi cổng đích (trục +Z của cổng đích)
	SceneManager.warp_player(body as Player, arrival.global_position, target.global_basis.z)
	warped.emit(body)
