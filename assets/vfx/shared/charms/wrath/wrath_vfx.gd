extends Node3D
## Tách khỏi Model để khí lực còn đọc được trong các nhịp chớp i-frame.

const MAX_PARTICLES: int = 24
const MAX_BURST_PARTICLES: int = 12
const MAX_WISP_PARTICLES: int = 8

@export_group("Hình ảnh")
@export var style: WrathVfxStyle

var _active: bool = false
var _left: float = 0.0
var _age: float = 0.0
var _pulse_age: float = 0.0
var _pulse_strength: float = 1.0
var _remaining_source: Callable
var _materials: Array[ShaderMaterial] = []
var _pulse_material: ShaderMaterial
var _pressure_material: ShaderMaterial
var _spawn_time: float = 0.14
var _fade_time: float = 0.20
var _pulse_time: float = 0.24

@onready var _pulse: MeshInstance3D = $Pulse
@onready var _pressure: MeshInstance3D = $Pressure
@onready var _corona: MeshInstance3D = $Corona
@onready var _motes: CPUParticles3D = $Motes
@onready var _burst: CPUParticles3D = $Burst
@onready var _wisps: CPUParticles3D = $Wisps
@onready var _meshes: Array[MeshInstance3D] = [_pulse, _pressure, _corona]


func _ready() -> void:
	# Chỉ sao material một lần khi đeo; mọi lần bị đánh dùng lại mesh, material và hạt.
	_pulse_material = _copy_material(_pulse)
	_pressure_material = _copy_material(_pressure)
	_copy_material(_corona)
	var mote_material: ShaderMaterial = _motes.material_override.duplicate() as ShaderMaterial
	_motes.material_override = mote_material
	_burst.material_override = mote_material
	_materials.append(mote_material)
	var wisp_material: ShaderMaterial = _wisps.material_override.duplicate() as ShaderMaterial
	_wisps.material_override = wisp_material
	_materials.append(wisp_material)
	_apply_style()
	reset()


func _exit_tree() -> void:
	reset()


func _process(delta: float) -> void:
	# Đồng hồ gameplay quyết định thời điểm tắt, kể cả khi tụt FPS hoặc bị hitstop.
	_left = maxf(float(_remaining_source.call()), 0.0) if _remaining_source.is_valid() else maxf(_left - delta, 0.0)
	_age += delta
	_pulse_age += delta
	if _left <= 0.0:
		reset()
		return
	_update_visuals()


func configure(value: Resource, remaining_source: Callable = Callable()) -> void:
	style = value as WrathVfxStyle
	_remaining_source = remaining_source


func activate(duration: float) -> void:
	if not is_node_ready() or duration <= 0.0 or style == null:
		return
	_pulse_strength = style.refresh_strength if _active else 1.0
	_left = duration
	_pulse_age = 0.0
	if not _active:
		_age = 0.0
		_motes.process_mode = Node.PROCESS_MODE_INHERIT
		_motes.visible = style.particle_count > 0
		if _motes.visible:
			_motes.restart()
			_motes.emitting = true
		_wisps.process_mode = Node.PROCESS_MODE_INHERIT
		_wisps.visible = style.wisp_count > 0
		if _wisps.visible:
			_wisps.restart()
			_wisps.emitting = true
	_burst.process_mode = Node.PROCESS_MODE_INHERIT
	_burst.visible = style.burst_count > 0
	if _burst.visible:
		_burst.restart()
		_burst.emitting = true
	_active = true
	show()
	set_process(true)
	_update_visuals()


func reset() -> void:
	_active = false
	_left = 0.0
	_age = 0.0
	_pulse_age = 0.0
	_pulse_strength = 1.0
	hide()
	set_process(false)
	if is_instance_valid(_motes):
		_stop_particles(_motes)
		_stop_particles(_burst)
		_stop_particles(_wisps)
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"strength", 0.0)
		material.set_shader_parameter(&"age", 0.0)
		material.set_shader_parameter(&"pulse_phase", 0.0)
		material.set_shader_parameter(&"envelope", 0.0)


func dispose() -> void:
	reset()
	queue_free()


func is_active() -> bool:
	return _active


func _copy_material(mesh: MeshInstance3D) -> ShaderMaterial:
	var material: ShaderMaterial = mesh.material_override.duplicate() as ShaderMaterial
	mesh.material_override = material
	_materials.append(material)
	return material


