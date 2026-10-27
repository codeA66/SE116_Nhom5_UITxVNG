class_name WeaponFusionSlot
extends Control
## Một hàng vũ khí trong tủ đồ: tên vũ khí và ổ ghép. Thả nguyên tố vào để ghép (đang ở vũ khí khác thì chuyển sang);
## kéo nguyên tố ra khỏi ổ để chuyển / tháo; chuột phải vào ổ để tháo nhanh.

signal hovered(text: String)

const ROW_SIZE := Vector2(300, 56)
const SOCKET_RADIUS := 20.0

var weapon: WeaponData
var element: ElementData
var fusion: FusionData


func _ready() -> void:
	custom_minimum_size = ROW_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)


func setup(data: WeaponData, fused: ElementData, combo: FusionData) -> void:
	weapon = data
	element = fused
	fusion = combo
	queue_redraw()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if element == null:
		return null
	set_drag_preview(InventoryMenu.make_drag_preview(element))
	return {"element": element.id, "from_slot": weapon.slot}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("element")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	GameState.fuse(data["element"], weapon.slot)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT and element:
		GameState.unfuse(weapon.slot)
		accept_event()


func _socket_center() -> Vector2:
	return Vector2(size.x - 34.0, size.y * 0.5)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.065, 0.10, 0.85))
	draw_rect(Rect2(Vector2.ZERO, size), Color("4d6376"), false, 1.0)
	var font := get_theme_default_font()
	var title := weapon.display_name if fusion == null else "%s  →  %s" % [weapon.display_name, fusion.display_name]
	draw_string(font, Vector2(14, size.y * 0.5 + 7), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 80.0, 18,
		Color.WHITE if element else Color("9ebdc8"))
	var socket := _socket_center()
	draw_circle(socket, SOCKET_RADIUS + 3.0, Color(0.02, 0.04, 0.06))
	if element:
		draw_circle(socket, SOCKET_RADIUS, element.color)
	else:
		draw_arc(socket, SOCKET_RADIUS, 0.0, TAU, 28, Color("4d6376"), 2.0, true)


func _on_mouse_entered() -> void:
	if fusion:
		hovered.emit("%s: %s\nChuột phải hoặc kéo ra để tháo." % [fusion.display_name, fusion.description])
	elif element:
		hovered.emit("%s đang ghép %s nhưng tổ hợp này chưa có buff." % [weapon.display_name, element.display_name])
	else:
		hovered.emit("%s: kéo một nguyên tố vào ổ bên phải để ghép." % weapon.display_name)
