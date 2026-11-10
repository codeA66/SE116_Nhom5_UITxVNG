class_name HomeScreen
extends MenuScreen
## Danh sách mục chính: Bắt đầu / Cài đặt / Thoát.

signal start_pressed
signal settings_pressed
signal quit_pressed

@onready var _start: MenuItem = $Items/Start
@onready var _settings: MenuItem = $Items/Settings
@onready var _quit: MenuItem = $Items/Quit


func _ready() -> void:
	super._ready()
	_start.pressed.connect(start_pressed.emit)
	_settings.pressed.connect(settings_pressed.emit)
	_quit.pressed.connect(quit_pressed.emit)


func get_settings_button() -> Control:
	return _settings
