class_name CharmsPage
extends MenuPage
## Trang Bùa (luôn hiện): hàng "đang đeo" + hạt ô khắc ở trên, lưới "bộ sưu tập" mọi bùa của game ở dưới
## (bùa chưa tìm thấy là bóng tối "?"). Enter để đeo / tháo, chỉ khi đứng ở khu đổi bùa (CharmStation).
## Đeo / tháo: bùa bay giữa lưới và hàng đang đeo, hạt ô khắc sáng / tắt lần lượt. Bị từ chối: ô rung + dòng trạng thái đỏ.
## Thêm bùa = thêm .tres vào ItemCatalog.charms, không sửa trang này.

var _grid_tiles: Array[CharmTile] = []
var _equipped_tiles: Array[CharmTile] = []
var _ghost: CharmTile
var _status_tween: Tween
var _last_used: int = 0

@onready var _equipped_heading: Label = $Layout/EquippedHeading
@onready var _equipped_row: HBoxContainer = $Layout/Equipped
@onready var _notches: NotchRow = $Layout/Notches
@onready var _notch_label: Label = $Layout/NotchLabel
@onready var _collection_heading: Label = $Layout/CollectionHeading
@onready var _grid: GridContainer = $Layout/Scroll/Margin/Grid
@onready var _scroll: ScrollContainer = $Layout/Scroll
@onready var _empty: Label = $Layout/Empty
@onready var _status: Label = $Layout/Status
@onready var _rule: OrnamentDivider = $Layout/Rule


func setup_style(menu_style: InventoryStyle) -> void:
	super(menu_style)
	_notches.color = style.ink
	_notches.empty_color = Color(style.dim, 0.6)
	for heading: Label in [_equipped_heading, _collection_heading, _notch_label]:
		heading.add_theme_font_size_override(&"font_size", style.heading_font)
		heading.add_theme_color_override(&"font_color", style.dim)
	_empty.add_theme_font_size_override(&"font_size", style.body_font)
	_empty.add_theme_color_override(&"font_color", style.faint)
	_status.add_theme_font_size_override(&"font_size", style.body_font)
	_rule.color = style.ornament
	_grid.columns = maxi(style.charm_columns, 1)
	# Bóng bùa bay giữa lưới và hàng đang đeo: dựng một lần, dùng lại
	_ghost = CharmTile.new()
	_ghost.focus_mode = Control.FOCUS_NONE
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.top_level = true
	_ghost.visible = false
	_ghost.setup_style(style)
	add_child(_ghost)


## Trang Bùa luôn hiện (kể cả chưa có bùa nào) để người chơi biết có hệ thống này
func is_available() -> bool:
	return true


func refresh() -> void:
	var catalog: Array[CharmData] = []
	for charm: CharmData in GameState.ITEMS.charms:
		if charm:
			catalog.append(charm)
	var equipped: Array[CharmData] = []
	for id: StringName in GameState.progress.equipped_charms:
		var charm := GameState.ITEMS.get_charm(id)
		if charm:
			equipped.append(charm)
	var used := GameState.get_used_notches()
	var total := GameState.get_charm_notches()
	_refresh_equipped(equipped, used < total)
	_refresh_grid(catalog)
	_notches.show_notches(_last_used if _notches.total == total else used, total)
	_notches.animate_to(used, style.notch_step_time)
	_last_used = used
	_notch_label.text = tr("Ô KHẮC  %d / %d") % [used, total]
	var owned_count := 0
	for charm: CharmData in catalog:
		if GameState.owns_charm(charm.id):
			owned_count += 1
	_collection_heading.text = tr("BỘ SƯU TẬP  %d / %d") % [owned_count, catalog.size()]
	_empty.visible = catalog.is_empty()
	_scroll.visible = not catalog.is_empty()
	_show_status(false)
	if is_instance_valid(_last_focus) and _last_focus.has_focus():
		detail_changed.emit(_last_focus.get_detail())


func _refresh_equipped(equipped: Array[CharmData], has_room: bool) -> void:
	var count := equipped.size() + (1 if has_room or equipped.is_empty() else 0)
	_resize(_equipped_tiles, count, _equipped_row, style.equipped_tile_size)
	for index in count:
		if index < equipped.size():
			_equipped_tiles[index].setup(equipped[index], CharmTile.Mode.EQUIPPED, true, true)
		else:
			_equipped_tiles[index].setup(null, CharmTile.Mode.EMPTY_SLOT, false, false)


