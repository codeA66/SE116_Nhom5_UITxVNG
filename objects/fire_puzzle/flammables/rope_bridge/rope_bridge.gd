class_name RopeBridge
extends Flammable
## Cầu treo gỗ bắc qua hố: đi được; cháy rụi thì sập (mất va chạm, ván rơi xuống hố) và mất đường qua.
## Không có persistent_id nên FlammableReset dựng lại khi player rời phòng.

## Ván rơi bao xa (m) và trong bao lâu khi sập
@export var fall_distance: float = 6.0
@export_range(0.1, 3.0, 0.05) var fall_time: float = 0.9

var _visual_home: Vector3


func _ready() -> void:
	super()
	_visual_home = _visual.position


func _on_burned_out() -> void:
	burnable.set_enabled(false)
	for child: Node in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred(&"disabled", true)
	_tween = create_tween().set_parallel()
	_tween.tween_property(_visual, ^"position:y", _visual_home.y - fall_distance, fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_visual, ^"rotation:x", 0.6, fall_time)
	_tween.chain().tween_callback(hide)


func _on_reset() -> void:
	_visual.position = _visual_home
	_visual.rotation = Vector3.ZERO
