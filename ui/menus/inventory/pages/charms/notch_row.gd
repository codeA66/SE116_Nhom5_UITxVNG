class_name NotchRow
extends Control
## Hàng ô khắc của bùa: chấm đặc = đang bị bùa chiếm, chấm rỗng = còn trống. Chỉ vẽ lại khi số đổi.

const DOT_RADIUS := 6.0
const DOT_GAP := 22.0

var used: int = 0
var total: int = 0
var color: Color = Color.WHITE
var empty_color: Color = Color(1, 1, 1, 0.4)


func show_notches(used_count: int, total_count: int) -> void:
	used = used_count
	total = total_count
	custom_minimum_size = Vector2(maxf(DOT_GAP * total, DOT_GAP), DOT_RADIUS * 2.0 + 6.0)
	queue_redraw()


func _draw() -> void:
	var start := size.x * 0.5 - DOT_GAP * float(total - 1) * 0.5
	for index in total:
		var center := Vector2(start + DOT_GAP * index, size.y * 0.5)
		if index < used:
			draw_circle(center, DOT_RADIUS, color)
		else:
			draw_arc(center, DOT_RADIUS, 0.0, TAU, 24, empty_color, 1.4, true)
