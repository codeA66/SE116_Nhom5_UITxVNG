class_name MenuBackdrop
extends Node3D
## Nền 3D của menu: cảnh khu trung tâm, camera bay vòng thật chậm quanh đền (cảnh sống, không đứng im như ảnh).
## Chỉ nạp phần cảnh (hub_scenery), không có player hay logic chơi.

@export var focus_point: Vector3 = Vector3(0, 2, -6)
@export_range(10.0, 400.0, 1.0) var orbit_radius: float = 92.0
@export_range(0.0, 200.0, 1.0) var orbit_height: float = 34.0
## Độ / giây. Rất chậm để mắt không mỏi khi đọc menu
@export_range(-20.0, 20.0, 0.1) var orbit_speed: float = 1.6
## Góc bắt đầu (độ, 0 = phía nam nhìn về bắc)
@export_range(-180.0, 180.0, 1.0) var start_angle: float = -18.0
## Lắc lên xuống nhẹ như máy quay cầm tay
@export_range(0.0, 10.0, 0.1) var bob_height: float = 1.2
@export_range(0.01, 2.0, 0.01) var bob_speed: float = 0.18

var _angle: float = 0.0
var _time: float = 0.0

@onready var _camera: Camera3D = $Camera


func _ready() -> void:
	_angle = deg_to_rad(start_angle)
	_place_camera()
	_camera.make_current()


func _process(delta: float) -> void:
	_time += delta
	_angle += deg_to_rad(orbit_speed) * delta
	_place_camera()


func _place_camera() -> void:
	var offset := Vector3(sin(_angle), 0.0, cos(_angle)) * orbit_radius
	offset.y = orbit_height + sin(_time * TAU * bob_speed) * bob_height
	_camera.look_at_from_position(focus_point + offset, focus_point, Vector3.UP)
