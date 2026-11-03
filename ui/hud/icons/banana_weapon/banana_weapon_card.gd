class_name BananaWeaponCard
extends Control
## Nội dung tách cột để tên, lượng đạn và phím chọn không nhập thành một chuỗi.
const ICON: Texture2D = preload("res://ui/hud/icons/banana_weapon/banana_weapon.svg")
var _amount: Label
var _status: Label
var _badge: PanelContainer
var _panel: PanelContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 24; offset_right = 392; offset_top = -132; offset_bottom = -24
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("101c28ed"); style.border_color = Color("779489")
	style.set_border_width_all(2); style.set_corner_radius_all(16)
	style.content_margin_left = 14; style.content_margin_right = 20
	style.content_margin_top = 10; style.content_margin_bottom = 12
	_panel = PanelContainer.new(); add_child(_panel); _panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_theme_stylebox_override("panel",style)
	var row: HBoxContainer = HBoxContainer.new(); row.add_theme_constant_override("separation",14); _panel.add_child(row)
	var picture: TextureRect = TextureRect.new(); picture.texture = ICON
	picture.custom_minimum_size = Vector2(120,78); picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; row.add_child(picture)
	var column: VBoxContainer = VBoxContainer.new(); column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",3); row.add_child(column)
	var name_label: Label = Label.new(); name_label.text = "bAKa-47"; name_label.add_theme_font_size_override("font_size",23)
	name_label.modulate = Color("ffe487"); column.add_child(name_label)
	var ammo_row: HBoxContainer = HBoxContainer.new(); ammo_row.add_theme_constant_override("separation",12); column.add_child(ammo_row)
	var caption: Label = Label.new(); caption.text = "ĐẠN"; caption.add_theme_font_size_override("font_size",12); caption.modulate = Color("9eafbb"); ammo_row.add_child(caption)
	_amount = Label.new(); _amount.add_theme_font_size_override("font_size",26); ammo_row.add_child(_amount)
	_status = Label.new(); _status.add_theme_font_size_override("font_size",11); column.add_child(_status)
	_badge = PanelContainer.new(); add_child(_badge)
	_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_badge.offset_left = -25; _badge.offset_right = 13; _badge.offset_top = -13; _badge.offset_bottom = 25
	var badge_style: StyleBoxFlat = StyleBoxFlat.new(); badge_style.bg_color = Color("183746")
	badge_style.border_color = Color("7dddff"); badge_style.set_border_width_all(2); badge_style.set_corner_radius_all(20)
	_badge.add_theme_stylebox_override("panel",badge_style)
	var key: Label = Label.new(); key.text = "V"; key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; key.add_theme_font_size_override("font_size",20); _badge.add_child(key)

func refresh(ammo: int, equipped: bool) -> void:
	_amount.text = "%02d" % ammo
	_amount.modulate = Color.WHITE if ammo > 0 else Color("ff8170")
	_status.text = "ĐANG TRANG BỊ" if equipped else "CHƯA TRANG BỊ"
	_status.modulate = Color("93efbc") if equipped else Color("9eafbb")
	var style: StyleBoxFlat = _panel.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = Color("f3ca60") if equipped else Color("66869a")
