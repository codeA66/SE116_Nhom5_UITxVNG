class_name DevMenu
extends CanvasLayer
## Bảng dev (F1): dựng nút theo danh sách cheat của DevConsole, gom theo nhóm. Giao diện mặc định của Godot cho gọn.
## Dòng "DEV: không lưu" hiện cả khi bảng đóng, để luôn biết phiên này không ghi save.

var _console: DevConsole
var _rows: Dictionary[DevCheat, Control] = {}

@onready var _panel: Control = $Panel
@onready var _list: VBoxContainer = $Panel/Scroll/List
@onready var _save_warning: Label = $SaveWarning


func _ready() -> void:
	_panel.hide()
	_save_warning.hide()


func setup(console: DevConsole) -> void:
	_console = console
	_console.cheats_changed.connect(_refresh)
	_build()
	_refresh()


## visible của bảng = visible của Panel (CanvasLayer luôn hiện để giữ dòng cảnh báo)
func is_open() -> bool:
	return _panel.visible


func open() -> void:
	_refresh_choices()
	_panel.show()


func close() -> void:
	_panel.hide()


func _build() -> void:
	var group := ""
	for cheat in _console.cheats:
		if cheat.group != group:
			group = cheat.group
			var header := Label.new()
			header.text = group
			header.add_theme_font_size_override(&"font_size", 18)
			_list.add_child(header)
		var row := _make_row(cheat)
		_list.add_child(row)
		_rows[cheat] = row


func _make_row(cheat: DevCheat) -> Control:
	match cheat.kind:
		DevCheat.Kind.TOGGLE:
			var check := CheckButton.new()
			check.text = cheat.title
			check.toggled.connect(func(on: bool) -> void: _console.set_enabled(cheat, on))
			return check
		DevCheat.Kind.SLIDER:
			var box := HBoxContainer.new()
			var label := Label.new()
			label.custom_minimum_size.x = 160.0
			box.add_child(label)
			var slider := HSlider.new()
			slider.min_value = cheat.min_value
			slider.max_value = cheat.max_value
			slider.step = cheat.step
			slider.value = cheat.value
			slider.custom_minimum_size.x = 200.0
			slider.value_changed.connect(func(v: float) -> void: _console.set_value(cheat, v))
			box.add_child(slider)
			return box
		DevCheat.Kind.CHOICE:
			var box := HBoxContainer.new()
			var options := OptionButton.new()
			options.custom_minimum_size.x = 300.0
			box.add_child(options)
			var go := Button.new()
			go.text = cheat.title
			go.pressed.connect(func() -> void:
				if options.selected >= 0:
					_console.choose(cheat, options.selected))
			box.add_child(go)
			return box
		_:
			var button := Button.new()
			button.text = cheat.title
			button.pressed.connect(func() -> void: _console.run(cheat))
			return button


func _refresh() -> void:
	_save_warning.visible = SaveManager.is_saving_blocked()
	for cheat: DevCheat in _rows:
		var row := _rows[cheat]
		match cheat.kind:
			DevCheat.Kind.TOGGLE:
				(row as CheckButton).set_pressed_no_signal(cheat.enabled)
			DevCheat.Kind.SLIDER:
				(row.get_child(0) as Label).text = "%s: x%.2f" % [cheat.title, cheat.value]


## Danh sách chọn (checkpoint của khu đang đứng) đổi theo khu: dựng lại mỗi lần mở bảng
func _refresh_choices() -> void:
	for cheat: DevCheat in _rows:
		if cheat.kind != DevCheat.Kind.CHOICE:
			continue
		var options := _rows[cheat].get_child(0) as OptionButton
		options.clear()
		for choice in cheat.get_choices(_console):
			options.add_item(choice)
