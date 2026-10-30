@tool
class_name HealthSegment
extends Control
## Một đoạn máu kiểu Death's Door: khối bo góc nghiêng, đầy thì xanh sáng, mất thì tối lại.
## Dùng làm HealthBar.segment_scene. Vẽ bằng StyleBoxFlat tạo một lần; chỉ vẽ lại khi đổi trạng thái.

@export var segment_size: Vector2 = Vector2(22.0, 12.0):
	set(value):
		segment_size = value
		custom_minimum_size = value
		queue_redraw()
## Độ nghiêng (theo tỉ lệ chiều cao) để các đoạn trông như vát chéo
@export_range(-1.0, 1.0) var skew: float = -0.35:
	set(value):
		skew = value
		queue_redraw()
@export var corner_radius: int = 4
@export var filled_color := Color(0.6, 0.82, 0.32, 1.0)
## Vệt sáng ở nửa trên đoạn máu
@export var highlight_color := Color(0.82, 0.95, 0.55, 0.55)
@export var empty_color := Color(0.12, 0.14, 0.1, 0.7)
@export var empty_border_color := Color(0.6, 0.82, 0.32, 0.25)
@export_group("Animation")
## Lúc mất máu, đoạn nháy trắng rồi tối dần trong bấy nhiêu giây
@export var transition_time: float = 0.25
@export var flash_color := Color(1.0, 1.0, 1.0, 1.0)

var filled: bool = true

## 0 = rỗng, 1 = đầy; tween qua giá trị này để chuyển màu mượt
var _fill: float = 1.0
var _tween: Tween
var _style := StyleBoxFlat.new()
var _highlight_style := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = segment_size


func set_filled(value: bool, animate: bool = true) -> void:
	if filled == value:
		return
	filled = value
	if _tween:
		_tween.kill()
	var target := 1.0 if filled else 0.0
	if animate and is_inside_tree() and transition_time > 0.0:
		_tween = create_tween()
		_tween.tween_method(_set_fill, _fill, target, transition_time)
	else:
		_set_fill(target)


func _set_fill(value: float) -> void:
	_fill = value
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	_style.skew = Vector2(skew, 0.0)
	_style.set_corner_radius_all(corner_radius)
	_style.anti_aliasing = true
	if filled:
		_style.bg_color = empty_color.lerp(filled_color, _fill)
		_style.set_border_width_all(0)
	else:
		# Đang tối dần: nháy trắng ở đầu chuyển tiếp
		_style.bg_color = empty_color.lerp(flash_color, _fill)
		_style.border_color = empty_border_color
		_style.set_border_width_all(1)
	draw_style_box(_style, rect)
	if filled and _fill > 0.0:
		# Vệt sáng không nghiêng: skew của StyleBoxFlat tính theo chiều cao khung nên khung thấp hơn sẽ lệch;
		# thụt vào thêm đúng phần nghiêng để vệt luôn nằm trong đoạn
		_highlight_style.set_corner_radius_all(corner_radius)
		_highlight_style.anti_aliasing = true
		_highlight_style.bg_color = Color(highlight_color, highlight_color.a * _fill)
		var inset := size.y * 0.2
		var side := inset + absf(skew) * size.y * 0.5
		if size.x - side * 2.0 >= 1.0:
			draw_style_box(_highlight_style, Rect2(Vector2(side, inset), Vector2(size.x - side * 2.0, size.y * 0.3)))
