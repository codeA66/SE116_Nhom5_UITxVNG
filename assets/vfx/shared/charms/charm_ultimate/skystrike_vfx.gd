class_name SkystrikeVfx
extends Node3D

signal finished

const EPSILON: float = 0.001
const FLOOR_BIAS: float = 0.012
const TURN_STEP: float = 2.399963

@export_group("Models")
@export var wings_scene: PackedScene
@export var shot_scene: PackedScene
@export var shard_scene: PackedScene

@export_group("Palette")
@export var ivory: Color = Color(1.0, 0.96, 0.86)
@export var flash_white: Color = Color.WHITE
@export var rim_gold: Color = Color(1.0, 0.69, 0.25)
@export var fire_gold: Color = Color(1.0, 0.43, 0.12)
@export var fissure_amber: Color = Color(0.81, 0.30, 0.12)
@export var aiming_fill: Color = Color(0.46, 0.30, 0.16)
@export var dust_brown: Color = Color(0.48, 0.41, 0.36)
@export var scorch_brown: Color = Color(0.12, 0.088, 0.078)
@export var rock_brown: Color = Color(0.34, 0.30, 0.28)

@export_group("Lift")
@export_range(0.3, 2.0, 0.05) var wing_scale: float = 0.95
@export_range(0.0, 2.0, 0.05) var shoulder_height: float = 0.78
@export_range(0.2, 8.0, 0.1) var halo_size: float = 4.8
@export_range(0.0, 1.0, 0.01) var halo_opacity: float = 0.64
@export_range(0.0, 4.0, 0.05) var wing_scroll_speed: float = 0.64
@export_range(0.05, 2.0, 0.01) var lift_dust_life: float = 0.38
@export_range(0.1, 8.0, 0.1) var lift_dust_radius: float = 2.05

@export_group("Aim and Flight")
@export_range(0.0, 6.0, 0.05) var tick_rotation_speed: float = 1.9
@export_range(0.0, 0.4, 0.005) var anticipation_life: float = 0.12
@export_range(0.01, 1.6, 0.01) var anticipation_start_ratio: float = 0.94
@export_range(0.01, 1.0, 0.01) var anticipation_end_ratio: float = 0.15
@export_range(0.0, 2.0, 0.05) var projectile_height: float = 0.85
@export_range(0.1, 3.0, 0.05) var projectile_scale: float = 1.25
@export_range(0.1, 12.0, 0.05) var trail_length: float = 6.4
@export_range(0.1, 5.0, 0.05) var trail_width: float = 2.28
@export_range(0.0, 0.3, 0.01) var trail_residue_life: float = 0.075
@export_range(0.1, 6.0, 0.05) var release_size: float = 2.6
@export_range(0.01, 0.5, 0.01) var release_life: float = 0.11
@export_range(0.01, 0.30, 0.005) var release_flash_life: float = 0.055
@export_range(0.0, 0.5, 0.01) var release_shake: float = 0.18
@export_range(0.0, 6.0, 0.05) var release_light_energy: float = 2.5
@export_range(0.1, 12.0, 0.1) var release_light_range: float = 4.4

@export_group("Impact")
@export_range(0.01, 0.3, 0.001) var flash_life: float = 0.045
@export_range(0.1, 3.0, 0.01) var flash_size_ratio: float = 1.22
@export_range(0.05, 1.5, 0.01) var fire_life: float = 0.33
@export_range(0.1, 3.0, 0.01) var fire_size_ratio: float = 0.96
@export_range(0.05, 1.5, 0.01) var shock_life: float = 0.43
@export_range(0.02, 0.55, 0.01) var shock_band_width: float = 0.24
@export_range(0.1, 1.0, 0.01) var shock_expansion_fraction: float = 0.76
@export_range(0.0, 0.5, 0.01) var impact_shake: float = 0.34
@export_range(0.0, 6.0, 0.05) var impact_light_energy: float = 2.0
@export_range(0.2, 3.0, 0.05) var impact_light_range_ratio: float = 1.55

