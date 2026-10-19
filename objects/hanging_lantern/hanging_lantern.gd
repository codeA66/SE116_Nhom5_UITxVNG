class_name HangingLantern
extends Node3D
## Đèn lồng treo đung đưa theo gió: nhịp lắc chính cộng một nhịp phụ không đều như gió giật.
## Chỉ chạy khi đèn nằm trong màn hình (VisibleOnScreenNotifier3D), ra ngoài thì tắt xử lý.

## Phần lồng đèn trong model, gốc nằm ở móc treo nên xoay quanh gốc là đung đưa
@export var swing_node_path: NodePath = ^"Model/Lantern_Post/Lantern_Swing"
@export_range(0.0, 45.0) var swing_degrees: float = 10.0
## Số nhịp lắc mỗi giây (rad/s của nhịp chính)
@export var swing_speed: float = 1.6
## 0 = lắc đều; càng lớn càng giật như gió thổi từng cơn
@export_range(0.0, 1.0) var gust_strength: float = 0.35
## Lệch pha ngẫu nhiên để các đèn cạnh nhau không lắc đồng loạt
@export var random_phase: bool = true
@export var gust_decay: float = 2.5
@export var gust_swing_degrees: float = 24.0
@export var light_energy: float = 0.55
@export var light_flicker: float = 0.3

var _time: float = 0.0
var _phase: float = 0.0
var _gust_energy: float = 0.0
var _gust_direction: Vector3 = Vector3.ZERO
var _hold_energy: float = 0.0
var _hold_direction: Vector3 = Vector3.ZERO
var _light: OmniLight3D
var _receiver: WindReactiveReceiver
var _reactive: WindReactiveComponent

@onready var _swing: Node3D = get_node(swing_node_path)
@onready var _notifier: VisibleOnScreenNotifier3D = $VisibleOnScreenNotifier3D


func _ready() -> void:
	if random_phase:
		_phase = randf() * TAU
	_light = OmniLight3D.new()
	_light.name = "LanternLight"
	_light.light_color = Color(1.0, 0.77, 0.5)
	_light.omni_range = 3.0
	_light.light_energy = light_energy
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, 1.2, 0.0)
	add_child(_light)
	_receiver = WindReactiveReceiver.new()
	_receiver.name = "WindReceiver"
	_receiver.collision_layer = 128
	_receiver.collision_mask = 64
	var receiver_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.8
	receiver_shape.shape = sphere
	receiver_shape.position.y = 1.2
	_receiver.add_child(receiver_shape)
	add_child(_receiver)
	_reactive = WindReactiveComponent.new()
	_reactive.name = "WindReactive"
	add_child(_reactive)
	_reactive.reacted.connect(apply_gust)
	_reactive.wind_changed.connect(_on_wind_changed)
	set_process(false)
	_notifier.screen_entered.connect(set_process.bind(true))
	_notifier.screen_exited.connect(set_process.bind(false))


func _process(delta: float) -> void:
	_time += delta
	_gust_energy = move_toward(_gust_energy, 0.0, gust_decay * delta)
	var current_energy: float = _gust_energy + _hold_energy
	var current_direction: Vector3 = _gust_direction * _gust_energy + _hold_direction * _hold_energy
	var t := _time * swing_speed + _phase
	var main := sin(t) + gust_strength * sin(t * 2.3 + 1.0) * sin(t * 0.37)
	# Lắc chính quanh trục tay đòn (X), thêm lắc nhỏ theo chiều tay đòn để không cứng
	_swing.rotation.x = deg_to_rad(swing_degrees) * main / (1.0 + gust_strength) + deg_to_rad(gust_swing_degrees) * sin(t * 3.2) * current_direction.z
	_swing.rotation.z = deg_to_rad(swing_degrees * 0.35) * sin(t * 0.8 + 2.0) + deg_to_rad(gust_swing_degrees) * sin(t * 2.7) * current_direction.x
	_light.light_energy = light_energy * (1.0 + light_flicker * current_energy * sin(t * 9.0))


func apply_gust(direction: Vector3, strength: float) -> void:
	if strength <= 0.0 or direction.is_zero_approx():
		return
	_gust_direction = global_basis.inverse() * direction.normalized()
	_gust_energy = clampf(_gust_energy + strength / 10.0, 0.0, 2.0)


func _on_wind_changed(direction: Vector3, strength: float) -> void:
	_hold_direction = global_basis.inverse() * direction
	_hold_energy = clampf(strength / 10.0, 0.0, 2.0)
