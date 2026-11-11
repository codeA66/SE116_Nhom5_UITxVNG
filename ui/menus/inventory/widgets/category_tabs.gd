class_name CategoryTabs
extends HBoxContainer
## Thanh phân mục Cấp 1 (Túi Đồ [Q] <-> Hệ Thống [E]) theo phong cách Zelda: Breath of the Wild.
## Phân mục đang chọn sáng màu ink, hiện nét hoa văn trang trí; phân mục phụ mờ màu dim.
## Người chơi có thể bấm phím Q / E hoặc click chuột trực tiếp vào tên phân mục.

signal category_selected(index: int)

var _style: InventoryStyle
var _active_index: int = 0

@onready var _inv_button: Control = $Inventory
@onready var _inv_label: Label = $Inventory/Content/Name
@onready var _inv_key: KeyGlyph = $Inventory/Content/Key
@onready var _inv_indicator: Control = $Inventory/Indicator

@onready var _sys_button: Control = $System
@onready var _sys_label: Label = $System/Content/Name
@onready var _sys_key: KeyGlyph = $System/Content/Key
@onready var _sys_indicator: Control = $System/Indicator


func _ready() -> void:
	for button: Control in [_inv_button, _sys_button]:
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_inv_button.gui_input.connect(_on_button_input.bind(0))
	_sys_button.gui_input.connect(_on_button_input.bind(1))


func configure(style: InventoryStyle, prev_action: StringName, next_action: StringName) -> void:
	_style = style
	for key: KeyGlyph in [_inv_key, _sys_key]:
		key.font_size = style.key_font
		key.fill_color = Color(0.0, 0.0, 0.0, 0.4)
	_inv_key.text = PageTabs.key_name(prev_action)
	_sys_key.text = PageTabs.key_name(next_action)
	set_active_category(_active_index)


func set_active_category(index: int) -> void:
	_active_index = index
	if _style == null:
		return
	var is_inv := (index == 0)

	# Túi Đồ
	_inv_label.add_theme_font_size_override(&"font_size", _style.tab_font + (2 if is_inv else 0))
	_inv_label.add_theme_color_override(&"font_color", _style.ink if is_inv else _style.dim)
	_inv_key.text_color = _style.ink if is_inv else _style.dim
	_inv_key.border_color = Color(_style.ink if is_inv else _style.dim, 0.85 if is_inv else 0.35)
	if _inv_indicator:
		_inv_indicator.modulate.a = 1.0 if is_inv else 0.0

	# Hệ Thống
	_sys_label.add_theme_font_size_override(&"font_size", _style.tab_font + (2 if not is_inv else 0))
	_sys_label.add_theme_color_override(&"font_color", _style.ink if not is_inv else _style.dim)
	_sys_key.text_color = _style.ink if not is_inv else _style.dim
	_sys_key.border_color = Color(_style.ink if not is_inv else _style.dim, 0.85 if not is_inv else 0.35)
	if _sys_indicator:
		_sys_indicator.modulate.a = 1.0 if not is_inv else 0.0


func _on_button_input(event: InputEvent, index: int) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		if index != _active_index:
			category_selected.emit(index)
