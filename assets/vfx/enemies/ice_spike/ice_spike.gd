extends Node3D
## Seven independent, seeded layers. Local +X is the forward ground path.
signal finished
const Style = preload("res://assets/vfx/enemies/ice_spike/ice_spike_style.gd")
const CRYSTAL = preload("res://assets/vfx/enemies/ice_spike/shaders/ice_crystal.gdshader")
const GLOW = preload("res://assets/vfx/enemies/ice_spike/shaders/ice_glow.gdshader")
const CRACKS = preload("res://assets/vfx/enemies/ice_spike/shaders/ice_cracks.gdshader")
const MIST = preload("res://assets/vfx/enemies/ice_spike/shaders/ice_mist.gdshader")
const PARTICLES = preload("res://assets/vfx/enemies/ice_spike/shaders/ice_particles.gdshader")
const LAYERS := ["CrystalCore", "SecondaryShards", "Glow", "FrostMist", "Sparks", "Shatter", "GroundCracks"]
@export var style: Style = preload("res://assets/vfx/enemies/ice_spike/ice_spike_default.tres")
var age := -1.0
var playing := false
var manual_clock := false
var solo_layer := ""
var layer_enabled: Dictionary = {}
var materials: Array[ShaderMaterial] = []
var batch_data: Dictionary = {}
var crystal_mesh: ArrayMesh

func _ready() -> void:
	style = style.duplicate(true)
	for layer in LAYERS: layer_enabled[layer] = true
	crystal_mesh = _crystal_mesh()
	rebuild()
	seek(-1.0)
	set_process(false)

func _triangle(a: Vector3, b: Vector3, c: Vector3, vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, uvs: PackedVector2Array) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for point in [a, b, c]:
		vertices.append(point)
		normals.append(normal)
		uvs.append(Vector2(point.x * 0.5 + 0.5, point.y))
	colors.append_array(PackedColorArray([Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1)]))

func _crystal_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var tip := Vector3(0.18, 1.0, -0.08)
	for side in 6:
		var a := float(side) * TAU / 6.0
		var b := float(side + 1) * TAU / 6.0
		var low_a := Vector3(cos(a) * 0.50, 0, sin(a) * 0.50)
		var low_b := Vector3(cos(b) * 0.50, 0, sin(b) * 0.50)
		var mid_a := Vector3(cos(a), 0.53, sin(a))
		var mid_b := Vector3(cos(b), 0.53, sin(b))
		_triangle(low_a, mid_a, mid_b, vertices, normals, colors, uvs)
		_triangle(low_a, mid_b, low_b, vertices, normals, colors, uvs)
		_triangle(mid_a, tip, mid_b, vertices, normals, colors, uvs)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func rebuild() -> void:
	materials.clear()
	batch_data.clear()
	for layer in LAYERS:
		for child in get_node(layer).get_children():
			get_node(layer).remove_child(child)
			child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = style.seed_value
	var core: Array = []
	var secondary: Array = []
	for row in 11:
		var u := float(row) / 10.0
		var count := 2 + int(u * 3.0)
		for index in count:
			var spread := 0.12 + pow(u, 1.3) * 1.05
			var z := (float(index) / maxf(count - 1, 1) * 2.0 - 1.0) * spread
			var height := (0.22 + pow(u, 1.45) * 2.45) * rng.randf_range(0.75, 1.2)
			var width := 0.07 + height * 0.10
			core.append(_instance(Vector3(u * style.path_length + rng.randf_range(-0.16, 0.16), -0.015, z), height, width, u, rng))
	for index in 11:
		var u := rng.randf_range(0.94, 1.0)
		var height := rng.randf_range(2.0, 4.1)
		core.append(_instance(Vector3(style.path_length + rng.randf_range(-0.65, 0.35), 0, rng.randf_range(-1.0, 1.0)), height, height * rng.randf_range(0.10, 0.15), u, rng))
	core.append(_instance(Vector3(style.path_length - 0.18, 0, -0.25), 4.6, 0.50, 0.98, rng))
	for index in 78:
		var u := rng.randf()
		var height := rng.randf_range(0.14, 0.55) * (0.6 + u)
		secondary.append(_instance(Vector3(u * style.path_length + rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-1, 1) * (0.12 + u * 1.35)), height, height * 0.18, u, rng))
	_batch("CrystalCore", "MainCrystals", core, crystal_mesh, _material(CRYSTAL, 0))
	_batch("SecondaryShards", "SmallCrystals", secondary, crystal_mesh, _material(CRYSTAL, 0))
	_batch("Glow", "CrystalGlow", core, crystal_mesh, _material(GLOW, 1))
	var mist: Array = []
	var sparks: Array = []
	var pieces: Array = []
	for index in 52:
		var u := rng.randf()
		var size_value := rng.randf_range(0.65, 1.65) * (0.6 + u)
		mist.append({"transform": Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size_value), Vector3(u * style.path_length, 0.15, rng.randf_range(-1, 1) * (0.15 + u))), "data": Color(rng.randf(), rng.randf(), u, rng.randf())})
	for index in 90:
		var u := rng.randf()
		sparks.append(_instance(Vector3(u * style.path_length, rng.randf_range(0.1, 1.7) * (0.4 + u), rng.randf_range(-1.2, 1.2)), rng.randf_range(0.04, 0.11), 0.025, u, rng))
	for index in 180:
		var u := pow(rng.randf(), 0.45)
		pieces.append(_instance(Vector3(u * style.path_length, rng.randf_range(0.15, 2.6) * u, rng.randf_range(-1.0, 1.0) * u), rng.randf_range(0.08, 0.30), rng.randf_range(0.035, 0.09), u, rng))
	_batch("FrostMist", "RollingFrost", mist, QuadMesh.new(), _material(MIST, -2))
	_batch("Sparks", "IceMotes", sparks, crystal_mesh, _material(PARTICLES, 2))
	var shatter_material := _material(PARTICLES, 3)
	shatter_material.set_shader_parameter("shatter", true)
	_batch("Shatter", "CrystalFragments", pieces, crystal_mesh, shatter_material)
	var ground := MeshInstance3D.new()
	ground.name = "CrackEnergy"
	ground.mesh = _ground_mesh()
	ground.material_override = _material(CRACKS, -3)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_node("GroundCracks").add_child(ground)
	seek(age)

