class_name SliderRow
extends SettingRow
## Dòng thanh trượt 0–100% cho một giá trị 0..1 của Settings (âm lượng, độ rung). Trái / phải để chỉnh.

var key: StringName

var _slider: HSlider
var _value: Label


func _init(setting_key: StringName) -> void:
	key = setting_key


func refresh() -> void:
	_slider.set_value_no_signal(roundf(float(Settings.get_value(key)) * 100.0))
	_value.text = "%d%%" % int(_slider.value)


func _build_control() -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 100.0
	_slider.step = _style.slider_step
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style.apply_slider(_slider)
	_slider.value_changed.connect(_on_value_changed)
	box.add_child(_slider)
	_value = Label.new()
	_value.custom_minimum_size.x = 64
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value.add_theme_font_size_override(&"font_size", _style.row_font)
	_value.add_theme_color_override(&"font_color", _style.ink)
	box.add_child(_value)
	# Dòng nhận focus bằng chính thanh trượt: phím trái / phải chỉnh luôn
	box.focus_mode = Control.FOCUS_NONE
	return box


func get_focus_control() -> Control:
	return _slider


func _on_value_changed(value: float) -> void:
	_value.text = "%d%%" % int(value)
	Settings.set_value(key, value / 100.0)
