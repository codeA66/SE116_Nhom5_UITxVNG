class_name ElementsPage
extends MenuPage
## Trang Nguyên tố: thẻ các nguyên tố (theo bảng ghép GameState.FUSIONS, thêm nguyên tố = thêm .tres) và ô vũ khí.
## Ghép bằng chuột: kéo thẻ thả vào ổ khảm. Ghép bằng phím / tay cầm: Enter trên thẻ để "cầm", Enter trên vũ khí để ghép.

var _held: ElementCard
var _cards: Array[ElementCard] = []
var _sockets: Array[WeaponSocket] = []

@onready var _card_grid: GridContainer = $Columns/Elements/Grid
@onready var _socket_list: VBoxContainer = $Columns/Weapons/List
@onready var _headings: Array[Label] = [$Columns/Elements/Heading, $Columns/Weapons/Heading]


func setup_style(menu_style: InventoryStyle) -> void:
	super(menu_style)
	for heading: Label in _headings:
		heading.add_theme_font_size_override(&"font_size", style.heading_font)
		heading.add_theme_color_override(&"font_color", style.dim)


func refresh() -> void:
	var fused_at := {}
	for slot: int in GameState.progress.fusions:
		fused_at[GameState.progress.fusions[slot]] = slot
	var owned := GameState.get_owned_elements()
	var elements := GameState.FUSIONS.elements
	_resize_cards(elements.size())
	for index in elements.size():
		var element := elements[index]
		_cards[index].setup(element, owned.has(element), fused_at.get(element.id, -1))
	var slots := WeaponData.Slot.values()
	_resize_sockets(slots.size())
	for index in slots.size():
		var slot := slots[index] as WeaponData.Slot
		var element := GameState.get_fused_element(slot)
		var fusion := GameState.FUSIONS.get_fusion(slot, element.id) if element else null
		_sockets[index].setup(slot, GameState.get_weapon_in_slot(slot), element, fusion)
	if is_instance_valid(_last_focus) and _last_focus.has_focus():
		detail_changed.emit(_last_focus.get_detail())


func handle_cancel() -> bool:
	if _held == null:
		return false
	_release_held()
	return true


func _resize_cards(count: int) -> void:
	while _cards.size() < count:
		var card := ElementCard.new()
		card.custom_minimum_size = style.element_card_size
		bind_tile(card)
		card.activated.connect(_on_card_activated)
		_card_grid.add_child(card)
		_cards.append(card)
	while _cards.size() > count:
		_cards.pop_back().queue_free()


func _resize_sockets(count: int) -> void:
	while _sockets.size() < count:
		var socket := WeaponSocket.new()
		socket.custom_minimum_size = style.weapon_socket_size
		bind_tile(socket)
		socket.activated.connect(_on_socket_activated)
		socket.alt_activated.connect(_on_socket_alt)
		_socket_list.add_child(socket)
		_sockets.append(socket)
	while _sockets.size() > count:
		_sockets.pop_back().queue_free()


func _on_card_activated(tile: MenuTile) -> void:
	var card := tile as ElementCard
	if not card.owned:
		sound_requested.emit(&"error")
		return
	if _held == card:
		_release_held()
		return
	_release_held()
	_held = card
	card.held = true
	sound_requested.emit(&"confirm")
	# Cầm xong thì con trỏ nhảy sang vũ khí đầu tiên đang có
	for socket: WeaponSocket in _sockets:
		if socket.weapon:
			socket.grab_focus()
			break


func _on_socket_activated(tile: MenuTile) -> void:
	var socket := tile as WeaponSocket
	if socket.weapon == null:
		sound_requested.emit(&"error")
		return
	if _held:
		var ok := GameState.fuse(_held.element.id, socket.slot)
		_release_held()
		sound_requested.emit(&"confirm" if ok else &"error")
	elif socket.element:
		GameState.unfuse(socket.slot)
		sound_requested.emit(&"confirm")


func _on_socket_alt(tile: MenuTile) -> void:
	var socket := tile as WeaponSocket
	if socket.element:
		GameState.unfuse(socket.slot)
		sound_requested.emit(&"confirm")


func _release_held() -> void:
	if is_instance_valid(_held):
		_held.held = false
	_held = null