@export_group("Residue")
@export_range(0.05, 4.0, 0.05) var scorch_life: float = 2.0
@export_range(0.1, 1.5, 0.05) var scorch_radius_ratio: float = 1.0
@export_range(0.0, 1.0, 0.01) var scorch_opacity: float = 0.86
@export_range(0.05, 4.0, 0.05) var fissure_life: float = 1.28
@export_range(0.01, 1.0, 0.01) var fissure_reveal_time: float = 0.21
@export_range(0.0, 2.0, 0.01) var landing_dust_life: float = 0.26
@export_range(0.1, 5.0, 0.05) var landing_dust_radius: float = 1.15

@export_group("Debris")
@export_range(0.0, 0.7, 0.01) var dust_spawn_ratio: float = 0.21
@export_range(0, 20, 1) var shard_count: int = 10
@export_range(0.05, 2.0, 0.01) var shard_life: float = 0.68
@export_range(0.0, 40.0, 0.5) var shard_gravity: float = 15.0
@export_range(0.0, 12.0, 0.1) var shard_launch_speed: float = 3.9
@export_range(0.05, 2.0, 0.01) var shard_scale: float = 0.73
@export var shard_material: ShaderMaterial
@export var projectile_material: ShaderMaterial
@export var wing_material: ShaderMaterial
@export var wing_rim_material: ShaderMaterial

var _wings: Node3D
var _wing_left: Node3D
var _wing_right: Node3D
var _tip_left: Node3D
var _tip_right: Node3D
var _projectile: Node3D
var _shards: MultiMeshInstance3D
var _anchor: Vector3
var _view_basis: Basis
var _impact_basis: Basis
var _spot: Vector3
var _floor_normal: Vector3 = Vector3.UP
var _radius: float = 1.0
var _shot_from: Vector3
var _shot_to: Vector3
var _shot_direction: Vector3
var _trail_basis: Basis
var _shot_clock: float = -1.0
var _shot_life: float = 0.0
var _tail: float = 0.0
var _burst_clock: float = -1.0
var _burst_life: float = 0.0
var _land_clock: float = -1.0
var _lift_dust_clock: float = -1.0
var _takeoff_dust_started: bool = false

@onready var _halo: MeshInstance3D = $Lift/Halo
@onready var _lift_dust: MeshInstance3D = $Lift/WindDust
@onready var _wing_light: OmniLight3D = $Lift/Light
@onready var _aim: MeshInstance3D = $Flight/Aim
@onready var _anticipation: MeshInstance3D = $Flight/Anticipation
@onready var _release: MeshInstance3D = $Flight/Release
@onready var _trail: MeshInstance3D = $Flight/Trail
@onready var _release_light: OmniLight3D = $Flight/ReleaseLight
@onready var _flash: MeshInstance3D = $Impact/Flash
@onready var _fire: MeshInstance3D = $Impact/FireCore
@onready var _shock: MeshInstance3D = $Impact/Ground/Shock
@onready var _scorch: MeshInstance3D = $Impact/Ground/Scorch
@onready var _fissures: MeshInstance3D = $Impact/Ground/Fissures
@onready var _dust: CPUParticles3D = $Impact/Dust
@onready var _embers: CPUParticles3D = $Impact/Embers
@onready var _impact_light: OmniLight3D = $Impact/Light

@onready var _halo_mat: ShaderMaterial = _halo.material_override as ShaderMaterial
@onready var _lift_dust_mat: ShaderMaterial = _lift_dust.material_override as ShaderMaterial
@onready var _aim_mat: ShaderMaterial = _aim.material_override as ShaderMaterial
@onready var _anticipation_mat: ShaderMaterial = _anticipation.material_override as ShaderMaterial
@onready var _release_mat: ShaderMaterial = _release.material_override as ShaderMaterial
@onready var _trail_mat: ShaderMaterial = _trail.material_override as ShaderMaterial
@onready var _flash_mat: ShaderMaterial = _flash.material_override as ShaderMaterial
@onready var _fire_mat: ShaderMaterial = _fire.material_override as ShaderMaterial
@onready var _shock_mat: ShaderMaterial = _shock.material_override as ShaderMaterial
@onready var _scorch_mat: ShaderMaterial = _scorch.material_override as ShaderMaterial
@onready var _fissure_mat: ShaderMaterial = _fissures.material_override as ShaderMaterial
@onready var _dust_mat: ShaderMaterial = _dust.material_override as ShaderMaterial
@onready var _ember_mat: ShaderMaterial = _embers.material_override as ShaderMaterial


