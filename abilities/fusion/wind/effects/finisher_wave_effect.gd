class_name FinisherWaveEffect
extends FusionEffect
## Nhát cuối của combo phóng thêm một vật (lưỡi liềm gió...) bay theo hướng chém. Thưởng cho người đánh trọn combo.

## Scene vật phóng ra (gốc kế thừa FusionMove)
@export var move_scene: PackedScene
## Sát thương / đẩy lùi của vật phóng ra
@export var attack: AttackData
## Nhát nào trong combo thì phóng: < 0 = nhát cuối
@export var combo_index: int = -1


func on_melee_active(user: Player, _attack: AttackData, index: int, combo_size: int, direction: Vector3, _active_time: float) -> void:
	var wanted := combo_size - 1 if combo_index < 0 else combo_index
	if index != wanted or move_scene == null:
		return
	var move := move_scene.instantiate() as FusionMove
	# Vật sống trong thế giới, không đi theo người chém
	user.get_parent().add_child(move)
	move.perform(user, attack, direction)
