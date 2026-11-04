class_name ExplosiveBanana
extends Node3D
@export var blast_radius: float = 3.0
var _direction: Vector3
var _source: Player
var _age: float=0
var _sweep: ShapeCast3D
var _visual: MeshInstance3D
func _ready() -> void:
	_visual=MeshInstance3D.new(); _visual.mesh=BananaGeometry.fruit(); var mat: StandardMaterial3D=StandardMaterial3D.new(); mat.albedo_color=Color(1,0.02,0.01); mat.emission_enabled=true; mat.emission=Color(1,0.02,0.01); _visual.material_override=mat; add_child(_visual)
	_sweep=ShapeCast3D.new(); var shape: SphereShape3D=SphereShape3D.new(); shape.radius=0.25; _sweep.shape=shape; _sweep.collision_mask=261; _sweep.collide_with_areas=true; _sweep.enabled=false; add_child(_sweep)
func launch(at: Vector3, direction: Vector3, source: Player) -> void:
	global_position=at; _direction=direction; _source=source
func _physics_process(delta: float) -> void:
	_age+=delta; _visual.rotate_z(delta*16); _sweep.target_position=_direction*14*delta; _sweep.force_shapecast_update()
	if _sweep.is_colliding() or _age>4: _explode(); return
	global_position+=_direction*14*delta
func _explode() -> void:
	GardenCombatEffects.explosion(get_parent() as Node3D,global_position,blast_radius)
	var shape: SphereShape3D=SphereShape3D.new(); shape.radius=blast_radius
	var query: PhysicsShapeQueryParameters3D=PhysicsShapeQueryParameters3D.new(); query.shape=shape; query.transform=global_transform; query.collision_mask=6; query.collide_with_bodies=false; query.collide_with_areas=true
	for result: Dictionary in get_world_3d().direct_space_state.intersect_shape(query):
		var hurt: HurtboxComponent=result.collider as HurtboxComponent
		if hurt==null: continue
		var actor: CharacterBody3D=hurt.get_parent() as CharacterBody3D
		if actor==null: continue
		var direction: Vector3=actor.global_position-global_position; direction.y=0; direction=direction.normalized()
		hurt.receive_hit(DamageInfo.new(2,DamageInfo.Type.PHYSICAL,Vector3.ZERO,_source))
		ForcedImpulse.push(actor,direction*7)
	queue_free()
