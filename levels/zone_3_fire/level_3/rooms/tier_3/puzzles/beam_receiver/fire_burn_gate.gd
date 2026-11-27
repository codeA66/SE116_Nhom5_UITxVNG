class_name FireBurnGate
extends StaticBody3D
## Cửa phong ấn mở bằng cách cháy lan tỏa tròn từ ký hiệu lửa cho đến khi tiêu hủy hết.
## Giữ cùng interface (opened, closed, height_changed) để thay thế StoneGate ở các cửa lửa.

signal opened
signal closed
signal height_changed

const BURN_SHADER: Shader = preload("res://assets/shaders/fire/door_burn_dissolve.gdshader")
const MIN_DURATION: float = 0.01

@export var sources: Array[Node] = []
@export var burn_plate: MeshInstance3D
@export var beam_surface: Area3D
@export var flame_symbols: Array[Node3D] = []
@export_range(0.05, 10.0, 0.05) var open_time: float = 2.4
@export_range(0.05, 10.0, 0.05) var retract_time: float = 0.6
@export_range(0.0, 1.0, 0.01) var open_trauma: float = 0.14

@export_group("Hiệu ứng cháy")
@export var burn_origin: Vector2 = Vector2(0.0, 0.05)
@export_range(0.5, 10.0, 0.05) var max_radius: float = 2.95
@export_range(0.02, 0.5, 0.01) var edge_width: float = 0.16
@export_range(0.0, 0.35, 0.01) var noise_strength: float = 0.11
@export_range(0.05, 1.0, 0.05) var symbol_fade_threshold: float = 0.35
## Ngưỡng tiến độ cháy mà tâm cửa vừa thủng lỗ để tia sáng đâm xuyên qua (~0.1–0.15 s với open_time = 2.4 s).
@export_range(0.01, 1.0, 0.01) var beam_pierce_threshold: float = 0.08
@export var base_color: Color = Color(0.5, 0.25, 0.085, 1.0)
@export_range(0.0, 8.0, 0.1) var emission_energy: float = 3.2

var is_open: bool = false

var _burn_progress: float = 0.0
var _desired_open: bool = false
var _sealed: bool = false
var _beam_pierced: bool = false
var _burn_tween: Tween
var _material: ShaderMaterial

@onready var _collision: CollisionShape3D = get_node_or_null(^"CollisionShape3D") as CollisionShape3D
@onready var _beam_surface_shape: CollisionShape3D = _resolve_beam_surface_shape()


func _ready() -> void:
	_setup_material()
	for source: Node in sources:
		if source == null or not source.has_signal(&"activated") or not source.has_method(&"is_active"):
			push_error("%s: nguồn %s không có signal activated / hàm is_active()" % [get_path(), source])
			continue
		source.connect(&"activated", _on_source_changed)
		if source.has_signal(&"deactivated"):
			source.connect(&"deactivated", _on_source_changed)
	_refresh(true)


func get_burn_progress() -> float:
	return _burn_progress


func is_gate_open() -> bool:
	return is_open


## Niêm phong cứng cửa (khi thay bằng tường gạch), chặn mọi kích hoạt làm hiện lại mặt cửa hay icon lửa.
func set_sealed(sealed: bool) -> void:
	if _sealed == sealed:
		return
	_sealed = sealed
	_kill_tween()
	if sealed:
		is_open = false
		_desired_open = false
		_beam_pierced = false
		_set_burn_progress(0.0)
		_set_collisions_disabled(false, true)
		if burn_plate != null:
			burn_plate.visible = false
		_set_symbols_visible(false)
	else:
		_refresh(true)


func _resolve_beam_surface_shape() -> CollisionShape3D:
	var area: Area3D = beam_surface
	if area == null:
		area = get_node_or_null(^"Visual/BeamSurface") as Area3D
	if area == null:
		return null
	return area.get_node_or_null(^"CollisionShape3D") as CollisionShape3D


func _setup_material() -> void:
	if burn_plate == null:
		return
	# Mỗi cánh cửa giữ tiến độ cháy riêng nên dùng ShaderMaterial riêng.
	_material = ShaderMaterial.new()
	_material.shader = BURN_SHADER
	_material.set_shader_parameter(&"burn_origin", burn_origin)
	_material.set_shader_parameter(&"max_radius", max_radius)
	_material.set_shader_parameter(&"edge_width", edge_width)
	_material.set_shader_parameter(&"noise_strength", noise_strength)
	_material.set_shader_parameter(&"base_color", base_color)
	_material.set_shader_parameter(&"emission_energy", emission_energy)
	_material.set_shader_parameter(&"burn_progress", 0.0)
	burn_plate.material_override = _material


