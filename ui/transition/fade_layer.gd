class_name FadeLayer
extends CanvasLayer
## Lớp phủ đen để chuyển cảnh: mờ dần thành đen rồi sáng lại.

@onready var _rect: ColorRect = $Rect


func fade_out(duration: float) -> void:
	await _fade_to(1.0, duration)


func fade_in(duration: float) -> void:
	await _fade_to(0.0, duration)


func _fade_to(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_rect, ^"color:a", alpha, duration)
	await tween.finished
