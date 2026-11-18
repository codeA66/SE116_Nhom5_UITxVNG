extends Node3D
## Đồng bộ hiệu ứng húc theo animation; tắt xử lý khi boss không húc.
signal impact

const WIND_SHADER: Shader = preload("charge_wind.gdshader")
const DUST_SHADER: Shader = preload("charge_dust.gdshader")
@export_group("Đồng bộ animation")
@export var animation_player_path: NodePath
@export var skeleton_path: NodePath
@export var auto_sync: bool = true
@export var charge_animation: StringName = &"Charge"
@export_range(0.01, 10.0) var charge_duration: float = 3.2
@export_range(0.0, 10.0) var impact_time: float = 64.0 / 30.0
@export_group("Hiển thị")
@export var effect_scale: float = 1.0
@export var wind_tint: Color = Color(0.72, 0.90, 1.0, 0.62)
@export var dust_tint: Color = Color(0.46, 0.34, 0.22, 0.42)
@export var forward_positive_z: bool = true
@export_group("Giới hạn hiệu ứng")
@export_range(1, 24) var wind_streak_count: int = 12
@export_range(1, 48) var foot_particle_count: int = 12
@export_range(1, 64) var impact_particle_count: int = 22
var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _head_bone: int = -1
var _feet: Array[int] = [-1, -1]
var _wind_root: Node3D
var _wind_materials: Array[ShaderMaterial] = []
var _ring: MeshInstance3D
var _ring_material: ShaderMaterial
var _dust: Array[CPUParticles3D] = []
var _clock: float = -1.0
var _previous_time: float = -1.0
var _manual: bool = false
var _external_clock: bool = false
var _following_charge: bool = false
var _was_low: Array[bool] = [false, false]
var _last_puff: Array[float] = [-1.0, -1.0]

func _ready() -> void:
	_player = get_node_or_null(animation_player_path) as AnimationPlayer if not animation_player_path.is_empty() else _find_type(get_parent(), "AnimationPlayer") as AnimationPlayer
	_skeleton = get_node_or_null(skeleton_path) as Skeleton3D if not skeleton_path.is_empty() else _find_type(get_parent(), "Skeleton3D") as Skeleton3D
	if _skeleton:
		_head_bone = _bone("Head")
		_feet = [_bone("LeftFoot"), _bone("RightFoot")]
	if _player != null:
		_player.animation_started.connect(_on_animation_started)
		_player.animation_finished.connect(_on_animation_finished)
	_wind_root = Node3D.new()
	_wind_root.name = "WindAtHorns"
	add_child(_wind_root)
	for i: int in range(wind_streak_count):
		var streak: MeshInstance3D = MeshInstance3D.new()
		streak.mesh = _ribbon(i)
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = WIND_SHADER
		material.set_shader_parameter("wind_color", wind_tint)
		material.set_shader_parameter("phase", float(i) * 0.173)
		streak.material_override = material
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_wind_root.add_child(streak)
		_wind_materials.append(material)
	_ring = MeshInstance3D.new()
	_ring.mesh = _annulus()
	_ring_material = ShaderMaterial.new()
	_ring_material.shader = WIND_SHADER
	_ring_material.set_shader_parameter("ring", true)
	_ring_material.set_shader_parameter("wind_color", Color(0.83, 0.94, 1.0, 0.50))
	_ring.material_override = _ring_material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	for i: int in range(3):
		var particles: CPUParticles3D = _make_dust(impact_particle_count if i == 2 else foot_particle_count)
		particles.name = "ImpactDust" if i == 2 else "FootDust%d" % i
		add_child(particles)
		_dust.append(particles)
	_apply_time(-1.0)
	set_process(false)
	if auto_sync and _player != null and _player.is_playing():
		_on_animation_started(_player.current_animation)

func _process(delta: float) -> void:
	if _external_clock:
		return
	var time: float = -1.0
	if auto_sync and _player and _following_charge and _player.is_playing():
		time = _player.current_animation_position
		_manual = false
	elif _manual:
		_clock += delta
		time = _clock
		if time > charge_duration:
			stop_charge()
			return
	else:
		stop_charge()
		return
	_apply_time(time)

func play_charge() -> void:
	_external_clock = false
	_following_charge = false
	_manual = true
	_clock = 0.0
	_reset_events()
	_apply_time(0.0)
	set_process(true)

func stop_charge() -> void:
	_manual = false
	_following_charge = false
	_external_clock = false
	_clock = -1.0
	_apply_time(-1.0)
	set_process(false)

func set_charge_time(seconds: float) -> void:
	_external_clock = true
	set_process(false)
	_apply_time(seconds)

func _on_animation_started(animation_name: StringName) -> void:
	if not auto_sync:
		return
	if String(animation_name).get_file() == String(charge_animation):
		_external_clock = false
		_following_charge = true
		_manual = false
		_reset_events()
		set_process(true)
	else:
		stop_charge()

func _on_animation_finished(animation_name: StringName) -> void:
	if auto_sync and String(animation_name).get_file() == String(charge_animation):
		stop_charge()

func _find_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child: Node in node.get_children():
		var found: Node = _find_type(child, type_name)
		if found:
			return found
	return null

func _bone(suffix: String) -> int:
	for i: int in range(_skeleton.get_bone_count()):
		if _skeleton.get_bone_name(i).ends_with(suffix):
			return i
	return -1

func _bone_position(index: int, fallback: Vector3) -> Vector3:
	if _skeleton and index >= 0:
		return to_local(_skeleton.to_global(_skeleton.get_bone_global_pose(index).origin))
	return fallback * effect_scale

