class_name MenuItem
extends Button
## Mục menu kiểu Death's Door: chưa chọn thì chữ mờ; chọn thì chữ sáng, hai hạt kim cương trượt vào hai bên
## và nét gạch mảnh mở rộng dưới chữ. Chuột lướt qua = chọn, nên chuột / phím / tay cầm dùng chung một trạng thái focus.

@export var accent_color: Color = Color(0.86, 0.82, 0.7)
@export_range(1.0, 20.0, 0.5) var ornament_size: float = 5.0
## Khoảng cách hạt trang trí tới mép chữ (px)
@export_range(0.0, 120.0, 1.0) var ornament_gap: float = 18.0
## Hạt trượt vào từ xa bấy nhiêu px khi được chọn
@export_range(0.0, 80.0, 1.0) var ornament_travel: float = 14.0
@export_range(0.01, 1.0, 0.01) var glow_time: float = 0.18
@export var show_underline: bool = true
## Bật: hạt trang trí đặt theo bề ngang cả nút (ô hồ sơ) thay vì theo bề ngang chữ
@export var span_full_width: bool = false
## Ô đang chọn (span_full_width): độ đậm dải sáng nền + hai nét mảnh trên dưới
@export_range(0.0, 1.0, 0.01) var band_alpha: float = 0.1

var _glow: float = 0.0
var _tween: Tween


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(_on_mouse_entered)
	focus_entered.connect(_animate_glow.bind(1.0))
	focus_exited.connect(_animate_glow.bind(0.0))


func _draw() -> void:
	if _glow <= 0.001:
		return
	var font := get_theme_font(&"font")
	var font_size := get_theme_font_size(&"font_size")
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var center := size * 0.5
	var color := accent_color
	color.a *= _glow
	var half := (size.x * 0.5 - ornament_size) if span_full_width else text_width * 0.5 + ornament_gap
	half += (1.0 - _glow) * ornament_travel
	_draw_diamond(Vector2(center.x - half, center.y), color)
	_draw_diamond(Vector2(center.x + half, center.y), color)
	if span_full_width:
		_draw_band(color)
	if show_underline and not span_full_width:
		var line_half := text_width * 0.5 * _glow
		var y := center.y + font_size * 0.62
		draw_line(Vector2(center.x - line_half, y), Vector2(center.x + line_half, y), color, 1.0, true)


func _draw_diamond(at: Vector2, color: Color) -> void:
	var s := ornament_size
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -s), at + Vector2(s, 0), at + Vector2(0, s), at + Vector2(-s, 0)]), color)


func _animate_glow(target: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_method(_set_glow, _glow, target, glow_time)


func _set_glow(value: float) -> void:
	_glow = value
	queue_redraw()


func _on_mouse_entered() -> void:
	if not disabled and focus_mode != Control.FOCUS_NONE:
		grab_focus()


## Dải sáng mờ dần về hai đầu + hai nét kẻ trên dưới (kiểu ô hồ sơ Hollow Knight): ô đang chọn nổi rõ trên nền 3D
func _draw_band(color: Color) -> void:
	var band := color
	band.a = band_alpha * _glow
	var clear := band
	clear.a = 0.0
	var mid := size.x * 0.5
	var points := PackedVector2Array([Vector2(0, 0), Vector2(mid, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(mid, size.y), Vector2(0, size.y)])
	draw_polygon(points, PackedColorArray([clear, band, clear, clear, band, clear]))
	var line_color := color
	line_color.a *= 0.6
	var line_clear := line_color
	line_clear.a = 0.0
	for y in [0.5, size.y - 0.5]:
		draw_polyline_colors(PackedVector2Array([Vector2(0, y), Vector2(mid, y), Vector2(size.x, y)]), PackedColorArray([line_clear, line_color, line_clear]), 1.0, true)
