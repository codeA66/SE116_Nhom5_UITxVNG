class_name PageTabs
extends HBoxContainer
## Đầu màn Tab: tên trang đang xem ở giữa (chữ có chân, nét hoa văn bên dưới), tên trang trước / sau mờ ở hai bên
## kèm phím Z / C (đọc từ Input Map). Bấm chuột vào tên trang hai bên cũng đổi trang.

signal previous_requested
signal next_requested

var _style: InventoryStyle

@onready var _previous: Label = $Previous/Name
@onready var _previous_key: KeyGlyph = $Previous/Key
@onready var _next: Label = $Next/Name
@onready var _next_key: KeyGlyph = $Next/Key
@onready var _title: Label = $Center/Title
@onready var _rule: OrnamentDivider = $Center/Rule


func _ready() -> void:
	for side: Control in [$Previous, $Next]:
		side.mouse_filter = Control.MOUSE_FILTER_STOP
		side.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	($Previous as Control).gui_input.connect(_on_side_input.bind(false))
	($Next as Control).gui_input.connect(_on_side_input.bind(true))


func configure(style: InventoryStyle, previous_action: StringName, next_action: StringName) -> void:
	_style = style
	_title.add_theme_font_size_override(&"font_size", style.title_font)
	_title.add_theme_color_override(&"font_color", style.ink)
	_rule.color = style.ornament
	for label: Label in [_previous, _next]:
		label.add_theme_font_size_override(&"font_size", style.tab_font)
		label.add_theme_color_override(&"font_color", style.dim)
	for key: KeyGlyph in [_previous_key, _next_key]:
		key.font_size = style.key_font
		key.text_color = style.dim
		key.border_color = Color(style.dim, 0.6)
		key.fill_color = Color(0.0, 0.0, 0.0, 0.35)
	_previous_key.text = key_name(previous_action)
	_next_key.text = key_name(next_action)


## titles: tên các trang đang mở được; index: trang đang xem
func show_pages(titles: PackedStringArray, index: int) -> void:
	_title.text = tr(titles[index]).to_upper() if index >= 0 and index < titles.size() else ""
	var many := titles.size() > 1
	($Previous as Control).modulate.a = 1.0 if many else 0.0
	($Next as Control).modulate.a = 1.0 if many else 0.0
	if many:
		_previous.text = titles[posmod(index - 1, titles.size())]
		_next.text = titles[posmod(index + 1, titles.size())]


func _on_side_input(event: InputEvent, forward: bool) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		if forward:
			next_requested.emit()
		else:
			previous_requested.emit()


## Tên phím đầu tiên gán cho action trong Input Map (không ghi cứng phím)
static func key_name(action: StringName) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key:
			return OS.get_keycode_string(key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode)
	return "?"
