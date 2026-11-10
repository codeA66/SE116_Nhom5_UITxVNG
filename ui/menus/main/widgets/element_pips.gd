@tool
class_name ElementPips
extends Control
## Hàng hạt nguyên tố trên ô hồ sơ: khu đã phá thì hạt sáng màu nguyên tố, chưa phá thì chỉ là viền mờ.

@export_range(2.0, 20.0, 0.5) var pip_size: float = 6.0
@export_range(0.0, 40.0, 0.5) var spacing: float = 8.0
@export var empty_color: Color = Color(0.58, 0.6, 0.63, 0.55)

var _colors: Array[Color] = []
var _lit: Array[bool] = []


func setup(colors: Array[Color], lit: Array[bool]) -> void:
	_colors = colors
	_lit = lit
	custom_minimum_size = Vector2(colors.size() * (pip_size * 2.0 + spacing), pip_size * 2.0 + 2.0)
	queue_redraw()


func _draw() -> void:
	var step := pip_size * 2.0 + spacing
	var y := size.y * 0.5
	for i in _colors.size():
		var c := Vector2(pip_size + i * step, y)
		var s := pip_size
		var points := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0), c + Vector2(0, -s)])
		if i < _lit.size() and _lit[i]:
			draw_colored_polygon(points.slice(0, 4), _colors[i])
		else:
			draw_polyline(points, empty_color, 1.0, true)
