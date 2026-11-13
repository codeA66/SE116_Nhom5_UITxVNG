class_name SettingsScreen
extends MenuScreen
## Màn Cài đặt của menu chính: khung Cài đặt dùng chung (SettingsPanel) + nút Quay lại.

signal back_pressed

@onready var panel: SettingsPanel = $Panel
@onready var _back: MenuItem = $Back


func _ready() -> void:
	super._ready()
	_back.pressed.connect(back_pressed.emit)
	default_focus = _back


func show_screen(data: MainMenuData, focus: Control = null) -> void:
	super(data, focus)
	if focus == null:
		panel.focus_default.call_deferred()
