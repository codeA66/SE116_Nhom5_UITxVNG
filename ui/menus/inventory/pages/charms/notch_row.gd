class_name NotchRow
extends Control
## Hàng ô khắc của bùa, vẽ thành hạt ngọc tròn: sáng = đang bị bùa chiếm, tối viền mờ = còn trống.
## animate_to() làm các hạt sáng / tắt lần lượt khi đeo / tháo. Chỉ vẽ lại khi số đổi hoặc đang chạy hiệu ứng.

const DOT_RADIUS := 7.0
const DOT_GAP := 24.0
## Quầng sáng quanh hạt đang dùng, tính theo bán kính
const GLOW_SCALE := 1.7

var used: float = 0.0
var total: int = 0
var color: Color = Color.WHITE
var empty_color: Color = Color(1, 1, 1, 0.4)

var _tween: Tween


func show_notches(used_count: int, total_count: int) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	used = float(used_count)
	total = total_count
	custom_minimum_size = Vector2(maxf(DOT_GAP * total, DOT_GAP), DOT_RADIUS * 2.0 * GLOW_SCALE)
	queue_redraw()


## Hạt sáng / tắt lần lượt từ số cũ tới số mới, mỗi hạt cách nhau step_time
func animate_to(used_count: int, step_time: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	var steps := absf(float(used_count) - used)
	if steps <= 0.0 or step_time <= 0.0:
		used = float(used_count)
		queue_redraw()
		return
	_tween = create_tween()
	_tween.tween_method(_set_used, used, float(used_count), step_time * steps)


func _set_used(value: float) -> void:
	used = value
	queue_redraw()


func _draw() -> void:
	var start := size.x * 0.5 - DOT_GAP * float(total - 1) * 0.5
	for index in total:
		var center := Vector2(start + DOT_GAP * index, size.y * 0.5)
		# Hạt đang sáng dở (giữa hiệu ứng) có độ sáng bằng phần lẻ
		var fill := clampf(used - float(index), 0.0, 1.0)
		draw_circle(center, DOT_RADIUS, Color(0.0, 0.0, 0.0, 0.45))
		draw_arc(center, DOT_RADIUS, 0.0, TAU, 24, empty_color, 1.4, true)
		if fill > 0.0:
			draw_circle(center, DOT_RADIUS * GLOW_SCALE, Color(color, 0.12 * fill))
			draw_circle(center, DOT_RADIUS * (0.55 + 0.45 * fill), Color(color, fill))
			draw_circle(center - Vector2(DOT_RADIUS, DOT_RADIUS) * 0.3, DOT_RADIUS * 0.28, Color(1, 1, 1, 0.55 * fill))
