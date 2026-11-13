extends Node
## Autoload "Settings": đọc / áp dụng / ghi cài đặt người chơi (âm lượng, hiển thị, phím, ngôn ngữ) ở user://settings.cfg.
## Menu chính, menu tạm dừng và trang Cài đặt trong Tab cùng đọc ghi qua đây, nên ba nơi luôn khớp nhau.
## File hỏng / thiếu / sai kiểu thì dùng giá trị mặc định (SettingsData), không bao giờ làm game dừng.
## Phải đứng sau ScreenShake trong danh sách autoload (áp dụng độ rung lúc khởi động).

## Một giá trị đổi (tên thuộc tính của SettingsData)
signal changed(key: StringName)
## Phím của một hoặc nhiều action đổi: chữ gợi ý phím (HUD, popup hướng dẫn...) nên đọc lại
signal bindings_changed

const DEFAULTS: SettingsData = preload("res://resources/settings/default_settings.tres")
const DEFAULT_PATH := "user://settings.cfg"
const AUDIO_BUSES: Dictionary[StringName, StringName] = {
	&"master_volume": &"Master",
	&"music_volume": &"Music",
	&"sfx_volume": &"SFX",
}
## Thuộc tính lưu ở mục nào của file
const SECTIONS: Dictionary[StringName, String] = {
	&"master_volume": "audio", &"music_volume": "audio", &"sfx_volume": "audio",
	&"fullscreen": "display", &"vsync": "display", &"screen_shake": "display",
	&"locale": "language",
}
const CONTROLS_SECTION := "controls"

## Giá trị đang dùng (bản sao của DEFAULTS, ghi đè bằng file)
var current: SettingsData

var _path: String = DEFAULT_PATH
## Phím gốc của mỗi action đổi được, chụp từ Input Map lúc khởi động (cho "Khôi phục mặc định")
var _default_events: Dictionary[StringName, Array] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action: StringName in DEFAULTS.rebindable_actions:
		if InputMap.has_action(action):
			_default_events[action] = InputMap.action_get_events(action).duplicate()
	load_settings()


## Test đổi sang file riêng để không đụng cài đặt thật của người chơi
func use_config_path(path: String) -> void:
	_path = path
	load_settings()


func get_value(key: StringName) -> Variant:
	return current.get(key)


## Đổi một giá trị: áp dụng ngay, ghi file, báo cho giao diện
func set_value(key: StringName, value: Variant) -> void:
	if not SECTIONS.has(key):
		push_error("Settings: không có mục '%s'" % key)
		return
	current.set(key, _sanitize(key, value))
	_apply(key)
	save_settings()
	changed.emit(key)


func load_settings() -> void:
	current = DEFAULTS.duplicate() as SettingsData
	_restore_default_bindings()
	var config := ConfigFile.new()
	if config.load(_path) == OK:
		for key: StringName in SECTIONS:
			if config.has_section_key(SECTIONS[key], key):
				current.set(key, _sanitize(key, config.get_value(SECTIONS[key], key)))
		for action: StringName in _default_events:
			if config.has_section_key(CONTROLS_SECTION, action):
				_apply_saved_events(action, config.get_value(CONTROLS_SECTION, action))
	for key: StringName in SECTIONS:
		_apply(key)
	bindings_changed.emit()


func save_settings() -> void:
	var config := ConfigFile.new()
	for key: StringName in SECTIONS:
		config.set_value(SECTIONS[key], key, current.get(key))
	for action: StringName in _default_events:
		var saved: Array = []
		for event: InputEvent in InputMap.action_get_events(action):
			var data := _event_to_dict(event)
			if not data.is_empty():
				saved.append(data)
		config.set_value(CONTROLS_SECTION, action, saved)
	var error := config.save(_path)
	if error != OK:
		push_error("Settings: không ghi được %s (lỗi %d)" % [_path, error])


## Phím chính của action (phím hiện trên màn Cài đặt); null nếu action không có phím
func get_primary_event(action: StringName) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventMouseButton:
			return event
	return null


## Đặt phím chính mới cho action. Phím đã thuộc action khác thì hai action đổi phím cho nhau.
## Trả về action bị đổi theo (để giao diện báo), &"" nếu không trùng
func rebind(action: StringName, event: InputEvent) -> StringName:
	var clean := _clean_event(event)
	if clean == null or not _default_events.has(action):
		return &""
	var old_primary := get_primary_event(action)
	var swapped := &""
	for other: StringName in _default_events:
		if other == action:
			continue
		for existing: InputEvent in InputMap.action_get_events(other):
			if _same_input(existing, clean):
				InputMap.action_erase_event(other, existing)
				if old_primary:
					InputMap.action_add_event(other, old_primary.duplicate())
				swapped = other
	_replace_primary(action, clean)
	save_settings()
	bindings_changed.emit()
	return swapped


func reset_bindings() -> void:
	_restore_default_bindings()
	save_settings()
	bindings_changed.emit()


