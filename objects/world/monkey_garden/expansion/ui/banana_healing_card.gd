class_name BananaHealingCard
extends Control
const ICON: Texture2D = preload("res://ui/hud/icons/banana_weapon/healing_banana.svg")
var _uses: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE; set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 418; offset_right = 687; offset_top = -120; offset_bottom = -24
	var panel: PanelContainer = PanelContainer.new(); add_child(panel); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style: StyleBoxFlat = StyleBoxFlat.new(); style.bg_color = Color("10291fed"); style.border_color = Color("8cde9a")
	style.set_border_width_all(2); style.set_corner_radius_all(14); style.set_content_margin_all(10); panel.add_theme_stylebox_override("panel",style)
	var row: HBoxContainer = HBoxContainer.new(); row.add_theme_constant_override("separation",10); panel.add_child(row)
	var image: TextureRect = TextureRect.new(); image.texture = ICON; image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; image.custom_minimum_size = Vector2(66,66); row.add_child(image)
	var column: VBoxContainer = VBoxContainer.new(); column.add_theme_constant_override("separation",3); row.add_child(column)
	var title: Label = Label.new(); title.text = "Chuối dinh dưỡng"; title.add_theme_font_size_override("font_size",16); title.modulate = Color("baffbf"); column.add_child(title)
	_uses = Label.new(); _uses.add_theme_font_size_override("font_size",22); column.add_child(_uses)
	var caption: Label = Label.new(); caption.text = "Hồi 1 máu / lần"; caption.add_theme_font_size_override("font_size",13); column.add_child(caption)
	var badge: PanelContainer = PanelContainer.new(); add_child(badge); badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -22; badge.offset_right = 12; badge.offset_top = -12; badge.offset_bottom = 22
	var key_style: StyleBoxFlat = StyleBoxFlat.new(); key_style.bg_color = Color("163b27"); key_style.border_color = Color("a5efb2")
	key_style.set_border_width_all(2); key_style.set_corner_radius_all(18); badge.add_theme_stylebox_override("panel",key_style)
	var key: Label = Label.new(); key.text = "H"; key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; badge.add_child(key)
	hide()

func refresh(uses: int, maximum: int) -> void:
	_uses.text = "%d / %d"%[uses,maximum]; _uses.modulate = Color.WHITE if uses > 0 else Color("f49c80")
