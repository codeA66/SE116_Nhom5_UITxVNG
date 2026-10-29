class_name TierZone
extends Area3D
## Vùng một tầng / một phòng của khu: player vào thì ẩn các phần map ngoài tầm nhìn (máy khỏi vẽ, khỏi lọc), đổi ánh nắng
## và môi trường sang mood của vùng; ra khỏi vùng thì trả lại như cũ. Chạy theo signal vào/ra, không kiểm tra mỗi frame.
## Nhiều tầng thì đặt nhiều TierZone, mỗi vùng tự giữ danh sách của mình.

## Phát khi player vào / ra vùng (cho nhạc nền, sương... nếu cần sau này)
signal player_entered
signal player_exited

## Phần map ẩn đi khi player ở trong vùng (chỉ ẩn hình, va chạm và logic vẫn giữ)
@export var hide_when_inside: Array[Node3D] = []
## Ngược lại: chỉ hiện khi player ở trong vùng (đèn phụ riêng của phòng...)
@export var show_when_inside: Array[Node3D] = []

@export_group("Ánh nắng")
## Đèn nắng của khu; để trống nếu tầng không đổi ánh sáng
@export var sun: DirectionalLight3D
@export var inside_sun_energy: float = 1.0
@export var inside_sun_color: Color = Color(0.86, 0.9, 1.0)
## Thời gian chuyển ánh sáng (giây); 0 = đổi ngay
@export_range(0.0, 5.0, 0.05) var blend_time: float = 1.2

@export_group("Môi trường")
## WorldEnvironment của khu; để trống nếu vùng không đổi môi trường
@export var world_environment: WorldEnvironment
## Môi trường dùng khi player ở trong vùng (nền, ánh sáng môi trường, phơi sáng...). Đổi ngay lúc bước vào,
## nên đặt mép vùng ở chỗ khuất (lối tối, vòm cửa) để không thấy cú đổi
@export var inside_environment: Environment

var _outside_energy: float
var _outside_color: Color
var _outside_environment: Environment
var _tween: Tween


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	monitorable = false
	if sun:
		_outside_energy = sun.light_energy
		_outside_color = sun.light_color
	if world_environment:
		_outside_environment = world_environment.environment
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_apply(true)
		player_entered.emit()


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		_apply(false)
		player_exited.emit()


func _apply(inside: bool) -> void:
	for node in hide_when_inside:
		if is_instance_valid(node):
			node.visible = not inside
	for node in show_when_inside:
		if is_instance_valid(node):
			node.visible = inside
	if world_environment and inside_environment:
		world_environment.environment = inside_environment if inside else _outside_environment
	if sun == null:
		return
	if _tween:
		_tween.kill()
	var energy := inside_sun_energy if inside else _outside_energy
	var color := inside_sun_color if inside else _outside_color
	if blend_time <= 0.0:
		sun.light_energy = energy
		sun.light_color = color
		return
	_tween = create_tween().set_parallel()
	_tween.tween_property(sun, ^"light_energy", energy, blend_time)
	_tween.tween_property(sun, ^"light_color", color, blend_time)
