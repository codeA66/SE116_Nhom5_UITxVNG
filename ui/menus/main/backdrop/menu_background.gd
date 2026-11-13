class_name MenuBackground
extends Control
## Nền menu chính kiểu Hollow Knight: trời gần đen, dáng cung điện mờ xa xa, vệt sáng xiên thở chậm, bụi sáng lơ lửng.
## Cảnh trôi rất chậm (tween lặp, không chạy mỗi frame) để nền sống mà mắt không mỏi khi đọc menu.

## Cảnh phóng to / thu nhỏ trong khoảng này
@export_range(1.0, 1.3, 0.005) var drift_zoom: float = 1.06
## Một nhịp phóng to rồi thu về (s)
@export_range(5.0, 240.0, 1.0) var drift_period: float = 60.0
## Trôi ngang tối đa (px)
@export_range(0.0, 200.0, 1.0) var drift_pan: float = 28.0

@onready var _scenery: TextureRect = $Scenery


func _ready() -> void:
	resized.connect(_center_pivot)
	_center_pivot()
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_scenery, ^"scale", Vector2.ONE * drift_zoom, drift_period * 0.5)
	tween.parallel().tween_property(_scenery, ^"position:x", -drift_pan, drift_period * 0.5)
	tween.tween_property(_scenery, ^"scale", Vector2.ONE, drift_period * 0.5)
	tween.parallel().tween_property(_scenery, ^"position:x", 0.0, drift_period * 0.5)


func _center_pivot() -> void:
	_scenery.pivot_offset = _scenery.size * 0.5
