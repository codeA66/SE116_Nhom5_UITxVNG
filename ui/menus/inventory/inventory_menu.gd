class_name InventoryMenu
extends Control
## Màn đồ của nhân vật, một tầng trang (kiểu Hollow Knight): bên trái là nội dung trang, bên phải là bảng chi tiết dùng chung.
## - Tab: các trang dưới TabPages (Bùa, Vật phẩm, Nguyên tố), đổi trang bằng Z / C.
## - H: Sổ tay mở riêng (các trang dưới HelpPages), không lẫn vào vòng trang của Tab.
## Cài đặt / thoát game chỉ nằm ở menu tạm dừng (Esc). Thêm trang = thêm MenuPage vào TabPages, không sửa file này.
## Game KHÔNG dừng khi mở (quái vẫn đánh); đang mở thì Player bỏ qua nút đánh (chuột trái cũng là nút chọn).

signal opened
signal closed

## TAB: vòng trang đồ (Tab). HELP: Sổ tay (H)
enum Mode {
	TAB = 0,
	HELP = 1,
}

const GROUP := &"inventory_menu"
const PANEL_BODY_Z_INDEX: int = 1

@export var player: Player
@export var toggle_action: StringName = &"inventory"
@export var help_action: StringName = &"help"
@export var previous_page_action: StringName = &"menu_prev_page"
@export var next_page_action: StringName = &"menu_next_page"
@export var style: InventoryStyle = preload("res://resources/ui/inventory_style.tres")
## Tiền hiện ở góc dưới phải (chỉ hiện ở màn Tab, không hiện ở Sổ tay)
@export var currency: CurrencyData = preload("res://resources/player/currency/soul_jade.tres")

var _mode: Mode = Mode.TAB
var _tab_pages: Array[MenuPage] = []
var _help_pages: Array[MenuPage] = []
var _tab_page_index: int = 0
var _help_page_index: int = 0

var _tween: Tween
var _page_tween: Tween
## Cụm [ô phím + chữ] ở chân màn: tạo một lần, mỗi lần đổi màn chỉ đổi chữ và ẩn / hiện (không tạo node mới)
var _footer_keys: Array[KeyGlyph] = []
var _footer_labels: Array[Label] = []

@onready var _backdrop: ColorRect = $Backdrop
@onready var _frame: CornerFrame = $Frame
@onready var _tabs: PageTabs = $Header/Tabs
@onready var _currency_label: Label = $Currency
@onready var _body: PanelContainer = $Body
@onready var _columns: HBoxContainer = $Body/Columns
@onready var _body_default: StyleBox = _body.get_theme_stylebox(&"panel")
@onready var _column_gap_default: int = _columns.get_theme_constant(&"separation")
@onready var _page_holder: Control = $Body/Columns/Pages
@onready var _tab_page_holder: Control = $Body/Columns/Pages/TabPages
@onready var _help_page_holder: Control = $Body/Columns/Pages/HelpPages
@onready var _detail: DetailPanel = $Body/Columns/Detail
@onready var _footer: HBoxContainer = $Footer
@onready var _sound: AudioStreamPlayer = $Sound


