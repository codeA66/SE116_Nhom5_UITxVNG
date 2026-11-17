extends Node3D
## Giữ các lớp nổ trên cùng đồng hồ để trả về pool không sót tia, đá hay vết cháy.

enum Kind { RAIN, SLAM, LIFT, LAND, SENTINEL_IN, SENTINEL_OUT, ENRAGE, COLLAPSE }

@export_group("Mặt sàn")
@export var floor_offset: float = 0.045
@export var ring_radius_ratio: float = 1.05
@export var scorch_radius_ratio: float = 0.86
@export var flame_material: Material
@export_group("Hạt")
@export_range(0.0, 1.0) var normal_ember_ratio: float = 0.65

static var _flame_mesh: ArrayMesh

var _elapsed: float
var _duration: float
var _radius: float
var _hot: bool
var _has_scorch: bool
var _has_shock: bool
var _reach: float

@onready var _ring: MeshInstance3D = $Ring
@onready var _echo: MeshInstance3D = $Echo
@onready var _flare: MeshInstance3D = $Flare
@onready var _scorch: MeshInstance3D = $Scorch
@onready var _embers: GPUParticles3D = $Embers
@onready var _smoke: GPUParticles3D = $Smoke
@onready var _rocks: GPUParticles3D = $Rocks
@onready var _flames: GPUParticles3D = $Flames
@onready var _ring_material: ShaderMaterial = _ring.material_override as ShaderMaterial
@onready var _echo_material: ShaderMaterial = _echo.material_override as ShaderMaterial
@onready var _flare_material: ShaderMaterial = _flare.material_override as ShaderMaterial
@onready var _scorch_material: ShaderMaterial = _scorch.material_override as ShaderMaterial


func _ready() -> void:
	if _flame_mesh == null:
		_flame_mesh = _build_flame_mesh()
	_flames.draw_pass_1 = _flame_mesh
	reset()


func _process(delta: float) -> void:
	_elapsed += delta
	var progress: float = minf(_elapsed / _duration, 1.0)
	if progress >= 1.0:
		reset()
		return
	_draw_burst(progress)


func play(world_point: Vector3, radius: float, kind: Kind, hot: bool, duration: float) -> void:
	reset()
	if duration <= 0.0:
		return
	global_position = world_point + Vector3.UP * floor_offset
	reset_physics_interpolation()
	_radius = radius
	_duration = duration
	_hot = hot
	_has_scorch = kind == Kind.RAIN or kind == Kind.SLAM or kind == Kind.LAND
	_has_shock = _has_scorch or kind == Kind.ENRAGE or kind == Kind.COLLAPSE
	_reach = 1.35 if kind == Kind.SLAM or kind == Kind.LAND or kind == Kind.ENRAGE else 1.0
	visible = true
	_ring.visible = _has_shock or kind == Kind.LIFT
	_echo.visible = _has_shock and kind != Kind.RAIN
	_flare.visible = kind != Kind.SENTINEL_OUT
	_scorch.visible = _has_scorch
	_embers.amount_ratio = 1.0 if hot else normal_ember_ratio
	_restart(_embers, duration)
	_restart(_smoke, duration)
	if _has_shock:
		_flames.scale = Vector3.ONE * clampf(radius * 0.68, 0.08, 2.45)
		_flames.amount_ratio = 1.0 if hot else 0.76
		_restart(_flames, duration * 0.86)
	if kind == Kind.SLAM or kind == Kind.LAND:
		_restart(_rocks, duration)
	_draw_burst(0.0)
	set_process(true)


func reset() -> void:
	visible = false
	set_process(false)
	_elapsed = 0.0
	_ring.hide()
	_echo.hide()
	_scorch.hide()
	_flare.hide()
	_embers.emitting = false
	_smoke.emitting = false
	_rocks.emitting = false
	_flames.emitting = false
	_embers.hide()
	_smoke.hide()
	_rocks.hide()
	_flames.hide()


func _draw_burst(progress: float) -> void:
	var out: float = 1.0 - pow(1.0 - progress, 3.0)
	var wave: float = 1.0 - smoothstep(0.23, 0.93, progress)
	var flash: float = 1.0 - smoothstep(0.02, 0.42, progress)
	var ring_size: float = _radius * lerpf(0.38, ring_radius_ratio * _reach, out)
	_ring.scale = Vector3(ring_size, 1.0, ring_size)
	_ring_material.set_shader_parameter(&"opacity", wave)
	var echo_size: float = ring_size * 0.73
	_echo.scale = Vector3(echo_size, 1.0, echo_size)
	_echo_material.set_shader_parameter(&"opacity", wave)
	var flare_size: float = _radius * lerpf(0.35, 1.17, out)
	_flare.scale = Vector3(flare_size, 1.0, flare_size)
	_flare_material.set_shader_parameter(&"opacity", flash * (1.0 if _hot else 0.75))
	var scorch_size: float = _radius * scorch_radius_ratio
	_scorch.scale = Vector3(scorch_size, 1.0, scorch_size)
	_scorch_material.set_shader_parameter(&"opacity", smoothstep(0.02, 0.28, progress) * (1.0 - smoothstep(0.44, 1.0, progress)))


func _build_flame_mesh() -> ArrayMesh:
	# Nếp gấp lệch tâm giữ dáng ngọn lửa khi nhìn từ trên và lúc các hạt quay.
	var outline: PackedVector2Array = PackedVector2Array([
		Vector2(-0.12, -0.28), Vector2(0.14, -0.28), Vector2(0.22, -0.03),
		Vector2(0.17, 0.28), Vector2(0.21, 0.72), Vector2(0.02, 0.48),
		Vector2(-0.03, 0.29), Vector2(-0.16, 0.37), Vector2(-0.21, 0.03),
	])
	var vertices: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	for turn: float in [0.0, PI * 0.5]:
		for i: int in range(outline.size()):
			var a: Vector2 = outline[i]
			var b: Vector2 = outline[(i + 1) % outline.size()]
			vertices.append(Vector3(0.0, 0.02, 0.05).rotated(Vector3.UP, turn))
			vertices.append(Vector3(a.x, a.y, 0.0).rotated(Vector3.UP, turn))
			vertices.append(Vector3(b.x, b.y, 0.0).rotated(Vector3.UP, turn))
			colors.append(Color(1.0, 0.98, 0.78))
			colors.append(Color(1.0, 0.51, 0.22))
			colors.append(Color(0.91, 0.30, 0.12))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, flame_material)
	return mesh


func _restart(particle: GPUParticles3D, duration: float) -> void:
	particle.lifetime = duration
	particle.show()
	particle.restart()
	particle.emitting = true