func _on_source_changed() -> void:
	_refresh(false)


func _refresh(instant: bool) -> void:
	if _sealed:
		return
	var pressed: bool = _are_sources_active()
	if pressed == _desired_open and not instant:
		return
	_desired_open = pressed
	_kill_tween()

	if pressed:
		_start_burn(instant)
	else:
		_retract_or_close(instant)


func _are_sources_active() -> bool:
	if sources.is_empty():
		return false
	for source: Node in sources:
		if not is_instance_valid(source) or not source.has_method(&"is_active") or not bool(source.call(&"is_active")):
			return false
	return true


func _start_burn(instant: bool) -> void:
	if burn_plate != null:
		burn_plate.visible = true
	if instant or open_time <= MIN_DURATION:
		_finish_burn()
		return
	if is_inside_tree() and open_trauma > 0.0:
		ScreenShake.add_trauma(open_trauma)
	var duration: float = maxf(open_time * (1.0 - _burn_progress), MIN_DURATION)
	_burn_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_burn_tween.tween_method(_set_burn_progress, _burn_progress, 1.0, duration)
	_burn_tween.finished.connect(_finish_burn)


func _finish_burn() -> void:
	_set_burn_progress(1.0)
	if burn_plate != null:
		burn_plate.visible = false
	_set_symbols_visible(false)
	_set_collisions_disabled(true, true)
	if not is_open:
		is_open = true
		opened.emit()
		call_deferred(&"_emit_height_changed")


func _retract_or_close(instant: bool) -> void:
	if _sealed:
		return
	_beam_pierced = false
	_set_collisions_disabled(false, false)
	if is_open:
		is_open = false
		_set_burn_progress(0.0)
		if burn_plate != null:
			burn_plate.visible = true
		_set_symbols_visible(true)
		closed.emit()
		call_deferred(&"_emit_height_changed")
		return
	if instant or _burn_progress <= 0.001 or retract_time <= MIN_DURATION:
		_finish_retract()
		return
	var duration: float = maxf(retract_time * _burn_progress, MIN_DURATION)
	_burn_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_burn_tween.tween_method(_set_burn_progress, _burn_progress, 0.0, duration)
	_burn_tween.finished.connect(_finish_retract)


func _finish_retract() -> void:
	if _sealed:
		return
	_beam_pierced = false
	_set_burn_progress(0.0)
	if burn_plate != null:
		burn_plate.visible = true
	_set_symbols_visible(true)


func _set_burn_progress(value: float) -> void:
	_burn_progress = clampf(value, 0.0, 1.0)
	if _material != null:
		_material.set_shader_parameter(&"burn_progress", _burn_progress)
	if not _sealed and not _beam_pierced and _desired_open and _burn_progress >= beam_pierce_threshold:
		_beam_pierced = true
		for source: Node in sources:
			if is_instance_valid(source) and source.has_method(&"force_latch"):
				source.call(&"force_latch")
		_set_collisions_disabled(true, true)
		call_deferred(&"_emit_height_changed")
	if _sealed:
		_set_symbols_visible(false)
	elif _burn_progress >= symbol_fade_threshold:
		_set_symbols_visible(false)
	elif not is_open:
		_set_symbols_visible(true)


func _set_collisions_disabled(body_disabled: bool, beam_surface_disabled: bool) -> void:
	if _collision != null:
		_collision.set_deferred(&"disabled", body_disabled)
	if _beam_surface_shape != null:
		_beam_surface_shape.set_deferred(&"disabled", beam_surface_disabled)


func _emit_height_changed() -> void:
	if is_inside_tree():
		height_changed.emit()


func _set_symbols_visible(shown: bool) -> void:
	for symbol: Node3D in flame_symbols:
		if is_instance_valid(symbol):
			symbol.visible = shown


func _kill_tween() -> void:
	if _burn_tween != null and _burn_tween.is_valid():
		_burn_tween.kill()
	_burn_tween = null