func _ready() -> void:
	# Menu tạm dừng tìm màn Tab qua nhóm này để mở thẳng Sổ hướng dẫn
	add_to_group(GROUP)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.color = style.ornament
	_frame.margin = style.frame_margin
	_frame.corner_size = style.corner_size
	var backdrop := _backdrop.material as ShaderMaterial
	backdrop.set_shader_parameter(&"base_dim", style.backdrop_dim)
	backdrop.set_shader_parameter(&"blur_lod", style.backdrop_blur)
	backdrop.set_shader_parameter(&"desaturate", style.backdrop_desaturate)
	
	_tabs.configure(style, previous_page_action, next_page_action)
	_tabs.previous_requested.connect(_change_page.bind(-1))
	_tabs.next_requested.connect(_change_page.bind(1))
	_tabs.page_requested.connect(_go_to_page)
	
	_detail.configure(style)
	_currency_label.add_theme_font_size_override(&"font_size", style.tab_font)
	_currency_label.add_theme_color_override(&"font_color", style.ink)
	_footer.add_theme_constant_override(&"separation", style.footer_gap)
	_refresh_footer()
	
	_setup_pages_in_holder(_tab_page_holder, _tab_pages)
	_setup_pages_in_holder(_help_page_holder, _help_pages)
	
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
		if visible and _mode == Mode.HELP:
			close()
		elif player == null or player.controls_enabled:
			open_to_page_type(TutorialsPage)
		return
	if event.is_action_pressed(toggle_action):
		get_viewport().set_input_as_handled()
		# Đang mở thì _input đã đóng (Tab lần nữa luôn đóng, như Esc, ở mục nào cũng vậy)
		if not visible and (player == null or player.controls_enabled):
			open(Mode.TAB)
		return
	# Màn đang đóng thì Esc thuộc về menu tạm dừng (PauseMenu), không mở màn Tab
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


## mode: màn Tab hay Sổ tay; page_index < 0 thì giữ trang đang xem lần trước
func open(mode: Mode = Mode.TAB, page_index: int = -1) -> void:
	if visible:
		return
	_mode = mode
	if page_index >= 0:
		_set_current_page_index(page_index)
	var available := _current_available_pages()
	if available.is_empty():
		return
	_set_current_page_index(clampi(_get_current_page_index(), 0, available.size() - 1))
	visible = true
	if player:
		player.set_attack_blocked_by_ui(true)
	_refresh_header()
	_refresh_footer()
	_show_page(available[_get_current_page_index()], 0)
	_animate_open(true)
	_play_sound(&"open")
	opened.emit()


## Mở menu và nhảy trực tiếp đến trang của kiểu class chỉ định (ví dụ TutorialsPage -> Sổ tay)
func open_to_page_type(target_type: Variant) -> void:
	for mode: Mode in [Mode.TAB, Mode.HELP]:
		var pages := _pages_of(mode)
		for i in pages.size():
			if is_instance_of(pages[i], target_type):
				if not visible:
					open(mode, i)
				else:
					_switch_mode(mode, i)
				return
	if not visible:
		open(Mode.TAB)


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
	var result: Array[MenuPage] = []
	for page: MenuPage in _pages_of(_mode):
		if page.is_available():
			result.append(page)
	return result


func _pages_of(mode: Mode) -> Array[MenuPage]:
	return _tab_pages if mode == Mode.TAB else _help_pages


func _available_pages() -> Array[MenuPage]:
	return _current_available_pages()


func _get_current_page_index() -> int:
	return _tab_page_index if _mode == Mode.TAB else _help_page_index


func _set_current_page_index(val: int) -> void:
	if _mode == Mode.TAB:
		_tab_page_index = val
	else:
		_help_page_index = val


## Đang mở mà chuyển giữa màn Tab và Sổ tay (ví dụ bấm H khi đang xem Tab)
func _switch_mode(target: Mode, target_page_index: int = -1) -> void:
	if _mode == target and target_page_index < 0:
		return
	var old := _current_page()
	if old:
		old.handle_cancel()
		old.hide()
	_mode = target
	if target_page_index >= 0:
		_set_current_page_index(target_page_index)
	_refresh_header()
	_refresh_footer()
	var available := _current_available_pages()
	if not available.is_empty():
		var idx := clampi(_get_current_page_index(), 0, available.size() - 1)
		_set_current_page_index(idx)
		_show_page(available[idx], 0)
	_play_sound(&"page")


## direction -1 = trang trước, 1 = trang sau (vòng tròn trong màn hiện tại)
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


## Bấm icon trang: nhảy thẳng tới trang index (trượt theo chiều đi tới)
func _go_to_page(index: int) -> void:
	var available := _current_available_pages()
	if not visible or index < 0 or index >= available.size() or index == _get_current_page_index():
		return
	var direction := 1 if index > _get_current_page_index() else -1
	var old := _current_page()
	if old:
		old.handle_cancel()
		old.hide()
	_set_current_page_index(index)
	_show_page(available[index], direction)
	_play_sound(&"page")