func _stop_particles(particles: CPUParticles3D) -> void:
	particles.emitting = false
	particles.hide()
	particles.process_mode = Node.PROCESS_MODE_DISABLED


func _apply_style() -> void:
	if style == null:
		return
	_spawn_time = maxf(style.spawn_time, 0.001)
	_fade_time = maxf(style.fade_time, 0.001)
	_pulse_time = maxf(style.pulse_time, 0.001)
	var radius: float = maxf(style.radius, 0.0)
	var rise: float = maxf(style.rise, 0.0)
	var width: float = maxf(style.stroke_width, 0.0)
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"ink_color", style.ink_color)
		material.set_shader_parameter(&"edge_color", style.edge_color)
		material.set_shader_parameter(&"accent_color", style.accent_color)
		material.set_shader_parameter(&"radius", radius)
		material.set_shader_parameter(&"center_height", style.center_height)
		material.set_shader_parameter(&"rise", rise)
		material.set_shader_parameter(&"stroke_width", width)
		material.set_shader_parameter(&"arc_span", clampf(style.arc_span, 0.0, 1.0))
		material.set_shader_parameter(&"spin_speed", maxf(style.spin_speed, 0.0))
		material.set_shader_parameter(&"pulse_radius_ratio", maxf(style.pulse_radius_ratio, 0.0))
	var extent: float = maxf(radius * maxf(style.pulse_radius_ratio, 1.6) + width, 0.05)
	var min_y: float = minf(0.0, style.center_height - rise - width)
	var max_y: float = maxf(style.center_height + rise + width, 0.05)
	var bounds: AABB = AABB(Vector3(-extent, min_y, -extent), Vector3(extent * 2.0, max_y - min_y, extent * 2.0))
	for mesh: MeshInstance3D in _meshes:
		mesh.custom_aabb = bounds
	_configure_particles(_motes, style.particle_count, MAX_PARTICLES, style.particle_lifetime, style.particle_speed, style.particle_size)
	_motes.position.y = style.center_height * 0.5
	_motes.emission_ring_radius = radius * 0.8
	_motes.emission_ring_inner_radius = radius * 0.35
	_motes.emission_ring_height = rise * 0.35
	_configure_particles(_burst, style.burst_count, MAX_BURST_PARTICLES, style.burst_lifetime, style.burst_speed, style.burst_size)
	_burst.position.y = style.center_height
	_burst.emission_sphere_radius = radius * 0.3
	_configure_particles(_wisps, style.wisp_count, MAX_WISP_PARTICLES, style.wisp_lifetime, style.wisp_speed, style.wisp_size)
	_wisps.position.y = style.center_height * 0.4
	_wisps.emission_ring_radius = radius
	_wisps.emission_ring_inner_radius = radius * 0.7
	_wisps.emission_ring_height = rise * 0.3


func _configure_particles(particles: CPUParticles3D, count: int, cap: int, lifetime: float, speed: float, size_value: float) -> void:
	particles.amount = clampi(count, 1, cap)
	particles.lifetime = maxf(lifetime, 0.01)
	particles.initial_velocity_min = maxf(speed, 0.0) * 0.6
	particles.initial_velocity_max = maxf(speed, 0.0)
	particles.scale_amount_min = maxf(size_value, 0.0)
	particles.scale_amount_max = particles.scale_amount_min * 1.6


func _update_visuals() -> void:
	var fade: float = clampf(_left / _fade_time, 0.0, 1.0)
	var spin_up: float = clampf(_age / _spawn_time, 0.0, 1.0)
	var envelope: float = smoothstep(0.0, 1.0, minf(fade, spin_up))
	var strength: float = clampf(style.opacity, 0.0, 1.0) * fade
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"age", _age)
		material.set_shader_parameter(&"envelope", envelope)
		material.set_shader_parameter(&"strength", strength)
	_pulse.visible = _pulse_age < _pulse_time
	_pulse_material.set_shader_parameter(&"pulse_phase", clampf(_pulse_age / _pulse_time, 0.0, 1.0))
	_pulse_material.set_shader_parameter(&"strength", strength * _pulse_strength)
	_pressure_material.set_shader_parameter(&"strength", strength * clampf(style.pressure_opacity, 0.0, 1.0))
