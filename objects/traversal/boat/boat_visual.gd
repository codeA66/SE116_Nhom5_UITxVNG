@tool
class_name BoatVisual
extends Node3D
## Chỉ điều khiển hình ảnh; tuyến chạy và vận tốc vẫn do Boat quản lý.

const SAIL_SHADER: Shader = preload("res://assets/shaders/environment/props/boat_sail.gdshader")

@export_range(0.0, 0.2) var flutter_amplitude: float = 0.045
@export_range(0.1, 12.0) var flutter_speed: float = 3.0
@export_range(0.01, 0.3) var furled_ratio: float = 0.06
@export var sail_top: float = 3.458
@export var sail_bottom: float = 1.248

var deployment: float = 1.0
var _materials: Array[ShaderMaterial] = []
var _deployment_tween: Tween
var _gust_tween: Tween

@onready var _cloth: MeshInstance3D = $Model/Game_Sail
@onready var _yards: MeshInstance3D = $Model/Game_Yards


func _ready() -> void:
	_prepare_materials(_cloth, false)
	_prepare_materials(_yards, true)
	set_deployment(1.0 if Engine.is_editor_hint() else 0.0)
	set_process(false)
	set_physics_process(false)


func set_deployment(value: float) -> void:
	deployment = clampf(value, 0.0, 1.0)
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"deployment", deployment)


func animate_deployment(target: float, duration: float) -> void:
	if _deployment_tween:
		_deployment_tween.kill()
	if duration <= 0.0:
		set_deployment(target)
		return
	_deployment_tween = create_tween()
	_deployment_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_deployment_tween.tween_method(set_deployment, deployment, target, duration)


func flutter(duration: float, strength: float) -> void:
	if _gust_tween:
		_gust_tween.kill()
	_set_gust(clampf(strength, 0.0, 1.0))
	if duration <= 0.0:
		_set_gust(0.0)
		return
	_gust_tween = create_tween()
	_gust_tween.tween_method(_set_gust, clampf(strength, 0.0, 1.0), 0.0, duration)


func _set_gust(value: float) -> void:
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"gust", value)


func _prepare_materials(mesh_instance: MeshInstance3D, is_yard: bool) -> void:
	# Tạo một lần mỗi thuyền để hai thuyền có thể cuộn buồm độc lập.
	for surface: int in range(mesh_instance.mesh.get_surface_count()):
		var original: BaseMaterial3D = mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = SAIL_SHADER
		material.set_shader_parameter(&"cloth_color", original.albedo_color if original else Color.WHITE)
		material.set_shader_parameter(&"is_yard", is_yard)
		material.set_shader_parameter(&"flutter_amplitude", flutter_amplitude)
		material.set_shader_parameter(&"flutter_speed", flutter_speed)
		material.set_shader_parameter(&"furled_ratio", furled_ratio)
		material.set_shader_parameter(&"sail_top", sail_top)
		material.set_shader_parameter(&"sail_bottom", sail_bottom)
		mesh_instance.set_surface_override_material(surface, material)
		_materials.append(material)
