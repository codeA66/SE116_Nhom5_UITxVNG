class_name ElephantCoat
extends Node3D
## Vỏ lửa nối theo các khớp của rig, co theo độ dài đốt vòi và chân.

const LIMBS := ["leftLeg1", "rightLeg1", "leftLeg2", "rightLeg2"]
const FLAME := preload("res://assets/shaders/fire/grid_flame.gdshader")
const LAVA := preload("res://entities/bosses/fire/elephant/vfx/lava_surface.gdshader")

var _skeleton: Skeleton3D
var _segments: Array[MeshInstance3D]
var _bones: Array[Vector2i]
var _base_radii: PackedFloat32Array
var _trunk_count: int
var _flame_material: ShaderMaterial
var _molten_material: ShaderMaterial
var _trunk_glow: MeshInstance3D


func setup(rig: Skeleton3D) -> void:
	_skeleton = rig
	_flame_material = ShaderMaterial.new()
	_flame_material.shader = FLAME
	_flame_material.set_shader_parameter(&"base_color", Color("f76b21"))
	_flame_material.set_shader_parameter(&"mid_color", Color("f43813"))
	_flame_material.set_shader_parameter(&"tip_color", Color("a71607"))
	_flame_material.set_shader_parameter(&"strength", 0.53)
	_molten_material = ShaderMaterial.new()
	_molten_material.shader = LAVA
	_molten_material.set_shader_parameter(&"style", 3)
	var shell := CylinderMesh.new()
	shell.height = 1.0
	shell.top_radius = 1.0
	shell.bottom_radius = 0.8
	shell.radial_segments = 9
	shell.cap_top = false
	shell.cap_bottom = false
	for i: int in range(1, 9):
		_segment(shell, "proboscis%02d" % i, "proboscis%02d" % (i + 1), lerpf(0.49, 0.19, i / 8.0))
	_trunk_count = _segments.size()
	for limb: String in LIMBS:
		_segment(shell, limb + "_LoResUpperLeg", limb + "_LoResLowerLeg", 0.47)
		_segment(shell, limb + "_LoResLowerLeg", limb + "_LoResFoot", 0.44)
		_segment(shell, limb + "_LoResFoot", limb + "_LoResToe", 0.36)
	var orb := SphereMesh.new()
	orb.radius = 0.2
	orb.height = 0.4
	orb.radial_segments = 8
	orb.rings = 3
	var glow_material := ShaderMaterial.new()
	glow_material.shader = LAVA
	glow_material.set_shader_parameter(&"style", 2)
	glow_material.set_shader_parameter(&"crust", Color("ed6512"))
	_trunk_glow = MeshInstance3D.new()
	_trunk_glow.mesh = orb
	_trunk_glow.material_override = glow_material
	_trunk_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trunk_glow)
	_trunk_glow.hide()
	set_coating(false, false)


func set_coating(trunk: bool, legs: bool, molten_trunk: bool = false) -> void:
	for i: int in _segments.size():
		var is_trunk := i < _trunk_count
		_segments[i].visible = trunk if is_trunk else legs
		_segments[i].material_override = _molten_material if is_trunk and molten_trunk else _flame_material
	set_process(trunk or legs or _trunk_glow.visible)
	if is_processing():
		_process(0.0)


func set_trunk_glow(enabled: bool) -> void:
	_trunk_glow.visible = enabled
	set_process(enabled or _segments.any(func(segment: MeshInstance3D) -> bool: return segment.visible))
	if enabled:
		_process(0.0)


func trunk_tip() -> Vector3:
	return _world_bone(_bones[_trunk_count - 1].y)


func _process(_delta: float) -> void:
	if _trunk_glow.visible:
		_trunk_glow.global_position = trunk_tip()
	for i: int in _segments.size():
		var segment := _segments[i]
		if not segment.visible:
			continue
		var pair := _bones[i]
		var from := _world_bone(pair.x)
		var to := _world_bone(pair.y)
		var axis := to - from
		if axis.length_squared() < 0.0001:
			continue
		var up := axis.normalized()
		var tangent := up.cross(Vector3.FORWARD if absf(up.z) < 0.85 else Vector3.RIGHT).normalized()
		var orientation := Basis(tangent, up, tangent.cross(up))
		var radius := _base_radii[i]
		var size := Vector3(radius, axis.length() + radius * 0.45, radius)
		segment.global_transform = Transform3D(orientation.scaled_local(size), (from + to) * 0.5)


func _segment(mesh: Mesh, from: String, to: String, radius: float) -> void:
	var pair := Vector2i(_skeleton.find_bone(from), _skeleton.find_bone(to))
	if pair.x < 0 or pair.y < 0:
		return
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)
	_segments.append(part)
	_bones.append(pair)
	_base_radii.append(radius)


func _world_bone(index: int) -> Vector3:
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(index).origin
