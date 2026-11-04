class_name RoofBananaGrunt
extends MonkeyGrunt
@export var excluded_platforms: Array[CollisionObject3D] = []

func get_projectile_exclusions() -> Array[CollisionObject3D]:
	return excluded_platforms

func _ready() -> void:
	super(); gravity = 0; movement.max_speed = 0; external_forces_enabled = false

func disable() -> void:
	set_dormant(true); velocity = Vector3.ZERO; play_anim(&"Idle")
	(get_node("ProjectileEmitter") as EnemyProjectileEmitter).finish_cast()

func set_dormant(dormant: bool) -> void:
	super(dormant)
	set_physics_process(not dormant)
