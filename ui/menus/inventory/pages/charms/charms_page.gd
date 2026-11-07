class_name CharmsPage
extends MenuPage
## Trang Bùa: hàng ô khắc (đã dùng / tổng), bùa đang đeo, lưới bùa đã có. Enter để đeo / tháo,
## nhưng chỉ khi đứng ở khu đổi bùa (CharmStation). Trang ẩn tới khi có bùa đầu tiên.

var _tiles: Array[CharmTile] = []

@onready var _notches: NotchRow = $Layout/Notches
@onready var _notch_label: Label = $Layout/NotchLabel
@onready var _grid: GridContainer = $Layout/Grid
@onready var _status: Label = $Layout/Status


func setup_style(menu_style: InventoryStyle) -> void:
	super(menu_style)
	_notches.color = style.ink
	_notches.empty_color = Color(style.dim, 0.6)
	_notch_label.add_theme_font_size_override(&"font_size", style.heading_font)
	_notch_label.add_theme_color_override(&"font_color", style.dim)
	_status.add_theme_font_size_override(&"font_size", style.body_font)


func is_available() -> bool:
	return not GameState.progress.charms.is_empty()


func refresh() -> void:
	var owned: Array[CharmData] = []
	for id: StringName in GameState.progress.charms:
		var charm := GameState.ITEMS.get_charm(id)
		if charm:
			owned.append(charm)
	while _tiles.size() < owned.size():
		var tile := CharmTile.new()
		tile.custom_minimum_size = style.charm_tile_size
		bind_tile(tile)
		tile.activated.connect(_on_charm_activated)
		_grid.add_child(tile)
		_tiles.append(tile)
	while _tiles.size() > owned.size():
		_tiles.pop_back().queue_free()
	for index in owned.size():
		_tiles[index].setup(owned[index], GameState.is_charm_equipped(owned[index].id))
	var used := GameState.get_used_notches()
	var total := GameState.get_charm_notches()
	_notches.show_notches(used, total)
	_notch_label.text = "Ô KHẮC  %d / %d" % [used, total]
	var allowed := GameState.can_change_charms()
	_status.text = "Đang ở khu đổi bùa: Enter để đeo / tháo." if allowed else "Chỉ đổi bùa được khi đứng ở khu đổi bùa."
	_status.add_theme_color_override(&"font_color", style.ink if allowed else style.dim)
	if is_instance_valid(_last_focus) and _last_focus.has_focus():
		detail_changed.emit(_last_focus.get_detail())


func _on_charm_activated(tile: MenuTile) -> void:
	var charm_tile := tile as CharmTile
	var id := charm_tile.charm.id
	var ok := GameState.unequip_charm(id) if charm_tile.equipped else GameState.equip_charm(id)
	sound_requested.emit(&"confirm" if ok else &"error")
