class_name BoulderSocket
extends Area3D
## Ổ đá: đá trượt gió (WindBoulder) đi qua đủ gần tâm ổ thì bị bắt vào và khoá lại, ổ bật sáng.
## Là "nguồn kích hoạt" cho cổng đá: có signal activated và hàm is_active().
## Chỉ xử lý mỗi frame khi có đá nằm trong vùng ổ (bật/tắt bằng signal vào/ra).

signal activated

## Đá cách tâm ổ (theo phương ngang) không quá bấy nhiêu mét thì bị bắt
@export_range(0.05, 2.0, 0.05) var catch_radius: float = 0.35
@export var lit_color: Color = Color(0.45, 0.95, 1.0)

var _active: bool = false
var _candidates: Array[WindBoulder] = []

@onready var _glow: MeshInstance3D = $Glow


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_glow.visible = false
	set_physics_process(false)


func is_active() -> bool:
	return _active


func _physics_process(_delta: float) -> void:
	for boulder in _candidates:
		var offset := boulder.global_position - global_position
		offset.y = 0.0
		if offset.length() <= catch_radius:
			_catch(boulder)
			return


func _catch(boulder: WindBoulder) -> void:
	(boulder.state_machine.current_state as WindBoulderState).on_seated(global_position)
	_active = true
	_candidates.clear()
	set_physics_process(false)
	set_deferred(&"monitoring", false)
	_glow.visible = true
	activated.emit()


func _on_body_entered(body: Node3D) -> void:
	if _active or not body is WindBoulder:
		return
	_candidates.append(body as WindBoulder)
	set_physics_process(true)


func _on_body_exited(body: Node3D) -> void:
	# Vùng ổ cũng chạm sàn/tường (layer world): chỉ xử lý đá, mảng có kiểu không nhận vật khác
	if not body is WindBoulder:
		return
	_candidates.erase(body as WindBoulder)
	if _candidates.is_empty():
		set_physics_process(false)
