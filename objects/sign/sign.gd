@tool
class_name Sign
extends Node3D
## Bia đá hướng dẫn: người chơi đi tới gần thì chữ hiện mờ dần phía trên bia, đi xa thì ẩn.
## Theo dõi bằng signal vào/ra vùng, không kiểm tra khoảng cách mỗi frame.
## Trong editor chữ luôn hiện để dễ đặt và đọc lại nội dung.

@export_multiline var text: String = "":
	set(value):
		text = value
		if is_node_ready():
			_label.text = value
## Bán kính quanh bia mà người chơi bước vào thì chữ hiện (mét)
@export var show_radius: float = 4.0:
	set(value):
		show_radius = maxf(value, 0.1)
		if is_node_ready():
			_apply_radius()
@export var fade_time: float = 0.25

var _bodies_inside: int = 0
var _tween: Tween

@onready var _label: Label3D = $Label
@onready var _show_area: Area3D = $ShowArea
@onready var _show_shape: CollisionShape3D = $ShowArea/CollisionShape3D


func _ready() -> void:
	_label.text = text
	_apply_radius()
	if Engine.is_editor_hint():
		return
	_set_label_alpha(0.0)
	_label.visible = false
	_show_area.body_entered.connect(_on_body_entered)
	_show_area.body_exited.connect(_on_body_exited)


func _apply_radius() -> void:
	(_show_shape.shape as SphereShape3D).radius = show_radius


func _on_body_entered(_body: Node3D) -> void:
	_bodies_inside += 1
	if _bodies_inside == 1:
		_fade_to(1.0)


func _on_body_exited(_body: Node3D) -> void:
	_bodies_inside = maxi(_bodies_inside - 1, 0)
	if _bodies_inside == 0:
		_fade_to(0.0)


func _fade_to(alpha: float) -> void:
	if _tween:
		_tween.kill()
	_label.visible = true
	_tween = create_tween()
	_tween.tween_method(_set_label_alpha, _label.modulate.a, alpha, fade_time)
	if alpha <= 0.0:
		# Ẩn hẳn khi mờ hết để không tốn lượt vẽ
		_tween.tween_callback(_label.hide)


func _set_label_alpha(alpha: float) -> void:
	_label.modulate.a = alpha
	_label.outline_modulate.a = alpha
