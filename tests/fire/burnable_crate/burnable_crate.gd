class_name BurnableCrate
extends StaticBody3D
## Thùng gỗ CHỈ DÙNG ĐỂ TEST: chứng minh BurnableComponent chạy với vật không có máu.
## Bắt lửa -> cháy (thời gian trong crate_burn.tres) -> tan (ẩn, tắt va chạm) -> hồi lại sau respawn_delay.
## Không lưu save, không đưa vào map thật. Vật thật (rào gỗ, dây leo, lò lửa) sẽ làm ở objects/ sau.
## Nhận gió với wind_multiplier = 0: vẫn có tín hiệu gió để lan lửa, nhưng không bị coi là "đang trôi" mãi
## (vật đứng yên không tự giảm lực đẩy, nên nếu nhận lực thì sẽ tự lan lửa cả lúc không có gió).

## Thời gian từ lúc tan tới lúc hồi lại (s)
@export var respawn_delay: float = 3.0

var _present: bool = true
var _respawn_left: float = 0.0

@onready var _burnable: BurnableComponent = $BurnableComponent
@onready var _wind_receiver: WindReceiverComponent = $WindReceiverComponent


## Nghe lửa tắt để tan; mặc định không xử lý gì mỗi frame
func _ready() -> void:
	_burnable.extinguished.connect(_on_extinguished)
	set_physics_process(false)


## Chỉ chạy lúc đang tan: đếm ngược tới lúc hồi lại
func _physics_process(delta: float) -> void:
	_respawn_left -= delta
	if _respawn_left <= 0.0:
		_set_present(true)


## Đúng khi thùng đang hiện (chưa tan)
func is_present() -> bool:
	return _present


## Lửa tắt (hết thời gian cháy) -> tan, bắt đầu đếm hồi lại
func _on_extinguished() -> void:
	if not _present:
		return
	_set_present(false)
	_respawn_left = respawn_delay
	set_physics_process(true)


## Hiện / tan: bật tắt hình, va chạm của thân, vùng nhận lửa và nhận gió (tan rồi thì không bắt lửa, không chặn đường)
func _set_present(present: bool) -> void:
	_present = present
	visible = present
	for child: Node in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred(&"disabled", not present)
	_burnable.set_enabled(present)
	_wind_receiver.enabled = present
	if present:
		set_physics_process(false)
