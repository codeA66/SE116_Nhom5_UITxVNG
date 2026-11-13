class_name MenuLogo
extends Control
## Logo đổi tỷ lệ giữa màn tiêu đề và menu để nhường chỗ cho các nút.

enum Layout { TITLE, HOME, HIDDEN }

## Tâm logo theo tỉ lệ chiều cao màn
@export_range(0.0, 1.0, 0.01) var title_center_y: float = 0.4
@export_range(0.0, 1.0, 0.01) var home_center_y: float = 0.26
@export_range(0.1, 2.0, 0.01) var home_scale: float = 0.72
## Lần đầu hiện: nét kẻ mở từ giữa ra (s)
@export_range(0.0, 4.0, 0.05) var reveal_time: float = 1.2

var _tween: Tween

@onready var _title: Label = $Title
@onready var _divider: OrnamentDivider = $Divider


func set_text(value: String) -> void:
	_title.text = value


func play_reveal() -> void:
	_title.modulate.a = 0.0
	_divider.reveal = 0.0
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_title, ^"modulate:a", 1.0, reveal_time)
	tween.parallel().tween_property(_divider, ^"reveal", 1.0, reveal_time * 1.2)


func set_layout(layout: Layout, duration: float) -> void:
	pivot_offset = size * 0.5
	var view_height := get_viewport_rect().size.y
	var target_y := 0.0
	var target_scale := 1.0
	var target_alpha := 1.0
	match layout:
		Layout.TITLE:
			target_y = view_height * title_center_y
		Layout.HOME:
			target_y = view_height * home_center_y
			target_scale = home_scale
		Layout.HIDDEN:
			target_y = view_height * home_center_y
			target_scale = home_scale
			target_alpha = 0.0
	var top := target_y - size.y * 0.5
	if _tween:
		_tween.kill()
	if duration <= 0.0:
		position.y = top
		scale = Vector2.ONE * target_scale
		modulate.a = target_alpha
		return
	_tween = create_tween().set_parallel().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, ^"position:y", top, duration)
	_tween.tween_property(self, ^"scale", Vector2.ONE * target_scale, duration)
	_tween.tween_property(self, ^"modulate:a", target_alpha, duration * 0.6)
