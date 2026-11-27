class_name CurrencyPickup
extends Node3D
## Viên tiền rơi (dùng chung mọi loại tiền): bật ra quanh chỗ rơi, rồi tự bay vào người nhặt, chạm thì phát collected.
## Hình nằm trong scene của từng loại tiền (node con Visual xoay tại chỗ, Trail tuỳ chọn là hạt có thuộc tính emitting),
## script chỉ lo chuyển động. Dùng object pool của PickupCollector: chỉ chạy _process trong lúc bay.

## Viên chạm người nhặt (collector cộng tiền rồi nhả về pool)
signal collected(pickup: CurrencyPickup)

const MIN_ECHO_SPACING: float = 0.05

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
## Lúc rơi ra viên nở từ 0 lên spawn_overshoot rồi về 1 trong spawn_scale_time giây (0 = không nở)
@export_range(0.0, 1.0, 0.01) var spawn_scale_time: float = 0.12
@export_range(1.0, 2.0, 0.01) var spawn_overshoot: float = 1.25
## Dư ảnh (node Echoes tuỳ chọn, mỗi con là một bản sao hình): xếp cách nhau echo_spacing mét theo quãng đường đã bay,
## nên bay nhanh hay chậm chuỗi bóng vẫn đều
@export_range(MIN_ECHO_SPACING, 2.0, 0.01) var echo_spacing: float = 0.35

## Loại tiền và số tiền viên này mang (rơi nhiều: ít viên, mỗi viên mang nhiều hơn)
var currency: CurrencyData
var value: int = 1

var _target: Node3D
var _velocity: Vector3 = Vector3.ZERO
var _age: float = 0.0
var _speed: float = 0.0
var _echoes: Array[Node3D] = []
## Các điểm đã đi qua, mới nhất trước; cấp phát một lần lúc _ready (không tạo mảng mỗi frame)
var _path: PackedVector3Array
var _path_last: Vector3
var _path_dist: float = 0.0
var _path_count: int = 1
var _sample_spacing: float = MIN_ECHO_SPACING

@onready var _visual: Node3D = get_node_or_null(^"Visual") as Node3D
@onready var _trail: Node = get_node_or_null(^"Trail")


func _ready() -> void:
	top_level = true
	set_process(false)
	_set_trail(false)
	var holder := get_node_or_null(^"Echoes")
	if holder:
		for child in holder.get_children():
			if child is Node3D:
				# Dư ảnh đứng yên theo toạ độ thế giới, không đi theo viên
				(child as Node3D).top_level = true
				_echoes.append(child)
	_path.resize(_echoes.size() + 1)
	_hide_echoes()


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
	_apply_spawn_scale()
	_reset_echo_path()
	_set_trail(true)
	set_process(true)


## Pool nhả về: tắt hẳn
func pool_released() -> void:
	set_process(false)
	_target = null
	_set_trail(false)
	_reset_echo_path()


func _process(delta: float) -> void:
	_age += delta
	if _visual:
		_visual.rotate_y(spin_speed * delta)
	if _age <= spawn_scale_time + delta:
		_apply_spawn_scale()
	if _age < pop_time:
		_velocity.y -= pop_gravity * delta
		global_position += _velocity * delta
		_update_echoes()
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
	_update_echoes()


## Nở 0 -> overshoot (60% thời gian) -> 1; chỉ đổi scale, không đổi chuyển động
func _apply_spawn_scale() -> void:
	if spawn_scale_time <= 0.0:
		scale = Vector3.ONE
		return
	var t := clampf(_age / spawn_scale_time, 0.0, 1.0)
	var s := lerpf(0.05, spawn_overshoot, t / 0.6) if t < 0.6 else lerpf(spawn_overshoot, 1.0, (t - 0.6) / 0.4)
	scale = Vector3.ONE * s


## Giữ phần quãng đường dư để FPS thấp không kéo giãn bóng; chỉ lưu những điểm còn cần cho chuỗi.
func _update_echoes() -> void:
	if _echoes.is_empty():
		return
	var spacing: float = _effective_echo_spacing()
	if not is_equal_approx(spacing, _sample_spacing):
		_reset_echo_path()
		return
	var segment: Vector3 = global_position - _path_last
	var distance: float = segment.length()
	var total: float = _path_dist + distance
	var remainder: float = fposmod(total, spacing)
	# Giới hạn trước khi đổi sang int: một frame vượt rất xa vẫn chỉ cập nhật tối đa số điểm của chuỗi.
	var samples: int = floori(minf(floorf(total / spacing), float(_path.size())))
	if samples > 0:
		var index: int = _path.size() - 1
		while index >= samples:
			_path[index] = _path[index - samples]
			index -= 1
		for sample: int in samples:
			_path[sample] = global_position - segment * ((remainder + float(sample) * spacing) / distance)
		_path_count = mini(_path.size(), _path_count + samples)
	_path_dist = remainder
	_path_last = global_position
	var fraction: float = 1.0 - remainder / spacing
	for index: int in _echoes.size():
		var echo: Node3D = _echoes[index]
		echo.visible = _path_count > index + 1
		if echo.visible:
			# Nội suy sau chuyển động giữ bóng đầu ở phía sau, không ẩn khi điểm mới trùng vị trí viên.
			echo.global_position = _path[index].lerp(_path[index + 1], fraction)


func _reset_echo_path() -> void:
	_path.fill(global_position)
	_path_last = global_position
	_path_dist = 0.0
	_path_count = 1
	_sample_spacing = _effective_echo_spacing()
	_hide_echoes()


func _effective_echo_spacing() -> float:
	return maxf(echo_spacing, MIN_ECHO_SPACING) if is_finite(echo_spacing) else MIN_ECHO_SPACING


func _hide_echoes() -> void:
	for echo in _echoes:
		echo.visible = false


func _set_trail(on: bool) -> void:
	if _trail and &"emitting" in _trail:
		_trail.set(&"emitting", on)
