class_name BoulderVolley
extends Node3D
## Một lượt ném tái sử dụng toàn bộ đá, cảnh báo, hitbox và bụi; quét cả quãng bay.

signal finished(volley: BoulderVolley)
signal main_impacted(at: Vector3)
signal shard_impacted(index: int, at: Vector3)
const INDICATOR: PackedScene = preload("res://objects/combat/indicators/aoe_circle_indicator.tscn")
const MAX_SHARDS: int = 12
var phase: int = 0
var age: float = 0.0
var destination: Vector3
var _origin: Vector3
var _skill: BoulderThrowSkillData
var _source: WeakRef
var _rock: MeshInstance3D
var _indicator: AoeCircleIndicator
var _hitbox: HitboxComponent
var _dust: CPUParticles3D
var _shards: Array[Dictionary] = []
var _terrain: ShapeCast3D
var _damage: ShapeCast3D
var _sphere: SphereShape3D
var _flight_hits: Array[HurtboxComponent] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
static var _stone_mesh: ArrayMesh
static var _stone_material: StandardMaterial3D

static func stone() -> MeshInstance3D:
	if _stone_mesh == null:
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 9
		sphere.rings = 4
		var source: Array = sphere.get_mesh_arrays()
		var points: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for triangle: int in int(indices.size() / 3):
			var vertices: Array[Vector3] = []
			for corner: int in 3:
				var at: Vector3 = points[indices[triangle * 3 + corner]]
				var uneven: float = 0.9 + sin(at.x * 7.0 + at.z * 4.0 + at.y * 3.0) * 0.07
				vertices.append(at * uneven)
			var normal: Vector3 = (vertices[1] - vertices[0]).cross(vertices[2] - vertices[0]).normalized()
			if normal.dot(vertices[0] + vertices[1] + vertices[2]) < 0.0: normal = -normal
			for at: Vector3 in vertices:
				surface.set_normal(normal)
				surface.add_vertex(at)
		_stone_mesh = surface.commit()
		_stone_material = StandardMaterial3D.new()
		_stone_material.albedo_color = Color("76503a")
		_stone_material.roughness = 1.0
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = _stone_mesh
	mesh.material_override = _stone_material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh

func _ready() -> void:
	top_level = true
	_rng.randomize()
	_rock = stone()
	add_child(_rock)
	_indicator = INDICATOR.instantiate() as AoeCircleIndicator
	add_child(_indicator)
	_hitbox = _make_hitbox()
	_dust = _make_dust(30)
	_sphere = SphereShape3D.new()
	_terrain = ShapeCast3D.new()
	_terrain.shape = _sphere
	_terrain.collision_mask = 257
	_terrain.collide_with_areas = false
	_terrain.enabled = false
	add_child(_terrain)
	_damage = ShapeCast3D.new()
	_damage.shape = _sphere
	_damage.collision_mask = 2
	_damage.collide_with_areas = true
	_damage.collide_with_bodies = false
	_damage.max_results = 8
	_damage.enabled = false
	add_child(_damage)
	for index: int in MAX_SHARDS:
		var mesh: MeshInstance3D = stone()
		add_child(mesh)
		var indicator: AoeCircleIndicator = INDICATOR.instantiate() as AoeCircleIndicator
		add_child(indicator)
		_shards.append({"mesh": mesh, "indicator": indicator, "hitbox": _make_hitbox(), "dust": _make_dust(12), "origin": Vector3.ZERO, "target": Vector3.ZERO, "time": 1.0, "landed": false, "hits": []})
	pool_released()

func prepare(skill: BoulderThrowSkillData, at: Vector3, source: WildEnemy) -> void:
	_skill = skill
	_source = weakref(source)
	global_transform = Transform3D.IDENTITY
	destination = at
	phase = 1
	age = 0.0
	visible = true
	_indicator.show_indicator(at, skill.impact_radius, skill.release_time + skill.flight_time)
	set_physics_process(false)

func aim(at: Vector3) -> void:
	if phase != 1: return
	destination = at
	_indicator.global_position = at + Vector3.UP * 0.025

func launch(at: Vector3) -> void:
	_origin = at
	age = 0.0
	phase = 2
	_flight_hits.clear()
	_rock.visible = true
	_rock.global_position = at
	_rock.scale = Vector3.ONE * _skill.rock_radius
	set_physics_process(true)

func pool_released() -> void:
	phase = 0
	visible = false
	set_physics_process(false)
	if _indicator == null: return
	_indicator.hide_indicator()
	_rock.hide()
	_hitbox.deactivate()
	_dust.emitting = false
	for shard: Dictionary in _shards:
		(shard.mesh as MeshInstance3D).hide()
		(shard.indicator as AoeCircleIndicator).hide_indicator()
		(shard.hitbox as HitboxComponent).deactivate()
		(shard.dust as CPUParticles3D).emitting = false

