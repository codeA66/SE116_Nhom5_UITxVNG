class_name TitleScreen
extends MenuScreen
## Màn mở đầu: chỉ có dòng "Nhấn phím bất kỳ" nhấp nháy dưới logo. Nhịp thở chậm, không chớp gắt.

var _period: float = 2.2
var _time: float = 0.0

@onready var _prompt: Label = $Prompt


func setup(data: MainMenuData) -> void:
	_prompt.text = data.press_any_key_text
	_period = data.prompt_blink_period


func show_screen(data: MainMenuData, focus: Control = null) -> void:
	super.show_screen(data, focus)
	_time = 0.0
	set_process(true)


func hide_screen(data: MainMenuData) -> void:
	super.hide_screen(data)
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	# Sin chậm từ 0.25 -> 1: không bao giờ tắt hẳn, người chơi luôn đọc được
	_prompt.modulate.a = 0.25 + 0.75 * (0.5 + 0.5 * cos(TAU * _time / maxf(_period, 0.01)))