func _show_page(page: MenuPage, direction: int) -> void:
	for other: MenuPage in _tab_pages + _help_pages:
		if other != page:
			other.hide()
	var panel_style: StyleBox = page.get_body_panel_style()
	_body.add_theme_stylebox_override(&"panel", panel_style if panel_style else _body_default)
	# Khung liền che gợi ý tương tác trong cảnh để chữ không đè lên nội dung.
	_body.z_index = PANEL_BODY_Z_INDEX if panel_style else 0
	var column_gap: int = page.get_body_column_gap()
	_columns.add_theme_constant_override(&"separation", column_gap if column_gap >= 0 else _column_gap_default)
	var custom_w: float = page.get_custom_detail_width()
	_detail.custom_minimum_size.x = custom_w if custom_w > 0.0 else style.detail_width
	_detail.set_art_layout(Vector2.ZERO, -1)
	page.configure_detail(_detail)
	page.refresh()
	page.show()
	page.focus_default()
	_refresh_tabs()
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
	_refresh_tabs()


func _refresh_tabs() -> void:
	var titles := PackedStringArray()
	var icons: Array[Texture2D] = []
	for available: MenuPage in _current_available_pages():
		titles.append(available.page_title)
		icons.append(available.page_icon)
	_tabs.show_pages(titles, _get_current_page_index(), icons)


func _refresh_header() -> void:
	if _mode == Mode.TAB:
		_currency_label.visible = true
		_currency_label.text = "%s  %d" % [currency.display_name, GameState.get_currency(currency.id)] if currency else ""
	else:
		_currency_label.visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_footer()
		_refresh_if_open.call_deferred()


func _refresh_footer() -> void:
	var entries: Array[PackedStringArray] = []
	if _mode == Mode.TAB:
		entries.append(PackedStringArray([PageTabs.key_name(toggle_action), tr("Đóng")]))
		entries.append(PackedStringArray([
			"%s / %s" % [PageTabs.key_name(previous_page_action), PageTabs.key_name(next_page_action)], tr("Đổi trang")]))
		entries.append(PackedStringArray([PageTabs.key_name(&"ui_accept"), tr("Xác nhận")]))
		entries.append(PackedStringArray([PageTabs.key_name(&"ui_cancel"), tr("Quay lại")]))
	else:
		entries.append(PackedStringArray([
			"%s / %s" % [PageTabs.key_name(help_action), PageTabs.key_name(&"ui_cancel")], tr("Đóng")]))
		entries.append(PackedStringArray([PageTabs.key_name(&"ui_accept"), tr("Xác nhận")]))
	while _footer_keys.size() < entries.size():
		_add_footer_entry()
	for i in _footer_keys.size():
		var used := i < entries.size()
		_footer_keys[i].get_parent().visible = used
		if used:
			_footer_keys[i].text = entries[i][0]
			_footer_labels[i].text = entries[i][1]


func _add_footer_entry() -> void:
	var group := HBoxContainer.new()
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_theme_constant_override(&"separation", style.footer_key_gap)
	var key := KeyGlyph.new()
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	key.font_size = style.key_font
	key.text_color = style.ink
	key.border_color = Color(style.dim, 0.7)
	key.fill_color = Color(0.0, 0.0, 0.0, 0.45)
	var label := Label.new()
	label.add_theme_font_size_override(&"font_size", style.key_font)
	label.add_theme_color_override(&"font_color", style.dim)
	group.add_child(key)
	group.add_child(label)
	_footer.add_child(group)
	_footer_keys.append(key)
	_footer_labels.append(label)


func _play_sound(kind: StringName) -> void:
	var stream: AudioStream = style.get(&"sound_%s" % kind) if style else null
	if stream:
		_sound.stream = stream
		_sound.play()
