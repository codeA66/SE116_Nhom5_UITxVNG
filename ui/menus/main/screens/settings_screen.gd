class_name SettingsScreen
extends MenuScreen
## Khung cài đặt (nội dung là hạng mục riêng trong backlog, chưa làm).

signal back_pressed

@onready var _back: MenuItem = $Back


func _ready() -> void:
	super._ready()
	_back.pressed.connect(back_pressed.emit)
	default_focus = _back
