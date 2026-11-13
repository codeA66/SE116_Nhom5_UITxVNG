class_name TrialTimer
extends CanvasLayer
## Đồng hồ đếm ngược của thử thách: chữ mm:ss giữa trên màn hình; dưới warning_time thì đỏ và nháy.
## Chỉ cập nhật khi giây hiển thị đổi (bộ điều khiển gọi set_time), không tự chạy mỗi frame.

@export var style: HudStyle = preload("res://resources/ui/hud_style.tres")
@export var font_size: int = 28
@export var warning_color: Color = Color("#da6553")

var _warning: bool = false
var _blink: Tween

@onready var _panel: PanelContainer = $Panel
@onready var _label: Label = $Panel/Time


func _ready() -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = style.ink
	box.border_color = style.gold
	box.border_width_bottom = 2
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 6
	box.content_margin_bottom = 8
	_panel.theme = style.theme
	_panel.add_theme_stylebox_override("panel", box)
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", style.ivory)
	_panel.hide()


func show_timer() -> void:
	_panel.show()


func hide_timer() -> void:
	_set_warning(false)
	_panel.hide()


func get_text() -> String:
	return _label.text


func is_warning() -> bool:
	return _warning


func set_time(seconds: float, warning_time: float) -> void:
	var whole: int = ceili(maxf(seconds, 0.0))
	_label.text = "%d:%02d" % [whole / 60, whole % 60]
	_set_warning(seconds <= warning_time)


func _set_warning(on: bool) -> void:
	if on == _warning:
		return
	_warning = on
	if _blink:
		_blink.kill()
	_label.modulate = Color.WHITE
	_label.add_theme_color_override("font_color", warning_color if on else style.ivory)
	if on:
		_blink = create_tween().set_loops()
		_blink.tween_property(_label, ^"modulate:a", 0.35, 0.4)
		_blink.tween_property(_label, ^"modulate:a", 1.0, 0.4)
