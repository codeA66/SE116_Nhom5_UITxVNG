extends Node3D
## Six independent layers; all geometry/instance data is allocated once.
## One explicit age uniform drives every shader, so pause/seek work without TIME.
signal finished
const Style = preload("res://assets/vfx/enemies/wolf/dark_claw/dark_claw_style.gd")
const CUT = preload("res://assets/vfx/enemies/wolf/dark_claw/shaders/claw_cut.gdshader")
const SMOKE = preload("res://assets/vfx/enemies/wolf/dark_claw/shaders/claw_smoke.gdshader")
const PARTICLES = preload("res://assets/vfx/enemies/wolf/dark_claw/shaders/claw_particles.gdshader")
const AURA = preload("res://assets/vfx/enemies/wolf/dark_claw/shaders/claw_aura.gdshader")
const LAYERS := ["Core", "Glow", "Smoke", "Embers", "Streaks", "Aura"]
@export var style: Style = preload("res://assets/vfx/enemies/wolf/dark_claw/dark_claw_default.tres")
@export var autoplay := false
var manual_clock := false
var age := 0.0
var playing := false
var solo_layer := ""
var layer_enabled := {"Core": true, "Glow": true, "Smoke": true, "Embers": true, "Streaks": true, "Aura": true}
var materials: Array[ShaderMaterial] = []
var impact_light: OmniLight3D

func _ready() -> void:
	style = style.duplicate(true)
	rebuild()
	stop()
	if autoplay:
		play()

func rebuild() -> void:
	materials.clear()
	for layer_name in LAYERS:
		var layer := get_node(layer_name)
		for child in layer.get_children():
			layer.remove_child(child)
			child.queue_free()
	for i in 3:
		var core := _material(CUT, 3)
		core.set_shader_parameter("cut_index", float(i))
		core.set_shader_parameter("hot_color", style.hot_color)
		_mesh("Core", "Cut_%d" % (i + 1), _ribbon(i, 1.0), core, 0.025 + i * 0.008)
		var glow := _material(CUT, 1)
		glow.set_shader_parameter("soft_layer", true)
		glow.set_shader_parameter("cut_index", float(i))
		_mesh("Glow", "Halo_%d" % (i + 1), _ribbon(i, 4.8), glow, 0.01)
		var smoke := _material(SMOKE, -2)
		smoke.set_shader_parameter("cut_index", float(i))
		_mesh("Smoke", "RippedShadow_%d" % (i + 1), _ribbon(i, 4.2), smoke, -0.05)
	var clouds := _material(SMOKE, -3)
	clouds.set_shader_parameter("kind", 1)
	_multimesh("Smoke", "DriftingSmoke", style.smoke_count, clouds, 0)
	var flakes := _material(SMOKE, 0)
	flakes.set_shader_parameter("kind", 2)
	_multimesh("Smoke", "InkFragments", style.ink_count, flakes, 1)
	var embers := _material(PARTICLES, 4)
	_multimesh("Embers", "RedEmbers", style.ember_count, embers, 2)
	var streaks := _material(PARTICLES, 2)
	streaks.set_shader_parameter("streaks", true)
	_multimesh("Streaks", "AfterimageStreaks", style.streak_count, streaks, 3)
	var aura := _material(AURA, -4)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 3.5
	_mesh("Aura", "ChargeSwirl", quad, aura, -0.12)
	impact_light = OmniLight3D.new()
	impact_light.name = "ImpactLight"
	impact_light.position.z = 0.7
	impact_light.light_color = style.edge_color
	impact_light.omni_range = 5.0
	get_node("Glow").add_child(impact_light)
	set_hue_shift(style.hue_shift)
	seek(age)

func _material(shader: Shader, priority: int) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = shader
	result.render_priority = priority
	result.set_shader_parameter("duration", style.duration)
	result.set_shader_parameter("shape_seed", float(style.seed_value))
	result.set_shader_parameter("edge_color", style.edge_color)
	result.set_shader_parameter("intensity", style.intensity)
	result.set_shader_parameter("hue_shift", style.hue_shift)
	result.set_shader_parameter("saturation_scale", style.saturation_scale)
	materials.append(result)
	return result

func _point(u: float, index: int) -> Vector3:
	var direction := Vector3(cos(deg_to_rad(style.angle_degrees)), sin(deg_to_rad(style.angle_degrees)), 0)
	var side := Vector3(-direction.y, direction.x, 0)
	var length_factor: float = [0.94, 1.03, 0.90][index]
	var offset := (float(index) - 1.0) * style.cut_spacing
	var bend := sin(u * PI) * (0.40 + float(index) * 0.035)
	var scar := sin(u * 11.0 + float(index) * 3.0) * sin(u * PI) * 0.025
	return direction * ((u - 0.5) * style.cut_length * length_factor) + side * (offset + bend + scar)

