class_name BurnableBarrier
extends StaticBody3D
## Vật cản đốt được (rào gỗ mục, dây leo khô) chắn lối: có va chạm thật; Phun lửa trúng thì bắt lửa,
## cháy hết thời gian trong BurnData thì tan hẳn (ẩn, tắt va chạm, không hồi lại).
## Có persistent_id thì nhớ đã đốt qua lần chơi sau.
## Hiệu năng: chỉ nghe signal của BurnableComponent, không có _process.

signal burned_away

## Cờ lưu trạng thái đã đốt. Để trống = mỗi lần vào khu vật cản lại hiện
@export var persistent_id: StringName
## Thời gian co / chìm hình khi tan (giây)
@export_range(0.05, 3.0, 0.05) var vanish_time: float = 0.6

var is_burned: bool = false

@onready var _burnable: BurnableComponent = $BurnableComponent
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		_remove(true)
		return
	_burnable.extinguished.connect(_on_extinguished)


## Lửa tắt (cháy hết thời gian) thì tan; lửa chỉ tắt sớm khi bị dập từ ngoài, lúc đó cũng coi như đã cháy rụi
func _on_extinguished() -> void:
	if is_burned:
		return
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	_remove(false)


func _remove(instant: bool) -> void:
	is_burned = true
	_burnable.set_enabled(false)
	for child: Node in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred(&"disabled", true)
	if instant:
		visible = false
		return
	var tween: Tween = create_tween()
	tween.tween_property(_visual, ^"scale", Vector3(1.0, 0.05, 1.0), vanish_time).set_ease(Tween.EASE_IN)
	tween.tween_callback(hide)
	burned_away.emit()
