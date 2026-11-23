class_name TutorialsPage
extends MenuPage
## Trang Hướng dẫn: danh sách dọc gom theo phân loại (mỗi loại một tiêu đề), nội dung chi tiết bên phải qua DetailPanel.
## Thứ tự loại và mục theo danh mục GameState.TUTORIALS (không theo thứ tự mở). Tự cập nhật khi mở khóa hướng dẫn mới.

var _cards: Array[TutorialCard] = []
## Tiêu đề phân loại dựng sẵn, dùng lại khi refresh
var _headings: Array[Label] = []

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


func get_category_headings() -> Array[Label]:
	var visible_headings: Array[Label] = []
	for heading in _headings:
		if heading.visible:
			visible_headings.append(heading)
	return visible_headings


func refresh() -> void:
	var unlocked := _sorted(GameState.get_unlocked_tutorials())
	while _cards.size() < unlocked.size():
		var card := TutorialCard.new()
		card.custom_minimum_size = Vector2(360.0, style.tutorial_row_height)
		bind_tile(card)
		_list.add_child(card)
		_cards.append(card)
	while _cards.size() > unlocked.size():
		var card: TutorialCard = _cards.pop_back()
		_list.remove_child(card)
		card.queue_free()
	# Xếp lại con của danh sách: tiêu đề loại rồi các thẻ của loại đó
	var order := 0
	var heading_count := 0
	var category := ""
	for index in unlocked.size():
		var tutorial := unlocked[index]
		if index == 0 or tutorial.category != category:
			category = tutorial.category
			var heading := _heading_at(heading_count)
			heading.text = tr(category).to_upper()
			heading.visible = true
			_list.move_child(heading, order)
			order += 1
			heading_count += 1
		_cards[index].setup(tutorial)
		_list.move_child(_cards[index], order)
		order += 1
	for index in range(heading_count, _headings.size()):
		_headings[index].visible = false
	_empty.visible = unlocked.is_empty()
	_scroll.visible = not unlocked.is_empty()
	if is_instance_valid(_last_focus) and _last_focus.has_focus():
		detail_changed.emit(_last_focus.get_detail())


## Gom theo loại: loại xếp theo lần đầu xuất hiện trong danh mục, trong loại xếp theo thứ tự danh mục
func _sorted(unlocked: Array[TutorialData]) -> Array[TutorialData]:
	var catalog := GameState.TUTORIALS.tutorials
	var category_rank: Dictionary[String, int] = {}
	for tutorial in catalog:
		if tutorial and not category_rank.has(tutorial.category):
			category_rank[tutorial.category] = category_rank.size()
	var result := unlocked.duplicate()
	result.sort_custom(func(a: TutorialData, b: TutorialData) -> bool:
		var rank_a: int = category_rank.get(a.category, category_rank.size())
		var rank_b: int = category_rank.get(b.category, category_rank.size())
		if rank_a != rank_b:
			return rank_a < rank_b
		return catalog.find(a) < catalog.find(b))
	return result


func _heading_at(index: int) -> Label:
	while _headings.size() <= index:
		var heading := Label.new()
		heading.add_theme_font_size_override(&"font_size", style.key_font)
		heading.add_theme_color_override(&"font_color", style.faint)
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_list.add_child(heading)
		_headings.append(heading)
	return _headings[index]
