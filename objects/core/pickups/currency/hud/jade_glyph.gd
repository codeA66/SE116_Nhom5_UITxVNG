@tool
class_name JadeGlyph
extends TextureRect
## Tinh thể nét gốc; TextureRect vẫn nhận tranh tay qua texture nếu được gán.
const Style = preload("res://resources/ui/hud_style.gd")
@export var style: Style = preload("res://resources/ui/hud_style.tres")
@export var jade_color: Color = Color.WHITE
## Không chạy process, chỉ vẽ lại khi dữ liệu hoặc kích thước đổi.
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_process(false)
	resized.connect(queue_redraw)
## Nét vàng mảnh thống nhất với viền bình, gân trong mang màu CurrencyData.
func _draw() -> void:
	if texture != null: return
	var glyph: Resource = style.glyphs.get(&"jade")
	if glyph == null: return
	var extent: float = maxf(minf(size.x,size.y)*0.48,0.01)
	glyph.draw_on(self,size*0.5,extent,style.gold,style.stroke_width())
	draw_line(size*Vector2(0.5,0.22),size*Vector2(0.5,0.78),jade_color,style.stroke_width(),true)
