class_name LevelGem
extends Control
## Viên ngọc cấp kỹ năng (ngọc cắt hình thoi có mặt sáng). Đã mở = màu nguyên tố, cấp đang dùng = có quầng sáng,
## chưa mở = viên tối viền mờ. Dùng làm Control trong lộ trình nâng cấp; thẻ nguyên tố gọi thẳng draw_gem().

## Không đặt tên "State": trùng class State của state machine
enum GemState { LOCKED, OWNED, CURRENT }

## Quầng sáng quanh viên đang dùng, tính theo cỡ ngọc
const HALO_SCALE := 2.1
## Mặt sáng phía trên trái làm viên ngọc có khối
const FACET_LIGHTEN := 0.55
const OUTLINE_DARKEN := 0.45

var state: GemState = GemState.LOCKED
var color: Color = Color.WHITE
var locked_color: Color = Color(1, 1, 1, 0.4)
var gem_size: float = 9.0
## Vẽ nét nối lên viên phía trên (lộ trình dọc); độ dài tính từ mép trên Control
var link_above: float = 0.0
var link_color: Color = Color(1, 1, 1, 0.3)


func setup(gem_state: GemState, gem_color: Color, faint: Color, half_height: float) -> void:
	state = gem_state
	color = gem_color
	locked_color = faint
	gem_size = half_height
	custom_minimum_size = Vector2(half_height * HALO_SCALE * 2.0, half_height * 2.6)
	queue_redraw()


func _draw() -> void:
	var center := Vector2(size.x * 0.5, minf(size.y * 0.5, gem_size * 1.6))
	if link_above > 0.0:
		draw_line(Vector2(center.x, -link_above), Vector2(center.x, center.y - gem_size * 1.2), link_color, 1.5, true)
	draw_gem(self, center, gem_size, state, color, locked_color)


## Vẽ một viên ngọc lên canvas bất kỳ (thẻ nguyên tố dùng trực tiếp, không cần tạo node)

static func draw_gem(canvas: CanvasItem, center: Vector2, half_height: float, gem_state: GemState, gem_color: Color, faint: Color) -> void:
	var h := half_height
	var w := half_height * 0.72
	var points := PackedVector2Array([
		center + Vector2(0.0, -h), center + Vector2(w, -h * 0.35), center + Vector2(w, h * 0.35),
		center + Vector2(0.0, h), center + Vector2(-w, h * 0.35), center + Vector2(-w, -h * 0.35)])
	var outline := points.duplicate()
	outline.append(points[0])
	if gem_state == GemState.LOCKED:
		canvas.draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.45))
		canvas.draw_polyline(outline, faint, 1.2, true)
		return
	if gem_state == GemState.CURRENT:
		canvas.draw_circle(center, h * HALO_SCALE * 0.62, Color(gem_color, 0.16))
		canvas.draw_circle(center, h * HALO_SCALE * 0.42, Color(gem_color, 0.22))
	canvas.draw_colored_polygon(points, gem_color)
	# Mặt sáng: tam giác trên-trái (đỉnh, góc trái trên, tâm)
	canvas.draw_colored_polygon(PackedVector2Array([points[0], points[5], center]), gem_color.lightened(FACET_LIGHTEN))
	canvas.draw_colored_polygon(PackedVector2Array([points[3], points[2], center]), gem_color.darkened(0.25))
	canvas.draw_polyline(outline, gem_color.darkened(OUTLINE_DARKEN), 1.2, true)
