class_name HitboxComponent
extends Area3D
## Vùng gây sát thương. Mặc định tắt, state tấn công bật trong active frames của đòn.
## Mỗi lần bật, một hurtbox chỉ bị trúng đúng một lần.
## Hình va chạm là một hộp (BoxShape3D) hướng về +Z của node cha; set_reach() kéo dài về phía trước.

signal hit(hurtbox: HurtboxComponent)

## Độ sâu tối thiểu của hộp (m)
const MIN_DEPTH := 0.1

var attack: AttackData

var _active: bool = false
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


## Tầm đánh (m) tính từ gốc node cha tới mép xa của hộp; mép sau giữ nguyên
func set_reach(reach: float) -> void:
	var box := _shape.shape as BoxShape3D
	if box == null:
		return
	# Hộp không ngắn hơn MIN_DEPTH để vẫn phát hiện được va chạm
	var depth := maxf(reach - _back_edge, MIN_DEPTH)
	box.size.z = depth
	_shape.position.z = _back_edge + depth * 0.5 - position.z


func activate(data: AttackData) -> void:
	attack = data
	_already_hit.clear()
	_active = true
	set_deferred(&"monitoring", true)


func deactivate() -> void:
	_active = false
	set_deferred(&"monitoring", false)


func _on_area_entered(area: Area3D) -> void:
	var hurtbox := area as HurtboxComponent
	if not _active or hurtbox == null or hurtbox in _already_hit:
		return
	_already_hit.append(hurtbox)
	# Đẩy ra xa người đánh; không dùng tâm hitbox vì tâm có thể nằm sau mục tiêu
	var origin := owner as Node3D if owner is Node3D else self
	var direction := hurtbox.global_position - origin.global_position
	direction.y = 0.0
	hurtbox.receive_hit(DamageInfo.new(attack.damage, attack.damage_type, direction.normalized() * attack.knockback, owner))
	hit.emit(hurtbox)
