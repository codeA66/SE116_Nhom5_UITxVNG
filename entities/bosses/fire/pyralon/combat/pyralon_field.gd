class_name PyralonField
extends Node3D
## Quản lý hiệu ứng và lông theo vòng đời trận, kể cả khi chuyển sang chiêu khác.

const WORLD := 1 | 256

@export var feather_scene: PackedScene
@export var fire_fx_scene: PackedScene

var actor: Pyralon
var profile: PyralonData
var _gold: Array[PyralonFeather] = []
var _command_candidates: Array[PyralonFeather] = []
var _feathers: ObjectPool
var _effects: ObjectPool
var _attack := AttackData.new()
var _floor := PhysicsRayQueryParameters3D.new()
var _wall := PhysicsRayQueryParameters3D.new()

@onready var _explosion: ExplosionComponent = $Explosion
@onready var ground: PyralonGroundFire = $GroundFire


func setup(boss: Pyralon) -> void:
	actor = boss
	profile = boss.profile
	_attack.damage = profile.feather_damage
	_attack.damage_type = DamageInfo.Type.FIRE
	_attack.knockback = 0.9
	_explosion.attack = _attack
	_floor.collision_mask = WORLD
	_wall.collision_mask = WORLD
	_feathers = _make_pool(feather_scene, 68)
	_effects = _make_pool(fire_fx_scene, 56)


func new_white(at: Vector3) -> PyralonFeather:
	var feather := _feathers.acquire() as PyralonFeather
	feather.setup(self, actor.target, at, false)
	return feather


func drop_gold(from: Vector3, landing: Vector3) -> void:
	var feather := _feathers.acquire() as PyralonFeather
	feather.setup(self, actor.target, from, true)
	_gold.append(feather)
	feather.drop(from, landing + Vector3.UP * profile.gold_hover_height)


func recycle(feather: PyralonFeather) -> void:
	_gold.erase(feather)
	_feathers.release(feather)


func reserve_gold() -> int:
	var count := 0
	for feather: PyralonFeather in _gold:
		if feather.available_for_command():
			feather.reserve()
			count += 1
	return count


func send_next_gold() -> bool:
	_command_candidates.clear()
	for feather: PyralonFeather in _gold:
		if feather.available_for_command():
			_command_candidates.append(feather)
	if _command_candidates.is_empty():
		return false
	var chosen := _command_candidates[randi() % _command_candidates.size()]
	chosen.chase()
	return true


func gold_count() -> int:
	return _gold.size()


func clear() -> void:
	ground.cancel()
	_gold.clear()
	if _feathers:
		_feathers.release_all()
		_effects.release_all()


func hit_feather(hurtbox: HurtboxComponent, direction: Vector3) -> void:
	var hit := DamageInfo.new(_attack.damage, _attack.damage_type, direction * _attack.knockback, actor)
	hit.attack = _attack
	hit.direction = direction
	hurtbox.receive_hit(hit)


func white_impact(at: Vector3, normal: Vector3) -> void:
	effect(PyralonFireFx.Kind.WHITE_IMPACT, at, normal, Vector2.ONE * 0.74, 0.34)
	if normal.y <= 0.4:
		CombatFx.spawn_hit(at, normal, Color("#ffd493"), 0.48)


func white_deflect(at: Vector3, velocity: Vector3) -> void:
	effect(PyralonFireFx.Kind.EMBER_BURST, at, velocity, Vector2.ONE * 0.72, 0.36)


func wall_splash(at: Vector3, normal: Vector3, width: float) -> void:
	var dir := normal.normalized()
	var floor_y := floor_at(at).y
	var anchor := Vector3(at.x, maxf(at.y + 0.45, floor_y + 1.35), at.z) + dir * 0.07
	effect(PyralonFireFx.Kind.WALL_SPLASH, anchor, dir, Vector2(width * 0.58, 1.65), 0.44)


func command_pulse(at: Vector3) -> void:
	effect(PyralonFireFx.Kind.COMMAND_PULSE, at, Vector3.ZERO, Vector2.ONE * 2.25, 0.44)


func command_feather_flash(at: Vector3) -> void:
	effect(PyralonFireFx.Kind.SHOCK, at, Vector3.ZERO, Vector2.ONE * 0.65, 0.22)


func fissure_chip(at: Vector3) -> void:
	effect(PyralonFireFx.Kind.DIRT_CHIP, at, Vector3.ZERO, Vector2.ONE * 0.78, 0.40)


