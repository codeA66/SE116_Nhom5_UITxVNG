class_name TonWindScreen
extends WindZone
## Mặt chắn chạy ngang luồng. Chỉ điểm ở sau mặt chắn mới khuất gió.

@export_range(0.1, 25.0, 0.1) var travel: float = 10.0
@export_range(0.1, 10.0, 0.1) var screen_speed: float = 2.5
@export_range(0.0, 20.0, 0.1) var replacement_time: float = 3.0
@export var reverse_path: bool = false

var _travelling: bool = false
var _gusting: bool = false
var _intact: bool = true
var _distance: float = 0.0
var _replacement_left: float = 0.0
var _screen_home: Vector3

@onready var _screen: AnimatableBody3D = $Screen
@onready var _screen_shape: BoxShape3D = $Screen/CollisionShape3D.shape as BoxShape3D
@onready var _dust: GPUParticles3D = $Dust
@onready var _warning: Node3D = $Warning
@onready var _dust_material: ParticleProcessMaterial = _dust.process_material as ParticleProcessMaterial


func _ready() -> void:
	super()
	_screen_home = _screen.position
	_sync_wind_visuals()
	configuration_changed.connect(_sync_wind_visuals)
	reset(false)


func get_wind_at(world_position: Vector3) -> Vector3:
	if not _gusting or data == null:
		return Vector3.ZERO
	var local := to_local(world_position)
	var half := size.abs() * 0.5
	if absf(local.x) > half.x or absf(local.y) > half.y or absf(local.z) > half.z:
		return Vector3.ZERO
	if _intact and _is_sheltered(local):
		return Vector3.ZERO
	return -global_basis.z.normalized() * maxf(data.strength, 0.0)


func update_gust(gusting: bool, warning: bool) -> void:
	_gusting = gusting
	_dust.emitting = gusting
	_warning.visible = warning or gusting


func reset(running: bool) -> void:
	_travelling = running
	_distance = 0.0
	_replacement_left = 0.0
	_place_screen()
	_set_intact(true)
	update_gust(false, false)
	set_physics_process(running)


func intercept_arrow() -> bool:
	if not _intact:
		return false
	_replacement_left = maxf(replacement_time, 0.0)
	_set_intact(false)
	return true


func _physics_process(delta: float) -> void:
	if not _travelling:
		return
	if not _intact:
		_replacement_left -= delta
		if _replacement_left > 0.0:
			return
		_distance = 0.0
		_place_screen()
		_screen.reset_physics_interpolation()
		_set_intact(true)
		return
	var span := maxf(travel, 0.01)
	_distance = fposmod(_distance + maxf(screen_speed, 0.0) * delta, 2.0 * span)
	_place_screen()


func _place_screen() -> void:
	var span := maxf(travel, 0.01)
	var offset := span - absf(span - _distance)
	_screen.position = _screen_home + Vector3.RIGHT * (span - offset if reverse_path else offset)


func _set_intact(intact: bool) -> void:
	_intact = intact
	_screen.visible = intact
	_screen.collision_layer = 256 if intact else 0


func _is_sheltered(point: Vector3) -> bool:
	var relative := point - _screen.position
	var half := _screen_shape.size * 0.5
	return relative.z <= -half.z and absf(relative.x) <= half.x and absf(relative.y) <= half.y


func _sync_wind_visuals() -> void:
	var volume := size.abs()
	var extents := volume * 0.45
	_dust_material.emission_box_extents = extents
	var flight := _dust_material.initial_velocity_max * _dust.lifetime
	var margin := Vector3.ONE
	_dust.visibility_aabb = AABB(-extents - margin - Vector3.BACK * flight,
		2.0 * (extents + margin) + Vector3.BACK * flight)
	_warning.scale = Vector3(clampf(volume.x / 8.0, 0.01, 1.0), 1.0,
		clampf(volume.z / 2.0, 0.01, 1.0))
