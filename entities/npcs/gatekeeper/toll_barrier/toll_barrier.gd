class_name TollBarrier
extends Node3D
## Hàng rào thu tiền: thanh chắn xoay quanh bản lề để mở; va chạm chặn lối tắt khi mở.
## Model thật (toll_barrier.glb) chỉ cần có node tên như beam_path; hiện là khối tạm cùng kích thước.

signal opened

## Thanh chắn quay quanh trục Z của chính nó (gốc đặt ở bản lề)
@export var beam_path: NodePath = ^"Visual/Beam"
## Góc nhấc lên khi mở (độ)
@export var open_angle_degrees: float = 80.0
@export var open_time: float = 0.6

var _open: bool = false
var _tween: Tween

@onready var _beam: Node3D = get_node_or_null(beam_path) as Node3D
@onready var _shape: CollisionShape3D = $Blocker/CollisionShape3D


func set_open(open: bool, animated: bool) -> void:
	if open == _open:
		return
	_open = open
	# Đổi va chạm ngoài lúc tính vật lý
	_shape.set_deferred(&"disabled", open)
	var target := deg_to_rad(open_angle_degrees) if open else 0.0
	if _tween and _tween.is_valid():
		_tween.kill()
	if _beam == null:
		if open:
			opened.emit()
		return
	if not animated or open_time <= 0.0 or not is_inside_tree():
		_beam.rotation.z = target
		if open:
			opened.emit()
		return
	_tween = create_tween()
	_tween.tween_property(_beam, "rotation:z", target, open_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if open:
		_tween.tween_callback(opened.emit)


func is_open() -> bool:
	return _open
