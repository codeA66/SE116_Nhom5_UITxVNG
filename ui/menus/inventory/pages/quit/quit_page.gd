class_name QuitPage
extends MenuPage
## Trang Thoát: Cho phép người chơi lưu tiến trình và quay về màn hình chính hoặc thoát game.

const MAIN_MENU_SCENE := "res://ui/menus/main/main_menu.tscn"

@onready var _heading: Label = $Layout/Heading
@onready var _btn_title: Button = $Layout/Buttons/TitleButton
@onready var _btn_desktop: Button = $Layout/Buttons/DesktopButton
@onready var _confirm_box: VBoxContainer = $Layout/ConfirmBox
@onready var _confirm_label: Label = $Layout/ConfirmBox/Label
@onready var _btn_confirm: Button = $Layout/ConfirmBox/Buttons/Confirm
@onready var _btn_cancel: Button = $Layout/ConfirmBox/Buttons/Cancel

var _pending_action: StringName = &""


func _ready() -> void:
	_btn_title.pressed.connect(_on_title_clicked)
	_btn_desktop.pressed.connect(_on_desktop_clicked)
	_btn_confirm.pressed.connect(_on_confirm_clicked)
	_btn_cancel.pressed.connect(_on_cancel_clicked)
	
	_btn_title.focus_entered.connect(_show_detail_for.bind(&"title"))
	_btn_desktop.focus_entered.connect(_show_detail_for.bind(&"desktop"))
	
	_confirm_box.visible = false


func setup_style(menu_style: InventoryStyle) -> void:
	super(menu_style)
	_heading.add_theme_font_size_override(&"font_size", style.heading_font)
	_heading.add_theme_color_override(&"font_color", style.dim)


func focus_default() -> void:
	if _confirm_box.visible:
		_btn_cancel.grab_focus()
	else:
		_btn_title.grab_focus()
	_show_detail_for(&"title")


func handle_cancel() -> bool:
	if _confirm_box.visible:
		_confirm_box.visible = false
		_btn_title.grab_focus()
		return true
	return false


func _on_title_clicked() -> void:
	_pending_action = &"title"
	_confirm_label.text = "Lưu tiến trình và quay về Màn hình chính?"
	_confirm_box.visible = true
	_btn_confirm.grab_focus()
	sound_requested.emit(&"confirm")


func _on_desktop_clicked() -> void:
	_pending_action = &"desktop"
	_confirm_label.text = "Lưu tiến trình và thoát ra Desktop?"
	_confirm_box.visible = true
	_btn_confirm.grab_focus()
	sound_requested.emit(&"confirm")


func _on_confirm_clicked() -> void:
	sound_requested.emit(&"confirm")
	SaveManager.save_game()
	if _pending_action == &"title":
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	elif _pending_action == &"desktop":
		get_tree().quit()


func _on_cancel_clicked() -> void:
	sound_requested.emit(&"close")
	handle_cancel()


func _show_detail_for(action: StringName) -> void:
	var entry := DetailEntry.new()
	if action == &"title":
		entry.title = "Về Màn Hình Chính"
		entry.subtitle = "Hệ Thống"
		entry.add_section("Mục Đích", "Lưu tiến trình nhân vật hiện tại và quay trở về màn hình chọn hồ sơ.")
		entry.hint = "Enter: Chọn hành động"
	elif action == &"desktop":
		entry.title = "Thoát Khỏi Trò Chơi"
		entry.subtitle = "Hệ Thống"
		entry.add_section("Mục Đích", "Lưu lại trò chơi và đóng hoàn toàn ứng dụng.")
		entry.hint = "Enter: Chọn hành động"
	detail_changed.emit(entry)