func _reset_events() -> void:
	_previous_time = -1.0
	_was_low[0] = false
	_was_low[1] = false
	_last_puff[0] = -1.0
	_last_puff[1] = -1.0
	for particles: CPUParticles3D in _dust:
		particles.emitting = false

func _apply_time(time: float) -> void:
	if time >= 0.0 and (_previous_time < 0.0 or time < _previous_time - 0.05):
		_reset_events()
	var head: Vector3 = _bone_position(_head_bone, Vector3(0.0, 0.98, 0.08))
	var facing: float = 1.0 if forward_positive_z else -1.0
	_wind_root.position = head
	_wind_root.scale = Vector3(effect_scale, effect_scale, effect_scale * facing)
	var strength: float = smoothstep(0.30, 0.57, time) * (1.0 - smoothstep(2.17, 2.45, time))
	_wind_root.visible = strength > 0.001
	for material: ShaderMaterial in _wind_materials:
		material.set_shader_parameter("effect_time", time)
		material.set_shader_parameter("strength", strength)
	var burst: float = (time - impact_time) / 0.24
	_ring.visible = burst >= 0.0 and burst <= 1.0
	if _ring.visible:
		_ring.position = head + Vector3(0.0, -0.03, (0.26 + burst * 0.14) * facing * effect_scale)
		_ring.scale = Vector3.ONE * lerpf(0.22, 0.72, burst) * effect_scale
		_ring_material.set_shader_parameter("strength", pow(1.0 - burst, 1.7))
	if time >= impact_time and _previous_time >= 0.0 and _previous_time < impact_time:
		_emit_dust(2, Vector3(0.0, 0.035, 0.10 * facing), 1.6)
		impact.emit()
	if time >= 0.40 and time <= 2.20:
		for i: int in range(2):
			var foot: Vector3 = _bone_position(_feet[i], Vector3(0.19 if i == 0 else -0.19, 0.08, 0.0))
			var low: bool = foot.y < 0.115 * effect_scale
			if low and not _was_low[i] and time - _last_puff[i] > 0.17:
				_emit_dust(i, Vector3(foot.x, 0.018 * effect_scale, foot.z), 1.0)
				_last_puff[i] = time
			_was_low[i] = low
	else:
		_was_low[0] = false
		_was_low[1] = false
	_previous_time = time

func _emit_dust(index: int, point: Vector3, size: float) -> void:
	var particles: CPUParticles3D = _dust[index]
	particles.position = point
	particles.scale = Vector3.ONE * size * effect_scale
	particles.restart()
	particles.emitting = true

func _make_dust(count: int) -> CPUParticles3D:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.emitting = false
	particles.amount = count
	particles.lifetime = 0.42
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.local_coords = false
	particles.direction = Vector3(0.0, 0.36, -1.0 if forward_positive_z else 1.0)
	particles.spread = 42.0
	particles.gravity = Vector3(0.0, -0.23, 0.0)
	particles.initial_velocity_min = 0.22
	particles.initial_velocity_max = 0.55
	particles.scale_amount_min = 0.06
	particles.scale_amount_max = 0.14
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.035
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(dust_tint.r, dust_tint.g, dust_tint.b, 0.0))
	gradient.set_color(1, Color(dust_tint.r, dust_tint.g, dust_tint.b, 0.0))
	gradient.add_point(0.12, dust_tint)
	particles.color_ramp = gradient
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.25))
	curve.add_point(Vector2(0.35, 0.80))
	curve.add_point(Vector2(1.0, 1.0))
	particles.scale_amount_curve = curve
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = DUST_SHADER
	quad.material = material
	particles.mesh = quad
	return particles

func _ribbon(id: int) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var angle: float = float(id) * TAU / float(wind_streak_count) + 0.17
	var radial: Vector3 = Vector3(cos(angle), sin(angle), 0.0)
	var width_axis: Vector3 = Vector3(-sin(angle), cos(angle), 0.0)
	for j: int in range(25):
		var t: float = float(j) / 24.0
		var radius: float = lerpf(0.16, 0.40, t) + sin(t * PI) * 0.10
		var center: Vector3 = radial * radius + Vector3(0.0, -0.09 * t, 0.30 - 1.12 * t)
		center += width_axis * sin(t * PI * 1.5 + float(id)) * 0.035
		var width: float = (0.011 + float(id % 3) * 0.003) * sin(PI * (0.04 + t * 0.92))
		vertices.append(center - width_axis * width)
		vertices.append(center + width_axis * width)
		uv.append(Vector2(t, 0.0))
		uv.append(Vector2(t, 1.0))
		if j < 24:
			var k: int = j * 2
			indices.append_array(PackedInt32Array([k, k + 1, k + 2, k + 1, k + 3, k + 2]))
	return _mesh(vertices, uv, indices)

func _annulus() -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for j: int in range(65):
		var t: float = float(j) / 64.0
		var axis: Vector3 = Vector3(cos(t * TAU), sin(t * TAU), 0.0)
		vertices.append(axis * 0.94)
		vertices.append(axis)
		uv.append(Vector2(t, 0.0))
		uv.append(Vector2(t, 1.0))
		if j < 64:
			var k: int = j * 2
			indices.append_array(PackedInt32Array([k, k + 1, k + 2, k + 1, k + 3, k + 2]))
	return _mesh(vertices, uv, indices)

func _mesh(vertices: PackedVector3Array, uv: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
