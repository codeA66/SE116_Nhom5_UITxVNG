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

var _material: ShaderMaterial

@onready var _drops: CPUParticles3D = $Droplets


func _ready() -> void:
	_material = _drops.material_override as ShaderMaterial
	_drops.gravity = Vector3(0.0, -gravity, 0.0)
	_drops.color_ramp = FxUtil.make_alpha_gradient([[0.0, 1.0], [0.85, 1.0], [1.0, 0.0]])
	_drops.finished.connect(_on_finished)


## position: điểm trúng; direction: hướng phun; floor_y: độ cao mặt sàn; power: nhân kích thước vết (đòn mạnh)
func play(world_position: Vector3, direction: Vector3, color: Color, floor_y: float, power: float = 1.0, kill: bool = false) -> void:
	global_position = world_position
	var dir := direction.normalized() if direction.length_squared() > 0.0001 else Vector3.UP
	_material.set_shader_parameter(&"color", color)
	_material.set_shader_parameter(&"floor_y", floor_y)
	_drops.direction = dir
	_drops.spread = spread_degrees
	_drops.amount = amount_kill if kill else amount_normal
	_drops.initial_velocity_min = speed_min
	_drops.initial_velocity_max = speed_max
	_drops.scale_amount_min = drop_length_min
	_drops.scale_amount_max = drop_length_max
	# Giọt sống đủ lâu để rơi tới sàn từ độ cao bắn
	_drops.lifetime = _fall_time(world_position.y - floor_y, speed_max) + 0.1
	_drops.restart()
	_drop_stains(world_position, dir, color, floor_y, power, kill)


## ObjectPool gọi khi nhả về
func pool_released() -> void:
	if _drops:
		_drops.emitting = false


## Thời gian rơi từ độ cao height với vận tốc đầu hướng lên tối đa speed (cận trên)
func _fall_time(height: float, speed: float) -> float:
	var h := maxf(height, 0.0)
	return (speed + sqrt(speed * speed + 2.0 * gravity * h)) / gravity


func _drop_stains(origin: Vector3, dir: Vector3, color: Color, floor_y: float, power: float, kill: bool) -> void:
	var count := stains_kill if kill else stains_normal
	var height := origin.y - floor_y
	for i in count:
		# Mẫu một vận tốc trong hình nón như hạt
		var tilt := deg_to_rad(spread_degrees) * sqrt(randf())
		var velocity := dir.rotated(_any_perpendicular(dir), tilt).rotated(dir, randf() * TAU) * randf_range(speed_min, speed_max)
		# y(t) = height + vy*t - g/2*t^2 = 0, lấy nghiệm dương
		var half_g := gravity * 0.5
		var t := (velocity.y + sqrt(velocity.y * velocity.y + 4.0 * half_g * maxf(height, 0.0))) / (2.0 * half_g)
		var landing := Vector3(origin.x + velocity.x * t, floor_y, origin.z + velocity.z * t)
		CombatFx.add_blood_stain(landing, randf_range(stain_size_min, stain_size_max) * power, color, t)


func _any_perpendicular(v: Vector3) -> Vector3:
	var helper := Vector3.UP if absf(v.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	return v.cross(helper).normalized()


func _on_finished() -> void:
	var pool := get_parent() as ObjectPool
	if pool:
		pool.release(self)