func _ready() -> void:
	_wings = wings_scene.instantiate() as Node3D
	add_child(_wings)
	_wing_left = _wings.find_child("WingLeft", true, false) as Node3D
	_wing_right = _wings.find_child("WingRight", true, false) as Node3D
	_tip_left = _wings.find_child("TipLeft", true, false) as Node3D
	_tip_right = _wings.find_child("TipRight", true, false) as Node3D
	_apply_mesh_materials(_wings, wing_material, wing_rim_material)
	_projectile = shot_scene.instantiate() as Node3D
	add_child(_projectile)
	_apply_mesh_materials(_projectile, projectile_material)
	_projectile.scale = Vector3.ONE * projectile_scale
	_shards = _make_shards()
	_build_dust_emitters()
	_apply_palette()
	pool_released()


func _process(delta: float) -> void:
	if _lift_dust_clock >= 0.0:
		_lift_dust_clock += delta
		_animate_lift_dust()
	if _shot_clock >= 0.0:
		_shot_clock += delta
		_animate_shot()
	if _burst_clock >= 0.0 and _burst_clock < _burst_life:
		_burst_clock = minf(_burst_clock + delta, _burst_life)
		_animate_impact()
	if _land_clock >= 0.0:
		_land_clock += delta
		if _lift_dust.visible:
			_animate_lift_dust()
		if _land_clock >= landing_dust_life and (_burst_clock < 0.0 or _burst_clock >= _burst_life):
			set_process(false)
			finished.emit()


func begin_cast(origin: Vector3, facing: Basis) -> void:
	_anchor = origin
	_view_basis = _camera_basis()
	_wings.show()
	_halo.show()
	_wing_light.show()
	_move_wings(origin, facing, 0.40)
	_pose(-1.18, -0.52)
	_light_wings(0.0, 0.35)
	set_process(true)


func lift(at: Vector3, facing: Basis, windup: float, upward: float) -> void:
	_move_wings(at, facing, lerpf(0.40, 1.0, windup))
	if upward <= 0.0:
		_pose(lerpf(-1.18, -0.90, windup), -0.52)
		_light_wings(0.10 * windup, lerpf(0.36, 0.69, windup))
		return
	var stroke: float = smoothstep(0.0, 0.40, upward)
	var settle: float = smoothstep(0.40, 1.0, upward)
	_pose(lerpf(lerpf(-0.90, 0.64, stroke), -0.16, settle), lerpf(0.34, -0.37, settle))
	_light_wings(lerpf(0.10, 1.0, upward), lerpf(1.0, 0.82, settle))
	if not _takeoff_dust_started and upward > 0.13:
		_takeoff_dust_started = true
		_lift_dust_clock = 0.0
		_animate_lift_dust()


func aim(at: Vector3, facing: Basis, target: Vector3, floor_normal: Vector3, radius: float,
		has_floor: bool, age: float, remaining: float) -> void:
	_move_wings(at, facing, 1.0)
	_pose(-0.16 + 0.095 * sin(age * 5.7), -0.37 + 0.07 * sin(age * 5.7 - 0.3))
	_light_wings(age * wing_scroll_speed, 0.80 + sin(age * 4.2) * 0.09)
	_aim.visible = has_floor
	if has_floor:
		_place_on_floor(_aim, target, _floor_basis(floor_normal), maxf(radius, EPSILON), FLOOR_BIAS * 2.0)
		_aim_mat.set_shader_parameter(&"remaining", clampf(remaining, 0.0, 1.0))
		_aim_mat.set_shader_parameter(&"rotation", age * tick_rotation_speed)


func release_shot(from: Vector3, to: Vector3, floor_normal: Vector3, radius: float, duration: float) -> void:
	_aim.hide()
	_pose(0.28, -0.62)
	_light_wings(0.86, 1.0)
	_radius = maxf(radius, EPSILON)
	_floor_normal = floor_normal
	_impact_basis = _floor_basis(floor_normal)
	_shot_from = from + Vector3.UP * projectile_height
	_shot_to = to
	_shot_life = maxf(duration, 0.0)
	_shot_clock = 0.0
	_shot_direction = _shot_from.direction_to(to)
	if _shot_direction.is_zero_approx():
		_shot_direction = Vector3.DOWN
	var view: Basis = _camera_basis()
	var side: Vector3 = view.z.cross(_shot_direction).normalized()
	if side.is_zero_approx():
		side = view.x
	_trail_basis = Basis(_shot_direction, side, _shot_direction.cross(side))
	_projectile.global_position = _shot_from
	_projectile.look_at(_shot_from + _shot_direction,
		Vector3.FORWARD if absf(_shot_direction.y) > 0.95 else Vector3.UP, true)
	_projectile.show()
	_release.global_transform = Transform3D(view.scaled(Vector3.ONE * release_size), _shot_from)
	_release_light.global_position = _shot_from
	ScreenShake.add_trauma(release_shake)
	_animate_shot()
	advance_flight(_shot_life)


