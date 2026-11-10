class_name TutorialsPage
extends MenuPage
## Trang Hướng dẫn: hiển thị danh sách thẻ dọc bên trái, nội dung chi tiết bên phải qua DetailPanel.
## Tự cập nhật khi có hướng dẫn mới được mở khóa từ GameState.

var _cards: Array[TutorialCard] = []

@onready var _scroll: ScrollContainer = $Layout/Scroll
@onready var _list: VBoxContainer = $Layout/Scroll/List
@onready var _empty: Label = $Layout/Empty
@onready var _heading: Label = $Layout/Heading


func setup_style(menu_style: InventoryStyle) -> void:
	super(menu_style)
	_heading.add_theme_font_size_override(&"font_size", style.heading_font)
	_heading.add_theme_color_override(&"font_color", style.dim)
	_empty.add_theme_font_size_override(&"font_size", style.body_font)
	_empty.add_theme_color_override(&"font_color", style.faint)


func get_custom_detail_width() -> float:
	return 720.0


func refresh() -> void:
	var unlocked: Array[TutorialData] = GameState.get_unlocked_tutorials()
	while _cards.size() < unlocked.size():
		var card := TutorialCard.new()
		card.custom_minimum_size = Vector2(360.0, 56.0)
		bind_tile(card)
		_list.add_child(card)
		_cards.append(card)
	while _cards.size() > unlocked.size():
		_cards.pop_back().queue_free()
	
	for index in unlocked.size():
		_cards[index].setup(unlocked[index])
	
	_empty.visible = unlocked.is_empty()
	_scroll.visible = not unlocked.is_empty()
	if is_instance_valid(_last_focus) and _last_focus.has_focus():
		detail_changed.emit(_last_focus.get_detail())
