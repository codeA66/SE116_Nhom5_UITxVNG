class_name SettingsPage
extends MenuPage
## Trang Cài Đặt: Điều chỉnh âm lượng nhanh, chế độ hiển thị màn hình, và tóm tắt điều khiển.

@onready var _heading: Label = $Layout/Heading
@onready var _master_slider: HSlider = $Layout/Controls/MasterVolume/Slider
@onready var _master_val: Label = $Layout/Controls/MasterVolume/Value
@onready var _fullscreen_check: CheckBox = $Layout/Controls/Fullscreen/Check


func _ready() -> void:
	_master_slider.value_changed.connect(_on_master_volume_changed)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	
	_master_slider.focus_entered.connect(_show_detail_for.bind(&"volume"))
	_fullscreen_check.focus_entered.connect(_show_detail_for.bind(&"fullscreen"))
	
	# Khởi tạo giá trị hiện tại
	var bus_idx := AudioServer.get_bus_index(&"Master")
	if bus_idx >= 0:
		var db := AudioServer.get_bus_volume_db(bus_idx)
		var linear := db_to_linear(db)
		_master_slider.value = roundi(linear * 100.0)
		_master_val.text = "%d%%" % int(_master_slider.value)
	
	var mode := DisplayServer.window_get_mode()
	_fullscreen_check.button_pressed = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


func setup_style(menu_style: InventoryStyle) -> void:
	super(menu_style)
	_heading.add_theme_font_size_override(&"font_size", style.heading_font)
	_heading.add_theme_color_override(&"font_color", style.dim)


func focus_default() -> void:
	_master_slider.grab_focus()
	_show_detail_for(&"volume")


func _on_master_volume_changed(value: float) -> void:
	_master_val.text = "%d%%" % int(value)
	var bus_idx := AudioServer.get_bus_index(&"Master")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if toggled_on else DisplayServer.WINDOW_MODE_WINDOWED)


func _show_detail_for(kind: StringName) -> void:
	var entry := DetailEntry.new()
	if kind == &"volume":
		entry.title = "Âm Lượng Tổng"
		entry.subtitle = "Âm thanh"
		entry.add_section("Mô tả", "Điều chỉnh mức âm lượng tổng của toàn bộ âm thanh và nhạc nền trong trò chơi.")
		entry.hint = "Trái / Phải: Tăng giảm âm lượng"
	elif kind == &"fullscreen":
		entry.title = "Chế Độ Toàn Màn Hình"
		entry.subtitle = "Hiển thị"
		entry.add_section("Mô tả", "Bật hoặc tắt chế độ hiển thị toàn màn hình để tối ưu tầm nhìn khi chơi.")
		entry.hint = "Phím Cách / Enter: Bật tắt"
	detail_changed.emit(entry)
