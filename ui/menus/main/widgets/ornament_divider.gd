@tool
class_name OrnamentDivider
extends Control
## Nét kẻ ngang mảnh, mờ dần về hai đầu, có hạt kim cương ở giữa (tách tiêu đề với nội dung).

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


func _draw() -> void:
	var y := size.y * 0.5
	var mid := size.x * 0.5
	var half := mid * reveal
	var clear := color
	clear.a = 0.0
	var gap := diamond_size * 2.2
	for side in [-1.0, 1.0]:
		var inner := Vector2(mid + side * gap, y)
		var outer := Vector2(mid + side * maxf(half, gap), y)
		var fade_at := inner.lerp(outer, 1.0 - fade_ratio)
		draw_polyline_colors(PackedVector2Array([inner, fade_at, outer]), PackedColorArray([color, color, clear]), 1.0, true)
	var s := diamond_size * reveal
	var c := Vector2(mid, y)
	if s > 0.1:
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), color)