func advance_flight(remaining: float) -> void:
	# Dùng đồng hồ bay của state để vòng co chạm đúng lúc đòn có hiệu lực.
	var duration: float = minf(_shot_life, anticipation_life)
	_anticipation.visible = duration > EPSILON and remaining > 0.0 and remaining <= duration
	if not _anticipation.visible:
		return
	var t: float = 1.0 - clampf(remaining / duration, 0.0, 1.0)
	var size_ratio: float = lerpf(anticipation_start_ratio, anticipation_end_ratio, t * t)
	_place_on_floor(_anticipation, _shot_to, _impact_basis, _radius * size_ratio, FLOOR_BIAS * 2.5)
	_anticipation_mat.set_shader_parameter(&"opacity", 0.64 + 0.28 * t)


func burst(at: Vector3, floor_normal: Vector3, radius: float) -> void:
	_end_shot(true)
	_burst_clock = 0.0
	_burst_life = maxf(maxf(scorch_life, fissure_life), maxf(maxf(shock_life, fire_life), flash_life))
	_burst_life = maxf(_burst_life, maxf(maxf(_dust.lifetime, _embers.lifetime), maxf(shard_life, trail_residue_life)))
	_radius = maxf(radius, EPSILON)
	_spot = at
	_floor_normal = floor_normal
	_impact_basis = _floor_basis(floor_normal)
	_view_basis = _camera_basis()
	_place_on_floor(_scorch, at, _impact_basis, _radius * scorch_radius_ratio, FLOOR_BIAS)
	_place_on_floor(_fissures, at, _impact_basis, _radius, FLOOR_BIAS * 2.0)
	_place_on_floor(_shock, at, _impact_basis, _radius, FLOOR_BIAS * 3.0)
	_impact_light.global_position = at + floor_normal * (_radius * 0.32)
	_impact_light.omni_range = _radius * impact_light_range_ratio
	_start_debris()
	_animate_impact()
	ScreenShake.add_trauma(impact_shake)


func begin_descent() -> void:
	_aim.hide()
	_end_shot(_burst_clock >= 0.0)


func descend(at: Vector3, facing: Basis, progress: float) -> void:
	_move_wings(at, facing, lerpf(1.0, 0.08, progress * progress))
	_pose(lerpf(-0.30, -1.15, progress), lerpf(-0.27, -0.68, progress))
	_light_wings(lerpf(1.0, 0.0, progress), 0.79 * (1.0 - progress))


func land() -> void:
	_wings.hide()
	_halo.hide()
	_wing_light.hide()
	_aim.hide()
	_lift_dust_clock = -1.0
	_land_clock = 0.0
	_animate_lift_dust()


func pool_released() -> void:
	_wings.hide()
	_halo.hide()
	_wing_light.hide()
	_lift_dust.hide()
	_aim.hide()
	_end_shot()
	_flash.hide()
	_fire.hide()
	_shock.hide()
	_scorch.hide()
	_fissures.hide()
	_shards.hide()
	_impact_light.hide()
	_dust.emitting = false
	_dust.hide()
	_embers.emitting = false
	_embers.hide()
	_burst_clock = -1.0
	_land_clock = -1.0
	_lift_dust_clock = -1.0
	_takeoff_dust_started = false
	set_process(false)


