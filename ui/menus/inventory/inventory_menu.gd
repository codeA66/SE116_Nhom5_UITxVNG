class_name InventoryMenu
extends Control
## Màn Tab phân cấp theo phong cách Zelda: Breath of the Wild:
## - Cấp 1 (Phân mục chính): TÚI ĐỒ (Inventory - Gameplay) [Q] <-> HỆ THỐNG (System - Meta) [E].
## - Cấp 2 (Trang con): Đổi bằng Z / C; bên trái là nội dung trang, bên phải là bảng chi tiết DetailPanel dùng chung.
## Phím Tab mở thẳng vào Túi Đồ; phím H mở thẳng vào Hệ Thống -> Sổ Hướng Dẫn.
## Game KHÔNG dừng khi mở (quái vẫn đánh); đang mở thì Player bỏ qua nút đánh (chuột trái cũng là nút chọn).

signal opened
signal closed

enum Category {
	INVENTORY = 0,
	SYSTEM = 1,
}

const GROUP := &"inventory_menu"

@export var player: Player
@export var toggle_action: StringName = &"inventory"
@export var help_action: StringName = &"help"
@export var prev_category_action: StringName = &"menu_category_prev"
@export var next_category_action: StringName = &"menu_category_next"
@export var previous_page_action: StringName = &"menu_prev_page"
@export var next_page_action: StringName = &"menu_next_page"
@export var style: InventoryStyle = preload("res://resources/ui/inventory_style.tres")
## Tiền hiện ở góc trên phải (chỉ hiện khi ở phân mục Túi Đồ)
@export var currency: CurrencyData = preload("res://resources/player/currency/soul_jade.tres")

var _current_category: Category = Category.INVENTORY
var _inventory_pages: Array[MenuPage] = []
var _system_pages: Array[MenuPage] = []
var _inv_page_index: int = 0
var _sys_page_index: int = 0

var _tween: Tween
var _page_tween: Tween

@onready var _backdrop: ColorRect = $Backdrop
@onready var _frame: CornerFrame = $Frame
@onready var _category_tabs: CategoryTabs = $Header/Categories
@onready var _tabs: PageTabs = $Header/Tabs
@onready var _currency_label: Label = $Header/Currency
@onready var _page_holder: Control = $Body/Pages
@onready var _inv_page_holder: Control = $Body/Pages/InventoryPages
@onready var _sys_page_holder: Control = $Body/Pages/SystemPages
@onready var _detail: DetailPanel = $Body/Detail
@onready var _footer: Label = $Footer
@onready var _sound: AudioStreamPlayer = $Sound


func _ready() -> void:
	# Menu tạm dừng tìm màn Tab qua nhóm này để mở thẳng Sổ hướng dẫn
	add_to_group(GROUP)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.color = style.ornament
	_frame.margin = style.frame_margin
	_frame.corner_size = style.corner_size
	(_backdrop.material as ShaderMaterial).set_shader_parameter(&"base_dim", style.backdrop_dim)
	
	_category_tabs.configure(style, prev_category_action, next_category_action)
	_category_tabs.category_selected.connect(_on_category_selected)
	
	_tabs.configure(style, previous_page_action, next_page_action)
	_tabs.previous_requested.connect(_change_page.bind(-1))
	_tabs.next_requested.connect(_change_page.bind(1))
	
	_detail.configure(style)
	_currency_label.add_theme_font_size_override(&"font_size", style.tab_font)
	_currency_label.add_theme_color_override(&"font_color", style.ink)
	_footer.add_theme_font_size_override(&"font_size", style.key_font)
	_footer.add_theme_color_override(&"font_color", style.faint)
	_refresh_footer()
	
	_setup_pages_in_holder(_inv_page_holder, _inventory_pages)
	_setup_pages_in_holder(_sys_page_holder, _system_pages)
	
	for progress_signal: Signal in [GameState.fusion_changed, GameState.progress_changed, GameState.progress_replaced,
			GameState.items_changed, GameState.charms_changed, GameState.tutorials_changed]:
		progress_signal.connect(_refresh_if_open)
	GameState.charm_station_changed.connect(_refresh_if_open.unbind(1))
	GameState.ability_level_changed.connect(_refresh_if_open.unbind(2))
	GameState.currency_changed.connect(_refresh_if_open.unbind(2))


func _setup_pages_in_holder(holder: Control, target_array: Array[MenuPage]) -> void:
	if holder == null:
		return
	for node in holder.get_children():
		var page := node as MenuPage
		if page == null:
			continue
		page.setup_style(style)
		page.detail_changed.connect(_detail.show_entry)
		page.sound_requested.connect(_play_sound)
		page.hide()
		target_array.append(page)


