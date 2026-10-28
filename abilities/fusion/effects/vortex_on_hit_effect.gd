class_name VortexOnHitEffect
extends FusionEffect
## Đạn của vũ khí trúng đâu thì nở một vật tại đó (hố hút gió...).

## Scene vật nở ra (gốc kế thừa FusionMove)
@export var move_scene: PackedScene
## Sát thương của vật (null = chỉ hút / đẩy, không gây sát thương)
@export var attack: AttackData
@export var flight_scene: PackedScene
@export var vfx_style: FusionWindStyle


func on_projectile_fired(user: Player, projectile: Node3D) -> void:
	if flight_scene == null:
		return
	var visual := flight_scene.instantiate() as WindVortexVfx
	visual.flight_mode = true
	user.get_parent().add_child(visual)
	visual.start_flight(projectile)


func get_shader_warmup_sources() -> Array[Node]:
	var sources := super.get_shader_warmup_sources()
	if move_scene:
		sources.append(move_scene.instantiate())
	if flight_scene:
		var flight := flight_scene.instantiate() as WindVortexVfx
		flight.flight_mode = true
		sources.append(flight)
	return sources


func on_projectile_impact(user: Player, position: Vector3, direction: Vector3) -> void:
	if move_scene == null or not is_instance_valid(user):
		return
	var move := move_scene.instantiate() as FusionMove
	user.get_parent().add_child(move)
	move.global_position = position
	move.perform(user, attack, direction)