func explode_gold(at: Vector3) -> void:
	var floor_point := floor_at(at)
	explode(at, floor_point, profile.gold_blast_radius, PyralonFireFx.Kind.BURST)


func explode_geyser(center: Vector3, floor_point: Vector3, radius: float) -> void:
	explode(center, floor_point, radius, PyralonFireFx.Kind.GEYSER)


func explode(center: Vector3, vfx_point: Vector3, radius: float, fx_kind: PyralonFireFx.Kind = PyralonFireFx.Kind.BURST) -> void:
	_explosion.global_position = center
	_explosion.radius = radius
	_explosion.explode(actor)
	var life := 0.92 if fx_kind == PyralonFireFx.Kind.GEYSER else 0.72
	effect(fx_kind, vfx_point, Vector3.ZERO, Vector2.ONE * radius, life)
	CombatFx.spawn_hit(center, Vector3.UP, Color("#ff982e"), radius * 0.45)


func effect(kind: PyralonFireFx.Kind, at: Vector3, direction: Vector3, size: Vector2, life: float) -> PyralonFireFx:
	var fx := _effects.acquire() as PyralonFireFx
	fx.play(kind, at, direction, size, life)
	return fx


func release_effect(fx: PyralonFireFx) -> void:
	if is_instance_valid(fx):
		_effects.release(fx)


func floor_at(point: Vector3) -> Vector3:
	var hit := _floor_hit(point)
	return hit.position if not hit.is_empty() else Vector3(point.x, actor.global_position.y, point.z)


func _floor_hit(point: Vector3) -> Dictionary:
	# Dò từ dưới trần phòng thử để lông trên cao không đáp lên nóc.
	_floor.from = Vector3(point.x, actor.global_position.y + 7.6, point.z)
	_floor.to = Vector3(point.x, actor.global_position.y - 2.0, point.z)
	var hit := get_world_3d().direct_space_state.intersect_ray(_floor)
	return hit if not hit.is_empty() and (hit.normal as Vector3).y > 0.55 else {}


func wall_between(from: Vector3, to: Vector3) -> Dictionary:
	_wall.from = from
	_wall.to = to
	return get_world_3d().direct_space_state.intersect_ray(_wall)


func gold_spots(count: int) -> PackedVector3Array:
	var spots := PackedVector3Array()
	for quadrant: int in 4:
		var goal := ceili((quadrant + 1) * count / 4.0)
		for _attempt: int in 120:
			if spots.size() >= goal:
				break
			var angle := (quadrant + randf()) * PI * 0.5
			var distance := sqrt(randf_range(0.12, 1.0)) * profile.spread_radius
			_try_gold_spot(actor.global_position + Vector3(sin(angle), 0.0, cos(angle)) * distance, spots, profile.gold_spacing)
	if spots.size() < count:
		# Lưới dự phòng giữ đủ điểm khi tường cắt qua nhiều phần của đĩa.
		var step := maxf(profile.gold_spacing, 0.5)
		var extent := ceili(profile.spread_radius / step)
		for x: int in range(-extent, extent + 1):
			for z: int in range(-extent, extent + 1):
				if spots.size() >= count:
					return spots
				_try_gold_spot(actor.global_position + Vector3(x, 0, z) * step, spots, step)
	return spots


func can_drop_gold(point: Vector3, spacing: float) -> bool:
	for feather: PyralonFeather in _gold:
		if feather.gold_position().slide(Vector3.UP).distance_to(point.slide(Vector3.UP)) < spacing:
			return false
	return true


func _try_gold_spot(point: Vector3, spots: PackedVector3Array, spacing: float) -> void:
	var hit := _floor_hit(point)
	if hit.is_empty():
		return
	var floor_point: Vector3 = hit.position
	if absf(floor_point.y - actor.global_position.y) > 0.40:
		return
	var height := Vector3.UP * profile.gold_hover_height
	if not wall_between(actor.global_position + height, floor_point + height).is_empty():
		return
	if not can_drop_gold(floor_point, spacing):
		return
	for other: Vector3 in spots:
		if floor_point.distance_to(other) < spacing:
			return
	spots.append(floor_point)


func _make_pool(scene: PackedScene, count: int) -> ObjectPool:
	var pool := ObjectPool.new()
	pool.scene = scene
	pool.initial_size = count
	add_child(pool)
	return pool
