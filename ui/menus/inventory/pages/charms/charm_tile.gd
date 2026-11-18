class_name CharmTile
extends MenuTile
## Mượn khung chọn và hiệu ứng của MenuTile để con trỏ có cùng cách đọc với các trang khác.

signal navigation_requested(tile: CharmTile, direction: Vector2i)

enum Mode { COLLECTION, EQUIPPED, EMPTY_SLOT }

const ARC_STEPS: int = 40
const MEDALLION_RADIUS: float = 0.39
const INNER_RADIUS: float = 0.80
const ICON_RATIO: float = 0.64
const LOCK_RATIO: float = 0.19
const DIRECTION_ACTIONS: Dictionary[StringName, Vector2i] = {
	&"ui_left": Vector2i.LEFT, &"move_left": Vector2i.LEFT,
	&"ui_right": Vector2i.RIGHT, &"move_right": Vector2i.RIGHT,
	&"ui_up": Vector2i.UP, &"move_forward": Vector2i.UP,
	&"ui_down": Vector2i.DOWN, &"move_back": Vector2i.DOWN,
}

var mode: Mode = Mode.COLLECTION
var charm: CharmData
var owned: bool = false
var equipped: bool = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventAction:
		for action: StringName in DIRECTION_ACTIONS:
			if event.is_action_pressed(action, true):
				navigation_requested.emit(self, DIRECTION_ACTIONS[action])
				accept_event()
				return
		if event.is_action_pressed(&"ui_accept"):
			activated.emit(self)
			accept_event()
			return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		activated.emit(self)
		accept_event()


func setup(data: CharmData, tile_mode: Mode, is_owned: bool, is_equipped: bool) -> void:
	if charm == data and mode == tile_mode and owned == is_owned and equipped == is_equipped:
		return
	charm = data
	mode = tile_mode
	owned = is_owned
	equipped = is_equipped
	queue_redraw()


func get_detail() -> DetailEntry:
	var entry: DetailEntry = DetailEntry.new()
	if mode == Mode.EMPTY_SLOT:
		entry.title = tr(style.charm_empty_slot_text)
		entry.add_section("", style.charm_empty_slot_description)
		return entry
	if not owned:
		entry.title = tr(style.charm_hidden_text)
		entry.add_section("", style.charm_hidden_description)
		return entry
	entry.title = tr(charm.display_name)
	entry.subtitle = tr(style.charm_cost_text) % charm.notch_cost
	if equipped:
		entry.subtitle += "  ·  " + tr(style.charm_equipped_text)
	entry.art_texture = charm.icon
	entry.add_section(style.charm_effect_text, charm.description)
	entry.lore = charm.lore
	if GameState.can_change_charms():
		var action_text: String = style.charm_remove_text if equipped else style.charm_equip_text
		entry.hint = tr(action_text) % PageTabs.key_name(&"ui_accept")
	return entry


func _draw_content(rect: Rect2) -> void:
	var center: Vector2 = rect.get_center()
	var radius: float = minf(rect.size.x, rect.size.y) * MEDALLION_RADIUS
	var line: float = style.charm_border_width
	var rim: Color = style.charm_socket_edge
	var is_worn: bool = mode == Mode.EQUIPPED
	if is_worn:
		rim = style.ornament
	elif has_focus():
		rim = style.charm_preview_color
	draw_circle(center, radius, style.charm_socket_fill, true, -1.0, true)
	draw_arc(center, radius, 0.0, TAU, ARC_STEPS, rim, line, true)
	draw_arc(center, radius * INNER_RADIUS, 0.0, TAU, ARC_STEPS, Color(rim, 0.38), line, true)
	if not owned or charm == null:
		draw_circle(center, radius * LOCK_RATIO, Color(rim, 0.60), true, -1.0, true)
		return
	var in_collection: bool = mode == Mode.COLLECTION
	var dim: bool = in_collection and equipped
	var tint: Color = Color.WHITE if charm.icon else style.ink
	if dim:
		tint.a *= 0.42
	_draw_emblem(charm.icon, center, rect.size.x * ICON_RATIO, tint, tr(charm.display_name))
	if dim:
		var mark: Vector2 = center + Vector2(radius, -radius) * INNER_RADIUS
		draw_circle(mark, radius * LOCK_RATIO * INNER_RADIUS, style.charm_preview_color, true, -1.0, true)