func _animate_lift_dust() -> void:
	var on_landing: bool = _land_clock >= 0.0
	var elapsed: float = _land_clock if on_landing else _lift_dust_clock
	var life: float = landing_dust_life if on_landing else lift_dust_life
	var t: float = _age_rate(elapsed, life)
	_lift_dust.visible = t < 1.0
	if not _lift_dust.visible:
		_lift_dust_clock = -1.0
		return
	var radius: float = landing_dust_radius if on_landing else lift_dust_radius
	_place_on_floor(_lift_dust, _anchor, Basis.IDENTITY, radius * lerpf(0.31, 1.0, 1.0 - (1.0 - t) * (1.0 - t)),
		FLOOR_BIAS * 1.5)
	_lift_dust_mat.set_shader_parameter(&"age", t)
	_lift_dust_mat.set_shader_parameter(&"opacity", (1.0 - t) * (0.64 if on_landing else 0.93))


func _animate_shot() -> void:
	var t: float = _age_rate(_shot_clock, _shot_life)
	var head: Vector3 = _shot_from.lerp(_shot_to, t * t * 0.45 + t * 0.55)
	_projectile.global_position = head
	_tail = minf(trail_length, _shot_from.distance_to(head))
	_draw_trail(head, _tail, 1.48 - t * 0.19, t)
	var age: float = _age_rate(_shot_clock, release_life)
	_release.visible = age < 1.0
	var flash: float = 1.0 - _age_rate(_shot_clock, release_flash_life)
	_release_mat.set_shader_parameter(&"opacity", 0.95 * (1.0 - age) + flash * 1.4)
	_release_light.visible = flash > 0.0
	_release_light.light_energy = release_light_energy * flash * flash


func _draw_trail(head: Vector3, tail: float, opacity: float, age: float) -> void:
	_trail.visible = tail > EPSILON and opacity > 0.0
	if not _trail.visible:
		return
	var size_by: Vector3 = Vector3(tail, trail_width, 1.0)
	_trail.global_transform = Transform3D(_trail_basis * Basis.from_scale(size_by), head - _shot_direction * tail * 0.46)
	_trail_mat.set_shader_parameter(&"age", age)
	_trail_mat.set_shader_parameter(&"opacity", opacity)


func _end_shot(keep_trail: bool = false) -> void:
	_shot_clock = -1.0
	_anticipation.hide()
	_projectile.hide()
	_release.hide()
	_release_light.hide()
	if not keep_trail:
		_trail.hide()
		_tail = 0.0


func _animate_impact() -> void:
	if _trail.visible:
		var age: float = _age_rate(_burst_clock, trail_residue_life)
		_draw_trail(_spot, _tail * lerpf(1.0, 0.55, age), (1.0 - age) * 0.72, 1.0 + age)
	_animate_ground()
	_animate_light()
	_animate_shards()
	_dust.visible = _burst_clock < _dust.lifetime
	_embers.visible = _burst_clock < _embers.lifetime


func _animate_ground() -> void:
	var wave: float = _age_rate(_burst_clock, shock_life)
	_shock.visible = wave < 1.0
	if _shock.visible:
		var reach: float = clampf(wave / maxf(shock_expansion_fraction, EPSILON), 0.0, 1.0)
		_shock_mat.set_shader_parameter(&"front", lerpf(0.16, 1.0, 1.0 - pow(1.0 - reach, 2.0)))
		_shock_mat.set_shader_parameter(&"opacity", (1.0 - smoothstep(0.30, 1.0, wave)) * 1.10)
	var char_age: float = _age_rate(_burst_clock, scorch_life)
	_scorch.visible = char_age < 1.0
	if _scorch.visible:
		var dim: float = 1.0 - smoothstep(0.42, 1.0, char_age)
		_scorch_mat.set_shader_parameter(&"opacity", dim * scorch_opacity)
	var split: float = _age_rate(_burst_clock, fissure_life)
	_fissures.visible = split < 1.0
	if _fissures.visible:
		var reveal: float = _age_rate(_burst_clock, fissure_reveal_time)
		_fissure_mat.set_shader_parameter(&"reveal", lerpf(0.08, 1.0, smoothstep(0.0, 1.0, reveal)))
		_fissure_mat.set_shader_parameter(&"heat", 1.0 - smoothstep(0.03, 0.87, split))
		_fissure_mat.set_shader_parameter(&"opacity", 1.0 - smoothstep(0.50, 1.0, split))


