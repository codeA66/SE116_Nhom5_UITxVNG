class_name SettingsPage
extends MenuPage
## Trang Cài đặt của màn Tab: dùng chung khung Cài đặt (SettingsPanel) với menu chính và menu tạm dừng,
## mô tả dòng đang chọn đưa sang bảng chi tiết của màn Tab.

@onready var _heading: Label = $Layout/Heading
@onready var _panel: SettingsPanel = $Layout/Panel


func _ready() -> void:
	_panel.row_focused.connect(_on_row_focused)
	_panel.sound_requested.connect(sound_requested.emit)


func setup_style(menu_style: InventoryStyle) -> void:
	super(menu_style)
	_heading.add_theme_font_size_override(&"font_size", style.heading_font)
	_heading.add_theme_color_override(&"font_color", style.dim)


func focus_default() -> void:
	_panel.focus_default()
	detail_changed.emit(null)


## Esc lúc đang chờ phím mới chỉ huỷ việc chờ, không đóng màn Tab
func handle_cancel() -> bool:
	return _panel.handle_cancel()


func _on_row_focused(row_title: String, row_description: String) -> void:
	var entry := DetailEntry.new()
	entry.title = row_title
	entry.subtitle = "Cài đặt"
	entry.add_section("", row_description)
	detail_changed.emit(entry)