## Đóng bằng Tab phải đọc trước giao diện: Tab cũng là phím chuyển focus của Godot (ui_focus_next),
## ô đang được chọn trong màn sẽ nuốt mất nếu chờ tới _unhandled_input
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(toggle_action):
		get_viewport().set_input_as_handled()
		close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(help_action):
		get_viewport().set_input_as_handled()
		if visible and _current_category == Category.SYSTEM and _current_page() is TutorialsPage:
			close()
		elif player == null or player.controls_enabled:
			open_to_page_type(TutorialsPage)
		return
	if event.is_action_pressed(toggle_action):
		get_viewport().set_input_as_handled()
		# Đang mở thì _input đã đóng (Tab lần nữa luôn đóng, như Esc, ở mục nào cũng vậy)
		if not visible and (player == null or player.controls_enabled):
			open(Category.INVENTORY)
		return
	# Màn đang đóng thì Esc thuộc về menu tạm dừng (PauseMenu), không mở màn Tab
	if not visible:
		return
	if event.is_action_pressed(prev_category_action):
		get_viewport().set_input_as_handled()
		_change_category(-1)
	elif event.is_action_pressed(next_category_action):
		get_viewport().set_input_as_handled()
		_change_category(1)
	elif event.is_action_pressed(previous_page_action):
		get_viewport().set_input_as_handled()
		_change_page(-1)
	elif event.is_action_pressed(next_page_action):
		get_viewport().set_input_as_handled()
		_change_page(1)
	elif event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		var page := _current_page()
		if page == null or not page.handle_cancel():
			close()


func open(target_category_or_index: Variant = Category.INVENTORY, target_index: int = -1) -> void:
	if visible:
		return
	if target_category_or_index is Category:
		_current_category = target_category_or_index
		if target_index >= 0:
			_set_current_page_index(target_index)
	elif target_category_or_index is int:
		if target_index >= 0:
			_current_category = target_category_or_index as Category
			_set_current_page_index(target_index)
		else:
			_set_current_page_index(target_category_or_index)
	
	var available := _current_available_pages()
	if available.is_empty():
		return
	_set_current_page_index(clampi(_get_current_page_index(), 0, available.size() - 1))
	visible = true
	if player:
		player.set_attack_blocked_by_ui(true)
	_category_tabs.set_active_category(int(_current_category))
	_refresh_header()
	_refresh_footer()
	_show_page(available[_get_current_page_index()], 0)
	_animate_open(true)
	_play_sound(&"open")
	opened.emit()


## Mở menu và nhảy trực tiếp đến trang của kiểu class chỉ định (ví dụ TutorialsPage)
func open_to_page_type(target_type: Variant) -> void:
	for i in _inventory_pages.size():
		if is_instance_of(_inventory_pages[i], target_type):
			if not visible:
				open(Category.INVENTORY, i)
			else:
				_switch_category(Category.INVENTORY, i)
			return
	
	for i in _system_pages.size():
		if is_instance_of(_system_pages[i], target_type):
			if not visible:
				open(Category.SYSTEM, i)
			else:
				_switch_category(Category.SYSTEM, i)
			return
	
	if not visible:
		open(Category.INVENTORY)


func close() -> void:
	if not visible:
		return
	var page := _current_page()
	if page:
		page.handle_cancel()
	if player:
		player.set_attack_blocked_by_ui(false)
	_detail.release()
	_play_sound(&"close")
	_animate_open(false)
	closed.emit()


## Trang đang xem (null nếu đang đóng)
func get_current_page() -> MenuPage:
	return _current_page() if visible else null


func _current_page() -> MenuPage:
	var available := _current_available_pages()
	var idx := _get_current_page_index()
	return available[idx] if idx >= 0 and idx < available.size() else null


func _current_available_pages() -> Array[MenuPage]:
	var pages := _inventory_pages if _current_category == Category.INVENTORY else _system_pages
	var result: Array[MenuPage] = []
	for page: MenuPage in pages:
		if page.is_available():
			result.append(page)
	return result


func _available_pages() -> Array[MenuPage]:
	return _current_available_pages()


func _get_current_page_index() -> int:
	return _inv_page_index if _current_category == Category.INVENTORY else _sys_page_index


func _set_current_page_index(val: int) -> void:
	if _current_category == Category.INVENTORY:
		_inv_page_index = val
	else:
		_sys_page_index = val


func _change_category(direction: int) -> void:
	var next_val := clampi(int(_current_category) + direction, 0, 1) as Category
	_switch_category(next_val)


func _on_category_selected(index: int) -> void:
	_switch_category(index as Category)