func _physics_process(delta: float) -> void:
	age += delta
	if phase == 2:
		var progress: float = minf(age / maxf(_skill.flight_time, 0.1), 1.0)
		var next: Vector3 = _arc(_origin, destination + Vector3.UP * _skill.rock_radius, progress, _skill.arc_height)
		var collision: Dictionary = _sweep(_rock.global_position, next, _skill.rock_radius, _flight_hits)
		_rock.global_position = next
		_rock.rotate_x(delta * 3.0)
		_rock.rotate_z(delta * 1.7)
		if not collision.is_empty() or progress >= 1.0:
			_impact_main(destination if collision.is_empty() else _ground(collision.point))
	elif phase == 3:
		for index: int in mini(_skill.shard_count, MAX_SHARDS):
			var shard: Dictionary = _shards[index]
			if shard.landed:
				var hitbox: HitboxComponent = shard.hitbox
				if hitbox.is_active() and age - float(shard.landed_at) > 0.16: hitbox.deactivate()
				continue
			var mesh: MeshInstance3D = shard.mesh
			var t: float = minf(age / float(shard.time), 1.0)
			var at: Vector3 = _arc(shard.origin, shard.target + Vector3.UP * _skill.shard_radius * 0.45, t, _skill.shard_arc_height)
			var collision: Dictionary = _sweep(mesh.global_position, at, _skill.shard_radius * 0.45, shard.hits)
			mesh.global_position = at
			mesh.rotate_x(delta * (4.0 + index))
			if t >= 1.0 or not collision.is_empty():
				var impact: Vector3 = shard.target if collision.is_empty() else _ground(collision.point)
				shard.landed = true
				shard.landed_at = age
				mesh.hide()
				(shard.indicator as AoeCircleIndicator).hide_indicator()
				_activate_ground(shard.hitbox, impact, _skill.shard_radius)
				_burst(shard.dust, impact, 0.5)
				shard_impacted.emit(index, impact)
		if age > 0.16 and _hitbox.is_active(): _hitbox.deactivate()
		if age >= _skill.shard_flight_time * 1.2 + 1.0:
			pool_released()
			finished.emit(self)

func _impact_main(at: Vector3) -> void:
	phase = 3
	age = 0.0
	destination = at
	_rock.hide()
	_indicator.hide_indicator()
	_activate_ground(_hitbox, at, _skill.impact_radius)
	_burst(_dust, at, 1.0)
	for index: int in mini(_skill.shard_count, MAX_SHARDS):
		var shard: Dictionary = _shards[index]
		var angle: float = (float(index) + _rng.randf_range(-0.25, 0.25)) * TAU / maxi(_skill.shard_count, 1)
		var minimum: float = maxf(_skill.shard_ring_min, _skill.impact_radius + _skill.shard_radius + 0.3)
		var radius: float = _rng.randf_range(minimum, maxf(minimum, _skill.shard_ring_max))
		shard.origin = at + Vector3.UP * 0.5
		shard.target = _ground(at + Vector3(cos(angle), 0, sin(angle)) * radius)
		shard.time = maxf(_skill.shard_flight_time, 0.1) * _rng.randf_range(0.88, 1.12)
		shard.landed = false
		(shard.hits as Array).clear()
		var mesh: MeshInstance3D = shard.mesh
		mesh.global_position = shard.origin
		mesh.scale = Vector3(0.8, 1.2, 0.9) * _skill.shard_radius * 0.45
		mesh.show()
		(shard.indicator as AoeCircleIndicator).show_indicator(shard.target, _skill.shard_radius, shard.time)
	main_impacted.emit(at)
	ScreenShake.add_trauma(0.15)

func _sweep(from: Vector3, to: Vector3, radius: float, hits: Array) -> Dictionary:
	_sphere.radius = maxf(radius, 0.05)
	_damage.global_position = from
	_damage.target_position = to - from
	_damage.force_shapecast_update()
	for index: int in _damage.get_collision_count():
		var hurtbox: HurtboxComponent = _damage.get_collider(index) as HurtboxComponent
		if hurtbox == null or hurtbox in hits: continue
		hits.append(hurtbox)
		var direction: Vector3 = (to - from).normalized()
		var info: DamageInfo = DamageInfo.new(_skill.damage, _skill.damage_type, direction * _skill.knockback, _source.get_ref())
		info.direction = direction
		info.attack = _skill
		hurtbox.receive_hit(info)
	_terrain.global_position = from
	_terrain.target_position = to - from
	_terrain.force_shapecast_update()
	if _terrain.is_colliding(): return {"point": _terrain.get_collision_point(0)}
	return {}

func _ground(at: Vector3) -> Vector3:
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4, at - Vector3.UP * 15, 257))
	return result.position if not result.is_empty() else at

func _arc(from: Vector3, to: Vector3, t: float, height: float) -> Vector3:
	return from.lerp(to, t) + Vector3.UP * height * 4.0 * t * (1.0 - t)

func _make_hitbox() -> HitboxComponent:
	var hitbox: HitboxComponent = HitboxComponent.new()
	hitbox.collision_layer = 16
	hitbox.collision_mask = 2
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.shape = CylinderShape3D.new()
	hitbox.add_child(shape)
	add_child(hitbox)
	hitbox.owner = self
	return hitbox

func _activate_ground(hitbox: HitboxComponent, at: Vector3, radius: float) -> void:
	var shape: CylinderShape3D = (hitbox.get_node("CollisionShape3D") as CollisionShape3D).shape as CylinderShape3D
	shape.radius = maxf(radius, 0.05)
	shape.height = 2.0
	hitbox.global_position = at + Vector3.UP
	hitbox.activate(_skill, 0.16)

func _make_dust(amount: int) -> CPUParticles3D:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.amount = amount
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.8
	particles.direction = Vector3.UP
	particles.spread = 65.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 5.0
	particles.gravity = Vector3.DOWN * 12.0
	particles.scale_amount_min = 0.035
	particles.scale_amount_max = 0.14
	particles.mesh = _stone_mesh
	particles.material_override = _stone_material
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = false
	add_child(particles)
	return particles

func _burst(particles: CPUParticles3D, at: Vector3, size: float) -> void:
	particles.global_position = at + Vector3.UP * 0.08
	particles.scale = Vector3.ONE * size
	particles.restart()
	particles.emitting = true
