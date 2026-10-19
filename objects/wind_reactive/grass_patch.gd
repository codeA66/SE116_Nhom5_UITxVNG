class_name WindReactiveGrassPatch
extends Node3D
## Một vùng nhận gió và một MultiMesh cho cụm cỏ lớn.

const GRASS_SCENE: PackedScene = preload("res://assets/models/wind_kit/grass_tuft.glb")
const FOLIAGE_SHADER: Shader = preload("res://assets/shaders/wind_react_foliage.gdshader")
const DEFAULT_DATA: WindReactData = preload("res://resources/wind_reactive/default.tres")

@export_range(1, 1000) var grass_count: int = 200
@export_range(1, 100) var columns: int = 20
@export_range(0.1, 10.0) var spacing: float = 0.8
@export var data: WindReactData = DEFAULT_DATA

var _material: ShaderMaterial

@onready var _multi: MultiMeshInstance3D = $GrassMultiMesh
@onready var _receiver: WindReceiverComponent = $WindReceiver
@onready var _reactive: WindReactiveComponent = $WindReactive
@onready var _shape: CollisionShape3D = $WindReceiver/CollisionShape3D


func _ready() -> void:
	var imported: Node3D = GRASS_SCENE.instantiate() as Node3D
	var source: MeshInstance3D = _find_mesh(imported)
	if source == null:
		imported.free()
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = source.mesh
	multi.instance_count = grass_count
	var row_count: int = ceili(float(grass_count) / float(columns))
	for index in grass_count:
		var x: float = (float(index % columns) - float(columns - 1) * 0.5) * spacing
		var z: float = (float(index / columns) - float(row_count - 1) * 0.5) * spacing
		multi.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(x, 0.0, z)))
	_multi.multimesh = multi
	_multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = FOLIAGE_SHADER
	_material.set_shader_parameter(&"recovery_seconds", data.recovery_seconds)
	_material.set_shader_parameter(&"bend_amount", data.bend_amount)
	_material.set_shader_parameter(&"flutter_speed", data.flutter_speed)
	_material.set_shader_parameter(&"tint", Color.WHITE)
	var bounds: AABB = source.get_aabb()
	_material.set_shader_parameter(&"anchor_height", bounds.position.y)
	_material.set_shader_parameter(&"foliage_height", maxf(bounds.size.y, 0.01))
	_multi.material_override = _material
	var box: BoxShape3D = _shape.shape as BoxShape3D
	box.size = Vector3(float(columns) * spacing, 2.0, float(row_count) * spacing)
	_reactive.reacted.connect(_on_reacted)
	_reactive.wind_changed.connect(_on_wind_changed)
	imported.free()


func _on_reacted(direction: Vector3, strength: float) -> void:
	var gust_started: float = WindReactiveClock.arm(get_tree(), data.recovery_seconds)
	_material.set_shader_parameter(&"gust_direction", global_basis.inverse() * direction)
	_material.set_shader_parameter(&"gust_strength", clampf(strength / maxf(data.full_strength, 0.01), 0.0, 2.0))
	_material.set_shader_parameter(&"gust_time", gust_started)


func _on_wind_changed(direction: Vector3, strength: float) -> void:
	_material.set_shader_parameter(&"hold_strength", clampf(strength / maxf(data.full_strength, 0.01), 0.0, 2.0))
	if strength > 0.0:
		_material.set_shader_parameter(&"hold_direction", global_basis.inverse() * direction)


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found: MeshInstance3D = _find_mesh(child)
		if found != null:
			return found
	return null
