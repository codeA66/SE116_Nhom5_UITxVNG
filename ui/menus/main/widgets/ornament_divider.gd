@tool
class_name OrnamentDivider
extends Control
## Nét kẻ ngang mảnh, mờ dần về hai đầu, có hạt kim cương ở giữa (tách tiêu đề với nội dung).

const FLOURISH_STEPS := 24
## Vòng xoắn cuộn bao nhiêu vòng và thu nhỏ bao nhiêu về cuối nét
const FLOURISH_TURNS := 0.9
const FLOURISH_SHRINK := 0.7
## Nét xoắn phụ phía dưới nhỏ hơn nét chính
const FLOURISH_MINOR := 0.55
## Vòng xoắn nhỏ phía ngoài mỗi bên (cuộn lên), tính theo flourish_size
const FLOURISH_FAR := 0.45
## Khoảng hở giữa nét kẻ và cụm hoa văn, tính theo flourish_size
const FLOURISH_SPAN := 3.4

@export var color: Color = Color(0.86, 0.82, 0.7, 0.85):
	set(value):
		color = value
		queue_redraw()
@export_range(1.0, 20.0, 0.5) var diamond_size: float = 4.5:
	set(value):
		diamond_size = value
		queue_redraw()
## Bao nhiêu phần bề ngang (mỗi bên) thì nét mờ hết
@export_range(0.05, 1.0, 0.01) var fade_ratio: float = 0.45:
	set(value):
		fade_ratio = value
		queue_redraw()
## 0..1: phần nét đang hiện tính từ giữa ra (chạy hiệu ứng mở nét)
@export_range(0.0, 1.0, 0.01) var reveal: float = 1.0:
	set(value):
		reveal = value
		queue_redraw()
## Thêm hai nét xoắn trang trí hai bên hạt kim cương (bảng nhận kỹ năng); tự cuộn ra theo reveal
@export var flourish: bool = false:
	set(value):
		flourish = value
		queue_redraw()
@export_range(2.0, 40.0, 0.5) var flourish_size: float = 9.0:
	set(value):
		flourish_size = value
		queue_redraw()



func _draw() -> void:
	var y := size.y * 0.5
	var mid := size.x * 0.5
	var half := mid * reveal
	var clear := color
	clear.a = 0.0
	var gap := diamond_size * 2.2 + (flourish_size * FLOURISH_SPAN if flourish else 0.0)
	for side in [-1.0, 1.0]:
		var inner := Vector2(mid + side * gap, y)
		var outer := Vector2(mid + side * maxf(half, gap), y)
		var fade_at := inner.lerp(outer, 1.0 - fade_ratio)
		draw_polyline_colors(PackedVector2Array([inner, fade_at, outer]), PackedColorArray([color, color, clear]), 1.0, true)
	var s := diamond_size * reveal
	var c := Vector2(mid, y)
	if s > 0.1:
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), color)
	if flourish and reveal > 0.0:
		_draw_flourish(c, reveal)


## Cụm hoa văn mỗi bên: xoắn lớn cuộn lên, xoắn phụ cuộn xuống, vòng nhỏ phía ngoài nối với nét kẻ
func _draw_flourish(center: Vector2, amount: float) -> void:
	var start := diamond_size * 1.6
	for side: float in [-1.0, 1.0]:
		var major := flourish_size
		var minor := flourish_size * FLOURISH_MINOR
		var far := flourish_size * FLOURISH_FAR
		_draw_spiral(center + Vector2(side * (start + major), 0.0), major, side, -1.0, amount)
		_draw_spiral(center + Vector2(side * (start + minor), 0.0), minor, side, 1.0, amount)
		_draw_spiral(center + Vector2(side * (start + flourish_size * 2.2 + far), 0.0), far, side, -1.0, amount)


## Một nét xoắn bắt đầu ở mép trong (phía hạt kim cương); vertical -1 = cuộn lên, 1 = cuộn xuống
func _draw_spiral(origin: Vector2, radius: float, side: float, vertical: float, amount: float) -> void:
	var points := PackedVector2Array()
	for i in FLOURISH_STEPS + 1:
		var t := float(i) / FLOURISH_STEPS * amount
		var angle := PI + t * TAU * FLOURISH_TURNS
		var r := radius * (1.0 - t * FLOURISH_SHRINK)
		points.append(origin + Vector2(cos(angle) * side, -sin(angle) * vertical) * r)
	draw_polyline(points, color, 1.2, true)
