class_name KeybindRow
extends SettingRow
## Dòng đổi phím của một action. Enter / click: chờ phím hoặc nút chuột mới (Esc để huỷ).
## Khung Cài đặt đưa input vào capture() khi dòng đang chờ, vì phím mới có thể là bất kỳ phím nào kể cả Enter.

## Bắt đầu / thôi chờ phím mới
signal listening_changed(row: KeybindRow, listening: bool)

var action: StringName
var is_listening: bool = false

var _button: Button


func _init(input_action: StringName) -> void:
	action = input_action


func refresh() -> void:
	if is_listening:
		_button.text = "Nhấn phím mới…"
		_button.add_theme_color_override(&"font_color", _style.accent)
		return
	var event := Settings.get_primary_event(action)
	_button.text = Settings.describe_event(event) if event else "—"
	_button.add_theme_color_override(&"font_color", _style.ink)


## Phím / nút chuột vừa bấm khi đang chờ. true = đã dùng sự kiện
func capture(event: InputEvent) -> bool:
	if not is_listening:
		return false
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		if key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE:
			stop_listening()
			return true
		_finish(event)
		return true
	var mouse := event as InputEventMouseButton
	if mouse and mouse.pressed:
		_finish(event)
		return true
	# Thả phím, di chuột...: nuốt luôn để không lọt xuống menu trong lúc chờ
	return event is InputEventKey or event is InputEventMouseButton


func stop_listening() -> void:
	if not is_listening:
		return
	is_listening = false
	refresh()
	listening_changed.emit(self, false)


func _build_control() -> Control:
	_button = _style.make_value_button()
	_button.pressed.connect(_on_pressed)
	return _button


func _on_pressed() -> void:
	if is_listening:
		return
	is_listening = true
	refresh()
	listening_changed.emit(self, true)


func _finish(event: InputEvent) -> void:
	Settings.rebind(action, event)
	is_listening = false
	refresh()
	listening_changed.emit(self, false)
