class_name MenuScreen
extends Control
## Một màn của menu chính. Hiện: mờ dần vào + trượt lên nhẹ rồi trao focus; ẩn: mờ ra rồi tắt hẳn
## (ẩn thì không nhận chuột / phím). Màn cụ thể kế thừa và phát signal cho state xử lý.

## Nút được chọn sẵn khi màn hiện
@export var default_focus: Control

var _tween: Tween


func _ready() -> void:
	visible = false
	modulate.a = 0.0


func show_screen(data: MainMenuData, focus: Control = null) -> void:
	if _tween:
		_tween.kill()
	visible = true
	position.y = data.screen_slide
	_tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, ^"modulate:a", 1.0, data.screen_fade_time)
	_tween.tween_property(self, ^"position:y", 0.0, data.screen_fade_time)
	var target := focus if focus else default_focus
	if target:
		target.grab_focus.call_deferred()


func hide_screen(data: MainMenuData) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, ^"modulate:a", 0.0, data.screen_fade_time * 0.6)
	_tween.tween_property(self, ^"position:y", -data.screen_slide * 0.5, data.screen_fade_time * 0.6)
	_tween.chain().tween_callback(hide)
