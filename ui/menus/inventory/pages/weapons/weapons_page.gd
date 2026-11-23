class_name WeaponsPage
extends MenuPage
## Trang Vũ khí: mỗi nhóm (WeaponData.Slot: cận chiến, đánh xa...) một hàng tiêu đề + lưới mọi vũ khí đã nhặt của nhóm,
## đánh dấu cái đang trang bị. Enter trên vũ khí khác = trang bị vào nhóm đó (đổi ở đâu cũng được).
## Nhóm dựng từ WeaponData.Slot: thêm nhóm mới = thêm giá trị enum + tên nhóm ở group_titles, không sửa code trang.

## Tên nhóm theo thứ tự giá trị WeaponData.Slot
@export var group_titles: PackedStringArray = PackedStringArray(["Cận chiến", "Đánh xa"])
@export var empty_group_text: String = "Chưa có vũ khí nào."

## Mỗi nhóm: {heading: Label, grid: GridContainer, empty: Label, tiles: Array[WeaponTile]} theo slot
var _groups: Dictionary[int, Dictionary] = {}

@onready var _scroll: ScrollContainer = $Scroll
@onready var _list: VBoxContainer = $Scroll/Groups


func setup_style(menu_style: InventoryStyle) -> void:
	super(menu_style)
	_list.add_theme_constant_override(&"separation", style.weapon_group_gap)
	for value: int in WeaponData.Slot.values():
		_build_group(value)
	# Số cột theo bề rộng trang: chỉ tính lại khi trang đổi cỡ, không chạy mỗi frame
	_scroll.resized.connect(_update_columns)


func get_group_tiles(slot: WeaponData.Slot) -> Array[WeaponTile]:
	var tiles: Array[WeaponTile] = []
	if _groups.has(slot):
		tiles.assign(_groups[slot]["tiles"])
	return tiles


func get_group_heading(slot: WeaponData.Slot) -> Label:
	return _groups[slot]["heading"] if _groups.has(slot) else null


func get_group_empty(slot: WeaponData.Slot) -> Label:
	return _groups[slot]["empty"] if _groups.has(slot) else null


func refresh() -> void:
	for slot: int in _groups:
		var group: Dictionary = _groups[slot]
		var owned := GameState.get_owned_weapons(slot as WeaponData.Slot)
		var equipped := GameState.get_weapon_in_slot(slot as WeaponData.Slot)
		var tiles: Array = group["tiles"]
		var grid: GridContainer = group["grid"]
		while tiles.size() < owned.size():
			var tile := WeaponTile.new()
			tile.custom_minimum_size = style.weapon_tile_size
			bind_tile(tile)
			tile.activated.connect(_on_tile_activated)
			grid.add_child(tile)
			tiles.append(tile)
		while tiles.size() > owned.size():
			var tile: WeaponTile = tiles.pop_back()
			grid.remove_child(tile)
			tile.queue_free()
		for index in owned.size():
			(tiles[index] as WeaponTile).setup(owned[index], owned[index] == equipped, _group_title(slot))
		(group["empty"] as Label).visible = owned.is_empty()
	_update_columns()
	if is_instance_valid(_last_focus) and _last_focus.has_focus():
		detail_changed.emit(_last_focus.get_detail())


func _on_tile_activated(tile: MenuTile) -> void:
	var weapon_tile := tile as WeaponTile
	if weapon_tile.equipped:
		return
	if GameState.equip_owned_weapon(weapon_tile.weapon):
		sound_requested.emit(&"confirm")
	else:
		weapon_tile.shake()
		sound_requested.emit(&"error")
	# Trang bị xong GameState phát progress_changed: màn Tab tự refresh, dấu trang bị đổi theo


func _build_group(slot: int) -> void:
	var heading := Label.new()
	heading.text = tr(_group_title(slot)).to_upper()
	heading.add_theme_font_size_override(&"font_size", style.heading_font)
	heading.add_theme_color_override(&"font_color", style.dim)
	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override(&"h_separation", style.weapon_tile_gap)
	grid.add_theme_constant_override(&"v_separation", style.weapon_tile_gap)
	var empty := Label.new()
	empty.text = tr(empty_group_text)
	empty.add_theme_font_size_override(&"font_size", style.body_font)
	empty.add_theme_color_override(&"font_color", style.faint)
	empty.visible = false
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 12)
	box.add_child(heading)
	box.add_child(grid)
	box.add_child(empty)
	_list.add_child(box)
	_groups[slot] = {"heading": heading, "grid": grid, "empty": empty, "tiles": []}


func _group_title(slot: int) -> String:
	return group_titles[slot] if slot < group_titles.size() else str(slot)


func _update_columns() -> void:
	var cell := style.weapon_tile_size.x + float(style.weapon_tile_gap)
	var columns := maxi(1, int((_scroll.size.x + float(style.weapon_tile_gap)) / cell))
	for slot: int in _groups:
		(_groups[slot]["grid"] as GridContainer).columns = columns
