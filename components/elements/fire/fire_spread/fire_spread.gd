class_name FireSpread
extends Node3D
## Luồng lửa phụt ra theo hướng gió từ một mục tiêu đang cháy (BurnableComponent gọi spread()).
## Bên trong là một IgniterArea tự đứng: bật trong active_time rồi tắt; chỉ làm cháy, không gây sát thương ngay.
## Mỗi thực thể có sẵn một node này, lúc nghỉ tắt hẳn (không quét va chạm, không xử lý) nên không cần pool.
## top_level: đặt theo toạ độ thế giới, không xoay theo model của thực thể.

## Phát khi luồng lửa bật (VFX / âm thanh nghe); direction = hướng gió, đã chuẩn hoá trên mặt phẳng ngang
signal fired(direction: Vector3)

@export var data: FireSpreadData

var _remaining: float = 0.0

@onready var _igniter: IgniterArea = $Igniter
@onready var _shape: CollisionShape3D = $Igniter/CollisionShape3D


## Tách khỏi transform của cha, tắt xử lý; không đốt chính thực thể chứa luồng lửa này
func _ready() -> void:
	top_level = true
	set_physics_process(false)
	# Owner của Igniter là gốc scene FireSpread; thực thể thật là owner của FireSpread (quái, hình nộm...)
	if owner:
		_igniter.exclude_root = owner


## Đếm ngược thời gian bật, hết thì tắt vùng và tắt xử lý
func _physics_process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		_igniter.deactivate()
		set_physics_process(false)


## Đúng khi luồng lửa đang bật
func is_active() -> bool:
	return _remaining > 0.0


## Thời gian chờ giữa hai lần phụt của cùng một mục tiêu (BurnableComponent dùng)
func get_cooldown() -> float:
	return data.spread_cooldown if data else 0.0


## Đúng khi mục tiêu vừa bắt lửa trong lúc còn trôi vì gió được phép phụt tiếp
func chains_while_pushed() -> bool:
	return data != null and data.chain_while_pushed


## Phụt lửa từ origin (chân mục tiêu) kéo dài theo direction; co giãn vùng theo dữ liệu rồi bật.
## source: người châm lửa ban đầu, truyền tiếp cho mục tiêu bị lan
func spread(origin: Vector3, direction: Vector3, source: Node = null) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if data == null or flat.is_zero_approx():
		return
	flat = flat.normalized()
	# +Z của node hướng theo gió: vùng trải từ tâm mục tiêu về phía xuôi gió
	global_transform = Transform3D(Basis.looking_at(-flat, Vector3.UP), origin)
	var box := _shape.shape as BoxShape3D
	box.size = Vector3(data.width, data.height, data.length)
	_shape.position = Vector3(0.0, data.height * 0.5, data.length * 0.5)
	_remaining = data.active_time
	_igniter.ignite_source = source
	_igniter.activate()
	set_physics_process(true)
	fired.emit(flat)
