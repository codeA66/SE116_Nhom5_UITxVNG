extends Node3D
## Giữ đồng hồ riêng để vệt không treo trên sàn khi game đang hitstop.

signal finished(slot: Node)

const USEC_PER_SECOND: float = 1000000.0
const MIN_DURATION: float = 0.001

@export_group("Blade Glint")
@export_range(0.05, 1.0) var glint_size: float = 0.48
@export_range(0.0, 1.0) var swing_glint_fade: float = 0.72

var arc_mesh: Mesh
var radial_limits: Vector2

var _start_usec: int
var _hold: float
var _breakup: float
var _tail: float
var _prime_lead: float
var _prime_limit: float
var _striking: bool = false
var _preparing: bool = false
var _blade: Node3D
var _tip_offset: Vector3

@onready var _body: MeshInstance3D = $Body
@onready var _halo: MeshInstance3D = $Halo
@onready var _glint: MeshInstance3D = $BladeGlint
@onready var _body_material: ShaderMaterial = _body.material_override as ShaderMaterial
@onready var _halo_material: ShaderMaterial = _halo.material_override as ShaderMaterial
@onready var _glint_material: ShaderMaterial = _glint.material_override as ShaderMaterial


func _ready() -> void:
	_body.mesh = arc_mesh
	_halo.mesh = arc_mesh
	_body_material.set_shader_parameter(&"radial_limits", radial_limits)
	_halo_material.set_shader_parameter(&"radial_limits", radial_limits)
	_glint.scale = Vector3.ONE * glint_size
	pool_released()


func _process(_delta: float) -> void:
	var age: float = float(Time.get_ticks_usec() - _start_usec) / USEC_PER_SECOND
	if not _striking:
		if age >= _prime_limit:
			finished.emit(self)
			return
		_update_glint(lerpf(0.78, 0.03, clampf(age / _prime_lead, 0.0, 1.0)))
		return
	var end_arc: float = _hold + _breakup
	if age >= end_arc + _tail:
		finished.emit(self)
		return
	if age < end_arc:
		var progress: float = clampf((age - _hold) / _breakup, 0.0, 1.0)
		_set_breakup(progress)
		_update_glint(swing_glint_fade)
	else:
		_body.hide()
		_halo.hide()
		var tail_age: float = clampf((age - end_arc) / maxf(_tail, MIN_DURATION), 0.0, 1.0)
		_update_glint(lerpf(swing_glint_fade, 1.0, tail_age))


func prime(blade_node: Node3D, blade_offset: Vector3, lead: float, reserve_time: float) -> void:
	_blade = blade_node
	_tip_offset = blade_offset
	_prime_lead = maxf(lead, MIN_DURATION)
	_prime_limit = _prime_lead + maxf(reserve_time, MIN_DURATION)
	_start_usec = Time.get_ticks_usec()
	_update_glint(0.30)
	set_process(true)


func prepare_shaders(at: Vector3, opacity: float) -> void:
	_preparing = true
	global_transform = Transform3D(Basis.IDENTITY, at)
	_body.scale = Vector3.ONE
	_halo.scale = Vector3.ONE
	_glint.position = Vector3.ZERO
	reset_physics_interpolation()
	_set_breakup(0.0)
	_body_material.set_shader_parameter(&"visibility_weight", opacity)
	_halo_material.set_shader_parameter(&"visibility_weight", opacity)
	_glint_material.set_shader_parameter(&"fade", 1.0 - opacity)
	_body.show()
	_halo.show()
	_glint.show()


func is_preparing_shaders() -> bool:
	return _preparing


func strike(pose: Transform3D, radius: float, returning: bool, hold: float, breakup: float,
		tail: float, blade_node: Node3D, blade_offset: Vector3) -> void:
	_blade = blade_node
	_tip_offset = blade_offset
	_hold = maxf(hold, 0.0)
	_breakup = maxf(breakup, MIN_DURATION)
	_tail = maxf(tail, 0.0)
	_striking = true
	global_transform = pose
	_body.scale = Vector3.ONE * radius
	_halo.scale = _body.scale
	reset_physics_interpolation()
	_body_material.set_shader_parameter(&"returning", returning)
	_halo_material.set_shader_parameter(&"returning", returning)
	_set_breakup(0.0)
	_body.show()
	_halo.show()
	_update_glint(swing_glint_fade)
	_start_usec = Time.get_ticks_usec()
	set_process(true)


func pool_released() -> void:
	set_process(false)
	_body.hide()
	_halo.hide()
	_glint.hide()
	_blade = null
	_striking = false
	if _preparing:
		_preparing = false
		_body_material.set_shader_parameter(&"visibility_weight", 1.0)
		_halo_material.set_shader_parameter(&"visibility_weight", 1.0)


func _set_breakup(value: float) -> void:
	_body_material.set_shader_parameter(&"breakup", value)
	_halo_material.set_shader_parameter(&"breakup", value)


func _update_glint(fade: float) -> void:
	if not is_instance_valid(_blade) or not _blade.is_visible_in_tree():
		_glint.hide()
		return
	_glint.global_position = _blade.to_global(_tip_offset)
	_glint_material.set_shader_parameter(&"fade", fade)
	_glint.show()
