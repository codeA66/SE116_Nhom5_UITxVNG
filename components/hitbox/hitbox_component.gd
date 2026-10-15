class_name HitboxComponent
extends Area3D
## Vùng gây sát thương. Mặc định tắt, state tấn công bật trong active frames của đòn.
## Mỗi lần bật, một hurtbox chỉ bị trúng đúng một lần.

signal hit(hurtbox: HurtboxComponent)

var attack: AttackData

var _active: bool = false
var _already_hit: Array[HurtboxComponent] = []


func _ready() -> void:
	monitorable = false
	monitoring = false
	area_entered.connect(_on_area_entered)


func is_active() -> bool:
	return _active


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
	hurtbox.receive_hit(attack.damage, direction.normalized() * attack.knockback)
	hit.emit(hurtbox)
