@tool
class_name HudGlyph
extends Resource
## Tranh nét chuẩn hóa: thêm biểu tượng bằng dữ liệu, không thêm nhánh theo tên kỹ năng.
@export var strokes: Array[PackedVector2Array] = []
@export var fills: Array[PackedVector2Array] = []
## Canvas giữ phép biến đổi trong lượt vẽ; không tạo mảng trong lúc hồi chiêu.
func draw_on(canvas: CanvasItem, center: Vector2, extent: float, tint: Color, width: float, angle: float = 0.0) -> void:
	if extent <= 0.0: return
	canvas.draw_set_transform(center,angle,Vector2.ONE*extent)
	for polygon: PackedVector2Array in fills:
		if polygon.size() >= 3: canvas.draw_colored_polygon(polygon,tint)
	for stroke: PackedVector2Array in strokes:
		if stroke.size() >= 2: canvas.draw_polyline(stroke,tint,maxf(width/extent,0.001),true)
	canvas.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
