class_name BananaWeaponCard
extends Control
## Tách tên, số đạn và phím để giữ bố cục khi đổi font hoặc kích thước.
const Style = preload("res://resources/ui/hud_style.gd")
const ICON: Texture2D = preload("res://ui/hud/icons/banana_weapon/banana_weapon.svg")
@export var style: Style = preload("res://resources/ui/hud_style.tres")
var _amount: Label
var _status: Label
var _panel_style: StyleBoxFlat

## Dựng một lần vì số đạn thay đổi thường xuyên hơn bố cục.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = style.theme
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_apply_offsets(self,style.banana_card_rect)

	var panel: PanelContainer = PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_style = _make_box(style.banana_panel_fill,style.banana_panel_border,style.banana_panel_radius)
	var margins: Vector4 = style.banana_card_margin
	_panel_style.content_margin_left = margins.x
	_panel_style.content_margin_top = margins.y
	_panel_style.content_margin_right = margins.z
	_panel_style.content_margin_bottom = margins.w
	panel.add_theme_stylebox_override(&"panel",_panel_style)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation",maxi(style.banana_row_gap,0))
	panel.add_child(row)
	var picture: TextureRect = TextureRect.new()
	picture.texture = ICON
	picture.custom_minimum_size = style.banana_picture_size.max(Vector2.ONE)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(picture)

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation",maxi(style.banana_column_gap,0))
	row.add_child(column)
	_add_label(column,style.banana_title,style.banana_title_font,style.banana_title_tint)
	var ammo_row: HBoxContainer = HBoxContainer.new()
	ammo_row.add_theme_constant_override(&"separation",maxi(style.banana_ammo_gap,0))
	column.add_child(ammo_row)
	_add_label(ammo_row,style.banana_ammo_caption,style.banana_caption_font,style.banana_caption_tint)
	_amount = _add_label(ammo_row,"",style.banana_amount_font,style.ivory)
	_status = _add_label(column,"",style.banana_status_font,style.banana_caption_tint)

	var badge: PanelContainer = PanelContainer.new()
	add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_apply_offsets(badge,style.banana_badge_rect)
	badge.add_theme_stylebox_override(&"panel",_make_box(style.banana_badge_fill,style.banana_badge_border,style.banana_badge_radius))
	var key: Label = _add_label(badge,style.banana_key_label,style.banana_key_font,style.ivory)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

## Chỉ cập nhật dữ liệu thay đổi, giữ cùng panel và nhãn suốt lượt chơi.
func refresh(ammo: int,equipped: bool) -> void:
	_amount.text = style.banana_ammo_format % ammo
	_amount.modulate = Color.WHITE if ammo > 0 else style.banana_empty_tint
	_status.text = style.banana_equipped_text if equipped else style.banana_unequipped_text
	_status.modulate = style.banana_equipped_tint if equipped else style.banana_caption_tint
	_panel_style.border_color = style.banana_panel_equipped_border if equipped else style.banana_panel_border

## Rect dùng chung cách đặt cạnh cho cả thẻ và nút nổi.
func _apply_offsets(control: Control,rect: Rect2) -> void:
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y

## Mỗi nền có resource riêng vì viền thẻ thay đổi khi trang bị.
func _make_box(fill: Color,border: Color,radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(maxi(style.banana_border_width,0))
	box.set_corner_radius_all(maxi(radius,0))
	return box

## Cùng font và viền chữ với HUD để số đạn đọc được trên sàn sáng.
func _add_label(parent: Control,value: String,font_size: int,tint: Color) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.add_theme_font_size_override(&"font_size",maxi(font_size,1))
	label.add_theme_color_override(&"font_color",tint)
	label.add_theme_color_override(&"font_outline_color",style.text_outline_color)
	label.add_theme_constant_override(&"outline_size",clampi(style.text_outline_size,0,8))
	parent.add_child(label)
	return label
