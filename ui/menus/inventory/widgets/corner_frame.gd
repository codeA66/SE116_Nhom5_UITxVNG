@tool
class_name CornerFrame
extends Control
## Hoa văn ở 4 góc màn Tab (kiểu khung góc của Hollow Knight / Hades): chỉ trang trí góc, giữa để trống
## cho cảnh game mờ phía sau. Mỗi góc: hai nét kẻ mờ dần, một vòng xoắn nhỏ và hạt kim cương.

const SPIRAL_STEPS := 20
const SPIRAL_TURNS := 0.85

@export var color: Color = Color(0.86, 0.84, 0.76, 0.85):
	set(value):
		color = value
		queue_redraw()
## Lề trong so với mép (px)
@export var margin: float = 26.0:
	set(value):
		margin = value
		queue_redraw()
## Độ dài nét kẻ mỗi góc (px)
@export var corner_size: float = 46.0:
	set(value):
		corner_size = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size).grow(-margin)
	var clear := Color(color, 0.0)
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var sx := -1.0 if corner.x > rect.get_center().x else 1.0
		var sy := -1.0 if corner.y > rect.get_center().y else 1.0
		# Hai nét kẻ đi ra từ góc, mờ dần ở đầu
		for direction: Vector2 in [Vector2(sx, 0.0), Vector2(0.0, sy)]:
			draw_polyline_colors(PackedVector2Array([corner, corner + direction * corner_size * 2.2]), PackedColorArray([color, clear]), 1.2, true)
		# Vòng xoắn nhỏ cuộn vào trong góc
		var radius := corner_size * 0.22
		var origin := corner + Vector2(sx, sy) * radius * 1.6
		var points := PackedVector2Array()
		for i in SPIRAL_STEPS + 1:
			var t := float(i) / SPIRAL_STEPS
			var angle := PI * 1.25 + t * TAU * SPIRAL_TURNS
			points.append(origin + Vector2(cos(angle) * sx, sin(angle) * sy) * radius * (1.0 - t * 0.6))
		draw_polyline(points, color, 1.2, true)
		var d := 3.5
		draw_colored_polygon(PackedVector2Array([corner + Vector2(0, -d), corner + Vector2(d, 0), corner + Vector2(0, d), corner + Vector2(-d, 0)]), color)
