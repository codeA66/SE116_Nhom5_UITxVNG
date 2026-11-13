class_name ToggleRow
extends SettingRow
## Dòng bật / tắt cho một giá trị bool của Settings (toàn màn hình, VSync). Enter / click để đổi.

var key: StringName

var _button: Button


func _init(setting_key: StringName) -> void:
	key = setting_key


func refresh() -> void:
	var on := bool(Settings.get_value(key))
	_button.text = "Bật" if on else "Tắt"
	_button.add_theme_color_override(&"font_color", _style.ink if on else _style.dim)


func _build_control() -> Control:
	_button = _style.make_value_button()
	_button.pressed.connect(_on_pressed)
	return _button


func _on_pressed() -> void:
	Settings.set_value(key, not bool(Settings.get_value(key)))
	refresh()
