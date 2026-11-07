class_name ItemsPage
extends MenuPage
## Trang Vật phẩm: lưới mọi vật phẩm đang có trong danh mục GameState.ITEMS (vật liệu nâng cấp, chìa khóa, đồ sưu tầm).
## Chỉ hiện thứ đã có, không lộ trước vật phẩm chưa tìm thấy. Thêm vật phẩm = thêm .tres vào danh mục.

var _tiles: Array[ItemTile] = []

@onready var _grid: GridContainer = $Layout/Grid
@onready var _empty: Label = $Layout/Empty
@onready var _heading: Label = $Layout/Heading


func setup_style(menu_style: InventoryStyle) -> void:
	super(menu_style)
	_heading.add_theme_font_size_override(&"font_size", style.heading_font)
	_heading.add_theme_color_override(&"font_color", style.dim)
	_empty.add_theme_font_size_override(&"font_size", style.body_font)
	_empty.add_theme_color_override(&"font_color", style.faint)


func refresh() -> void:
	var owned: Array[ItemData] = []
	for item: ItemData in GameState.ITEMS.items:
		if item and GameState.get_item_count(item) > 0:
			owned.append(item)
	while _tiles.size() < owned.size():
		var tile := ItemTile.new()
		tile.custom_minimum_size = style.item_tile_size
		bind_tile(tile)
		_grid.add_child(tile)
		_tiles.append(tile)
	while _tiles.size() > owned.size():
		_tiles.pop_back().queue_free()
	for index in owned.size():
		_tiles[index].setup(owned[index], GameState.get_item_count(owned[index]))
	_empty.visible = owned.is_empty()
	if is_instance_valid(_last_focus) and _last_focus.has_focus():
		detail_changed.emit(_last_focus.get_detail())
