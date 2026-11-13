class_name HomeScreen
extends MenuScreen
## Danh sách mục chính: Tiếp tục (chỉ khi có hồ sơ) / Bắt đầu / Cài đặt / Thoát.

signal continue_pressed
signal start_pressed
signal settings_pressed
signal quit_pressed

@onready var _continue: MenuItem = $Items/Continue
@onready var _start: MenuItem = $Items/Start
@onready var _settings: MenuItem = $Items/Settings
@onready var _quit: MenuItem = $Items/Quit


func _ready() -> void:
	super._ready()
	_continue.pressed.connect(continue_pressed.emit)
	_start.pressed.connect(start_pressed.emit)
	_settings.pressed.connect(settings_pressed.emit)
	_quit.pressed.connect(quit_pressed.emit)


func get_settings_button() -> Control:
	return _settings


## Hiện / ẩn "Tiếp tục" theo việc có hồ sơ hay không; con trỏ mặc định vào mục đầu tiên đang hiện
func set_can_continue(can_continue: bool) -> void:
	_continue.visible = can_continue
	default_focus = _continue if can_continue else _start