func _instance(at: Vector3, height: float, width: float, u: float, rng: RandomNumberGenerator) -> Dictionary:
	var basis_value := Basis(Vector3.UP, rng.randf_range(-PI, PI))
	basis_value = Basis(Vector3.BACK, rng.randf_range(-0.46, -0.08)) * basis_value
	basis_value = basis_value * Basis.from_scale(Vector3(width, height, width * 0.8))
	return {"transform": Transform3D(basis_value, at), "data": Color(rng.randf(), rng.randf(), u, rng.randf())}

func _material(shader: Shader, priority: int) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = shader
	result.render_priority = priority
	result.set_shader_parameter("core_color", style.core_color)
	result.set_shader_parameter("edge_color", style.edge_color)
	materials.append(result)
	return result

func _batch(layer: String, node_name: String, instances: Array, mesh: Mesh, material: ShaderMaterial) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = instances.size()
	for index in instances.size():
		mm.set_instance_transform(index, instances[index].transform)
		mm.set_instance_custom_data(index, instances[index].data)
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	node.material_override = material
	node.custom_aabb = AABB(Vector3(-3, -4, -6), Vector3(style.path_length + 9, 14, 12))
	get_node(layer).add_child(node)
	batch_data[layer] = instances

func _ground_mesh() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.4, 0.018, -2), Vector3(style.path_length + 0.8, 0.018, -2), Vector3(-0.4, 0.018, 2), Vector3(style.path_length + 0.8, 0.018, 2)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 1, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func seek(seconds: float) -> void:
	age = seconds
	for material in materials:
		material.set_shader_parameter("age", age)
		material.set_shader_parameter("growth_time", style.growth_time)
		material.set_shader_parameter("shatter_time", style.shatter_time)
		material.set_shader_parameter("duration", style.duration)
		material.set_shader_parameter("intensity", style.intensity)
	for layer in LAYERS:
		get_node(layer).visible = age >= 0.0 and age < style.duration and layer_enabled.get(layer, true) and (solo_layer.is_empty() or solo_layer == layer)

func set_layer_enabled(layer: String, enabled: bool) -> void:
	assert(layer in LAYERS)
	layer_enabled[layer] = enabled
	seek(age)

func play() -> void:
	playing = true
	seek(0.0)
	set_process(not manual_clock)

func _process(delta: float) -> void:
	seek(age + delta)
	if age >= style.duration:
		playing = false
		set_process(false)
		finished.emit()
