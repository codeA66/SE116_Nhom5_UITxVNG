class_name BoulderSocket
extends Area3D
## Ổ đá: đá trượt gió (WindBoulder) đi qua đủ gần tâm ổ thì bị bắt vào và khoá lại, ổ bật sáng.
## Là "nguồn kích hoạt" cho cổng đá: có signal activated và hàm is_active().
## Chỉ xử lý mỗi frame khi có đá nằm trong vùng ổ (bật/tắt bằng signal vào/ra).

signal activated
signal deactivated

## Đá cách tâm ổ (theo phương ngang) không quá bấy nhiêu mét thì bị bắt
@export_range(0.05, 2.0, 0.05) var catch_radius: float = 0.35
@export var lit_color: Color = Color(0.45, 0.95, 1.0)
@export_group("Pressure Plate")
@export var pressure_mode: bool = false
@export_range(0.2, 4.0, 0.05) var pressure_radius: float = 1.2
@export_range(0.02, 0.3, 0.01) var contact_tolerance: float = 0.12
@export var released_color: Color = Color("e64b50")
@export_range(0.0, 4.0, 0.1) var glow_energy: float = 1.2
@export_range(0.0, 3.0, 0.1) var press_flash: float = 0.8
@export_range(0.05, 1.0, 0.05) var flash_time: float = 0.2

var _active: bool = false
var _candidates: Array[WindBoulder] = []
var _occupants: Array[Node3D] = []
var _settled_stones: Array[WindBoulder] = []
var _pressure_material: StandardMaterial3D
var _flash: Tween

@onready var _glow: MeshInstance3D = $Glow


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_glow.visible = false
	set_physics_process(false)
	if pressure_mode:
		collision_mask = 3 # World (đá) và Player; lọc kiểu body bên dưới.
		var sensor: CollisionShape3D = $CollisionShape3D
		var shape: CylinderShape3D = CylinderShape3D.new()
		shape.radius = pressure_radius
		shape.height = contact_tolerance * 2.0
		sensor.shape = shape
		sensor.position.y = contact_tolerance * 0.5
		_pressure_material = StandardMaterial3D.new()
		_pressure_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_pressure_material.emission_enabled = true
		_glow.material_override = _pressure_material
		_glow.visible = true
		_show_pressure(false)


func is_active() -> bool:
	return _active


func _physics_process(_delta: float) -> void:
	if pressure_mode:
		_refresh_pressure()
		return
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
	if pressure_mode:
		if (body is Player or body is WindBoulder) and not _occupants.has(body):
			_occupants.append(body)
			if body is WindBoulder and (body as WindBoulder).state_machine.current_state.name != WindBoulderState.SLIDING:
				_settled_stones.append(body as WindBoulder)
			body.tree_exiting.connect(_remove_occupant.bind(body), CONNECT_ONE_SHOT)
			set_physics_process(true)
			_refresh_pressure()
		return
	if _active or not body is WindBoulder:
		return
	_candidates.append(body as WindBoulder)
	set_physics_process(true)


func _on_body_exited(body: Node3D) -> void:
	if pressure_mode:
		_remove_occupant(body)
		return
	# Vùng ổ cũng chạm sàn/tường (layer world): chỉ xử lý đá, mảng có kiểu không nhận vật khác
	if not body is WindBoulder:
		return
	_candidates.erase(body as WindBoulder)
	if _candidates.is_empty():
		set_physics_process(false)


func _remove_occupant(body: Node3D) -> void:
	_occupants.erase(body)
	if body is WindBoulder:
		_settled_stones.erase(body as WindBoulder)
	var callback: Callable = _remove_occupant.bind(body)
	if body.tree_exiting.is_connected(callback):
		body.tree_exiting.disconnect(callback)
	_refresh_pressure()
	set_physics_process(not _occupants.is_empty())


func _refresh_pressure() -> void:
	var pressed: bool = false
	for body in _occupants:
		if not is_instance_valid(body) or body.is_queued_for_deletion():
			continue
		var feet: Vector3 = to_local(body.global_position)
		if absf(feet.y) > contact_tolerance or Vector2(feet.x, feet.z).length() > pressure_radius:
			continue
		if body is Player and (not (body as Player).is_on_floor() or (body as Player).velocity.y > 0.1):
			continue
		if body is WindBoulder:
			_settle_pressure_stone(body as WindBoulder, feet)
		pressed = true
	if pressed == _active:
		return
	_active = pressed
	_show_pressure(pressed)
	if pressed:
		activated.emit()
	else:
		deactivated.emit()


func _settle_pressure_stone(boulder: WindBoulder, feet: Vector3) -> void:
	# Dừng một lần mỗi lượt vào tâm; đá vẫn nhận cú thổi tiếp theo để rời bàn đạp.
	if _settled_stones.has(boulder) or Vector2(feet.x, feet.z).length() > minf(catch_radius, pressure_radius):
		return
	_settled_stones.append(boulder)
	if boulder.state_machine.current_state.name == WindBoulderState.SLIDING:
		boulder.target = boulder.global_position
		boulder.notify_slide_stopped()
		boulder.state_machine.transition_to(WindBoulderState.IDLE)


func _show_pressure(pressed: bool) -> void:
	if _flash:
		_flash.kill()
	var color: Color = lit_color if pressed else released_color
	_pressure_material.albedo_color = color
	_pressure_material.emission = color
	_pressure_material.emission_energy_multiplier = glow_energy + (press_flash if pressed else 0.0)
	if pressed:
		_flash = create_tween()
		_flash.tween_property(_pressure_material, "emission_energy_multiplier", glow_energy, flash_time)
