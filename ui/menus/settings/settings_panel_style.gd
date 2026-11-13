class_name SettingsPanelStyle
extends Resource
## Màu, cỡ chữ, kích thước của khung Cài đặt. Cùng một khung dùng ở menu chính, menu tạm dừng và màn Tab,
## nên mỗi nơi có thể gán style riêng (cỡ chữ nhỏ hơn trong Tab) mà không sửa code.

@export_group("Màu")
@export var ink: Color = Color(0.94, 0.93, 0.89)
@export var dim: Color = Color(0.58, 0.6, 0.63)
@export var accent: Color = Color(0.86, 0.82, 0.7)
## Rãnh thanh trượt
@export var track: Color = Color(1, 1, 1, 0.14)

@export_group("Cỡ")
@export var tab_font: int = 24
@export var row_font: int = 22
@export var description_font: int = 18
@export var row_height: float = 46.0
## Bề ngang ô điều chỉnh bên phải mỗi dòng
@export var control_width: float = 280.0
@export var marker_size: float = 4.0
@export_range(1.0, 25.0, 1.0) var slider_step: float = 5.0
@export var tab_gap: int = 52
@export var row_gap: int = 4


func apply_slider(slider: HSlider) -> void:
	var rail := StyleBoxFlat.new()
	rail.bg_color = track
	rail.content_margin_top = 2.0
	rail.content_margin_bottom = 2.0
	var filled := StyleBoxFlat.new()
	filled.bg_color = accent
	filled.content_margin_top = 2.0
	filled.content_margin_bottom = 2.0
	var focus := StyleBoxEmpty.new()
	slider.add_theme_stylebox_override(&"slider", rail)
	slider.add_theme_stylebox_override(&"grabber_area", filled)
	slider.add_theme_stylebox_override(&"grabber_area_highlight", filled)
	slider.add_theme_stylebox_override(&"focus", focus)


## Nút chữ không viền cho ô giá trị (Bật / Tắt, tên phím, ngôn ngữ)
func make_value_button() -> Button:
	var button := Button.new()
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override(&"font_size", row_font)
	button.add_theme_color_override(&"font_focus_color", ink)
	button.add_theme_color_override(&"font_hover_color", ink)
	button.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	return button