func _ribbon(index: int, width_scale: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	const SEGMENTS := 96
	for segment in SEGMENTS + 1:
		var u := float(segment) / float(SEGMENTS)
		var center := _point(u, index)
		var direction := (_point(minf(u + 0.002, 1.0), index) - _point(maxf(u - 0.002, 0.0), index)).normalized()
		var side := Vector3(-direction.y, direction.x, 0)
		var half_width := style.cut_width * width_scale * pow(maxf(sin(u * PI), 0.0001), 0.65)
		for sign_value in [-1.0, 1.0]:
			vertices.append(center + side * half_width * sign_value)
			normals.append(Vector3.BACK)
			uvs.append(Vector2(u, (sign_value + 1) * 0.5))
		if segment < SEGMENTS:
			var at := segment * 2
			indices.append_array(PackedInt32Array([at, at + 1, at + 2, at + 1, at + 3, at + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func _mesh(layer: String, node_name: String, mesh: Mesh, material: ShaderMaterial, z: float) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.position.z = z
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_node(layer).add_child(node)

func _multimesh(layer: String, node_name: String, count: int, material: ShaderMaterial, kind: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = style.seed_value + kind * 139
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = QuadMesh.new()
	mm.instance_count = count
	for index in count:
		var center := _point(rng.randf_range(0.08, 0.92), rng.randi_range(0, 2))
		var size_value := 1.0
		if kind == 0:
			center += Vector3(rng.randf_range(-0.20, 0.20), rng.randf_range(-0.18, 0.18), rng.randf_range(-0.22, -0.08))
			size_value = rng.randf_range(0.45, 1.2)
		elif kind == 1:
			center += Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.5, 0.5), rng.randf_range(-0.1, 0.16))
			size_value = rng.randf_range(0.04, 0.16)
		else:
			center += Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25), rng.randf_range(0.03, 0.20))
		var transform_value := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size_value), center)
		mm.set_instance_transform(index, transform_value)
		mm.set_instance_custom_data(index, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf()))
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-5, -5, -2), Vector3(10, 10, 4))
	get_node(layer).add_child(node)

func play() -> void:
	playing = true
	seek(0.0)
	set_process(not manual_clock)

func stop() -> void:
	playing = false
	age = style.duration
	seek(age)
	set_process(false)

func seek(seconds: float) -> void:
	age = clampf(seconds, 0.0, style.duration)
	for material in materials:
		material.set_shader_parameter("age", age)
		material.set_shader_parameter("duration", style.duration)
		material.set_shader_parameter("intensity", style.intensity)
	for layer_name in LAYERS:
		get_node(layer_name).visible = age < style.duration and layer_enabled[layer_name] and (solo_layer.is_empty() or layer_name == solo_layer)
	impact_light.light_energy = exp(-pow((age / style.duration - 0.25) * 11.0, 2.0)) * style.intensity * 2.0

func set_layer_enabled(layer: String, enabled: bool) -> void:
	assert(layer in LAYERS)
	layer_enabled[layer] = enabled
	seek(age)

func set_hue_shift(value: float) -> void:
	set_color_palette(value, style.saturation_scale)

func set_color_palette(value: float, saturation: float = 1.0) -> void:
	style.hue_shift = fposmod(value, 1.0)
	style.saturation_scale = clampf(saturation, 0.0, 1.0)
	for material in materials:
		material.set_shader_parameter("hue_shift", style.hue_shift)
		material.set_shader_parameter("saturation_scale", style.saturation_scale)
	var base := style.edge_color
	impact_light.light_color = base if is_zero_approx(style.hue_shift) and style.saturation_scale == 1.0 else Color.from_hsv(fposmod(base.h + style.hue_shift, 1.0), base.s * style.saturation_scale, base.v, base.a)

func _process(delta: float) -> void:
	seek(age + delta)
	if age >= style.duration:
		playing = false
		set_process(false)
		finished.emit()

func phase_name() -> String:
	var t := age / style.duration
	if t < 0.115: return "01 · STARTUP"
	if t < 0.22: return "02 · SLASH APPEARS"
	if t < 0.38: return "03 · PEAK IMPACT"
	if t < 0.70: return "04 · TRAILING ENERGY"
	if t < 1.0: return "05 · FADE OUT"
	return "FINISHED"
