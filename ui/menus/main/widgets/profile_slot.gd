class_name ProfileSlot
extends HBoxContainer
## Một ô hồ sơ (kiểu Hollow Knight): số ô, nơi đang đứng, tiền, hạt 4 nguyên tố, số kỹ năng.
## Ô trống ghi "Hành trình mới". Nút Xóa nằm riêng bên phải, chỉ hiện khi ô có dữ liệu.

signal chosen(slot: int)
signal delete_requested(slot: int)

var slot: int = 1

@onready var _main: MenuItem = $Main
@onready var _number: Label = $Main/Row/Number
@onready var _name: Label = $Main/Row/Info/Name
@onready var _detail: Label = $Main/Row/Info/Detail
@onready var _pips: ElementPips = $Main/Row/Pips
@onready var _delete: MenuItem = $Delete


func _ready() -> void:
	_main.pressed.connect(func() -> void: chosen.emit(slot))
	_delete.pressed.connect(func() -> void: delete_requested.emit(slot))


## progress = null: ô trống
func setup(slot_number: int, progress: PlayerProgress, data: MainMenuData, registry: ZoneRegistry) -> void:
	slot = slot_number
	_number.text = str(slot_number)
	_delete.text = data.delete_text
	_delete.add_theme_color_override(&"font_focus_color", data.danger_color)
	_delete.add_theme_color_override(&"font_hover_color", data.danger_color)
	_delete.accent_color = data.danger_color
	var has_data := progress != null
	# Giữ chỗ nút Xóa cả khi ô trống: 4 ô luôn thẳng hàng
	_delete.disabled = not has_data
	_delete.focus_mode = Control.FOCUS_ALL if has_data else Control.FOCUS_NONE
	_delete.modulate.a = 1.0 if has_data else 0.0
	_pips.visible = has_data
	_detail.visible = has_data
	if not has_data:
		_name.text = data.empty_slot_text
		_name.modulate = data.dim_color
		return
	_name.modulate = Color.WHITE
	_name.text = registry.get_location_name(progress.checkpoint_zone)
	var parts: PackedStringArray = []
	if data.shown_currency:
		parts.append("%d %s" % [progress.currencies.get(data.shown_currency.id, 0), data.shown_currency.display_name])
	parts.append("%d kỹ năng" % progress.abilities.size())
	_detail.text = "   ·   ".join(parts)
	var colors: Array[Color] = []
	var lit: Array[bool] = []
	for zone in registry.element_zones:
		colors.append(zone.color)
		lit.append(zone.is_cleared_in(progress))
	_pips.setup(colors, lit)


func get_main_button() -> MenuItem:
	return _main


func get_delete_button() -> MenuItem:
	return _delete
