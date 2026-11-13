class_name SpiderSkill
extends EnemyState
## Cơ sở cho kỹ năng chủ động của nhện (nhảy vồ, phun tơ...). Thêm kỹ năng mới = thêm node state kế thừa lớp này
## vào StateMachine của FireSpider; SpiderChase tự tìm và dùng, không phải sửa state có sẵn.
## Lớp con ghi đè các hàm _min_range / _max_range / _cooldown_time (số lấy từ FireSpiderData) và can_use nếu cần điều kiện riêng.

## Kỹ năng số nhỏ được xét trước
@export var priority: int = 0

var spider: FireSpider
var _cooldown_left: float = 0.0


func _ready() -> void:
	super()
	spider = owner as FireSpider
	assert(spider != null, "%s chỉ dùng cho FireSpider" % name)


## FireSpider gọi mỗi khung vật lý (số kỹ năng rất ít)
func tick(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)


func can_use() -> bool:
	if _cooldown_left > 0.0 or not enemy.has_target() or not enemy.is_on_floor():
		return false
	var distance: float = enemy.distance_to_target()
	return distance >= _min_range() and distance <= _max_range()


func start_cooldown() -> void:
	_cooldown_left = _cooldown_time()


func _min_range() -> float:
	return 0.0


func _max_range() -> float:
	return INF


func _cooldown_time() -> float:
	return 0.0
