extends Node3D
## Target-centered warning during windup, then an upward burst at paw contact.
signal finished
const GROUND = preload("res://assets/vfx/enemies/wind_slam/shaders/wind_ground.gdshader")
const RIBBON = preload("res://assets/vfx/enemies/wind_slam/shaders/wind_ribbon.gdshader")
const MIST = preload("res://assets/vfx/enemies/wind_slam/shaders/wind_mist.gdshader")
const PARTICLES = preload("res://assets/vfx/enemies/wind_slam/shaders/wind_particles.gdshader")
const LAYERS := ["RingCore", "EdgeGlow", "CenterAura", "WindStreaks", "BurstPlume", "Mist", "Particles", "Debris"]
@export var radius := 2.5
@export var plume_height := 5.8
@export var warning_start := 0.04
@export var burst_time := 0.9666667
@export var tail_duration := 2.2
var age := -1.0
var manual_clock := false
var playing := false
var solo_layer := ""
var layer_enabled: Dictionary = {}
var materials: Array[ShaderMaterial] = []

func _ready() -> void:
	for layer in LAYERS:
		var group := Node3D.new()
		group.name = layer
		add_child(group)
		layer_enabled[layer] = true
	for index in 3:
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE * radius * 2.34
		var mat := _material(GROUND, index - 3)
		mat.set_shader_parameter("layer_kind", index)
		var node := _mesh(LAYERS[index], "GroundLayer", plane, mat)
		node.position.y = 0.04 + index * 0.007
	for index in 5:
		var mat := _material(RIBBON, 0)
		mat.set_shader_parameter("warning", true)
		mat.set_shader_parameter("seed_value", float(index))
		_mesh("WindStreaks", "ChargeRibbon%d" % index, _ribbon(float(index) * TAU / 5, 1.45, radius * 0.84, 0.24, 0.64 + float(index % 3) * 0.12), mat)
	for index in 7:
		var mat := _material(RIBBON, 1)
		mat.set_shader_parameter("seed_value", float(index))
		_mesh("BurstPlume", "UpdraftRibbon%d" % index, _ribbon(float(index) * TAU / 7, plume_height * (0.85 + float(index % 3) * 0.075), radius * 0.72, 0.35 + float(index % 3) * 0.19, 0.67 + float(index % 4) * 0.13), mat)
	for index in 6:
		var mat := _material(RIBBON, -1)
		mat.set_shader_parameter("soft_plume", true)
		mat.set_shader_parameter("seed_value", float(index + 12))
		_mesh("BurstPlume", "AirSheet%d" % index, _ribbon(float(index) * TAU / 6, plume_height * 0.97, radius * 0.57, 1.6, 0.25 + float(index % 3) * 0.12), mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41389
	_batch("Mist", 36, QuadMesh.new(), _material(MIST, -2), rng)
	var fleck := PrismMesh.new()
	fleck.size = Vector3(0.7, 1.8, 0.18)
	_batch("Particles", 85, fleck, _material(PARTICLES, 2), rng)
	var rock := SphereMesh.new()
	rock.radial_segments = 5
	rock.rings = 1
	rock.radius = 0.65
	rock.height = 1.1
	var rock_mat := _material(PARTICLES, 0)
	rock_mat.set_shader_parameter("debris", true)
	_batch("Debris", 26, rock, rock_mat, rng)
	seek(-1.0)
	set_process(false)

func _material(shader: Shader, priority: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.render_priority = priority
	materials.append(mat)
	return mat

func _mesh(layer: String, node_name: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 12, 12))
	get_node(layer).add_child(node)
	return node

func _ribbon(phase: float, height: float, base_radius: float, width: float, turns: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for step in 97:
		var t := float(step) / 96.0
		var angle := phase + t * TAU * turns + sin(t * TAU * 1.4 + phase) * 0.14
		var r := base_radius * (1.0 - t * 0.53) + sin(t * PI * 2.0 + phase) * 0.12
		var ribbon_width := width * (0.2 + pow(sin(t * PI), 0.65) * 0.8)
		for side in 2:
			var a := angle + (float(side) - 0.5) * ribbon_width / maxf(r, 0.1)
			vertices.append(Vector3(cos(a) * r, 0.07 + height * t, sin(a) * r))
			uvs.append(Vector2(float(side), t))
		if step < 96:
			var i := step * 2
			indices.append_array(PackedInt32Array([i, i + 1, i + 2, i + 1, i + 3, i + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _batch(layer: String, count: int, mesh: Mesh, material: Material, rng: RandomNumberGenerator) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = count
	for index in count:
		var angle := rng.randf() * TAU
		var r := sqrt(rng.randf()) * radius * 0.95
		var size_value := rng.randf_range(0.04, 0.11)
		var y := rng.randf_range(0.0, 0.5)
		if layer == "Mist":
			size_value = rng.randf_range(1.0, 2.1)
			y = rng.randf_range(0.2, 2.8)
		elif layer == "Debris": size_value = rng.randf_range(0.10, 0.26)
		var basis_value := Basis.from_euler(Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU).scaled(Vector3.ONE * size_value)
		mm.set_instance_transform(index, Transform3D(basis_value, Vector3(cos(angle) * r, y, sin(angle) * r)))
		mm.set_instance_custom_data(index, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf()))
	var node := MultiMeshInstance3D.new()
	node.name = layer + "Batch"
	node.multimesh = mm
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-7, -2, -7), Vector3(14, 16, 14))
	get_node(layer).add_child(node)

func total_duration() -> float:
	return burst_time + tail_duration

func seek(seconds: float) -> void:
	age = seconds
	for mat in materials:
		mat.set_shader_parameter("age", age)
		mat.set_shader_parameter("warning_start", warning_start)
		mat.set_shader_parameter("burst_time", burst_time)
		mat.set_shader_parameter("tail_duration", tail_duration)
	for layer in LAYERS:
		var warning: bool = layer in ["RingCore", "EdgeGlow", "CenterAura", "WindStreaks"]
		var active := age >= warning_start and age < burst_time if warning else age >= burst_time and age < total_duration()
		get_node(layer).visible = active and layer_enabled.get(layer, true) and (solo_layer.is_empty() or solo_layer == layer)

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
	if age >= total_duration():
		playing = false
		set_process(false)
		finished.emit()