func _animate_light() -> void:
	var flash: float = _age_rate(_burst_clock, flash_life)
	_flash.visible = flash < 1.0
	if _flash.visible:
		var width: float = _radius * flash_size_ratio
		_place_card(_flash, _spot + _floor_normal * (width * 0.15), width, width * 0.82)
		_flash_mat.set_shader_parameter(&"opacity", (1.0 - flash * flash) * 1.85)
	var fire: float = _age_rate(_burst_clock, fire_life)
	_fire.visible = fire < 1.0
	_impact_light.visible = fire < 1.0
	if _fire.visible:
		var swell: float = smoothstep(0.0, 0.43, fire)
		var cooling: float = 1.0 - smoothstep(0.24, 1.0, fire)
		var width: float = _radius * fire_size_ratio * lerpf(0.35, 1.0, swell)
		_place_card(_fire, _spot + _floor_normal * (width * 0.22), width, width * 0.77)
		_fire_mat.set_shader_parameter(&"age", fire)
		_fire_mat.set_shader_parameter(&"opacity", cooling * 1.20)
		_impact_light.light_energy = impact_light_energy * cooling * cooling


func _start_debris() -> void:
	_dust.global_transform = Transform3D(_impact_basis.scaled(Vector3.ONE * _radius), _spot)
	_dust.show()
	_dust.restart()
	_dust.emitting = true
	_embers.global_position = _spot + _floor_normal * (_radius * 0.10)
	_embers.direction = _floor_normal
	_embers.show()
	_embers.restart()
	_embers.emitting = true


func _animate_shards() -> void:
	var t: float = _age_rate(_burst_clock, shard_life)
	_shards.visible = t < 1.0 and _shards.multimesh.instance_count > 0
	if not _shards.visible:
		return
	var cool: float = 1.0 - smoothstep(0.12, 1.0, t)
	shard_material.set_shader_parameter(&"heat", cool)
	for index: int in _shards.multimesh.instance_count:
		var angle: float = float(index) * TURN_STEP
		var outward: Vector3 = _impact_basis * Vector3(cos(angle), 0.0, sin(angle))
		var distance: float = _radius * (0.11 + t * (0.52 + float(index % 3) * 0.17))
		var impulse: float = shard_launch_speed * (1.0 + float(index % 4) * 0.11)
		var height: float = maxf(FLOOR_BIAS, 0.12 + impulse * _burst_clock - 0.5 * shard_gravity * _burst_clock * _burst_clock)
		var point: Vector3 = _spot + outward * distance + _floor_normal * height
		var size_by: float = shard_scale * (0.69 + 0.15 * float(index % 4)) * (1.0 - smoothstep(0.63, 1.0, t))
		var spin: Basis = Basis.from_euler(Vector3(t * 4.8 + angle, t * 2.0, t * 3.4 - angle))
		_shards.multimesh.set_instance_transform(index, Transform3D(spin.scaled(Vector3.ONE * size_by), to_local(point)))


func _move_wings(at: Vector3, facing: Basis, opening: float) -> void:
	var origin: Vector3 = at + Vector3.UP * shoulder_height
	_wings.global_transform = Transform3D(facing.orthonormalized().scaled(Vector3.ONE * opening * wing_scale), origin)
	_wing_light.global_position = origin
	_place_card(_halo, origin - _view_basis.z * 0.39, halo_size * opening, halo_size * opening * 0.79)


func _pose(stroke: float, tip: float) -> void:
	_wing_left.rotation.z = stroke
	_wing_right.rotation.z = -stroke
	_tip_left.rotation.z = tip
	_tip_right.rotation.z = -tip


func _light_wings(scroll: float, power: float) -> void:
	wing_material.set_shader_parameter(&"scroll", scroll)
	wing_material.set_shader_parameter(&"opacity", power)
	wing_rim_material.set_shader_parameter(&"scroll", scroll)
	wing_rim_material.set_shader_parameter(&"opacity", power)
	_halo_mat.set_shader_parameter(&"opacity", power * halo_opacity)
	_wing_light.light_energy = power * 0.58


