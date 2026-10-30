extends Node3D
## Hình ảnh nghe activated độc lập với logic gọi phà; dựng sẵn để warmup khi tải phòng.

signal finished

const SEGMENTS: int = 64

@export_group("Timing")
@export_range(0.2, 4.0, 0.05) var duration: float = 1.8
@export_range(0.03, 0.2, 0.01) var launch_time: float = 0.07
@export_range(0.1, 0.6, 0.01) var burst_time: float = 0.24
@export_group("Shape")
@export_range(0.2, 4.0, 0.05) var ground_radius: float = 1.65
@export_range(0.5, 8.0, 0.1) var post_height: float = 2.9
@export_range(0.2, 2.0, 0.05) var spiral_radius: float = 0.65
@export_range(4.0, 40.0, 1.0) var beam_height: float = 18.0
@export_range(0.08, 0.8, 0.01) var beam_radius: float = 0.6
@export_group("Color")
@export var interaction_color: Color = Color("3fe0d0")
@export var core_color: Color = Color("efffff")
@export var edge_color: Color = Color("173b50")
@export_group("Particles")
@export_range(4, 32, 1) var spark_count: int = 24
@export_range(1.0, 12.0, 0.5) var spark_speed: float = 6.0

var _ring: MeshInstance3D
var _rim: MeshInstance3D
var _spiral: MeshInstance3D
var _beam: MeshInstance3D
var _beam_core: MeshInstance3D
var _flash: MeshInstance3D
var _sparks: CPUParticles3D
var _materials: Array[StandardMaterial3D] = []
var _tween: Tween


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.88
	ring_mesh.outer_radius = 1.0
	ring_mesh.rings = 48
	ring_mesh.ring_segments = 6
	_ring = _mesh(ring_mesh, interaction_color)
	_ring.position.y = 0.07
	_rim = _mesh(ring_mesh, edge_color)
	_rim.position.y = 0.045
	_spiral = _mesh(_spiral_mesh(), interaction_color)
	_beam = _mesh(_plume_mesh(false), interaction_color)
	_beam_core = _mesh(_plume_mesh(true), core_color)
	(_beam.material_override as StandardMaterial3D).vertex_color_use_as_albedo = true
	(_beam_core.material_override as StandardMaterial3D).vertex_color_use_as_albedo = true
	var flash_mesh: SphereMesh = SphereMesh.new()
	flash_mesh.radius = 0.24
	flash_mesh.height = 0.48
	flash_mesh.radial_segments = 16
	flash_mesh.rings = 8
	_flash = _mesh(flash_mesh, core_color)
	_flash.position.y = post_height
	_build_sparks()
	visible = false


func play() -> void:
	if _tween != null and _tween.is_running():
		return
	visible = true
	_update(0.0)
	_sparks.lifetime = minf(maxf(duration, 0.2), 1.1)
	_sparks.restart()
	_sparks.emitting = true
	_tween = create_tween()
	_tween.tween_method(_update, 0.0, 1.0, maxf(duration, 0.2))
	_tween.tween_callback(_finish)


func _update(progress: float) -> void:
	var expansion: float = 1.0 - pow(1.0 - progress, 3.0)
	var radius: float = ground_radius * lerpf(0.35, 1.0, expansion)
	_ring.scale = Vector3(radius, 0.6, radius)
	_rim.scale = Vector3(radius * 1.035, 1.0, radius * 1.035)
	_spiral.rotation.y = progress * TAU * 0.7
	_spiral.position.y = progress * post_height * 0.45
	var age: float = progress * maxf(duration, 0.2)
	# Phóng hết chiều cao trong 70 ms, giữ thân sáng rồi thu ngang ở cuối.
	var launch: float = 1.0 - pow(1.0 - clampf(age / maxf(launch_time, 0.01), 0.0, 1.0), 3.0)
	var closing: float = 1.0 - smoothstep(0.83, 1.0, progress)
	_beam.scale = Vector3(maxf(0.001, closing), maxf(0.01, launch * beam_height), maxf(0.001, closing))
	_beam.position.y = post_height
	_beam.rotation.y = age * 0.55
	_beam_core.scale = _beam.scale
	_beam_core.position = _beam.position
	_beam_core.rotation.y = -age * 0.35
	var burst: float = clampf(age / maxf(burst_time, 0.01), 0.0, 1.0)
	var flash_size: float = maxf(0.001, (1.0 - burst) * 2.8)
	_flash.scale = Vector3(flash_size, flash_size * 0.55, flash_size)
	_flash.visible = burst < 1.0
	var fade: float = 1.0 - smoothstep(0.4, 1.0, progress)
	for material: StandardMaterial3D in _materials:
		var color: Color = material.albedo_color
		color.a = fade
		material.albedo_color = color
	# Cột sáng giữ độ nét suốt pha giữ, không mờ dần cùng vòng dưới đất.
	_set_alpha(_beam, closing)
	_set_alpha(_beam_core, closing)
	_set_alpha(_flash, (1.0 - burst) * (1.0 - burst))


