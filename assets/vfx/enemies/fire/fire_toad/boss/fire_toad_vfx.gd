extends Node3D
## Tách điểm bám của thân và mặt đất để sóng nổ đứng yên ở vị trí va chạm.

class ShotVisual:
	var root: Node3D
	var cracks: MeshInstance3D
	var tail: MeshInstance3D
	var embers: GPUParticles3D
	var projectile: Node3D
	var tint_source: OmniLight3D
	var last_position: Vector3
	var reflected: bool

const ImpactVfx = preload("res://assets/vfx/enemies/fire/fire_toad/impact/fire_toad_impact_vfx.gd")

enum MouthPhase { OFF, CHARGE, UP, FORWARD, WEB }

@export_group("Mõm")
@export var volley_flash_time: float = 0.38
@export var forward_flash_time: float = 0.24
@export var web_cue_scale: float = 0.76
@export var charge_size: float = 0.54
@export var mouth_socket: StringName = &"MouthSocket"
@export_group("Va chạm")
@export var takeoff_radius: float = 1.65
@export var takeoff_time: float = 0.46
@export var slam_burst_time: float = 0.66
@export var landing_radius: float = 2.7
@export var landing_time: float = 0.68
@export var sentinel_radius: float = 1.05
@export var sentinel_burst_time: float = 0.51
@export var enrage_radius: float = 2.8
@export var enrage_burst_time: float = 0.72
@export var collapse_delay: float = 0.27

@export_group("Vết máu khi ngã")
@export var death_feedback: DeathEffectData
@export var blood_feedback: HitFeedbackData
@export_range(0.1, 64.0, 0.1) var death_floor_probe_depth: float = 24.0
@export_range(0.01, 1.0, 0.01) var death_floor_slack: float = 0.10

@export_group("Cầu lửa ngang")
@export_range(1, 12, 1) var shot_slots: int = 6
@export var shot_hot_cracks: Material
@export var shot_cold_cracks: Material
@export var shot_hot_tail: Material
@export var shot_cold_tail: Material
@export var shot_hot_embers: Mesh
@export var shot_cold_embers: Mesh

var _shots: Array[ShotVisual] = []
var _active_shots: int
var _fallback: Marker3D
var _facing: Node3D
var _visual_model: Node3D
var _rig: Skeleton3D
var _mouth_bone: int = -1
var _mode: MouthPhase = MouthPhase.OFF
var _mouth_age: float
var _mouth_duration: float
var _hot: bool
var _leaping: bool
var _hovering: bool
var _dying: bool
var _death_remaining: float
var _collapse_remaining: float
var _death_duration: float
var _collapse_pending: bool
var _death_ground_y: float
var _death_probe_y: float
var _death_floor_ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _impact_cursor: int
var _impacts: Array[ImpactVfx] = []

@onready var _socket: Node3D = $Mouth
@onready var _mouth_core: MeshInstance3D = $Mouth/Core
@onready var _mouth_glow: MeshInstance3D = $Mouth/Glow
@onready var _mouth_beam: MeshInstance3D = $Mouth/Beam
@onready var _web_cue: Node3D = $Mouth/WebCue
@onready var _up_sparks: GPUParticles3D = $Mouth/UpSparks
@onready var _forward_sparks: GPUParticles3D = $Mouth/ForwardSparks
@onready var _body: Node3D = $Body
@onready var _trail: GPUParticles3D = $Body/LeapTrail
@onready var _trail_smoke: GPUParticles3D = $Body/LeapSmoke
@onready var _jet: Node3D = $Body/HoverJet
@onready var _jet_sparks: GPUParticles3D = $Body/HoverJet/JetSparks
@onready var _aura: GPUParticles3D = $Body/Aura
@onready var _ash: GPUParticles3D = $Body/DeathAsh
@onready var _smoke: GPUParticles3D = $Body/DeathSmoke
@onready var _death_veil: MeshInstance3D = $Body/DeathVeil


