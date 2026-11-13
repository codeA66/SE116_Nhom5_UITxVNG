class_name ChoiceRow
extends SettingRow
## Dòng chọn một trong nhiều lựa chọn (ngôn ngữ). Enter / click / trái / phải để đổi lựa chọn.

var key: StringName
## Giá trị lưu -> chữ hiện
var options: Dictionary = {}

var _button: Button


func _init(setting_key: StringName, choices: Dictionary) -> void:
	key = setting_key
	options = choices


func refresh() -> void:
	var value: Variant = Settings.get_value(key)
	_button.text = "‹  %s  ›" % str(options.get(value, value)) if options.size() > 1 else str(options.get(value, value))


func _build_control() -> Control:
	_button = _style.make_value_button()
	_button.pressed.connect(_step.bind(1))
	_button.gui_input.connect(_on_gui_input)
	return _button


func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left"):
		_step(-1)
		_button.accept_event()
	elif event.is_action_pressed(&"ui_right"):
		_step(1)
		_button.accept_event()


func _step(direction: int) -> void:
	if options.size() <= 1:
		return
	var keys := options.keys()
	var index := keys.find(Settings.get_value(key))
	Settings.set_value(key, keys[posmod(index + direction, keys.size())])
	refresh()
