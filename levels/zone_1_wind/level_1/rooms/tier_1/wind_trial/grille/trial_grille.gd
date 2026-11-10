extends StaticBody3D
## Hai cánh dùng cùng một tween. Chỉ nhả va chạm khi lối đã mở hoàn toàn.

@export var starts_open: bool = false

const TRAVEL := 2.1
const SLIDE_TIME := 0.42

var is_open: bool = false
var _slide: Tween

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _left: Node3D = $Left
@onready var _right: Node3D = $Right
@onready var _closed_left: float = _left.position.x
@onready var _closed_right: float = _right.position.x


func _ready() -> void:
	set_open(starts_open, false)


func set_open(open: bool, animated: bool = true) -> void:
	if animated and open == is_open:
		return
	is_open = open
	if _slide and _slide.is_running():
		_slide.kill()
	var left_x := _closed_left - TRAVEL if open else _closed_left
	var right_x := _closed_right + TRAVEL if open else _closed_right
	if not animated:
		_left.position.x = left_x
		_right.position.x = right_x
		_shape.set_deferred(&"disabled", open)
		return
	if not open:
		_shape.set_deferred(&"disabled", false)
	_slide = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_slide.tween_property(_left, "position:x", left_x, SLIDE_TIME)
	_slide.tween_property(_right, "position:x", right_x, SLIDE_TIME)
	if open:
		_slide.finished.connect(func() -> void: _shape.set_deferred(&"disabled", true))
