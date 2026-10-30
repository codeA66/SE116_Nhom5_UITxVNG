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
@export_group("Light")
## Ánh sáng gắn vào phần lồng đèn nên đung đưa theo; vị trí tính từ móc treo (gốc của Lantern_Swing)
@export var light_offset: Vector3 = Vector3(0.0, -0.75, 0.0)
@export var light_color: Color = Color(0.4, 0.88, 1.0)
@export var light_energy: float = 1.6
@export var light_range: float = 4.5
## Lập loè thường xuyên (như lửa) và thêm khi bị gió thổi
@export_range(0.0, 1.0) var idle_flicker: float = 0.08
@export var light_flicker: float = 0.3
## Quầng sáng quanh đèn (m); 0 = không có quầng
@export var halo_size: float = 1.3

var _time: float = 0.0
var _phase: float = 0.0
var _gust_energy: float = 0.0
var _gust_direction: Vector3 = Vector3.ZERO
var _hold_energy: float = 0.0
var _hold_direction: Vector3 = Vector3.ZERO
var _light: OmniLight3D
## Mọi đèn dùng chung mesh + material quầng sáng (không tạo riêng mỗi đèn)
static var _halo_mesh: QuadMesh
var _receiver: WindReactiveReceiver
var _reactive: WindReactiveComponent

@onready var _swing: Node3D = get_node(swing_node_path)
@onready var _notifier: VisibleOnScreenNotifier3D = $VisibleOnScreenNotifier3D


func _ready() -> void:
	if random_phase:
		_phase = randf() * TAU
	_light = OmniLight3D.new()
	_light.name = "LanternLight"
	_light.light_color = light_color
	_light.omni_range = light_range
	_light.light_energy = light_energy
	_light.shadow_enabled = false
	_light.position = light_offset
	_swing.add_child(_light)
	if halo_size > 0.0:
		var halo := MeshInstance3D.new()
		halo.name = "Halo"
		halo.mesh = _get_halo_mesh()
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halo.position = light_offset
		halo.scale = Vector3.ONE * halo_size
		_swing.add_child(halo)
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
	var idle := idle_flicker * (sin(_time * 7.3 + _phase) * 0.6 + sin(_time * 12.1 + _phase * 2.0) * 0.4)
	_light.light_energy = light_energy * (1.0 + idle + light_flicker * current_energy * sin(t * 9.0))


func apply_gust(direction: Vector3, strength: float) -> void:
	if strength <= 0.0 or direction.is_zero_approx():
		return
	_gust_direction = global_basis.inverse() * direction.normalized()
	_gust_energy = clampf(_gust_energy + strength / 10.0, 0.0, 2.0)


func _on_wind_changed(direction: Vector3, strength: float) -> void:
	_hold_direction = global_basis.inverse() * direction
	_hold_energy = clampf(strength / 10.0, 0.0, 2.0)


static func _get_halo_mesh() -> QuadMesh:
	if _halo_mesh == null:
		_halo_mesh = QuadMesh.new()
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/environment/light/lantern_halo.gdshader")
		_halo_mesh.material = material
	return _halo_mesh
