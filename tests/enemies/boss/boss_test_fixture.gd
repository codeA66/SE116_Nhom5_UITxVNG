extends Node3D
## Dựng boss và mục tiêu thật, không chỉnh biến private của combat component.

const BOSS_PATH: String = "res://entities/bosses/boss_1/boss_1.tscn"


func spawn_boss(maximum_health: int = 50, multiplier: int = 2) -> Boss1:
	var boss: Boss1 = (load(BOSS_PATH) as PackedScene).instantiate() as Boss1
	boss.data = boss.data.duplicate() as BossData
	boss.data.max_health = maximum_health
	boss.data.damage_multiplier_phase3 = multiplier
	(boss.get_node("ChargeController") as BossChargeController).enabled = false
	for property: StringName in [&"phase2_grunt_count", &"phase2_shield_count", &"phase2_caster_count", &"phase3_grunt_count", &"phase3_shield_count", &"phase3_caster_count"]:
		(boss.get_node("Minions") as BossMinionController).set(property, 0)
	add_child(boss)
	boss.set_physics_process(false)
	return boss


func spawn_target(at: Vector3, invincibility: float = 0.6) -> CharacterBody3D:
	var body: CharacterBody3D = CharacterBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 0
	var health: HealthComponent = HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = 100
	body.add_child(health)
	var hurtbox: HurtboxComponent = HurtboxComponent.new()
	hurtbox.name = "HurtboxComponent"
	hurtbox.health = health
	hurtbox.invincibility_time = invincibility
	hurtbox.collision_layer = 2
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.35
	shape.shape = sphere
	shape.position.y = 0.9
	hurtbox.add_child(shape)
	body.add_child(hurtbox)
	add_child(body)
	health.owner = body
	hurtbox.owner = body
	body.position = at
	return body


func spawn_box(size: Vector3, at: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.position = at
	return body
