class_name InventoryMenu
extends Control
## Màn Tab: nhiều trang (Nguyên tố, Vật phẩm, Bùa...), tên trang ở giữa, tên trang hai bên ở mép đổi bằng Z / C;
## bên trái là ô của trang, bên phải là bảng chi tiết dùng chung. Nền là cảnh game làm tối, hoa văn ở 4 góc.
## Game KHÔNG dừng khi mở (quái vẫn đánh); đang mở thì Player bỏ qua nút đánh (chuột trái cũng là nút chọn).
## Thêm trang = thêm node MenuPage vào Body/Pages. Chỉ làm mới khi đang mở và tiến trình đổi; không chạy mỗi frame.

signal opened
signal closed

@export var player: Player
@export var toggle_action: StringName = &"inventory"
@export var help_action: StringName = &"help"
@export var previous_page_action: StringName = &"menu_prev_page"
@export var next_page_action: StringName = &"menu_next_page"
@export var style: InventoryStyle = preload("res://resources/ui/inventory_style.tres")
## Tiền hiện ở góc trên phải
@export var currency: CurrencyData = preload("res://resources/player/currency/soul_jade.tres")

var _pages: Array[MenuPage] = []
var _page_index: int = 0
var _tween: Tween
var _page_tween: Tween

@onready var _backdrop: ColorRect = $Backdrop
@onready var _frame: CornerFrame = $Frame
@onready var _tabs: PageTabs = $Header/Tabs
@onready var _currency_label: Label = $Header/Currency
@onready var _page_holder: Control = $Body/Pages
@onready var _detail: DetailPanel = $Body/Detail
@onready var _footer: Label = $Footer
@onready var _sound: AudioStreamPlayer = $Sound


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.color = style.ornament
	_frame.margin = style.frame_margin
	_frame.corner_size = style.corner_size
	(_backdrop.material as ShaderMaterial).set_shader_parameter(&"base_dim", style.backdrop_dim)
	_tabs.configure(style, previous_page_action, next_page_action)
	_tabs.previous_requested.connect(_change_page.bind(-1))
	_tabs.next_requested.connect(_change_page.bind(1))
	_detail.configure(style)
	_currency_label.add_theme_font_size_override(&"font_size", style.tab_font)
	_currency_label.add_theme_color_override(&"font_color", style.ink)
	_footer.add_theme_font_size_override(&"font_size", style.key_font)
	_footer.add_theme_color_override(&"font_color", style.faint)
	_footer.text = "%s  Đóng      %s / %s  Đổi trang      %s  Xác nhận      %s  Quay lại" % [PageTabs.key_name(toggle_action),
		PageTabs.key_name(previous_page_action), PageTabs.key_name(next_page_action), PageTabs.key_name(&"ui_accept"), PageTabs.key_name(&"ui_cancel")]
	for node in _page_holder.get_children():
		var page := node as MenuPage
		if page == null:
			continue
		page.setup_style(style)
		page.detail_changed.connect(_detail.show_entry)
		page.sound_requested.connect(_play_sound)
		page.hide()
		_pages.append(page)
	for progress_signal: Signal in [GameState.fusion_changed, GameState.progress_changed, GameState.progress_replaced,
			GameState.items_changed, GameState.charms_changed, GameState.tutorials_changed]:
		progress_signal.connect(_refresh_if_open)
	GameState.charm_station_changed.connect(_refresh_if_open.unbind(1))
	GameState.ability_level_changed.connect(_refresh_if_open.unbind(2))
	GameState.currency_changed.connect(_refresh_if_open.unbind(2))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(help_action):
		get_viewport().set_input_as_handled()
		if visible and _current_page() is TutorialsPage:
			close()
		elif player == null or player.controls_enabled:
			open_to_page_type(TutorialsPage)
		return
	if event.is_action_pressed(toggle_action):
		get_viewport().set_input_as_handled()
		if visible:
			close()
		elif player == null or player.controls_enabled:
			open()
		return
	if not visible:
		return
	if event.is_action_pressed(previous_page_action):
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


func open(target_index: int = -1) -> void:
	if visible:
		return
	var available := _available_pages()
	if available.is_empty():
		return
	if target_index >= 0:
		_page_index = target_index
	_page_index = clampi(_page_index, 0, available.size() - 1)
	visible = true
	if player:
		player.set_attack_blocked_by_ui(true)
	_refresh_header()
	_show_page(available[_page_index], 0)
	_animate_open(true)
	_play_sound(&"open")
	opened.emit()


## Mở menu và nhảy trực tiếp đến trang của kiểu class chỉ định (ví dụ TutorialsPage)
func open_to_page_type(target_type: Variant) -> void:
	var available := _available_pages()
	var found_index := -1
	for i in available.size():
		if is_instance_of(available[i], target_type):
			found_index = i
			break
	if found_index >= 0:
		if not visible:
			open(found_index)
		else:
			_page_index = found_index
			_show_page(available[_page_index], 0)
	elif not visible:
		open()


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
	var available := _available_pages()
	return available[_page_index] if _page_index >= 0 and _page_index < available.size() else null


func _available_pages() -> Array[MenuPage]:
	var result: Array[MenuPage] = []
	for page: MenuPage in _pages:
		if page.is_available():
			result.append(page)
	return result


## direction -1 = trang trước, 1 = trang sau (vòng tròn)
func _change_page(direction: int) -> void:
	var available := _available_pages()
	if not visible or available.size() < 2:
		return
	var old := _current_page()
	if old:
		old.handle_cancel()
		old.hide()
	_page_index = posmod(_page_index + direction, available.size())
	_show_page(available[_page_index], direction)
	_play_sound(&"page")


func _show_page(page: MenuPage, direction: int) -> void:
	for other: MenuPage in _pages:
		if other != page:
			other.hide()
	var custom_w := page.get_custom_detail_width()
	_detail.custom_minimum_size.x = custom_w if custom_w > 0.0 else style.detail_width
	page.refresh()
	page.show()
	page.focus_default()
	var titles := PackedStringArray()
	for available: MenuPage in _available_pages():
		titles.append(available.page_title)
	_tabs.show_pages(titles, _page_index)
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
		# Trang đang xem vừa mất (hoặc trang mới vừa mở): dựng lại thanh trang
		_page_index = 0
		var available := _available_pages()
		if not available.is_empty():
			_show_page(available[0], 0)
		return
	page.refresh()
	var titles := PackedStringArray()
	for available: MenuPage in _available_pages():
		titles.append(available.page_title)
	_tabs.show_pages(titles, _page_index)


func _refresh_header() -> void:
	_currency_label.text = "%s  %d" % [currency.display_name, GameState.get_currency(currency.id)] if currency else ""


func _play_sound(kind: StringName) -> void:
	var stream: AudioStream = style.get(&"sound_%s" % kind) if style else null
	if stream:
		_sound.stream = stream
		_sound.play()
