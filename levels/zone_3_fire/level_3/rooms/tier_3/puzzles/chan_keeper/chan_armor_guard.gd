class_name ChanArmorGuard
extends HitGuard
## Lớp giáp môi trường nhận tín hiệu từ rãnh đồng. Khiên tay vẫn thuộc FSM của lính.

signal armor_broken

@export var armor_indicator: Node3D


func _ready() -> void:
	var hurtbox: GuardedHurtboxComponent = get_parent() as GuardedHurtboxComponent
	hurtbox.guards.push_front(self)


func try_block(_info: DamageInfo) -> bool:
	return enabled


func break_armor() -> void:
	if not enabled:
		return
	enabled = false
	armor_indicator.hide()
	armor_broken.emit()
