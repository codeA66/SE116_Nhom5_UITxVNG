class_name TrialSeal
extends StaticBody3D
## Màn lửa chắn cửa trong lúc thử thách (FinalTrial gọi set_closed): đóng thì có va chạm và tấm lửa dựng lên,
## mở thì hạ xuống rồi ẩn, tắt va chạm. Chỉ tween khi đổi trạng thái.

@export var size: Vector2 = Vector2(4.0, 3.2)
@export_range(0.05, 2.0, 0.05) var switch_time: float = 0.35

var is_closed: bool = false

var _tween: Tween

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	(_shape.shape as BoxShape3D).size = Vector3(size.x, size.y, 0.6)
	_shape.position.y = size.y * 0.5
	_visual.scale = Vector3(size.x / 4.0, size.y / 3.2, 1.0)
	set_closed(false, true)


func set_closed(closed: bool, instant: bool = false) -> void:
	is_closed = closed
	_shape.set_deferred(&"disabled", not closed)
	if _tween:
		_tween.kill()
	var full: Vector3 = Vector3(size.x / 4.0, size.y / 3.2, 1.0)
	if instant:
		_visual.visible = closed
		_visual.scale = full
		return
	_visual.visible = true
	_visual.scale = Vector3(full.x, 0.01, 1.0) if closed else full
	_tween = create_tween()
	_tween.tween_property(_visual, ^"scale", full if closed else Vector3(full.x, 0.01, 1.0), switch_time).set_trans(Tween.TRANS_BACK if closed else Tween.TRANS_SINE)
	if not closed:
		_tween.tween_callback(_visual.hide)