func _set_alpha(instance: MeshInstance3D, alpha: float) -> void:
	var material: StandardMaterial3D = instance.material_override as StandardMaterial3D
	var color: Color = material.albedo_color
	color.a = alpha
	material.albedo_color = color


func _finish() -> void:
	visible = false
	_sparks.emitting = false
	finished.emit()


func _mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	instance.material_override = material
	_materials.append(material)
	add_child(instance)
	return instance


func _spiral_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for strand: int in 2:
		var offset: int = vertices.size()
		for step: int in SEGMENTS + 1:
			var t: float = float(step) / SEGMENTS
			var angle: float = t * TAU * 1.2 + strand * PI
			var center: Vector3 = Vector3(cos(angle) * spiral_radius, t * post_height, sin(angle) * spiral_radius)
			var width: float = 0.075 * sin(t * PI)
			vertices.append(center + Vector3.UP * width)
			vertices.append(center - Vector3.UP * width)
			if step < SEGMENTS:
				var i: int = offset + step * 2
				indices.append_array(PackedInt32Array([i, i + 1, i + 2, i + 1, i + 3, i + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _plume_mesh(core: bool) -> ArrayMesh:
	# Dải lệch pha, đứt lõi và mép răng tạo thân năng lượng thay cho ống sáng đều.
	var vertices: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	var strands: int = 3 if core else 5
	for strand: int in strands:
		var phase: float = strand * 2.399
		var direction: Vector3 = Vector3(cos(phase), 0.0, sin(phase))
		var side: Vector3 = Vector3(-sin(phase), 0.0, cos(phase))
		var offset: int = vertices.size()
		for step: int in 33:
			var t: float = float(step) / 32.0
			var envelope: float = pow(1.0 - t, 0.65)
			var jagged: float = 0.65 + 0.35 * sin(t * 53.0 + phase)
			var width: float = beam_radius * envelope * jagged * (0.15 if core else 0.58)
			var drift: float = sin(t * 17.0 + phase) * beam_radius * envelope
			var center: Vector3 = Vector3.UP * t * (0.8 + strand * 0.04) + direction * drift
			var alpha: float = (0.9 if core else 0.55) * (1.0 - smoothstep(0.65, 1.0, t))
			if core:
				alpha *= smoothstep(-0.4, 0.35, sin(t * 31.0 + phase))
			for edge: int in 3:
				vertices.append(center + side * width * (edge - 1))
				colors.append(Color(1.0, 1.0, 1.0, alpha if edge == 1 else 0.0))
			if step < 32:
				for edge: int in 2:
					var i: int = offset + step * 3 + edge
					indices.append_array(PackedInt32Array([i, i + 1, i + 3, i + 1, i + 4, i + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_sparks() -> void:
	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.amount = spark_count
	_sparks.one_shot = true
	_sparks.explosiveness = 1.0
	_sparks.lifetime = maxf(duration, 0.2)
	_sparks.position.y = post_height
	_sparks.direction = Vector3.UP
	_sparks.spread = 100.0
	_sparks.initial_velocity_min = spark_speed * 0.65
	_sparks.initial_velocity_max = spark_speed
	_sparks.gravity = Vector3(0.0, -3.0, 0.0)
	_sparks.scale_amount_min = 0.035
	_sparks.scale_amount_max = 0.075
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([core_color, interaction_color, Color(interaction_color, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	_sparks.color_ramp = gradient
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	var mote: SphereMesh = SphereMesh.new()
	mote.radial_segments = 6
	mote.rings = 3
	mote.radius = 1.0
	mote.height = 2.0
	mote.material = material
	_sparks.mesh = mote
	add_child(_sparks)
