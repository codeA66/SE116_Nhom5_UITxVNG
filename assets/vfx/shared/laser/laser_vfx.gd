class_name LaserVfx
extends Node3D
## Dùng kết quả đo tia của bẫy để hình ảnh và điểm va luôn cùng vị trí.

@export_group("Phong cách")
@export var style: LaserVfxStyle

var _warn_animation: Tween
var _flash_animation: Tween
var _shutdown_animation: Tween
var _beam_on: bool = false
var _hits_wall: bool = false
var _flash_amount: float = 0.0

@onready var _beam: MeshInstance3D = $Beam
@onready var _warning: MeshInstance3D = $Warning
@onready var _muzzle: Node3D = $MuzzleFx
@onready var _impact: Node3D = $ImpactFx
@onready var _muzzle_flare: MeshInstance3D = $MuzzleFx/Flare
@onready var _impact_flare: MeshInstance3D = $ImpactFx/Flare
@onready var _charge: GPUParticles3D = $MuzzleFx/Charge
@onready var _muzzle_burst: GPUParticles3D = $MuzzleFx/Burst
@onready var _impact_burst: GPUParticles3D = $ImpactFx/Burst
@onready var _impact_sparks: GPUParticles3D = $ImpactFx/Sparks


func _ready() -> void:
	if style == null:
		return
	_beam.material_override = style.beam_material
	_warning.material_override = style.beam_material
	_warning.set_instance_shader_parameter(&"warning", true)
	_muzzle.position.z = -style.face_offset
	_muzzle_flare.material_override = style.flare_material
	_muzzle_flare.set_instance_shader_parameter(&"sprite_size", style.muzzle_flare_size)
	_impact_flare.material_override = style.flare_material
	_impact_flare.set_instance_shader_parameter(&"sprite_size", style.impact_flare_size)
	_configure_particles(_charge, style.charge_motion, style.charge_amount, style.charge_lifetime)
	_configure_particles(_muzzle_burst, style.muzzle_burst_motion, style.muzzle_burst_amount,
		style.muzzle_burst_lifetime)
	_configure_particles(_impact_burst, style.impact_burst_motion, style.impact_burst_amount,
		style.impact_burst_lifetime)
	_configure_particles(_impact_sparks, style.impact_spark_motion, style.impact_spark_amount,
		style.impact_spark_lifetime)


func apply_phase(next: LaserEmitter.Phase, remaining: float, full_duration: float, ray_length: float,
		wall_normal: Vector3, beam_width: float, blink_rate: float, offset: float) -> void:
	if style == null:
		return
	_stop_warning()
	if next == LaserEmitter.Phase.ON:
		_start_beam(ray_length, wall_normal, beam_width, offset, full_duration - remaining)
		return
	_begin_shutdown()
	if next == LaserEmitter.Phase.WARN and remaining > 0.0:
		_start_warning(remaining, full_duration, ray_length, beam_width, blink_rate, offset)


func _configure_particles(emitter: GPUParticles3D, motion: Material, count: int, age: float) -> void:
	emitter.material_override = style.spark_material
	emitter.process_material = motion
	emitter.amount = clampi(count, 1, 12)
	emitter.lifetime = age


func _fit_ribbon(ribbon: MeshInstance3D, ray_length: float, width: float, offset: float) -> void:
	ribbon.position.z = -ray_length * 0.5
	# Render cắt theo hộp của mesh gốc, nên hộp phải bao cả phần shader kéo dài.
	var half_bounds: Vector3 = Vector3(width, width, ray_length * 0.5)
	ribbon.custom_aabb = AABB(-half_bounds, half_bounds * 2.0)
	ribbon.set_instance_shader_parameter(&"ray_length", ray_length)
	ribbon.set_instance_shader_parameter(&"ray_width", width)
	ribbon.set_instance_shader_parameter(&"flicker_offset", offset)


func _start_warning(remaining: float, full_duration: float, ray_length: float, beam_width: float,
		blink_rate: float, offset: float) -> void:
	_fit_ribbon(_warning, ray_length, beam_width * style.beam_width_scale * style.warn_width_ratio,
		offset)
	_warning.set_instance_shader_parameter(&"warn_blink_rate", blink_rate)
	var initial_progress: float = 1.0 - clampf(remaining / full_duration, 0.0, 1.0)
	_set_warn_progress(initial_progress)
	_warning.show()
	_charge.emitting = true
	_warn_animation = create_tween()
	_warn_animation.tween_method(_set_warn_progress, initial_progress, 1.0, remaining)


func _set_warn_progress(progress: float) -> void:
	var brightness: float = style.warn_curve.sample_baked(progress) if style.warn_curve else progress
	_warning.set_instance_shader_parameter(&"warn_progress", clampf(brightness, 0.0, 1.0))


func _stop_warning() -> void:
	if _warn_animation:
		_warn_animation.kill()
		_warn_animation = null
	_warning.hide()
	_charge.emitting = false


func _start_beam(ray_length: float, wall_normal: Vector3, beam_width: float, offset: float,
		elapsed: float) -> void:
	if _shutdown_animation:
		_shutdown_animation.kill()
		_shutdown_animation = null
	_beam_on = true
	_fit_ribbon(_beam, ray_length, beam_width * style.beam_width_scale, offset)
	_beam.set_instance_shader_parameter(&"envelope", 1.0)
	_beam.show()
	_hits_wall = not wall_normal.is_zero_approx()
	if _hits_wall:
		_impact.position = Vector3(0.0, 0.0, -ray_length) + wall_normal * style.face_offset
		_impact.basis = Basis(Quaternion(Vector3.BACK, wall_normal))
		_impact_sparks.emitting = true
	if is_zero_approx(elapsed):
		_muzzle_burst.restart()
		if _hits_wall:
			_impact_burst.restart()
	_muzzle_flare.show()
	_impact_flare.visible = _hits_wall
	var flash_left: float = style.flash_time - maxf(elapsed, 0.0)
	if flash_left <= 0.0:
		_set_flash(0.0)
		return
	var initial_flash: float = flash_left / style.flash_time
	_set_flash(initial_flash)
	_flash_animation = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_flash_animation.tween_method(_set_flash, initial_flash, 0.0, flash_left)


func _set_flash(amount: float) -> void:
	_flash_amount = amount
	_set_flare_envelope(1.0)


func _set_flare_envelope(envelope: float) -> void:
	var flash: float = _flash_amount * style.flash_strength
	_muzzle_flare.set_instance_shader_parameter(&"strength", (style.muzzle_glow + flash) * envelope)
	if _hits_wall:
		_impact_flare.set_instance_shader_parameter(&"strength", (style.impact_glow + flash) * envelope)


func _begin_shutdown() -> void:
	if not _beam_on:
		return
	_beam_on = false
	if _flash_animation:
		_flash_animation.kill()
		_flash_animation = null
	_muzzle_burst.emitting = false
	_impact_burst.emitting = false
	_impact_sparks.emitting = false
	_shutdown_animation = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shutdown_animation.tween_method(_set_shutdown, 1.0, 0.0, style.shutdown_time)
	_shutdown_animation.tween_callback(_hide_beam)


func _set_shutdown(amount: float) -> void:
	_beam.set_instance_shader_parameter(&"envelope", amount)
	_set_flare_envelope(amount)


func _hide_beam() -> void:
	_beam.hide()
	_muzzle_flare.hide()
	_impact_flare.hide()
