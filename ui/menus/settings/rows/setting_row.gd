class_name SettingRow
extends HBoxContainer
## Một dòng của màn Cài đặt: tên bên trái, ô điều chỉnh bên phải. Dòng được chọn thì tên sáng và có hạt thoi đánh dấu.
## Loại dòng mới (thanh trượt, bật/tắt, đổi phím...) kế thừa lớp này và tự dựng ô điều chỉnh trong _build_control().

## Ô điều chỉnh của dòng vừa được chọn: khung Cài đặt hiện mô tả
signal focused(row: SettingRow)

var title: String = ""
var description: String = ""

var _label: Label
var _style: SettingsPanelStyle
var _selected: bool = false


func setup(row_title: String, row_description: String, panel_style: SettingsPanelStyle) -> void:
	title = row_title
	description = row_description
	_style = panel_style
	custom_minimum_size.y = _style.row_height
	add_theme_constant_override(&"separation", 16)
	_label = Label.new()
	_label.text = title
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override(&"font_size", _style.row_font)
	add_child(_label)
	var control := _build_control()
	control.custom_minimum_size.x = _style.control_width
	add_child(control)
	var target := get_focus_control()
	target.focus_entered.connect(_set_selected.bind(true))
	target.focus_exited.connect(_set_selected.bind(false))
	target.mouse_entered.connect(target.grab_focus)
	_set_selected(false)
	refresh()


## Ô nhận focus của dòng (khung Cài đặt dùng để đưa con trỏ vào trang)
func get_focus_control() -> Control:
	return get_child(1) as Control


## Đọc lại giá trị từ Settings. Lớp con ghi đè
func refresh() -> void:
	pass


## Lớp con ghi đè: tạo ô điều chỉnh (Control nhận focus)
func _build_control() -> Control:
	return Control.new()


func _set_selected(selected: bool) -> void:
	_selected = selected
	_label.add_theme_color_override(&"font_color", _style.ink if selected else _style.dim)
	queue_redraw()
	if selected:
		focused.emit(self)


func _draw() -> void:
	if not _selected:
		return
	var y := size.y * 0.5
	var s := _style.marker_size
	var at := Vector2(-s * 3.0, y)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -s), at + Vector2(s, 0), at + Vector2(0, s), at + Vector2(-s, 0)]), _style.accent)
	var faint := _style.accent
	faint.a = 0.0
	var line := _style.accent
	line.a = 0.35
	draw_polyline_colors(PackedVector2Array([Vector2(0, size.y - 1), Vector2(size.x * 0.5, size.y - 1), Vector2(size.x, size.y - 1)]),
		PackedColorArray([line, line, faint]), 1.0, true)