func _ready() -> void:
	# Tạo các vệt một lần để lúc bắn chỉ chọn slot có sẵn.
	var prototype: Node3D = $Shots/ShotPrototype
	for i: int in range(shot_slots):
		var shot: ShotVisual = ShotVisual.new()
		shot.root = prototype if i == 0 else prototype.duplicate() as Node3D
		if i > 0:
			$Shots.add_child(shot.root)
		shot.cracks = shot.root.get_node("Cracks") as MeshInstance3D
		shot.tail = shot.root.get_node("Tail") as MeshInstance3D
		shot.embers = shot.root.get_node("Embers") as GPUParticles3D
		_shots.append(shot)
	for mesh: Node in _web_cue.find_children("*", "GeometryInstance3D", true, false):
		(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in $Impacts.get_children():
		_impacts.append(child as ImpactVfx)
	set_process(false)
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	set_physics_process(false)
	var feet: Vector3 = global_position
	var grounded: Vector3 = Vector3.INF
	if blood_feedback != null and blood_feedback.blood_floor_mask != 0:
		_death_floor_ray.collision_mask = blood_feedback.blood_floor_mask
		var start: Vector3 = Vector3(feet.x, _death_probe_y + death_floor_slack, feet.z)
		grounded = CombatFx.find_blood_floor(
			get_world_3d().direct_space_state, _death_floor_ray, start, death_floor_probe_depth
		)

	if death_feedback == null:
		_play_impact(feet, takeoff_radius * _model_scale(), ImpactVfx.Kind.COLLAPSE, landing_time)
		return
	var burst_position: Vector3 = grounded if grounded.is_finite() else feet
	CombatFx.spawn_death(burst_position, death_feedback.color, death_feedback.effect_scale)
	if (grounded.is_finite() and blood_feedback != null and blood_feedback.bleeds
			and death_feedback.puddle_size > 0.0):
		CombatFx.spawn_puddle(grounded, death_feedback.puddle_size, blood_feedback.blood_color)


func _process(delta: float) -> void:
	if _active_shots > 0:
		_update_shots()
	_sync_body()
	if _mode != MouthPhase.OFF:
		_mouth_age += delta
		if _mouth_age >= _mouth_duration:
			_hide_mouth()
		else:
			_draw_mouth(_mouth_age / _mouth_duration)
	if _dying:
		_death_remaining -= delta
		var age: float = 1.0 - clampf(_death_remaining / _death_duration, 0.0, 1.0)
		if _death_veil.visible:
			_death_veil.set_instance_shader_parameter(&"vfx_progress", age)
			_death_veil.set_instance_shader_parameter(&"vfx_opacity", smoothstep(0.06, 0.27, age) * (1.0 - smoothstep(0.57, 1.0, age)))
			_death_veil.scale = Vector3.ONE * lerpf(0.7, 1.35, age)
		if _death_remaining <= 0.0:
			_stop_particles(_ash)
			_stop_particles(_smoke)
			_death_veil.hide()
			_dying = false
	if _collapse_pending:
		_collapse_remaining -= delta
		if _collapse_remaining <= 0.0 and global_position.y <= _death_ground_y + death_floor_slack:
			# Chờ hạ xuống trước khi thả vũng, kể cả khi cú kết liễu xảy ra trên không.
			_collapse_pending = false
			set_physics_process(true)
	if (_mode == MouthPhase.OFF and not _dying and not _collapse_pending
			and not _hovering and not _leaping and not _hot and _active_shots == 0):
		set_process(false)


func bind_model(visual_model: Node3D, fallback: Marker3D) -> void:
	_visual_model = visual_model
	_fallback = fallback
	_facing = fallback.get_parent() as Node3D
	var skeletons: Array[Node] = visual_model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_rig = skeletons[0] as Skeleton3D
		_mouth_bone = _rig.find_bone(mouth_socket)
	_sync_body()


func charge_rain(duration: float) -> void:
	_open_mouth(MouthPhase.CHARGE, duration)


func spit_up(count: int) -> void:
	_open_mouth(MouthPhase.UP, volley_flash_time)
	_up_sparks.amount_ratio = clampf(float(count) / float(_up_sparks.amount), 0.0, 1.0)
	_restart_particles(_up_sparks)


func charge_web(duration: float) -> void:
	_open_mouth(MouthPhase.WEB, duration)


func spit_forward() -> void:
	_open_mouth(MouthPhase.FORWARD, forward_flash_time)
	_forward_sparks.amount_ratio = 1.0 if _hot else 0.64
	_restart_particles(_forward_sparks)


func play_shot(projectile: Node3D, direction: Vector3) -> void:
	var original: Node3D = projectile.get_node("Visual") as Node3D
	for shot: ShotVisual in _shots:
		if shot.projectile == projectile:
			# Có thể mượn lại cùng viên đạn trước khi tới frame dọn vệt.
			_start_shot(shot, projectile, direction)
			return
	for shot: ShotVisual in _shots:
		if is_instance_valid(shot.projectile):
			continue
		_active_shots += 1
		_start_shot(shot, projectile, direction)
		return
	original.show()


func _start_shot(shot: ShotVisual, projectile: Node3D, direction: Vector3) -> void:
	(projectile.get_node("Visual") as Node3D).hide()
	shot.projectile = projectile
	shot.tint_source = projectile.get_node("OmniLight3D") as OmniLight3D
	shot.last_position = projectile.global_position
	shot.reflected = false
	shot.cracks.material_override = shot_hot_cracks
	shot.tail.material_override = shot_hot_tail
	shot.embers.draw_pass_1 = shot_hot_embers
	shot.root.global_transform = Transform3D(_shot_basis(direction), shot.last_position)
	shot.root.reset_physics_interpolation()
	shot.root.show()
	shot.embers.amount_ratio = 1.0 if _hot else 0.78
	_restart_particles(shot.embers)
	set_process(true)


func begin_leap() -> void:
	_leaping = true
	_sync_body()
	_play_impact(global_position, takeoff_radius * _model_scale(), ImpactVfx.Kind.LIFT, takeoff_time)
	_trail.amount_ratio = 1.0 if _hot else 0.68
	_restart_particles(_trail)
	_restart_particles(_trail_smoke)
	set_process(true)


func end_leap() -> void:
	_leaping = false
	_stop_particles(_trail)
	_stop_particles(_trail_smoke)


func slam_land(where: Vector3, radius: float) -> void:
	end_leap()
	_play_impact(where, radius, ImpactVfx.Kind.SLAM, slam_burst_time)


func platform_land() -> void:
	if not _leaping:
		return
	end_leap()
	_play_impact(global_position, takeoff_radius * _model_scale(), ImpactVfx.Kind.LIFT, takeoff_time)


func sentinel_puff(where: Vector3, spawning: bool) -> void:
	var kind: ImpactVfx.Kind = ImpactVfx.Kind.SENTINEL_IN if spawning else ImpactVfx.Kind.SENTINEL_OUT
	_play_impact(where, sentinel_radius, kind, sentinel_burst_time)


func begin_hover() -> void:
	_hovering = true
	_sync_body()
	_play_impact(global_position, landing_radius * _model_scale(), ImpactVfx.Kind.LIFT, landing_time)
	_jet.show()
	_jet_sparks.amount_ratio = 1.0 if _hot else 0.7
	_restart_particles(_jet_sparks)
	set_process(true)


func end_hover(where: Vector3) -> void:
	_stop_hover()
	_play_impact(where, landing_radius * _model_scale(), ImpactVfx.Kind.LAND, landing_time)


func phase_changed(phase: StringName) -> void:
	if phase != &"enraged":
		return
	_hot = true
	_sync_body()
	_restart_particles(_aura)
	_play_impact(global_position, enrage_radius * _model_scale(), ImpactVfx.Kind.ENRAGE, enrage_burst_time)
	set_process(true)


func state_changed(_previous: StringName, current: StringName) -> void:
	if current != &"Hover" and _hovering:
		_stop_hover()
	if current != &"LavaSlam" and current != &"WebRetreat" and _leaping:
		end_leap()
	if current != &"FireRain" and current != &"WebRetreat" and _mode != MouthPhase.OFF:
		_hide_mouth()


func death(duration: float, ground_y: float) -> void:
	_hot = false
	end_leap()
	_stop_hover()
	_stop_particles(_aura)
	_hide_mouth()
	_death_remaining = duration
	_death_duration = maxf(duration, 0.001)
	_death_ground_y = ground_y
	_death_probe_y = maxf(ground_y, global_position.y)
	_collapse_pending = true
	_collapse_remaining = minf(collapse_delay, duration * 0.6)
	_dying = true
	_sync_body()
	_ash.lifetime = minf(_ash.lifetime, duration)
	_smoke.lifetime = minf(_smoke.lifetime, duration)
	_restart_particles(_ash)
	_restart_particles(_smoke)
	_death_veil.set_instance_shader_parameter(&"vfx_opacity", 0.0)
	_death_veil.show()
	set_process(true)


func _update_shots() -> void:
	for shot: ShotVisual in _shots:
		if shot.projectile == null:
			continue
		if not is_instance_valid(shot.projectile) or not shot.projectile.visible:
			shot.projectile = null
			shot.tint_source = null
			shot.root.hide()
			_stop_particles(shot.embers)
			_active_shots -= 1
			continue
		var point: Vector3 = shot.projectile.global_position
		var direction: Vector3 = point - shot.last_position
		if direction.length_squared() > 0.000001:
			shot.root.global_transform = Transform3D(_shot_basis(direction), point)
			shot.last_position = point
		if not shot.reflected and shot.tint_source.light_color.b > shot.tint_source.light_color.r:
			shot.reflected = true
			shot.cracks.material_override = shot_cold_cracks
			shot.tail.material_override = shot_cold_tail
			shot.embers.draw_pass_1 = shot_cold_embers


func _shot_basis(direction: Vector3) -> Basis:
	var flight: Vector3 = direction.normalized()
	if flight.is_zero_approx():
		flight = Vector3.FORWARD
	var up: Vector3 = Vector3.UP if absf(flight.y) < 0.98 else Vector3.FORWARD
	var side: Vector3 = flight.cross(up).normalized()
	return Basis(side, flight, side.cross(flight))


func _model_scale() -> float:
	return absf(_visual_model.scale.x) if _visual_model else 1.0


func _sync_body() -> void:
	if _facing:
		_body.rotation.y = _facing.rotation.y
	_body.scale = Vector3.ONE * _model_scale()


func _open_mouth(mode: MouthPhase, duration: float) -> void:
	_hide_mouth()
	if duration <= 0.0:
		return
	_mode = mode
	_mouth_duration = duration
	_mouth_age = 0.0
	_mouth_beam.visible = mode == MouthPhase.UP or mode == MouthPhase.FORWARD
	_web_cue.visible = mode == MouthPhase.WEB
	_mouth_core.visible = mode != MouthPhase.WEB
	_socket.show()
	_draw_mouth(0.0)
	_socket.reset_physics_interpolation()
	set_process(true)


func _draw_mouth(progress: float) -> void:
	var world_basis: Basis = _facing.global_basis.orthonormalized()
	var world_point: Vector3 = _fallback.global_position
	if _mouth_bone >= 0:
		world_point = _rig.to_global(_rig.get_bone_global_pose(_mouth_bone).origin)
	if _mode == MouthPhase.FORWARD or _mode == MouthPhase.WEB:
		world_basis = world_basis.rotated(world_basis.x, PI * 0.5)
	_socket.global_transform = Transform3D(world_basis.scaled(Vector3.ONE * _model_scale()), world_point)
	var strength: float = smoothstep(0.0, 0.95, progress)
	if _mode == MouthPhase.UP or _mode == MouthPhase.FORWARD:
		strength = 1.0 - smoothstep(0.05, 0.85, progress)
	var wide: float = charge_size * lerpf(0.3, 1.4 if _hot else 1.15, strength)
	var core_size: float = wide * (1.0 if _mode != MouthPhase.WEB else 1.5)
	_mouth_core.scale = Vector3.ONE * core_size
	if _mode == MouthPhase.WEB:
		var web_size: float = strength * lerpf(0.70, 1.13, 1.0 - smoothstep(0.75, 1.0, progress))
		_web_cue.scale = Vector3.ONE * maxf(web_size * web_cue_scale, 0.01)
		_web_cue.rotation.y = lerpf(-0.6, 0.3, progress)
	_mouth_glow.scale = Vector3.ONE * (wide * 2.2)
	_mouth_glow.set_instance_shader_parameter(&"vfx_opacity", strength * 0.84)
	_mouth_beam.set_instance_shader_parameter(&"vfx_opacity", strength)
	_mouth_beam.set_instance_shader_parameter(&"vfx_dissolve", progress * 0.8)


func _hide_mouth() -> void:
	_mode = MouthPhase.OFF
	_stop_particles(_up_sparks)
	_stop_particles(_forward_sparks)
	_socket.hide()


func _stop_hover() -> void:
	_hovering = false
	_stop_particles(_jet_sparks)
	_jet.hide()


func _play_impact(where: Vector3, radius: float, kind: ImpactVfx.Kind, duration: float) -> void:
	var impact: ImpactVfx = _impacts[_impact_cursor]
	_impact_cursor = (_impact_cursor + 1) % _impacts.size()
	impact.play(where, radius, kind, _hot, duration)


func _restart_particles(particle: GPUParticles3D) -> void:
	particle.show()
	particle.restart()
	particle.emitting = true


func _stop_particles(particle: GPUParticles3D) -> void:
	particle.emitting = false
	particle.hide()
