class_name SettingsPanel
extends VBoxContainer
## Khung Cài đặt dùng chung: hàng mục (Âm thanh / Hiển thị / Điều khiển / Ngôn ngữ) và các dòng của mục đang chọn.
## Mọi giá trị đọc ghi qua autoload Settings, nên menu chính, menu tạm dừng và màn Tab luôn hiện giống nhau.
## Thêm mục mới = thêm một hàm dựng dòng vào CATEGORIES; thêm loại dòng mới = kế thừa SettingRow.

## Dòng được chọn đổi: nơi chứa hiện mô tả (màn Tab đưa sang bảng chi tiết)
signal row_focused(title: String, description: String)
## Xin nơi chứa phát âm thanh (move / confirm)
signal sound_requested(kind: StringName)

const CATEGORIES: Array[Dictionary] = [
	{"title": "Âm thanh", "build": &"_build_audio"},
	{"title": "Hiển thị", "build": &"_build_display"},
	{"title": "Điều khiển", "build": &"_build_controls"},
	{"title": "Ngôn ngữ", "build": &"_build_language"},
]

@export var panel_style: SettingsPanelStyle
## Hiện dòng mô tả dưới khung (tắt khi nơi chứa có bảng chi tiết riêng như màn Tab)
@export var show_description: bool = true

var _tabs: Array[MenuItem] = []
var _pages: Array[VBoxContainer] = []
var _current: int = 0
var _listening: KeybindRow
var _description: Label
var _last_row: SettingRow


func _ready() -> void:
	if panel_style == null:
		panel_style = SettingsPanelStyle.new()
	add_theme_constant_override(&"separation", 18)
	var tab_row := HBoxContainer.new()
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_row.add_theme_constant_override(&"separation", panel_style.tab_gap)
	add_child(tab_row)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(holder)
	for index in CATEGORIES.size():
		var tab := MenuItem.new()
		tab.text = CATEGORIES[index]["title"]
		tab.flat = true
		tab.accent_color = panel_style.accent
		tab.add_theme_font_size_override(&"font_size", panel_style.tab_font)
		tab.focus_entered.connect(_show_category.bind(index))
		tab_row.add_child(tab)
		_tabs.append(tab)
		var page := VBoxContainer.new()
		page.add_theme_constant_override(&"separation", panel_style.row_gap)
		# Chừa lề trái cho hạt thoi đánh dấu dòng
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_child(page)
		_pages.append(page)
		call(CATEGORIES[index]["build"], page)
	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description.custom_minimum_size.y = panel_style.description_font * 2.6
	_description.add_theme_font_size_override(&"font_size", panel_style.description_font)
	_description.add_theme_color_override(&"font_color", panel_style.dim)
	_description.visible = show_description
	add_child(_description)
	_show_category(0)
	Settings.changed.connect(_refresh_rows.unbind(1))
	Settings.bindings_changed.connect(_refresh_rows)


func _input(event: InputEvent) -> void:
	# Đang chờ phím mới: mọi phím (kể cả Enter, Tab) là phím được chọn, không để menu dùng
	if _listening and is_visible_in_tree() and _listening.capture(event):
		get_viewport().set_input_as_handled()


## Đưa con trỏ vào khung (mục đầu tiên)
func focus_default() -> void:
	_tabs[_current].grab_focus()


## Esc khi đang ở khung. true = khung đã xử lý (huỷ chờ phím), nơi chứa không đóng
func handle_cancel() -> bool:
	if _listening:
		_listening.stop_listening()
		return true
	return false


func is_listening() -> bool:
	return _listening != null


func _show_category(index: int) -> void:
	if index != _current:
		sound_requested.emit(&"move")
	_current = index
	for i in _pages.size():
		_pages[i].visible = i == index
	_description.text = ""
	_link_focus(index)


## Bấm xuống từ hàng mục vào dòng đầu của mục đang chọn, bấm lên từ dòng đầu về đúng mục đó
## (để mặc Godot đoán theo vị trí thì có lúc nhảy thẳng xuống nút Quay lại bên dưới khung)
func _link_focus(index: int) -> void:
	var first := _first_focus(_pages[index])
	if first == null:
		return
	for tab in _tabs:
		tab.focus_neighbor_bottom = tab.get_path_to(first)
	first.focus_neighbor_top = first.get_path_to(_tabs[index])


func _first_focus(page: VBoxContainer) -> Control:
	for child in page.get_children():
		if child is SettingRow:
			return (child as SettingRow).get_focus_control()
		if child is Control and (child as Control).focus_mode != Control.FOCUS_NONE:
			return child as Control
	return null


func _refresh_rows() -> void:
	for page in _pages:
		for row in page.get_children():
			if row is SettingRow:
				(row as SettingRow).refresh()


func _add_row(page: VBoxContainer, row: SettingRow, row_title: String, row_description: String) -> void:
	page.add_child(row)
	row.setup(row_title, row_description, panel_style)
	row.focused.connect(_on_row_focused)


func _on_row_focused(row: SettingRow) -> void:
	if _last_row != row:
		sound_requested.emit(&"move")
	_last_row = row
	_description.text = row.description
	row_focused.emit(row.title, row.description)


func _build_audio(page: VBoxContainer) -> void:
	_add_row(page, SliderRow.new(&"master_volume"), "Âm lượng tổng", "Âm lượng của toàn bộ trò chơi.")
	_add_row(page, SliderRow.new(&"music_volume"), "Nhạc nền", "Nhạc nền ở menu và trong khi chơi.")
	_add_row(page, SliderRow.new(&"sfx_volume"), "Hiệu ứng âm thanh", "Tiếng đánh, kỹ năng, giao diện.")


func _build_display(page: VBoxContainer) -> void:
	_add_row(page, ToggleRow.new(&"fullscreen"), "Toàn màn hình", "Chơi toàn màn hình hoặc trong cửa sổ.")
	_add_row(page, ToggleRow.new(&"vsync"), "Đồng bộ dọc (VSync)", "Chống xé hình; tắt nếu thấy trễ phím.")
	_add_row(page, SliderRow.new(&"screen_shake"), "Rung màn hình", "Độ rung khi đánh trúng, bị đánh, nổ. 0% là tắt rung.")


func _build_controls(page: VBoxContainer) -> void:
	for action: StringName in Settings.DEFAULTS.rebindable_actions:
		if not InputMap.has_action(action):
			continue
		var row := KeybindRow.new(action)
		_add_row(page, row, Settings.DEFAULTS.rebindable_actions[action], "Enter hoặc click rồi nhấn phím mới. Esc để huỷ. Phím đã dùng cho việc khác sẽ đổi chỗ cho nhau.")
		row.listening_changed.connect(_on_listening_changed)
	var reset := MenuItem.new()
	reset.text = "Khôi phục phím mặc định"
	reset.flat = true
	reset.accent_color = panel_style.accent
	reset.add_theme_font_size_override(&"font_size", panel_style.row_font)
	reset.pressed.connect(_on_reset_bindings)
	page.add_child(reset)


func _build_language(page: VBoxContainer) -> void:
	_add_row(page, ChoiceRow.new(&"locale", Settings.DEFAULTS.languages), "Ngôn ngữ", "Hiện game mới có Tiếng Việt.")


func _on_listening_changed(row: KeybindRow, listening: bool) -> void:
	if listening:
		if _listening and _listening != row:
			_listening.stop_listening()
		_listening = row
		sound_requested.emit(&"confirm")
	elif _listening == row:
		_listening = null


func _on_reset_bindings() -> void:
	if _listening:
		_listening.stop_listening()
	Settings.reset_bindings()
	sound_requested.emit(&"confirm")
