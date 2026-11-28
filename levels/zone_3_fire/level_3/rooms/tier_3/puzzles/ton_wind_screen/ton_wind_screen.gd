class_name TonWindScreen
extends WindZone
## Mặt chắn chạy ngang luồng. Chỉ điểm ở sau mặt chắn mới khuất gió.

@export_range(0.1, 40.0, 0.1) var travel: float = 10.0
@export_range(0.1, 10.0, 0.1) var screen_speed: float = 2.5
@export_range(0.0, 20.0, 0.1) var replacement_time: float = 3.0
@export var reverse_path: bool = false
@export_range(0.0, 5.0, 0.05) var paired_screen_delay: float = 0.0
@export var screen_home_offset: Vector3 = Vector3.ZERO
@export var paired_track_offset: float = 0.35
@export var fixed_cover: AABB
@export_group("Hạt gió")
@export_range(0.5, 8.0, 0.1) var approach_distance: float = 1.4
@export_range(1.0, 20.0, 0.1) var particle_speed: float = 6.8
@export_range(0.0, 1.0, 0.05) var particle_height_min: float = 0.35
@export_range(0.0, 1.0, 0.05) var particle_height_max: float = 0.85

var _travelling: bool = false
var _gusting: bool = false
var _intact: bool = true
var _distance: float = 0.0
var _replacement_left: float = 0.0
var _screen_home: Vector3
var _paired_screen: AnimatableBody3D
var _track_time: float = 0.0

@onready var _screen: AnimatableBody3D = $Screen
@onready var _screen_shape: BoxShape3D = $Screen/CollisionShape3D.shape as BoxShape3D
@onready var _dust: GPUParticles3D = $Dust
@onready var _warning: Node3D = $Warning
@onready var _dust_material: ShaderMaterial = _dust.process_material as ShaderMaterial


func _ready() -> void:
	super()
	_screen_home = _screen.position + screen_home_offset
	if paired_screen_delay > 0.0:
		_paired_screen = _screen.duplicate() as AnimatableBody3D
		_paired_screen.name = &"PairedScreen"
		add_child(_paired_screen)
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
	if fixed_cover.has_volume() and _is_behind(local, fixed_cover.get_center(), fixed_cover.size * 0.5):
		return Vector3.ZERO
	if _intact and _is_behind(local, _screen.position, _screen_shape.size * 0.5):
		return Vector3.ZERO
	if _paired_screen and _paired_screen.visible and _is_behind(local, _paired_screen.position, _screen_shape.size * 0.5):
		return Vector3.ZERO
	return -global_basis.z.normalized() * maxf(data.strength, 0.0)


func update_gust(gusting: bool, warning: bool) -> void:
	_gusting = gusting
	_dust.visible = gusting
	if gusting:
		_update_cover_mask()
	_dust.emitting = gusting
	_warning.visible = warning or gusting


func reset(running: bool) -> void:
	_travelling = running
	_distance = 0.0
	_track_time = 0.0
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
	_track_time += delta
	_distance = fposmod(_distance + maxf(screen_speed, 0.0) * delta, 2.0 * span)
	_place_screen()


func _place_screen() -> void:
	_screen.position = _screen_home + Vector3.RIGHT * _track_offset(_distance)
	if _paired_screen:
		var launched := _track_time >= paired_screen_delay
		if _paired_screen.visible != launched:
			_paired_screen.visible = launched
			_paired_screen.collision_layer = _screen.collision_layer if launched else 0
		_paired_screen.position = _screen_home + Vector3(
			_track_offset(maxf(_track_time - paired_screen_delay, 0.0) * screen_speed), 0.0, paired_track_offset)
	if _gusting:
		_update_cover_mask()


func _track_offset(distance: float) -> float:
	var span := maxf(travel, 0.01)
	var offset := span - absf(span - fposmod(distance, 2.0 * span))
	return span - offset if reverse_path else offset


func _set_intact(intact: bool) -> void:
	_intact = intact
	_screen.visible = intact
	_screen.collision_layer = 256 if intact else 0
	_update_cover_mask()


func _update_cover_mask() -> void:
	_dust_material.set_shader_parameter(&"has_panel", _intact)
	_dust_material.set_shader_parameter(&"panel", _screen.position)
	_dust_material.set_shader_parameter(&"has_pair", is_instance_valid(_paired_screen) and _paired_screen.visible)
	if _paired_screen:
		_dust_material.set_shader_parameter(&"paired_panel", _paired_screen.position)


func _is_behind(point: Vector3, cover_center: Vector3, half: Vector3) -> bool:
	var relative := point - cover_center
	return relative.z <= -half.z and absf(relative.x) <= half.x and absf(relative.y) <= half.y


func _sync_wind_visuals() -> void:
	var volume := size.abs()
	_screen_home.z = volume.z * 0.5 + _screen_shape.size.z * 0.5 + screen_home_offset.z
	_place_screen()

	_dust_material.set_shader_parameter(&"has_fixed", fixed_cover.has_volume())
	_dust_material.set_shader_parameter(&"fixed_center", fixed_cover.get_center())
	_dust_material.set_shader_parameter(&"fixed_half", fixed_cover.size * 0.5)
	_dust_material.set_shader_parameter(&"zone_half", volume * 0.5)
	_dust_material.set_shader_parameter(&"panel_half", _screen_shape.size * 0.5)
	var streak_half: Vector3 = _dust.draw_pass_1.get_aabb().size * 0.5
	var height: float = minf(_screen_shape.size.y, volume.y)
	var bottom: float = _screen_home.y - _screen_shape.size.y * 0.5
	var min_y: float = maxf(bottom + height * minf(particle_height_min, particle_height_max), -volume.y * 0.5)
	var max_y: float = minf(bottom + height * maxf(particle_height_min, particle_height_max), volume.y * 0.5)
	_dust_material.set_shader_parameter(&"flight_height", Vector2(minf(min_y, max_y), max_y))
	_dust_material.set_shader_parameter(&"streak_half", streak_half)
	_warning.position.z = volume.z * 0.5
	var source_z: float = maxf(volume.z * 0.5, _screen_home.z + maxf(paired_track_offset, 0.0) + _screen_shape.size.z * 0.5)
	source_z = maxf(source_z, fixed_cover.end.z if fixed_cover.has_volume() else source_z) + approach_distance
	_dust_material.set_shader_parameter(&"source_z", source_z)
	_dust_material.set_shader_parameter(&"flight_speed", particle_speed)
	var length: float = source_z + volume.z * 0.5
	_dust.lifetime = length / (particle_speed * 0.85) + 0.2
	_dust.visibility_aabb = AABB(-volume * 0.5, Vector3(volume.x, volume.y, length)).grow(0.5)
	_warning.scale = Vector3(clampf(volume.x / 8.0, 0.01, 1.0), 1.0,
		clampf(volume.z / 2.0, 0.01, 1.0))