func _apply_palette() -> void:
	wing_material.set_shader_parameter(&"tint", rim_gold)
	wing_material.set_shader_parameter(&"edge_color", ivory)
	wing_rim_material.set_shader_parameter(&"tint", rim_gold)
	projectile_material.set_shader_parameter(&"tint", fire_gold)
	projectile_material.set_shader_parameter(&"edge_color", ivory)
	_halo_mat.set_shader_parameter(&"tint", rim_gold)
	_lift_dust_mat.set_shader_parameter(&"tint", dust_brown)
	_aim_mat.set_shader_parameter(&"tint", aiming_fill)
	_aim_mat.set_shader_parameter(&"edge_color", rim_gold)
	_anticipation_mat.set_shader_parameter(&"tint", rim_gold)
	_release_mat.set_shader_parameter(&"tint", rim_gold)
	_trail_mat.set_shader_parameter(&"tint", fire_gold)
	_trail_mat.set_shader_parameter(&"edge_color", ivory)
	_flash_mat.set_shader_parameter(&"tint", flash_white)
	_fire_mat.set_shader_parameter(&"tint", fire_gold)
	_fire_mat.set_shader_parameter(&"edge_color", ivory)
	_shock_mat.set_shader_parameter(&"tint", fire_gold)
	_shock_mat.set_shader_parameter(&"edge_color", rim_gold)
	_shock_mat.set_shader_parameter(&"band_width", shock_band_width)
	_scorch_mat.set_shader_parameter(&"tint", scorch_brown)
	_fissure_mat.set_shader_parameter(&"tint", fissure_amber)
	_fissure_mat.set_shader_parameter(&"edge_color", rim_gold)
	_dust_mat.set_shader_parameter(&"tint", dust_brown)
	_ember_mat.set_shader_parameter(&"tint", fire_gold)
	_ember_mat.set_shader_parameter(&"edge_color", rim_gold)
	shard_material.set_shader_parameter(&"tint", rock_brown)
	shard_material.set_shader_parameter(&"edge_color", fire_gold)
	_impact_light.light_color = fire_gold
	_wing_light.light_color = rim_gold
	_release_light.light_color = ivory
	_release_light.omni_range = release_light_range


func _build_dust_emitters() -> void:
	var points: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	for index: int in _dust.amount:
		var angle: float = TAU * float(index) / float(_dust.amount)
		var radial: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		points.append(radial * dust_spawn_ratio + Vector3.UP * 0.088)
		normals.append((radial + Vector3.UP * 0.18).normalized())
	_dust.emission_points = points
	_dust.emission_normals = normals


func _make_shards() -> MultiMeshInstance3D:
	var source_model: Node3D = shard_scene.instantiate() as Node3D
	var source: MeshInstance3D = source_model as MeshInstance3D
	if source == null:
		source = source_model.find_child("SkystrikeShard", true, false) as MeshInstance3D
	var batch: MultiMesh = MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = source.mesh
	batch.instance_count = clampi(shard_count, 0, 20)
	source_model.free()
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = &"RockShards"
	instance.multimesh = batch
	instance.material_override = shard_material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _apply_mesh_materials(model: Node3D, material: Material, overlay: Material = null) -> void:
	if model is MeshInstance3D:
		_style_mesh(model as MeshInstance3D, material, overlay)
	for part: Node in model.find_children("*", "MeshInstance3D", true, false):
		_style_mesh(part as MeshInstance3D, material, overlay)


func _style_mesh(mesh: MeshInstance3D, material: Material, overlay: Material) -> void:
	mesh.material_override = material
	mesh.material_overlay = overlay
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _camera_basis() -> Basis:
	var camera: Camera3D = get_viewport().get_camera_3d()
	return camera.global_basis.orthonormalized() if is_instance_valid(camera) else Basis.IDENTITY


func _floor_basis(normal: Vector3) -> Basis:
	var tangent: Vector3 = Vector3.RIGHT if absf(normal.dot(Vector3.FORWARD)) > 0.98 else Vector3.FORWARD
	var right: Vector3 = tangent.cross(normal).normalized()
	return Basis(right, normal, right.cross(normal).normalized())


func _place_on_floor(instance: MeshInstance3D, at: Vector3, axis: Basis, radius: float, offset: float) -> void:
	instance.global_transform = Transform3D(axis.scaled(Vector3.ONE * radius), at + axis.y * offset)


func _place_card(instance: MeshInstance3D, at: Vector3, width: float, height: float) -> void:
	instance.global_transform = Transform3D(_view_basis * Basis.from_scale(Vector3(width, height, 1.0)), at)


func _age_rate(elapsed: float, duration: float) -> float:
	return clampf(elapsed / maxf(duration, EPSILON), 0.0, 1.0)
