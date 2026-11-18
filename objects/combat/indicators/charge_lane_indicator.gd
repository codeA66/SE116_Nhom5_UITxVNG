class_name ChargeLaneIndicator
extends Node3D
## Chỉ thị tách khỏi scale của boss; chiều rộng nhận từ hitbox thực tế.

@export var fill_color: Color = Color(1.0, 0.035, 0.015, 0.28)
@export var border_color: Color = Color(1.0, 0.12, 0.04, 0.95)
@export_range(0.001, 1.0) var border_width: float = 0.08
@export var ground_offset: float = 0.035
@export var ground_probe_height: float = 3.0
@export var ground_probe_depth: float = 10.0
@export_flags_3d_physics var ground_mask: int = 1

var displayed_width: float = 0.0
var displayed_length: float = 0.0

var _fill: MeshInstance3D
var _left: MeshInstance3D
var _right: MeshInstance3D
var _tip: MeshInstance3D
var _border_material: StandardMaterial3D
var _fill_material: StandardMaterial3D
var _probe: RayCast3D

func _ready() -> void:
	top_level = true
	_probe = RayCast3D.new()
	add_child(_probe)
	_probe.top_level = true
	_probe.enabled = false
	_probe.collision_mask = ground_mask
	_fill_material = _material(fill_color)
	_border_material = _material(border_color)
	_fill = _plane(_fill_material)
	_left = _plane(_border_material)
	_right = _plane(_border_material)
	_tip = MeshInstance3D.new()
	var triangle: ArrayMesh = ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0, 0, 1)])
	triangle.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_tip.mesh = triangle
	_tip.material_override = _border_material
	_tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_tip)
	hide_lane()

func show_lane(origin: Vector3, direction: Vector3, width: float, length: float, progress: float) -> void:
	displayed_width = maxf(width, 0.01)
	displayed_length = maxf(length, 0.01)
	_probe.global_position = origin + Vector3.UP * ground_probe_height
	_probe.target_position = _probe.to_local(origin - Vector3.UP * ground_probe_depth)
	_probe.collision_mask = ground_mask
	_probe.force_raycast_update()
	var normal: Vector3 = _probe.get_collision_normal() if _probe.is_colliding() else Vector3.UP
	var start: Vector3 = _probe.get_collision_point() if _probe.is_colliding() else origin
	var forward: Vector3 = direction.slide(normal).normalized()
	if forward.is_zero_approx():
		forward = Vector3.FORWARD
	global_transform = Transform3D(Basis(normal.cross(forward).normalized(), normal, forward), start + normal * ground_offset)
	_fill.scale = Vector3(displayed_width, 1.0, displayed_length)
	_fill.position.z = displayed_length * 0.5
	var edge: float = minf(border_width, displayed_width * 0.25)
	_left.scale = Vector3(edge, 1.0, displayed_length)
	_right.scale = _left.scale
	_left.position = Vector3(-displayed_width * 0.5 + edge * 0.5, 0.001, displayed_length * 0.5)
	_right.position = Vector3(displayed_width * 0.5 - edge * 0.5, 0.001, displayed_length * 0.5)
	var tip_length: float = minf(displayed_width * 0.6, displayed_length)
	_tip.scale = Vector3(displayed_width, 1.0, tip_length)
	_tip.position = Vector3(0, 0.002, displayed_length - tip_length)
	var tint: Color = fill_color
	tint.a = lerpf(fill_color.a, minf(fill_color.a + 0.3, 1.0), clampf(progress, 0.0, 1.0))
	_fill_material.albedo_color = tint
	visible = true

func hide_lane() -> void:
	visible = false
	set_process(false)
	set_physics_process(false)

func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	return material

func _plane(material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2.ONE
	instance.mesh = plane
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance
