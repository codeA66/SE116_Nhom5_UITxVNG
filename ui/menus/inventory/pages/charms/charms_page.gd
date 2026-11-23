class_name CharmsPage
extends MenuPage
## Cập nhật ô theo tiến trình để đổi con trỏ, ngôn ngữ hay khu vực không dựng lại lưới.

var _grid_tiles: Array[CharmTile] = []
var _equipped_tiles: Array[CharmTile] = []
var _spare_tiles: Array[CharmTile] = []
var _ghost: CharmTile
var _flight_target: CharmTile
var _flight_tween: Tween
var _flight_id: int = 0
var _status_tween: Tween
var _tiles_dirty: bool = true
var _status_dirty: bool = true
var _instant_notches: bool = true
var _owned_count: int = 0
var _catalog_count: int = 0
var _room: int = 0
var _denial: String = ""

@onready var _layout: VBoxContainer = $Layout
@onready var _loadout: VBoxContainer = $Layout/Loadout
@onready var _equipped_heading: Label = $Layout/Loadout/Heading
@onready var _equipped_scroll: ScrollContainer = $Layout/Loadout/Scroll
@onready var _equipped_margin: MarginContainer = $Layout/Loadout/Scroll/Margin
@onready var _equipped_row: HBoxContainer = $Layout/Loadout/Scroll/Margin/Equipped
@onready var _capacity: HBoxContainer = $Layout/Loadout/Capacity
@onready var _notches: NotchRow = $Layout/Loadout/Capacity/Notches
@onready var _notch_label: Label = $Layout/Loadout/Capacity/NotchLabel
@onready var _collection_heading: Label = $Layout/CollectionHeading
@onready var _grid: GridContainer = $Layout/Collection/Scroll/Margin/Grid
@onready var _scroll: ScrollContainer = $Layout/Collection/Scroll
@onready var _grid_margin: MarginContainer = $Layout/Collection/Scroll/Margin
@onready var _empty: Label = $Layout/Collection/Empty
@onready var _status: Label = $Layout/Loadout/Status
@onready var _rule: HSeparator = $Layout/Rule


func _ready() -> void:
	GameState.charms_changed.connect(_mark_tiles_dirty)
	GameState.progress_replaced.connect(_mark_progress_replaced)
	GameState.charm_station_changed.connect(_mark_station_changed)
	_scroll.resized.connect(_update_columns)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_status_dirty = true
		_denial = ""


func setup_style(menu_style: InventoryStyle) -> void:
	super(menu_style)
	_notches.configure(style)
	for heading: Label in [_equipped_heading, _collection_heading, _notch_label]:
		heading.add_theme_font_size_override(&"font_size", style.heading_font)
		heading.add_theme_color_override(&"font_color", style.dim)
	_equipped_heading.add_theme_color_override(&"font_color", style.ornament)
	for label: Label in [_empty, _status]:
		label.add_theme_font_size_override(&"font_size", style.body_font)
		label.add_theme_color_override(&"font_color", style.dim)
	_status.custom_minimum_size.y = _status.get_theme_default_font().get_height(style.body_font)
	for container: Container in [_layout, _loadout, _capacity, _equipped_row]:
		container.add_theme_constant_override(&"separation", style.charm_section_gap)
	_equipped_row.add_theme_constant_override(&"separation", maxi(roundi(style.charm_equipped_gap), 0))
	for margin: MarginContainer in [_equipped_margin, _grid_margin]:
		for side: StringName in [&"margin_top", &"margin_bottom", &"margin_left", &"margin_right"]:
			margin.add_theme_constant_override(side, style.charm_grid_inset)
	_grid.add_theme_constant_override(&"h_separation", style.charm_tile_gap)
	_grid.add_theme_constant_override(&"v_separation", style.charm_tile_gap)
	_grid.columns = maxi(style.charm_columns, 1)
	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = Color(style.ornament, 0.28)
	_rule.add_theme_stylebox_override(&"separator", line)
	_ghost = CharmTile.new()
	_ghost.setup_style(style)
	_ghost.floating = true
	_ghost.top_level = true
	_ghost.z_index = 4
	_ghost.hide()
	add_child(_ghost)
	_ghost.focus_mode = Control.FOCUS_NONE
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE


func get_body_panel_style() -> StyleBox:
	return style.charm_panel if style.charm_body_box else null


func get_body_column_gap() -> int:
	return style.charm_column_gap


func get_custom_detail_width() -> float:
	return style.charm_detail_width


func configure_detail(panel: DetailPanel) -> void:
	panel.set_art_layout(style.charm_art_size, style.charm_title_lines)


func refresh() -> void:
	if _tiles_dirty:
		_tiles_dirty = false
		_sync_tiles()
		_status_dirty = true
	if not _status_dirty:
		return
	_status_dirty = false
	_notch_label.text = tr(style.charm_capacity_text) % [GameState.get_used_notches(), _notches.total]
	_collection_heading.text = tr(style.charm_collection_text) % [_owned_count, _catalog_count]
	if is_instance_valid(_last_focus) and _last_focus.has_focus():
		_on_tile_focused(_last_focus)
	else:
		_update_preview(null)
		if is_visible_in_tree():
			focus_default()


func focus_default() -> void:
	if is_instance_valid(_last_focus) and _last_focus.is_visible_in_tree():
		_last_focus.grab_focus()
		return
	for tile: CharmTile in _grid_tiles:
		if tile.owned:
			tile.grab_focus()
			return
	if not _grid_tiles.is_empty():
		_grid_tiles[0].grab_focus()
	elif not _equipped_tiles.is_empty():
		_equipped_tiles[0].grab_focus()
	else:
		detail_changed.emit(null)


func handle_cancel() -> bool:
	_cancel_flight()
	_clear_denial()
	return false


func _mark_tiles_dirty() -> void:
	_tiles_dirty = true


func _mark_progress_replaced() -> void:
	_instant_notches = true
	_mark_tiles_dirty()
	_cancel_flight()
	_clear_denial()


func _mark_station_changed(_inside: bool) -> void:
	_status_dirty = true
	_clear_denial()


func _sync_tiles() -> void:
	var catalog: Array[CharmData] = []
	var catalog_order: Dictionary[StringName, int] = {}
	var owned_ids: Dictionary[StringName, bool] = {}
	for charm: CharmData in GameState.ITEMS.charms:
		if charm == null:
			continue
		var owned: bool = GameState.owns_charm(charm.id)
		# Bùa chưa có vẫn hiện thành ô kín (kiểu Hollow Knight) để người chơi biết còn bùa để đi tìm; tắt bằng style
		if owned or style.charm_show_undiscovered:
			owned_ids[charm.id] = owned
			catalog_order[charm.id] = catalog.size()
			catalog.append(charm)
	# Bùa đã có đứng trước, rồi theo độ hiếm; bùa chưa có không lộ độ hiếm. Giữ thứ tự danh mục khi bằng nhau
	# vì sort_custom không bảo toàn thứ tự đó.
	catalog.sort_custom(func(left: CharmData, right: CharmData) -> bool:
		if owned_ids[left.id] != owned_ids[right.id]:
			return owned_ids[left.id]
		var left_priority: int = left.rarity.sort_priority if left.rarity and owned_ids[left.id] else 0
		var right_priority: int = right.rarity.sort_priority if right.rarity and owned_ids[right.id] else 0
		if left_priority != right_priority:
			return left_priority > right_priority
		return catalog_order[left.id] < catalog_order[right.id]
	)
	var used: int = GameState.get_used_notches()
	var total: int = GameState.get_charm_notches()
	_room = maxi(total - used, 0)
	_refresh_equipped()
	_resize(_grid_tiles, catalog.size(), _grid, style.charm_tile_size)
	_owned_count = 0
	_catalog_count = catalog.size()
	for index: int in range(catalog.size()):
		var charm: CharmData = catalog[index]
		var owned: bool = owned_ids[charm.id]
		_owned_count += int(owned)
		_grid_tiles[index].setup(charm, CharmTile.Mode.COLLECTION, owned, owned and GameState.is_charm_equipped(charm.id))
	_empty.visible = _owned_count == 0
	_scroll.visible = not catalog.is_empty()
	_notches.set_capacity(used, total, not _instant_notches and is_visible_in_tree())
	_instant_notches = false


func _refresh_equipped() -> void:
	var equipped: Array[CharmData] = []
	for id: StringName in GameState.progress.equipped_charms:
		var charm: CharmData = GameState.ITEMS.get_charm(id)
		if charm:
			equipped.append(charm)
	var count: int = equipped.size() + int(_room > 0 or equipped.is_empty())
	_resize(_equipped_tiles, count, _equipped_row, style.equipped_tile_size)
	for index: int in range(count):
		# Ô trống hẹp được tái dùng thành bùa thật; phải trả lại kích thước trước khi vẽ.
		_equipped_tiles[index].custom_minimum_size = style.equipped_tile_size
		if index < equipped.size():
			_equipped_tiles[index].setup(equipped[index], CharmTile.Mode.EQUIPPED, true, true)
		else:
			_equipped_tiles[index].setup(null, CharmTile.Mode.EMPTY_SLOT, false, false)
			_equipped_tiles[index].custom_minimum_size.x = maxf(style.charm_empty_width, 1.0)


## Giữ ô đã tạo để đeo và tháo nhiều lần không phân bổ lại node.
func _resize(tiles: Array[CharmTile], count: int, parent: Container, tile_size: Vector2) -> void:
	while tiles.size() > count:
		var tile: CharmTile = tiles.pop_back()
		if _last_focus == tile:
			_last_focus = null
		tile.hide()
		_spare_tiles.append(tile)
	while tiles.size() < count:
		var tile: CharmTile
		if _spare_tiles.is_empty():
			tile = CharmTile.new()
			bind_tile(tile)
			tile.activated.connect(_on_tile_activated)
			tile.navigation_requested.connect(_navigate)
			parent.add_child(tile)
		else:
			tile = _spare_tiles.pop_back()
			if tile.get_parent() != parent:
				tile.reparent(parent, false)
			parent.move_child(tile, -1)
		tile.custom_minimum_size = tile_size
		tile.modulate.a = 1.0
		tile.show()
		tiles.append(tile)


func _update_columns() -> void:
	if not style or _scroll.size.x <= 0.0:
		return
	var gap: float = float(style.charm_tile_gap)
	var inner_width: float = _scroll.size.x - 2.0 * style.charm_grid_inset - _scroll.get_v_scroll_bar().get_combined_minimum_size().x
	_grid.columns = clampi(floori((inner_width + gap) / maxf(style.charm_tile_size.x + gap, 1.0)),
		1, maxi(style.charm_columns, 1))


func _navigate(tile: CharmTile, direction: Vector2i) -> void:
	var in_grid: bool = tile.mode == CharmTile.Mode.COLLECTION
	var tiles: Array[CharmTile] = _grid_tiles if in_grid else _equipped_tiles
	var index: int = tiles.find(tile)
	if index < 0:
		return
	var column: int = index % _grid.columns if in_grid else index
	if direction.y == 0:
		var next: int = index + direction.x
		var next_column: int = column + direction.x
		if next >= 0 and next < tiles.size() and (not in_grid or (next_column >= 0 and next_column < _grid.columns)):
			tiles[next].grab_focus()
	elif in_grid:
		if direction.y < 0 and index < _grid.columns:
			_focus_column(_equipped_tiles, _equipped_tiles.size(), tile)
		else:
			var row_start: int = index - column + direction.y * _grid.columns
			if row_start >= 0 and row_start < tiles.size():
				tiles[mini(row_start + column, tiles.size() - 1)].grab_focus()
	elif direction.y > 0:
		_focus_column(_grid_tiles, mini(_grid.columns, _grid_tiles.size()), tile)


func _focus_column(tiles: Array[CharmTile], count: int, from: CharmTile) -> void:
	var target: CharmTile
	var best: float = INF
	var center: float = from.get_global_rect().get_center().x
	for index: int in range(count):
		var distance: float = absf(tiles[index].get_global_rect().get_center().x - center)
		if distance < best:
			target = tiles[index]
			best = distance
	if target:
		target.grab_focus()


func _on_tile_focused(tile: MenuTile) -> void:
	if _last_focus != tile:
		_clear_denial()
	_update_preview(tile as CharmTile)
	super(tile)


func _update_preview(tile: CharmTile) -> void:
	var cost: int = 0
	if tile and tile.owned and not tile.equipped and tile.charm:
		cost = tile.charm.notch_cost
	_notches.set_preview(cost)
	_show_status(cost)


func _show_status(cost: int) -> void:
	var content: String = _denial
	var tint: Color = style.warning
	if content.is_empty():
		if not GameState.can_change_charms():
			content = tr(style.charm_station_text)
			tint = style.dim
		elif cost > _room:
			content = tr(style.charm_refusal_text) % [_room, cost]
			tint = style.charm_preview_color
	_status.text = content
	_status.add_theme_color_override(&"font_color", tint)


func _on_tile_activated(tile: MenuTile) -> void:
	var selected: CharmTile = tile as CharmTile
	if not selected or not selected.owned or selected.charm == null:
		return
	var charm: CharmData = selected.charm
	if not GameState.can_change_charms():
		_deny(selected, tr(style.charm_station_text))
		return
	_cancel_flight()
	_clear_denial()
	var from: Rect2 = selected.get_global_rect()
	var unequipping: bool = selected.equipped
	var accepted: bool = GameState.unequip_charm(charm.id) if unequipping else GameState.equip_charm(charm.id)
	if not accepted:
		_deny(selected, tr(style.charm_refusal_text) % [_room, charm.notch_cost])
		return
	sound_requested.emit(&"confirm")
	var ticket: int = _flight_id
	# Chờ Container sắp ô đích để bóng bùa đáp đúng vị trí.
	await get_tree().process_frame
	if not is_visible_in_tree() or ticket != _flight_id:
		return
	var target: CharmTile = _find_tile(_grid_tiles if unequipping else _equipped_tiles, charm.id)
	if target == null:
		return
	if unequipping:
		target.grab_focus()
		_scroll.ensure_control_visible(target)
	else:
		_equipped_scroll.ensure_control_visible(target)
	_fly(charm, from, target)


func _find_tile(tiles: Array[CharmTile], id: StringName) -> CharmTile:
	for tile: CharmTile in tiles:
		if tile.charm and tile.charm.id == id:
			return tile
	return null


func _fly(charm: CharmData, from: Rect2, target: CharmTile) -> void:
	var to: Rect2 = target.get_global_rect()
	_ghost.setup(charm, CharmTile.Mode.EQUIPPED, true, true)
	_ghost.global_position = from.position
	_ghost.size = from.size
	_ghost.show()
	_flight_target = target
	target.modulate.a = 0.0
	_flight_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_flight_tween.tween_property(_ghost, "global_position", to.position, style.charm_fly_time)
	_flight_tween.tween_property(_ghost, "size", to.size, style.charm_fly_time)
	_flight_tween.chain().tween_callback(_land)


func _land() -> void:
	_ghost.hide()
	if is_instance_valid(_flight_target):
		_flight_target.modulate.a = 1.0
		_flight_target.flash()
	_flight_target = null


func _cancel_flight() -> void:
	_flight_id += 1
	if _flight_tween:
		_flight_tween.kill()
	if is_instance_valid(_flight_target):
		_flight_target.modulate.a = 1.0
	_flight_target = null
	if _ghost:
		_ghost.hide()


func _deny(tile: CharmTile, reason: String) -> void:
	_clear_denial()
	_denial = reason
	tile.shake()
	_notches.pulse_refusal()
	sound_requested.emit(&"error")
	_update_preview(tile)
	_status_tween = create_tween()
	_status_tween.tween_interval(style.charm_refusal_hold)
	_status_tween.tween_callback(_restore_status)


func _restore_status() -> void:
	_status_tween = null
	_denial = ""
	_update_preview(_last_focus as CharmTile)


func _clear_denial() -> void:
	if _status_tween:
		_status_tween.kill()
		_status_tween = null
	_denial = ""
