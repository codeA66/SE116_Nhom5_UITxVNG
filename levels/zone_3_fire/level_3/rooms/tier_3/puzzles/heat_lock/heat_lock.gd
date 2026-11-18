class_name HeatLock
extends Area3D
## Khóa chỉ xử lý khi đang nhận tia; ngắt tia phải nung lại từ đầu.

signal activated
signal deactivated
signal melted
signal heat_changed(ratio: float)

@export var show_lock_mesh: bool = false:
	set(value):
		show_lock_mesh = value
		if is_node_ready():
			_show_state()
			_show_heat(get_heat_ratio())

var _data: LiPuzzleData
var _flag: StringName
var _active: bool = false
var _enabled: bool = true
var _illuminated: bool = false
var _heat: float = 0.0
var _material: StandardMaterial3D

@onready var _ore: MeshInstance3D = $Ore
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _glow: OmniLight3D = $Glow


func _ready() -> void:
	set_physics_process(false)
	_show_state()


func _physics_process(delta: float) -> void:
	_heat += delta
	var ratio: float = clampf(_heat / maxf(_data.melt_time, 0.01), 0.0, 1.0)
	_show_heat(ratio)
	if ratio < 1.0:
		return
	_active = true
	set_physics_process(false)
	_show_state()
	if not _flag.is_empty():
		GameState.set_flag(_flag)
	activated.emit()
	melted.emit()


func configure(data: LiPuzzleData, persistent_flag: StringName) -> void:
	_data = data
	_flag = persistent_flag
	GameState.progress_replaced.connect(_restore)
	_restore()


func is_active() -> bool:
	return _active


func get_heat_ratio() -> float:
	return clampf(_heat / maxf(_data.melt_time, 0.01), 0.0, 1.0) if _data else 0.0


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		set_illuminated(false)


func set_illuminated(illuminated: bool) -> void:
	var receiving: bool = illuminated and _enabled and not _active and _data != null
	if receiving == _illuminated:
		return
	_illuminated = receiving
	set_physics_process(receiving)
	if not receiving:
		_heat = 0.0
		_show_heat(0.0)


func _restore() -> void:
	var was_active: bool = _active
	_active = not _flag.is_empty() and GameState.has_flag(_flag)
	_illuminated = false
	_heat = 0.0
	set_physics_process(false)
	_show_state()
	_show_heat(0.0)
	if _active != was_active:
		if _active:
			activated.emit()
		else:
			deactivated.emit()


func _show_state() -> void:
	_ore.visible = show_lock_mesh and not _active
	if show_lock_mesh and _material == null:
		_material = _ore.get_active_material(0).duplicate() as StandardMaterial3D
		_ore.material_override = _material
	_shape.set_deferred(&"disabled", _active)
	_glow.visible = not _active


func _show_heat(ratio: float) -> void:
	if _data == null:
		return
	if _material != null:
		_material.albedo_color = _data.cold_color.lerp(_data.hot_color, ratio)
		_material.emission_enabled = ratio > 0.0
		_material.emission = _data.hot_color
		_material.emission_energy_multiplier = ratio * _data.heat_emission
	_glow.light_energy = ratio * _data.heat_emission
	heat_changed.emit(ratio)
