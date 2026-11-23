class_name CharmTile
extends MenuTile
## Mượn khung chọn và hiệu ứng của MenuTile để con trỏ có cùng cách đọc với các trang khác.

signal navigation_requested(tile: CharmTile, direction: Vector2i)

enum Mode { COLLECTION, EQUIPPED, EMPTY_SLOT }

const RARITY_VFX: PackedScene = preload("res://ui/menus/inventory/effects/charm_rarity/charm_rarity_vfx.tscn")
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
var floating: bool = false

var _settle_tween: Tween
var _settle: float = 0.0
var _swing: float = 0.0
var _rarity_visual: CharmRarityVfx
var _diamond_points: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


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
	if _settle_tween:
		_settle_tween.kill()
	_settle = 0.0
	_swing = 0.0
	_sync_rarity()
	queue_redraw()


## Ô đang đeo / ô trống vẽ kiểu treo dây (style cũ) hay huy hiệu tròn như lưới
func uses_pendant() -> bool:
	return style != null and style.charm_pendant_equipped and mode != Mode.COLLECTION


func flash() -> void:
	if not uses_pendant():
		super.flash()
		return
	if style == null:
		return
	if _settle_tween:
		_settle_tween.kill()
	var duration: float = maxf(style.charm_pendant_settle_time, 0.0)
	if duration <= 0.0:
		_set_pendant_settle(0.0)
		return
	_settle_tween = create_tween()
	_settle_tween.tween_method(_set_pendant_settle, 1.0, 0.0, duration)


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
	if charm.rarity:
		entry.subtitle = tr(charm.rarity.display_name) + "  ·  " + entry.subtitle
	if equipped:
		entry.subtitle += "  ·  " + tr(style.charm_equipped_text)
	entry.art_texture = charm.icon
	entry.add_section(style.charm_effect_text, charm.description)
	entry.lore = tr(charm.lore)
	if GameState.can_change_charms():
		var action_text: String = style.charm_remove_text if equipped else style.charm_equip_text
		entry.hint = tr(action_text) % PageTabs.key_name(&"ui_accept")
	return entry


func _draw_content(rect: Rect2) -> void:
	if floating:
		_draw_emblem(charm.icon, rect.get_center(), minf(rect.size.x, rect.size.y) * style.charm_pendant_icon_ratio,
			Color.WHITE, tr(charm.display_name))
		return
	if uses_pendant():
		_draw_pendant(rect)
		return
	var center: Vector2 = rect.get_center()
	if mode == Mode.EMPTY_SLOT:
		# Ô trống: chỉ một vòng tròn mờ để thấy còn chỗ đeo, không tranh mắt với bùa thật
		var empty_radius: float = minf(rect.size.x, rect.size.y) * MEDALLION_RADIUS
		var empty_rim: Color = style.charm_preview_color if has_focus() else Color(style.charm_socket_edge, 0.8)
		draw_arc(center, empty_radius, 0.0, TAU, ARC_STEPS, empty_rim, style.charm_border_width, true)
		return
	var radius: float = minf(rect.size.x, rect.size.y) * MEDALLION_RADIUS
	var line: float = style.charm_border_width
	var rim: Color = style.charm_socket_edge
	if _has_rarity():
		rim = charm.rarity.tint
	if has_focus():
		rim = charm.rarity.highlight if _has_rarity() else style.charm_preview_color
	_update_rarity_geometry(center, radius)
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


func _draw_brackets(rect: Rect2, color: Color) -> void:
	if not uses_pendant():
		# Kiểu huy hiệu: ô đang chọn đã sáng vòng (rim) nên không cần góc ngoặc vuông, trừ khi style bật lại
		if style.charm_focus_brackets:
			super._draw_brackets(rect, color)
		return
	if floating:
		return
	var anchor: Vector2 = Vector2(rect.get_center().x, rect.size.y * style.charm_hanger_y_ratio)
	var center: Vector2 = anchor + Vector2(0.0, rect.size.y * style.charm_pendant_drop_ratio)
	var radius: float = minf(rect.size.x, rect.size.y) * 0.47
	if mode == Mode.EMPTY_SLOT:
		_draw_diamond(center, style.charm_cost_mark_size * 2.0, color, false)
		return
	draw_arc(center, radius, -0.65, 0.65, ARC_STEPS, color, style.charm_border_width, true)
	draw_arc(center, radius, PI - 0.65, PI + 0.65, ARC_STEPS, color, style.charm_border_width, true)


func _draw_pendant(rect: Rect2) -> void:
	var height: float = rect.size.y
	var anchor: Vector2 = Vector2(rect.get_center().x, height * style.charm_hanger_y_ratio)
	var drop: float = height * clampf(style.charm_pendant_drop_ratio, 0.0, 0.6)
	var center: Vector2 = anchor + Vector2(sin(_swing), cos(_swing)) * drop
	var radius: float = minf(rect.size.x, rect.size.y) * 0.40
	var line: float = maxf(style.charm_border_width, 0.1)
	var gold: Color = style.charm_preview_color
	if _has_rarity():
		gold = charm.rarity.tint
	var thread: Color = Color(style.ornament, 0.35)
	var half_gap: float = maxf(style.charm_equipped_gap, 0.0) * 0.5
	draw_line(Vector2(-half_gap, anchor.y), Vector2(rect.size.x + half_gap, anchor.y), thread, line, true)
	if mode == Mode.EMPTY_SLOT:
		_draw_diamond(anchor, maxf(style.charm_cost_mark_size, 1.0), Color(thread, 0.7), false)
		draw_line(anchor, anchor + Vector2(0.0, drop * 0.45), Color(thread, 0.5), line, true)
		_draw_diamond(anchor + Vector2(0.0, drop * 0.55), maxf(style.charm_cost_mark_size * 1.4, 1.0), thread, false)
		return
	_update_rarity_geometry(center, radius)
	_draw_diamond(anchor, maxf(style.charm_cost_mark_size * 1.5, 1.0), Color(gold, 0.85), false)
	var bail: Vector2 = center + Vector2(0.0, -radius * 0.83)
	draw_line(anchor + Vector2(0.0, 4.0), bail, Color(gold, 0.58), line, true)
	draw_arc(bail, maxf(style.charm_cost_mark_size, 1.0), 0.0, TAU, 12, Color(gold, 0.8), line, true)
	draw_circle(center, radius * 0.90, Color(gold, 0.025 + 0.075 * _settle), true, -1.0, true)
	draw_arc(center, radius, 0.4, PI - 0.4, ARC_STEPS, Color(gold, 0.28 + _settle * 0.5), line, true)
	draw_arc(center, radius, PI + 0.4, TAU - 0.4, ARC_STEPS, Color(gold, 0.28 + _settle * 0.5), line, true)
	_draw_emblem(charm.icon, center, minf(rect.size.x, rect.size.y) * style.charm_pendant_icon_ratio, Color.WHITE, tr(charm.display_name))
	var cost: int = clampi(charm.notch_cost, 0, 6)
	var mark: float = maxf(style.charm_cost_mark_size, 0.0)
	for index: int in range(cost):
		var point: Vector2 = Vector2(center.x + (float(index) - float(cost - 1) * 0.5) * mark * 3.5, height - mark * 2.0)
		_draw_diamond(point, mark, Color(gold, 0.85), true)


func _has_rarity() -> bool:
	return owned and charm != null and charm.rarity != null


func _sync_rarity() -> void:
	if not _has_rarity() or floating:
		if is_instance_valid(_rarity_visual):
			_rarity_visual.configure(null)
		return
	if not is_instance_valid(_rarity_visual):
		# Mỗi ô giữ lại một hiệu ứng để đeo/tháo hoặc tái dùng ô không tạo hạt/node liên tục.
		_rarity_visual = RARITY_VFX.instantiate() as CharmRarityVfx
		add_child(_rarity_visual)
	_rarity_visual.configure(charm.rarity)


func _update_rarity_geometry(center: Vector2, radius: float) -> void:
	if _has_rarity() and is_instance_valid(_rarity_visual) and not floating:
		_rarity_visual.set_geometry(center, radius, has_focus())


func _draw_diamond(center: Vector2, radius: float, color: Color, filled: bool) -> void:
	if radius <= 0.0:
		return
	_diamond_points[0] = center + Vector2(0.0, -radius)
	_diamond_points[1] = center + Vector2(radius, 0.0)
	_diamond_points[2] = center + Vector2(0.0, radius)
	_diamond_points[3] = center + Vector2(-radius, 0.0)
	if filled and radius > 0.0:
		draw_colored_polygon(_diamond_points, color)
	else:
		for index: int in range(4):
			draw_line(_diamond_points[index], _diamond_points[(index + 1) % 4], color, style.charm_border_width, true)


func _set_pendant_settle(value: float) -> void:
	_settle = value
	_swing = sin((1.0 - value) * TAU * 1.5) * value * deg_to_rad(style.charm_pendant_swing_degrees)
	queue_redraw()
