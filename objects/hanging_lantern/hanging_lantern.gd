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

var _time: float = 0.0
var _phase: float = 0.0

@onready var _swing: Node3D = get_node(swing_node_path)
@onready var _notifier: VisibleOnScreenNotifier3D = $VisibleOnScreenNotifier3D


func _ready() -> void:
	if random_phase:
		_phase = randf() * TAU
	set_process(false)
	_notifier.screen_entered.connect(set_process.bind(true))
	_notifier.screen_exited.connect(set_process.bind(false))


func _process(delta: float) -> void:
	_time += delta
	var t := _time * swing_speed + _phase
	var main := sin(t) + gust_strength * sin(t * 2.3 + 1.0) * sin(t * 0.37)
	# Lắc chính quanh trục tay đòn (X), thêm lắc nhỏ theo chiều tay đòn để không cứng
	_swing.rotation.x = deg_to_rad(swing_degrees) * main / (1.0 + gust_strength)
	_swing.rotation.z = deg_to_rad(swing_degrees * 0.35) * sin(t * 0.8 + 2.0)
