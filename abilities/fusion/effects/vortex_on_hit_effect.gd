class_name VortexOnHitEffect
extends FusionEffect
## Đạn của vũ khí trúng đâu thì nở một vật tại đó (hố hút gió...).

## Scene vật nở ra (gốc kế thừa FusionMove)
@export var move_scene: PackedScene
## Sát thương của vật (null = chỉ hút / đẩy, không gây sát thương)
@export var attack: AttackData


func on_projectile_impact(user: Player, position: Vector3, direction: Vector3) -> void:
	if move_scene == null or not is_instance_valid(user):
		return
	var move := move_scene.instantiate() as FusionMove
	user.get_parent().add_child(move)
	move.global_position = position
	move.perform(user, attack, direction)
