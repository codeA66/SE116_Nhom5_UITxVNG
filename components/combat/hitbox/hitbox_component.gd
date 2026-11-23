class_name HitboxComponent
extends Area3D
## Vùng gây sát thương. Mặc định tắt, state tấn công bật trong active frames của đòn.
## Mỗi lần bật, một hurtbox chỉ bị trúng đúng một lần.
## Hình va chạm là một hộp (BoxShape3D) hướng về +Z của node cha; set_reach() kéo dài về phía trước.

signal hit(hurtbox: HurtboxComponent)
## Chỉ phát khi receive_hit chấp nhận đòn, sau khi sát thương và i-frame đã áp dụng.
signal hit_applied(hurtbox: HurtboxComponent)
## Phát khi hitbox bật: vệt chém, âm thanh... bắt đầu theo đòn mà không cần state biết
signal activated(attack: AttackData)
## Phát khi hitbox tắt (hết active frames hoặc bị ngắt giữa chừng): thứ đi kèm đòn (vùng gây cháy...) tắt theo
signal deactivated
## Phát khi đòn bị hủy giữa chừng (dash, kỹ năng): VFX của nhát đó tắt nhanh thay vì chờ mờ hết
signal cancelled

## Độ sâu tối thiểu của hộp (m)
const MIN_DEPTH := 0.1

var attack: AttackData

var _active: bool = false
## Độ dài khoảng bật của lần activate gần nhất (s); -1 nếu state không báo
var _active_duration: float = -1.0
var _already_hit: Array[HurtboxComponent] = []
## Mép sau của hộp (tính theo node cha): giữ cố định để đánh sát người vẫn trúng
var _back_edge: float = 0.0

@onready var _shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	monitorable = false
	monitoring = false
	area_entered.connect(_on_area_entered)
	var box := _shape.shape as BoxShape3D
	if box:
		_back_edge = position.z + _shape.position.z - box.size.z * 0.5


func is_active() -> bool:
	return _active


func get_active_duration() -> float:
	return _active_duration


## Tầm đánh hiện tại (m) tính từ gốc node cha tới mép xa của hộp
func get_reach() -> float:
	var box := _shape.shape as BoxShape3D
	return _back_edge + box.size.z if box else 0.0


## Tầm đánh (m) tính từ gốc node cha tới mép xa của hộp; mép sau giữ nguyên
func set_reach(reach: float) -> void:
	var box := _shape.shape as BoxShape3D
	if box == null:
		return
	# Hộp không ngắn hơn MIN_DEPTH để vẫn phát hiện được va chạm
	var depth := maxf(reach - _back_edge, MIN_DEPTH)
	box.size.z = depth
	_shape.position.z = _back_edge + depth * 0.5 - position.z


## Bề ngang và chiều cao hộp (m), giữ nguyên tâm; dùng cho chiêu có vùng đánh chỉnh theo dữ liệu (luồng lửa...)
func set_cross_section(width: float, height: float) -> void:
	var box := _shape.shape as BoxShape3D
	if box == null:
		return
	box.size.x = maxf(width, MIN_DEPTH)
	box.size.y = maxf(height, MIN_DEPTH)


## duration: độ dài khoảng bật (s) để VFX/âm thanh khớp nhịp; bỏ trống nếu state không tính
func activate(data: AttackData, duration: float = -1.0) -> void:
	attack = data
	_active_duration = duration
	_already_hit.clear()
	_active = true
	set_deferred(&"monitoring", true)
	activated.emit(data)


func deactivate() -> void:
	_active = false
	set_deferred(&"monitoring", false)
	deactivated.emit()


## Hủy đòn đang diễn: tắt hitbox rồi báo cancelled (khác deactivate thường lúc hết active frames)
func cancel() -> void:
	deactivate()
	cancelled.emit()


func _on_area_entered(area: Area3D) -> void:
	try_hit(area as HurtboxComponent)


## Dùng chung cho Area và sweep; mỗi mục tiêu chỉ được xét một lần mỗi đòn.
func try_hit(hurtbox: HurtboxComponent) -> bool:
	if not _active or attack == null or hurtbox == null or hurtbox in _already_hit:
		return false
	if not _can_hit(hurtbox):
		return false
	_already_hit.append(hurtbox)
	var direction: Vector3 = _get_hit_direction(hurtbox)
	var info := DamageInfo.new(attack.damage, attack.damage_type, direction * attack.knockback, owner)
	info.direction = direction
	info.attack = attack
	info.apply_weapon_damage_bonus(self)
	var accepted: bool = hurtbox.receive_hit(info)
	if accepted:
		hit_applied.emit(hurtbox)
	hit.emit(hurtbox)
	return accepted


func _can_hit(_hurtbox: HurtboxComponent) -> bool:
	return true


func _get_hit_direction(hurtbox: HurtboxComponent) -> Vector3:
	# Đẩy từ người đánh thay vì tâm hitbox vốn có thể đã vượt mục tiêu.
	var origin := owner as Node3D if owner is Node3D else self
	var direction := hurtbox.global_position - origin.global_position
	direction.y = 0.0
	return direction.normalized()