## Tên phím ngắn gọn để hiện (W, Space, Chuột trái...)
func describe_event(event: InputEvent) -> String:
	var key := event as InputEventKey
	if key:
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return OS.get_keycode_string(code)
	var mouse := event as InputEventMouseButton
	if mouse:
		match mouse.button_index:
			MOUSE_BUTTON_LEFT:
				return tr("Chuột trái")
			MOUSE_BUTTON_RIGHT:
				return tr("Chuột phải")
			MOUSE_BUTTON_MIDDLE:
				return tr("Chuột giữa")
		return tr("Chuột %d") % mouse.button_index
	return "?"


func _apply(key: StringName) -> void:
	if AUDIO_BUSES.has(key):
		_apply_volume(AUDIO_BUSES[key], float(current.get(key)))
	elif key == &"fullscreen":
		# Chỉ đổi khi thật sự khác: cửa sổ phóng to / game chạy nhúng trong editor không bị ép về Windowed (editor báo lỗi)
		var mode := DisplayServer.window_get_mode()
		var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if is_full != current.fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if current.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	elif key == &"vsync":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if current.vsync else DisplayServer.VSYNC_DISABLED)
	elif key == &"screen_shake":
		ScreenShake.strength = current.screen_shake
	elif key == &"locale":
		TranslationServer.set_locale(current.locale)


func _apply_volume(bus_name: StringName, linear: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	# 0 thì tắt hẳn bus: linear_to_db(0) = -inf
	AudioServer.set_bus_mute(bus, linear <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(linear, 0.0001)))


## Giá trị đọc từ file / giao diện về đúng kiểu và khoảng, sai thì giữ mặc định
func _sanitize(key: StringName, value: Variant) -> Variant:
	var fallback: Variant = DEFAULTS.get(key)
	match typeof(fallback):
		TYPE_FLOAT:
			if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
				return fallback
			return clampf(float(value), 0.0, 1.0)
		TYPE_BOOL:
			return value if typeof(value) == TYPE_BOOL else fallback
		TYPE_STRING:
			if key == &"locale" and not DEFAULTS.languages.has(str(value)):
				return fallback
			return str(value) if typeof(value) == TYPE_STRING else fallback
	return fallback


func _restore_default_bindings() -> void:
	for action: StringName in _default_events:
		InputMap.action_erase_events(action)
		for event: InputEvent in _default_events[action]:
			InputMap.action_add_event(action, event.duplicate())


func _apply_saved_events(action: StringName, saved: Variant) -> void:
	if typeof(saved) != TYPE_ARRAY:
		return
	var events: Array[InputEvent] = []
	for item: Variant in saved:
		var event := _dict_to_event(item)
		if event:
			events.append(event)
	# Danh sách rỗng / hỏng: giữ phím mặc định để người chơi không mất điều khiển
	if events.is_empty():
		return
	InputMap.action_erase_events(action)
	for event in events:
		InputMap.action_add_event(action, event)


func _replace_primary(action: StringName, event: InputEvent) -> void:
	var events := InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	var replaced := false
	for existing: InputEvent in events:
		var is_primary := not replaced and (existing is InputEventKey or existing is InputEventMouseButton)
		if is_primary:
			replaced = true
			continue
		if not _same_input(existing, event):
			InputMap.action_add_event(action, existing)


## Chỉ giữ phần cần so sánh / lưu: phím vật lý hoặc nút chuột, bỏ trạng thái nhấn và phím bổ trợ
func _clean_event(event: InputEvent) -> InputEvent:
	var key := event as InputEventKey
	if key:
		var clean_key := InputEventKey.new()
		clean_key.physical_keycode = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return clean_key
	var mouse := event as InputEventMouseButton
	if mouse:
		var clean_mouse := InputEventMouseButton.new()
		clean_mouse.button_index = mouse.button_index
		return clean_mouse
	return null


func _same_input(a: InputEvent, b: InputEvent) -> bool:
	var ka := a as InputEventKey
	var kb := b as InputEventKey
	if ka and kb:
		var code_a := ka.physical_keycode if ka.physical_keycode != KEY_NONE else ka.keycode
		var code_b := kb.physical_keycode if kb.physical_keycode != KEY_NONE else kb.keycode
		return code_a == code_b
	var ma := a as InputEventMouseButton
	var mb := b as InputEventMouseButton
	return ma != null and mb != null and ma.button_index == mb.button_index


func _event_to_dict(event: InputEvent) -> Dictionary:
	var key := event as InputEventKey
	if key:
		return {"type": "key", "code": key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode}
	var mouse := event as InputEventMouseButton
	if mouse:
		return {"type": "mouse", "button": mouse.button_index}
	return {}


func _dict_to_event(item: Variant) -> InputEvent:
	if typeof(item) != TYPE_DICTIONARY:
		return null
	var data := item as Dictionary
	var kind: Variant = data.get("type")
	if kind == "key" and typeof(data.get("code")) == TYPE_INT and int(data["code"]) > 0:
		var key := InputEventKey.new()
		key.physical_keycode = int(data["code"]) as Key
		return key
	if kind == "mouse" and typeof(data.get("button")) == TYPE_INT and int(data["button"]) > 0:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = int(data["button"]) as MouseButton
		return mouse
	return null
