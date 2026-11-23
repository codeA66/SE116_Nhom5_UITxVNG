class_name ElementsPage
extends MenuPage
## Trang Nguyên tố: chỉ hiện nguyên tố đã mở khóa (theo bảng GameState.FUSIONS, thêm nguyên tố = thêm .tres) và cấp
## hiện tại của kỹ năng. Chỉ để xem: kỹ năng tự lên cấp khi nhặt Ấn, không nâng cấp hay ghép vũ khí ở đây.
## Không lộ tên / mô tả cấp sau (người chơi tự khám phá khi lên cấp).

var _cards: Array[ElementCard] = []
## Cấp kỹ năng lần cuối người chơi thấy trên màn Tab: lên cấp từ lần trước thì thẻ lóe sáng một lần
var _seen_levels: Dictionary[StringName, int] = {}

@onready var _card_grid: GridContainer = $Layout/Grid
@onready var _empty: Label = $Layout/Empty


func setup_style(menu_style: InventoryStyle) -> void:
	super(menu_style)
	_empty.add_theme_font_size_override(&"font_size", style.body_font)
	_empty.add_theme_color_override(&"font_color", style.faint)


func refresh() -> void:
	var owned := GameState.get_owned_elements()
	while _cards.size() < owned.size():
		var card := ElementCard.new()
		card.custom_minimum_size = style.element_card_size
		bind_tile(card)
		_card_grid.add_child(card)
		_cards.append(card)
	while _cards.size() > owned.size():
		var card: ElementCard = _cards.pop_back()
		_card_grid.remove_child(card)
		card.queue_free()
	for index in owned.size():
		_cards[index].setup(owned[index])
		_flash_if_leveled(_cards[index])
	_empty.visible = owned.is_empty()
	if is_instance_valid(_last_focus) and _last_focus.has_focus():
		detail_changed.emit(_last_focus.get_detail())


func _flash_if_leveled(card: ElementCard) -> void:
	var id := card.element.id
	if _seen_levels.has(id) and card.level > _seen_levels[id]:
		card.flash()
		sound_requested.emit(&"confirm")
	_seen_levels[id] = card.level
