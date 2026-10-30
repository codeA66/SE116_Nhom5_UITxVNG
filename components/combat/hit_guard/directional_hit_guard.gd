class_name DirectionalHitGuard
extends HitGuard
## Khiên theo hướng: chặn đòn tới trong một cung phía trước facing_node.
## Hướng đòn tới lấy từ knockback của DamageInfo (kiếm: từ người đánh tới mục tiêu; tên: hướng bay).

const FULL_ARC_DEGREES := 360.0
## Ngưỡng dot không bao giờ đạt được (dot <= 1): cung 0 không chặn gì
const NEVER_BLOCK := 2.0
## Ngưỡng dot luôn đạt (dot >= -1): cung 360 chặn mọi hướng
const ALWAYS_BLOCK := -2.0

## Node cho biết mặt trước (+Z của node này), thường là Model của quái
@export var facing_node: Node3D
## Độ rộng cung chặn (độ). 0 = không chặn gì, 360 = chặn mọi hướng
@export_range(0.0, 360.0, 1.0) var arc_degrees: float = 120.0:
	set(value):
		arc_degrees = value
		_update_cos_half_arc()
## Chặn cả bẫy môi trường (đòn bỏ qua bất tử). Mặc định không: gai vẫn gây sát thương
@export var blocks_hazards: bool = false

## cos(nửa cung); chặn khi dot(mặt trước, hướng đòn tới) >= giá trị này
var _cos_half_arc: float = 0.5


func _ready() -> void:
	_update_cos_half_arc()


func try_block(info: DamageInfo) -> bool:
	if not enabled or facing_node == null:
		return false
	if info.ignores_invincibility and not blocks_hazards:
		return false
	# Hướng từ khiên tới nguồn đòn = ngược hướng đẩy
	var incoming := -info.knockback
	incoming.y = 0.0
	if incoming.is_zero_approx():
		var source := info.source as Node3D
		if source == null:
			# Không xác định được hướng thì cho trúng
			return false
		incoming = source.global_position - facing_node.global_position
		incoming.y = 0.0
		if incoming.is_zero_approx():
			return false
	var facing := facing_node.global_basis.z
	facing.y = 0.0
	if facing.is_zero_approx():
		return false
	return facing.normalized().dot(incoming.normalized()) >= _cos_half_arc


func _update_cos_half_arc() -> void:
	# Cung 0 / 360 xử lý riêng: so sánh số thực với cos(0) / cos(180) = ±1 dễ lệch ở sai số cuối
	if arc_degrees <= 0.0:
		_cos_half_arc = NEVER_BLOCK
	elif arc_degrees >= FULL_ARC_DEGREES:
		_cos_half_arc = ALWAYS_BLOCK
	else:
		_cos_half_arc = cos(deg_to_rad(arc_degrees * 0.5))