func _switch_category(target: Category, target_page_index: int = -1) -> void:
	if _current_category == target and target_page_index < 0:
		return
	var old := _current_page()
	if old:
		old.handle_cancel()
		old.hide()
	
	var dir := 1 if target > _current_category else -1
	_current_category = target
	if target_page_index >= 0:
		_set_current_page_index(target_page_index)
	
	_category_tabs.set_active_category(int(_current_category))
	_refresh_header()
	_refresh_footer()
	
	var available := _current_available_pages()
	if not available.is_empty():
		var idx := clampi(_get_current_page_index(), 0, available.size() - 1)
		_set_current_page_index(idx)
		_show_page(available[idx], dir)
	_play_sound(&"page")


## direction -1 = trang trước, 1 = trang sau (vòng tròn trong phân mục hiện tại)
func _change_page(direction: int) -> void:
	var available := _current_available_pages()
	if not visible or available.size() < 2:
		return
	var old := _current_page()
	if old:
		old.handle_cancel()
		old.hide()
	var new_idx := posmod(_get_current_page_index() + direction, available.size())
	_set_current_page_index(new_idx)
	_show_page(available[new_idx], direction)
	_play_sound(&"page")


func _show_page(page: MenuPage, direction: int) -> void:
	for other: MenuPage in _inventory_pages + _system_pages:
		if other != page:
			other.hide()
	var custom_w := page.get_custom_detail_width()
	_detail.custom_minimum_size.x = custom_w if custom_w > 0.0 else style.detail_width
	page.refresh()
	page.show()
	page.focus_default()
	var titles := PackedStringArray()
	for available: MenuPage in _current_available_pages():
		titles.append(available.page_title)
	_tabs.show_pages(titles, _get_current_page_index())
	if direction == 0:
		return
	# Trang mới trượt vào từ phía đang đổi tới
	if _page_tween and _page_tween.is_valid():
		_page_tween.kill()
	_page_holder.position.x = style.page_slide * float(direction)
	_page_holder.modulate.a = 0.0
	_page_tween = create_tween().set_parallel(true)
	_page_tween.tween_property(_page_holder, "position:x", 0.0, style.page_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_page_tween.tween_property(_page_holder, "modulate:a", 1.0, style.page_time)


func _animate_open(showing: bool) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	if showing:
		modulate.a = 0.0
		_tween.tween_property(self, "modulate:a", 1.0, style.open_time).set_trans(Tween.TRANS_SINE)
	else:
		_tween.tween_property(self, "modulate:a", 0.0, style.close_time).set_trans(Tween.TRANS_SINE)
		_tween.tween_callback(hide)


func _refresh_if_open() -> void:
	if not visible:
		return
	_refresh_header()
	var page := _current_page()
	if page == null or not page.visible:
		_set_current_page_index(0)
		var available := _current_available_pages()
		if not available.is_empty():
			_show_page(available[0], 0)
		return
	page.refresh()
	var titles := PackedStringArray()
	for available: MenuPage in _current_available_pages():
		titles.append(available.page_title)
	_tabs.show_pages(titles, _get_current_page_index())


func _refresh_header() -> void:
	if _current_category == Category.INVENTORY:
		_currency_label.visible = true
		_currency_label.text = "%s  %d" % [currency.display_name, GameState.get_currency(currency.id)] if currency else ""
	else:
		_currency_label.visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_footer()
		_refresh_if_open.call_deferred()


func _refresh_footer() -> void:
	if _current_category == Category.INVENTORY:
		_footer.text = tr("%s  Đóng      %s / %s  Phân mục      %s / %s  Đổi trang      %s  Xác nhận      %s  Quay lại") % [
			PageTabs.key_name(toggle_action),
			PageTabs.key_name(prev_category_action), PageTabs.key_name(next_category_action),
			PageTabs.key_name(previous_page_action), PageTabs.key_name(next_page_action),
			PageTabs.key_name(&"ui_accept"), PageTabs.key_name(&"ui_cancel")
		]
	else:
		_footer.text = tr("%s / %s  Đóng      %s / %s  Phân mục      %s / %s  Đổi trang      %s  Xác nhận      %s  Quay lại") % [
			PageTabs.key_name(help_action), PageTabs.key_name(&"ui_cancel"),
			PageTabs.key_name(prev_category_action), PageTabs.key_name(next_category_action),
			PageTabs.key_name(previous_page_action), PageTabs.key_name(next_page_action),
			PageTabs.key_name(&"ui_accept"), PageTabs.key_name(&"ui_cancel")
		]


func _play_sound(kind: StringName) -> void:
	var stream: AudioStream = style.get(&"sound_%s" % kind) if style else null
	if stream:
		_sound.stream = stream
		_sound.play()
