class_name VortexOnHitEffect
extends FusionEffect
## Đạn của vũ khí trúng đâu thì nở một vật tại đó (hố hút gió...).

## Scene vật nở ra (gốc kế thừa FusionMove)
@export var move_scene: PackedScene
## Sát thương của vật (null = chỉ hút / đẩy, không gây sát thương)
@export var attack: AttackData
@export var flight_scene: PackedScene
@export var vfx_style: FusionWindStyle
@export_range(1, 32) var flight_pool_size: int = 4
@export_range(1, 32) var move_pool_size: int = 4


func prepare_for_combat(user: Player) -> void:
	if flight_scene:
		user.get_fusion_pool(self, flight_scene, flight_pool_size, _configure_flight)
	if move_scene:
		user.get_fusion_pool(self, move_scene, move_pool_size)


func on_projectile_fired(user: Player, projectile: Node3D) -> void:
	if flight_scene == null:
		return
	var pool := user.get_fusion_pool(self, flight_scene, flight_pool_size, _configure_flight)
	var visual := pool.acquire() as WindVortexVfx
	visual.start_flight(projectile)


func get_shader_warmup_sources() -> Array[Node]:
	var sources := super.get_shader_warmup_sources()
	# Pool thật đã có mesh/material và được ShaderWarmup quét trong cây của player.
	return sources


func on_projectile_impact(user: Player, position: Vector3, direction: Vector3) -> void:
	if move_scene == null or not is_instance_valid(user):
		return
	var pool := user.get_fusion_pool(self, move_scene, move_pool_size)
	var move := pool.acquire() as FusionMove
	move.global_position = position
	move.perform(user, attack, direction)


func _configure_flight(node: Node) -> void:
	var visual := node as WindVortexVfx
	visual.flight_mode = true
	if vfx_style:
		visual.style = vfx_style