func _refresh_grid(catalog: Array[CharmData]) -> void:
	_resize(_grid_tiles, catalog.size(), _grid, style.charm_tile_size)
	for index in catalog.size():
		var charm := catalog[index]
		_grid_tiles[index].setup(charm, CharmTile.Mode.COLLECTION, GameState.owns_charm(charm.id), GameState.is_charm_equipped(charm.id))


func _resize(tiles: Array[CharmTile], count: int, parent: Container, tile_size: Vector2) -> void:
	while tiles.size() < count:
		var tile := CharmTile.new()
		tile.custom_minimum_size = tile_size
		bind_tile(tile)
		tile.activated.connect(_on_tile_activated)
		parent.add_child(tile)
		tiles.append(tile)
	while tiles.size() > count:
		var removed: CharmTile = tiles.pop_back()
		if _last_focus == removed:
			_last_focus = null
		removed.queue_free()


func _on_tile_activated(tile: MenuTile) -> void:
	var charm_tile := tile as CharmTile
	if charm_tile.mode == CharmTile.Mode.EMPTY_SLOT or not charm_tile.owned:
		return
	var charm := charm_tile.charm
	var unequipping := charm_tile.equipped
	var from := charm_tile.get_global_rect()
	if not GameState.can_change_charms():
		_deny(charm_tile, "Chỉ đổi bùa được khi đứng ở khu đổi bùa.")
		return
	var ok := GameState.unequip_charm(charm.id) if unequipping else GameState.equip_charm(charm.id)
	if not ok:
		var room := GameState.get_charm_notches() - GameState.get_used_notches()
		_deny(charm_tile, "Không đủ ô khắc (còn %d, cần %d)." % [room, charm.notch_cost])
		return
	sound_requested.emit(&"confirm")
	# GameState đã báo đổi bùa -> màn Tab gọi refresh() ngay trong lệnh trên; đợi xếp lại bố cục rồi mới biết chỗ đáp
	await get_tree().process_frame
	var target := _find_tile(_grid_tiles if unequipping else _equipped_tiles, charm.id)
	if target:
		_fly(charm, from, target)
	if unequipping:
		# Tháo từ hàng đang đeo: con trỏ về ô của bùa đó trong lưới
		var grid_tile := _find_tile(_grid_tiles, charm.id)
		if grid_tile and not grid_tile.has_focus():
			grid_tile.grab_focus()


func _find_tile(tiles: Array[CharmTile], id: StringName) -> CharmTile:
	for tile: CharmTile in tiles:
		if tile.charm and tile.charm.id == id:
			return tile
	return null


## Bóng bùa bay từ ô cũ tới ô mới; ô đích ẩn tới khi bóng đáp rồi lóe sáng
func _fly(charm: CharmData, from: Rect2, target: CharmTile) -> void:
	var to := target.get_global_rect()
	_ghost.setup(charm, CharmTile.Mode.EQUIPPED, true, true)
	_ghost.global_position = from.position
	_ghost.size = from.size
	_ghost.visible = true
	target.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_ghost, "global_position", to.position, style.charm_fly_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_ghost, "size", to.size, style.charm_fly_time)
	tween.chain().tween_callback(_land.bind(target))


func _land(target: CharmTile) -> void:
	_ghost.visible = false
	if is_instance_valid(target):
		target.modulate.a = 1.0
		target.flash()


func _deny(tile: CharmTile, reason: String) -> void:
	tile.shake()
	sound_requested.emit(&"error")
	_status.text = reason
	_show_status(true)


## Dòng trạng thái: bình thường nói đang ở khu đổi bùa hay không; bị từ chối thì đỏ một lúc rồi về như cũ
func _show_status(denied: bool) -> void:
	if _status_tween and _status_tween.is_valid():
		_status_tween.kill()
	if denied:
		_status.add_theme_color_override(&"font_color", style.warning)
		_status_tween = create_tween()
		_status_tween.tween_interval(style.level_flash_time * 2.0)
		_status_tween.tween_callback(_show_status.bind(false))
		return
	var allowed := GameState.can_change_charms()
	_status.text = "Đang ở khu đổi bùa: Enter để đeo / tháo." if allowed else "Chỉ đổi bùa được khi đứng ở khu đổi bùa."
	_status.add_theme_color_override(&"font_color", style.ink if allowed else style.dim)
