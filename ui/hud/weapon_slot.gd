@tool
class_name WeaponSlot
extends Control
## Chỉ hiện vũ khí đã nhặt; nhãn duy nhất là phím đang gán trong Input Map.

@export var slot: WeaponData.Slot = WeaponData.Slot.SWORD
@export var input_action: StringName = &"weapon_1"
@export var accent_color := Color("7be9ff")

var selected: bool = false
var owned: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	refresh()


func refresh() -> void:
	owned = GameState.get_weapon_in_slot(slot) != null
	var equipped := GameState.get_weapon()
	selected = equipped != null and equipped.slot == slot
	visible = owned
	$Icon.modulate = Color.WHITE if selected else Color("9ebdc8")
	$Key.modulate = accent_color if selected else Color("91a4b3")
	refresh_binding()
	queue_redraw()


func refresh_binding() -> void:
	var label := "—"
	if InputMap.has_action(input_action):
		var events := InputMap.action_get_events(input_action)
		if not events.is_empty():
			label = _binding_label(events[0])
	if $Key.text != label:
		$Key.text = label
		# Phím dài (Space, Ctrl+Q...) không bị cắt hoặc đè lên ô bên cạnh.
		custom_minimum_size.x = maxf(64.0, $Key.get_minimum_size().x + 8.0)
		queue_redraw()


func _binding_label(event: InputEvent) -> String:
	if event is InputEventKey:
		if event.keycode != KEY_NONE:
			return event.as_text_keycode()
		if event.physical_keycode != KEY_NONE:
			return event.as_text_physical_keycode()
		return event.as_text_key_label()
	if event is InputEventMouseButton:
		var modifiers: Array[String] = []
		if event.ctrl_pressed:
			modifiers.append("Ctrl")
		if event.alt_pressed:
			modifiers.append("Alt")
		if event.shift_pressed:
			modifiers.append("Shift")
		if event.meta_pressed:
			modifiers.append("Meta")
		var button: String = {
			MOUSE_BUTTON_WHEEL_UP: "Wheel ↑", MOUSE_BUTTON_WHEEL_DOWN: "Wheel ↓",
			MOUSE_BUTTON_WHEEL_LEFT: "Wheel ←", MOUSE_BUTTON_WHEEL_RIGHT: "Wheel →",
		}.get(event.button_index, "M%d" % event.button_index)
		modifiers.append(button)
		return "+".join(modifiers)
	if event is InputEventJoypadButton:
		return "Pad %d" % event.button_index
	if event is InputEventJoypadMotion:
		return "Axis %d%s" % [event.axis, "+" if event.axis_value >= 0.0 else "−"]
	return event.as_text()


func _draw() -> void:
	var center := Vector2(size.x * 0.5, 32)
	var radius := 28.0
	var points := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	if selected:
		for width: float in [10.0, 7.0, 4.0]:
			draw_polyline(outline, Color(accent_color, 0.07), width, true)
	draw_colored_polygon(points, Color("173545") if selected else Color(0.035, 0.065, 0.10, 0.88))
	draw_polyline(outline, accent_color if selected else Color("4d6376"), 2.0, true)
