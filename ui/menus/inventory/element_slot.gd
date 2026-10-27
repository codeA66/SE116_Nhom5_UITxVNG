class_name ElementSlot
extends Control
## Ô một nguyên tố trong tủ đồ. Kéo ra để ghép vào vũ khí; thả nguyên tố đang ghép về đúng ô của nó để tháo.
## Chưa có nguyên tố thì hiện ô khóa, không kéo được.

signal hovered(text: String)

const SIZE := Vector2(64, 64)

var element: ElementData
var owned: bool = false
## Ô vũ khí đang chứa nguyên tố này; -1 = chưa ghép
var fused_slot: int = -1


func _ready() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)


func setup(data: ElementData, is_owned: bool, in_slot: int) -> void:
	element = data
	owned = is_owned
	fused_slot = in_slot
	tooltip_text = ""
	queue_redraw()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not owned:
		return null
	set_drag_preview(InventoryMenu.make_drag_preview(element))
	return {"element": element.id}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("from_slot") and data.get("element") == element.id


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	GameState.unfuse(data["from_slot"])


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, 28.0, Color(0.035, 0.065, 0.10, 0.9))
	if not owned:
		draw_arc(center, 26.0, 0.0, TAU, 32, Color("4d6376"), 2.0, true)
		_draw_text("?", center, Color("4d6376"))
		return
	# Đang ghép: mờ đi, viền nét đứt kiểu "đã lấy ra"
	var color := element.color if fused_slot < 0 else Color(element.color, 0.35)
	draw_circle(center, 22.0, color)
	draw_arc(center, 26.0, 0.0, TAU, 32, element.color, 2.0, true)
	if element.icon:
		draw_texture_rect(element.icon, Rect2(center - Vector2(16, 16), Vector2(32, 32)), false)
	else:
		_draw_text(element.display_name.left(1), center, Color(0.05, 0.08, 0.12))


func _draw_text(text: String, center: Vector2, color: Color) -> void:
	var font := get_theme_default_font()
	var font_size := 22
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center + Vector2(-text_size.x * 0.5, text_size.y * 0.32), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _on_mouse_entered() -> void:
	if not owned:
		hovered.emit("Chưa có nguyên tố này.")
	elif fused_slot >= 0:
		hovered.emit("%s: đang ghép vào vũ khí, kỹ năng %s tạm khóa. Kéo về đây để tháo." % [element.display_name, element.ability.display_name])
	else:
		hovered.emit("%s: kéo vào một vũ khí để ghép. Khi ghép, kỹ năng %s tạm khóa." % [element.display_name, element.ability.display_name])
