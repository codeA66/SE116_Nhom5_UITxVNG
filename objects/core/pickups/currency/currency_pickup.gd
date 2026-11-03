class_name CurrencyPickup
extends Node3D
## Viên tiền rơi (dùng chung mọi loại tiền): bật ra quanh chỗ rơi, rồi tự bay vào người nhặt, chạm thì phát collected.
## Hình nằm trong scene của từng loại tiền (node con Visual xoay tại chỗ, Trail tuỳ chọn là hạt có thuộc tính emitting),
## script chỉ lo chuyển động. Dùng object pool của PickupCollector: chỉ chạy _process trong lúc bay.

## Viên chạm người nhặt (collector cộng tiền rồi nhả về pool)
signal collected(pickup: CurrencyPickup)

@export_group("Pop")
## Tốc độ bật ngang / bật lên lúc rơi ra (m/s)
@export var pop_speed: Vector2 = Vector2(1.5, 3.0)
@export var pop_up: Vector2 = Vector2(3.5, 5.0)
@export var pop_gravity: float = 14.0
## Thời gian bật ra trước khi bắt đầu bay về người (s)
@export_range(0.05, 2.0, 0.01) var pop_time: float = 0.35
@export_group("Home")
## Gia tốc và tốc độ tối đa khi bay về người (m/s², m/s)
@export var home_accel: float = 40.0
@export var home_max_speed: float = 22.0
## Độ bẻ lái về người mỗi giây (lớn = bay thẳng hơn)
@export var home_steer: float = 8.0
## Chạm người khi cách điểm nhắm bấy nhiêu mét
@export var collect_radius: float = 0.45
## Nhắm vào ngực người nhặt (cao hơn chân bấy nhiêu)
@export var target_height: float = 0.8
@export_group("Look")
## Tốc độ xoay của node Visual (rad/s)
@export var spin_speed: float = 6.0

## Loại tiền và số tiền viên này mang (rơi nhiều: ít viên, mỗi viên mang nhiều hơn)
var currency: CurrencyData
var value: int = 1

var _target: Node3D
var _velocity: Vector3 = Vector3.ZERO
var _age: float = 0.0
var _speed: float = 0.0

@onready var _visual: Node3D = get_node_or_null(^"Visual") as Node3D
@onready var _trail: Node = get_node_or_null(^"Trail")


func _ready() -> void:
	top_level = true
	set_process(false)
	_set_trail(false)


## Rơi ra ở origin rồi bay về target
func launch(origin: Vector3, target: Node3D, kind: CurrencyData, amount: int) -> void:
	currency = kind
	value = amount
	_target = target
	global_position = origin + Vector3.UP * 0.4
	var angle := randf() * TAU
	var flat := Vector3(cos(angle), 0.0, sin(angle)) * randf_range(pop_speed.x, pop_speed.y)
	_velocity = flat + Vector3.UP * randf_range(pop_up.x, pop_up.y)
	_age = 0.0
	_speed = 0.0
	_set_trail(true)
	set_process(true)


## Pool nhả về: tắt hẳn
func pool_released() -> void:
	set_process(false)
	_target = null
	_set_trail(false)


func _process(delta: float) -> void:
	_age += delta
	if _visual:
		_visual.rotate_y(spin_speed * delta)
	if _age < pop_time:
		_velocity.y -= pop_gravity * delta
		global_position += _velocity * delta
		return
	# Người nhặt đã mất (đổi khu giữa chừng): vẫn tính tiền, không để viên trôi mãi
	if not is_instance_valid(_target):
		collected.emit(self)
		return
	var to_target := _target.global_position + Vector3.UP * target_height - global_position
	var distance := to_target.length()
	if distance <= collect_radius:
		collected.emit(self)
		return
	_speed = minf(_speed + home_accel * delta, home_max_speed)
	_velocity = _velocity.lerp(to_target / distance * _speed, clampf(home_steer * delta, 0.0, 1.0))
	var step := _velocity * delta
	# Không bay vọt qua người khi tốc độ cao
	if step.length() >= distance:
		collected.emit(self)
		return
	global_position += step


func _set_trail(on: bool) -> void:
	if _trail and &"emitting" in _trail:
		_trail.set(&"emitting", on)
