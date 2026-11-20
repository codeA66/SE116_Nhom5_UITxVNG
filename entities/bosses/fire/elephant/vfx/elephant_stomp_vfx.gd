class_name ElephantStompVfx
extends Node3D

const ERUPTION := preload("res://entities/bosses/fire/elephant/vfx/lava_eruption.gdshader")
const DURATION: float = 1.18

var _age: float
var _materials: Array[ShaderMaterial]


func _ready() -> void:
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2.ONE * 2.0
	_add_layer(floor_mesh, 0, Vector3.UP * 0.12)
	var flame := CylinderMesh.new()
	flame.radial_segments = 32
	flame.height = 1.65
	flame.top_radius = 0.89
	flame.bottom_radius = 0.95
	flame.cap_top = false
	flame.cap_bottom = false
	_add_layer(flame, 1, Vector3.UP * 0.89)
	_build_rocks()
	stop()


func play(at: Vector3, radius: float) -> void:
	global_position = at
	rotation.y = randf_range(0.0, TAU)
	scale = Vector3(radius, 1.0, radius)
	reset_physics_interpolation()
	_age = 0.0
	_update_materials()
	show()
	set_physics_process(true)


func stop() -> void:
	hide()
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= DURATION:
		stop()
		return
	_update_materials()


func _update_materials() -> void:
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"age", _age)


func _material(layer: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = ERUPTION
	material.set_shader_parameter(&"layer", layer)
	_materials.append(material)
	return material


func _add_layer(mesh: Mesh, layer: int, offset: Vector3) -> void:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(layer)
	node.position = offset
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _build_rocks() -> void:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_custom_data = true
	batch.mesh = _rock_mesh()
	batch.instance_count = 34
	var rng := RandomNumberGenerator.new()
	rng.seed = 1138
	for i: int in batch.instance_count:
		var angle := TAU * (i + rng.randf_range(-0.48, 0.48)) / batch.instance_count
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var large := i % 3 == 0
		var width := rng.randf_range(0.082, 0.14) if large else rng.randf_range(0.024, 0.079)
		var height := rng.randf_range(0.52, 0.99) if large else rng.randf_range(0.17, 0.55)
		var size := Vector3(width, height, width * rng.randf_range(0.76, 1.2))
		var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), angle, rng.randf_range(-0.3, 0.3)))
		batch.set_instance_transform(i, Transform3D(tilt.scaled(size), radial * rng.randf_range(0.23, 0.88)))
		batch.set_instance_custom_data(i, Color(angle / TAU, rng.randf(), rng.randf(), rng.randf()))
	var node := MultiMeshInstance3D.new()
	node.multimesh = batch
	node.material_override = _material(2)
	node.custom_aabb = AABB(Vector3(-1, 0, -1), Vector3(2, 3, 2))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _rock_mesh() -> ArrayMesh:
	var lower := PackedVector3Array()
	var ridge := PackedVector3Array()
	var top := PackedVector3Array()
	for side: int in 7:
		var angle := TAU * side / 7.0
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		lower.append(radial * (0.27 + 0.10 * sin(side * 2.2)) + Vector3.DOWN * 0.36)
		ridge.append(radial * (0.50 + 0.09 * cos(side * 4.4)) + Vector3.UP * (0.02 - 0.13 * sin(side * 1.8)))
		top.append(radial * (0.31 + 0.10 * cos(side * 2.3)) + Vector3(-0.15, 0.39 + 0.13 * sin(side * 2.3), 0.09))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: int in 7:
		var next := (side + 1) % 7
		_rock_face(surface, lower[side], lower[next], ridge[next])
		_rock_face(surface, lower[side], ridge[next], ridge[side])
		_rock_face(surface, ridge[side], ridge[next], top[side])
		_rock_face(surface, top[side], ridge[next], top[next])
		_rock_face(surface, top[side], top[next], Vector3(-0.08, 0.44, 0.13))
		_rock_face(surface, lower[next], lower[side], Vector3(0.03, -0.41, -0.03))
	return surface.commit()


func _rock_face(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	for point: Vector3 in [a, b, c]:
		surface.set_normal(normal)
		surface.set_uv(Vector2(point.x + point.z * 0.32 + 0.60, point.y + point.z * 0.36 + 0.60))
		surface.add_vertex(point)
