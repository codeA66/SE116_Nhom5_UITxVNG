class_name BloodSpray
extends Node3D
## Tia máu phun hình nón theo hướng đòn (pool): giọt thon kéo dài theo vận tốc, rơi theo trọng lực,
## chạm sàn thì biến mất và để lại vết trên sàn (BloodStains, qua CombatFx). Đòn kết liễu phun nhiều hơn.
## Điểm rơi của vết tính bằng công thức đạn đạo từ cùng phân bố vận tốc với giọt (hạt CPU không có va chạm).

@export_group("Droplets")
@export var amount_normal: int = 12
@export var amount_kill: int = 16
@export var speed_min: float = 3.0
@export var speed_max: float = 8.0
@export var spread_degrees: float = 35.0
## Bề dài giọt (m)
@export var drop_length_min: float = 0.25
@export var drop_length_max: float = 0.5
@export var gravity: float = 16.0

@export_group("Stains")
@export var stains_normal: int = 3
@export var stains_kill: int = 8
@export var stain_size_min: float = 0.35
@export var stain_size_max: float = 0.7
@export_range(0.1, 64.0, 0.1) var floor_probe_depth: float = 24.0
@export_range(0.01, 1.0, 0.01) var floor_probe_lift: float = 0.12

var _material: ShaderMaterial
var _floor_ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _floor_hint: float
var _stain_color: Color
var _stain_power: float
var _killed: bool

@onready var _drops: CPUParticles3D = $Droplets


func _ready() -> void:
	_material = _drops.material_override as ShaderMaterial
	_drops.gravity = Vector3(0.0, -gravity, 0.0)
	_drops.color_ramp = FxUtil.make_alpha_gradient([[0.0, 1.0], [0.85, 1.0], [1.0, 0.0]])
	_drops.finished.connect(_on_finished)
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	set_physics_process(false)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var start: Vector3 = global_position + Vector3.UP * floor_probe_lift
	var floor_contact: Vector3 = CombatFx.find_blood_floor(space, _floor_ray, start, floor_probe_depth)
	var ground_y: float = floor_contact.y if floor_contact.is_finite() else _floor_hint
	_emit_drops(ground_y)
	_drop_stains(ground_y, space)


## position: điểm trúng; direction: hướng phun; floor_y: độ cao mặt sàn; power: nhân kích thước vết (đòn mạnh)
func play(
	world_position: Vector3, direction: Vector3, color: Color, floor_y: float, power: float = 1.0,
	kill: bool = false, droplet_scale: float = 1.0, floor_mask: int = 0
) -> void:
	global_position = world_position
	reset_physics_interpolation()
	_floor_hint = floor_y
	_stain_color = color
	_stain_power = power
	_killed = kill
	_material.set_shader_parameter(&"color", color)
	_drops.direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.UP
	_drops.spread = spread_degrees
	_drops.amount = amount_kill if kill else amount_normal
	_drops.initial_velocity_min = speed_min
	_drops.initial_velocity_max = speed_max
	var size_factor: float = maxf(droplet_scale, 0.01)
	_drops.scale_amount_min = drop_length_min * size_factor
	_drops.scale_amount_max = drop_length_max * size_factor
	if floor_mask != 0:
		_floor_ray.collision_mask = floor_mask
		set_physics_process(true)
		return
	set_physics_process(false)
	_emit_drops(floor_y)
	_drop_stains(floor_y)


## ObjectPool gọi khi nhả về
func pool_released() -> void:
	set_physics_process(false)
	if _drops:
		_drops.emitting = false


func _emit_drops(floor_y: float) -> void:
	_material.set_shader_parameter(&"floor_y", floor_y)
	# Giọt sống đủ lâu để rơi tới sàn từ độ cao bắn.
	_drops.lifetime = _fall_time(global_position.y - floor_y, speed_max) + 0.1
	_drops.restart()


## Thời gian rơi từ độ cao height với vận tốc đầu hướng lên tối đa speed (cận trên)
func _fall_time(height: float, speed: float) -> float:
	var h := maxf(height, 0.0)
	return (speed + sqrt(speed * speed + 2.0 * gravity * h)) / gravity


func _drop_stains(floor_y: float, space: PhysicsDirectSpaceState3D = null) -> void:
	var origin: Vector3 = global_position
	var direction: Vector3 = _drops.direction
	var axis: Vector3 = _any_perpendicular(direction)
	var count: int = stains_kill if _killed else stains_normal
	for i: int in range(count):
		var tilt: float = deg_to_rad(spread_degrees) * sqrt(randf())
		var velocity: Vector3 = direction.rotated(axis, tilt).rotated(direction, randf() * TAU) * randf_range(speed_min, speed_max)
		var travel_time: float = _fall_time(origin.y - floor_y, velocity.y)
		var landing: Vector3 = _landing_point(origin, velocity, floor_y, travel_time)
		if space != null:
			landing = _floor_at(space, landing, origin.y)
			if not landing.is_finite():
				continue
			if not is_equal_approx(landing.y, floor_y):
				travel_time = _fall_time(origin.y - landing.y, velocity.y)
				landing = _floor_at(space, _landing_point(origin, velocity, landing.y, travel_time), origin.y)
				if not landing.is_finite():
					continue
				travel_time = _fall_time(origin.y - landing.y, velocity.y)
		CombatFx.add_blood_stain(landing, randf_range(stain_size_min, stain_size_max) * _stain_power, _stain_color, travel_time)


func _landing_point(origin: Vector3, velocity: Vector3, floor_y: float, travel_time: float) -> Vector3:
	return Vector3(origin.x + velocity.x * travel_time, floor_y, origin.z + velocity.z * travel_time)


func _floor_at(space: PhysicsDirectSpaceState3D, point: Vector3, from_y: float) -> Vector3:
	var start: Vector3 = Vector3(point.x, from_y + floor_probe_lift, point.z)
	return CombatFx.find_blood_floor(space, _floor_ray, start, floor_probe_depth)


func _any_perpendicular(v: Vector3) -> Vector3:
	var helper := Vector3.UP if absf(v.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	return v.cross(helper).normalized()


func _on_finished() -> void:
	var pool := get_parent() as ObjectPool
	if pool:
		pool.release(self)
