class_name PyralonField
extends Node3D
## Quản lý hiệu ứng và lông theo vòng đời trận, kể cả khi chuyển sang chiêu khác.

const WORLD := 1 | 256

@export var feather_scene: PackedScene
@export var fire_fx_scene: PackedScene
@export var sky_crater_scene: PackedScene

var actor: Pyralon
var profile: PyralonData
var _gold: Array[PyralonFeather] = []
var _crimson_wall: Array[PyralonFeather] = []
var _crimson_ground: Array[PyralonFeather] = []
var _crimson_returning: Array[PyralonFeather] = []
var _crimson_return_total: int = 0
var _command_candidates: Array[PyralonFeather] = []
var _feathers: ObjectPool
var _effects: ObjectPool
var _sky_craters: ObjectPool
var _attack := AttackData.new()
var _floor := PhysicsRayQueryParameters3D.new()
var _wall := PhysicsRayQueryParameters3D.new()

@onready var _explosion: ExplosionComponent = $Explosion
@onready var ground: PyralonGroundFire = $GroundFire
@onready var rift_chain: PyralonRiftChain = $RiftChain


func setup(boss: Pyralon) -> void:
	actor = boss
	profile = boss.profile
	_attack.damage = profile.feather_damage
	_attack.damage_type = DamageInfo.Type.FIRE
	_attack.knockback = 0.9
	_explosion.attack = _attack
	_floor.collision_mask = WORLD
	_wall.collision_mask = WORLD
	_feathers = _make_pool(feather_scene, 140)
	_effects = _make_pool(fire_fx_scene, 160)
	if sky_crater_scene:
		_sky_craters = _make_pool(sky_crater_scene, 8)


func is_phase_two() -> bool:
	return actor != null and actor.is_phase_two()


func scaled_gold_count(base_count: int) -> int:
	if is_phase_two():
		return maxi(1, roundi(float(base_count) * profile.p2_gold_count_mult))
	return base_count


func new_white(at: Vector3) -> PyralonFeather:
	var feather := _feathers.acquire() as PyralonFeather
	feather.setup(self, actor.target, at, false, false)
	return feather


func new_crimson_wall(at: Vector3) -> PyralonFeather:
	var feather := _feathers.acquire() as PyralonFeather
	feather.setup(self, actor.target, at, false, true)
	_crimson_wall.append(feather)
	return feather


func new_crimson_ground(at: Vector3) -> PyralonFeather:
	var feather := _feathers.acquire() as PyralonFeather
	feather.setup(self, actor.target, at, false, true)
	_crimson_ground.append(feather)
	return feather


func launch_wall_crimson_feathers() -> int:
	var launched := 0
	var refire_speed := maxf(actor.player_speed() * profile.p2_wall_refire_speed_ratio, 3.0)
	var batch := _crimson_wall.duplicate()
	_crimson_wall.clear()
	for feather: PyralonFeather in batch:
		if is_instance_valid(feather) and feather.mode in [PyralonFeather.Mode.CRIMSON_WALL_STUCK, PyralonFeather.Mode.CRIMSON_WALL_FLY]:
			feather.launch_from_wall(refire_speed)
			if not _crimson_returning.has(feather):
				_crimson_returning.append(feather)
			launched += 1
	if launched > 0:
		_crimson_return_total = maxi(_crimson_return_total, _crimson_returning.size())
	return launched


func queue_ground_crimson_uproot() -> int:
	# Lần lượt bứng toàn bộ lông đỏ đang cắm sàn lên không và bắn lại player.
	var queued := 0
	var batch := _crimson_ground.duplicate()
	_crimson_ground.clear()
	var step := maxf(profile.p2_barrage_relaunch_interval, 0.015)
	for feather: PyralonFeather in batch:
		if is_instance_valid(feather) and feather.mode in [PyralonFeather.Mode.CRIMSON_GROUND_STUCK, PyralonFeather.Mode.CRIMSON_GROUND_FLY]:
			feather.begin_ground_uproot(float(queued) * step, profile.p2_barrage_lift_height, profile.p2_barrage_lift_time)
			if not _crimson_returning.has(feather):
				_crimson_returning.append(feather)
			queued += 1
	if queued > 0:
		_crimson_return_total = maxi(_crimson_return_total, _crimson_returning.size())
	return queued


func crimson_wall_count() -> int:
	return _crimson_wall.size()


func crimson_ground_count() -> int:
	return _crimson_ground.size()


func crimson_returning_count() -> int:
	return _crimson_returning.size()


func has_crimson_returning_busy() -> bool:
	if not is_phase_two():
		return false
	# Đợi xích lửa ở đòn bổ rìu Phase 2 kích hoạt lông cắm tường (nếu xích đang bay ra chưa kích).
	if rift_chain and rift_chain.stage in [PyralonRiftChain.Stage.SLASH, PyralonRiftChain.Stage.PORTAL_OPEN, PyralonRiftChain.Stage.CHAIN_FIRE] and not _crimson_wall.is_empty():
		return true
	if _crimson_returning.is_empty():
		return false
	var cutoff := maxi(2, int(ceil(float(_crimson_return_total) * profile.crimson_return_done_ratio)))
	return _crimson_returning.size() > cutoff


func drop_gold(from: Vector3, landing: Vector3) -> void:
	var feather := _feathers.acquire() as PyralonFeather
	feather.setup(self, actor.target, from, true, false)
	_gold.append(feather)
	feather.drop(from, landing + Vector3.UP * profile.gold_hover_height)


func recycle(feather: PyralonFeather) -> void:
	_gold.erase(feather)
	_crimson_wall.erase(feather)
	_crimson_ground.erase(feather)
	_crimson_returning.erase(feather)
	if _crimson_returning.is_empty():
		_crimson_return_total = 0
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
	if rift_chain:
		rift_chain.cancel()
	_gold.clear()
	_crimson_wall.clear()
	_crimson_ground.clear()
	_crimson_returning.clear()
	_crimson_return_total = 0
	if _feathers:
		_feathers.release_all()
	if _effects:
		_effects.release_all()
	if _sky_craters:
		_sky_craters.release_all()


func hit_feather(hurtbox: HurtboxComponent, direction: Vector3) -> void:
	hit_damage(hurtbox, _attack.damage, direction, _attack.knockback)


func hit_damage(hurtbox: HurtboxComponent, damage: int, direction: Vector3, knockback: float = 0.9) -> void:
	var hit := DamageInfo.new(damage, _attack.damage_type, direction * knockback, actor)
	hit.attack = _attack
	hit.direction = direction
	hurtbox.receive_hit(hit)


func white_impact(at: Vector3, normal: Vector3, flight_dir: Vector3 = Vector3.DOWN, crimson: bool = false) -> void:
	# Lông trắng (hoặc lông đỏ lượt bay 2) cắm theo góc bay thật rồi bén lửa cháy dần từ đỉnh xuống gốc thành tro trong 1.6s.
	var fx := effect(PyralonFireFx.Kind.WHITE_IMPACT, at, normal, Vector2.ONE * 0.78, 1.60)
	fx.set_embed_direction(flight_dir, crimson)
	if normal.y <= 0.4:
		CombatFx.spawn_hit(at, normal, Color("#ff3842") if crimson else Color("#ffd493"), 0.42)


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


func explode_with_damage(
	center: Vector3,
	vfx_point: Vector3,
	radius: float,
	damage: int,
	fx_kind: PyralonFireFx.Kind,
	life: float = 1.05
) -> void:
	var prev_damage := _attack.damage
	_attack.damage = damage
	_explosion.global_position = center
	_explosion.radius = radius
	_explosion.explode(actor)
	_attack.damage = prev_damage
	effect(fx_kind, vfx_point, Vector3.ZERO, Vector2.ONE * radius, life)
	CombatFx.spawn_hit(center, Vector3.UP, Color("#ff982e"), radius * 0.55)


func push_target_outward(origin: Vector3, radius: float, push_speed: float) -> bool:
	# Đẩy lùi player ra xa qua WindReceiverComponent (KHÔNG gây sát thương, tự chặn tường an toàn).
	if not is_instance_valid(actor.target):
		return false
	var target_char := actor.target as Character
	if target_char == null or target_char.wind_receiver == null:
		return false
	var offset := (target_char.global_position - origin).slide(Vector3.UP)
	if offset.length() > radius:
		return false
	var dir := offset.normalized() if offset.length_squared() > 0.0025 else actor.get_facing_direction().slide(Vector3.UP).normalized()
	if dir.is_zero_approx():
		dir = Vector3.BACK
	target_char.wind_receiver.clear_push()
	target_char.wind_receiver.push(dir * push_speed)
	return true


func sky_crater(at: Vector3, radius: float, damage: int, heavy: bool) -> void:
	# Gây sát thương nổ vùng đáp Sky Dive và dựng bộ VFX crater 3D + cột lửa phun trào + đá văng + sóng xung kích hoàn toàn mới.
	var prev_damage := _attack.damage
	_attack.damage = damage
	_explosion.global_position = at + Vector3.UP * 0.5
	_explosion.radius = radius
	_explosion.explode(actor)
	_attack.damage = prev_damage
	if _sky_craters:
		var crater := _sky_craters.acquire() as PyralonSkyCrater
		crater.play(at, radius, heavy, 3.4 if heavy else 2.8)
	CombatFx.spawn_hit(at + Vector3.UP * 0.45, Vector3.UP, Color("#ff982e"), radius * 0.55)


func scatter_gold_ring(center: Vector3, count: int) -> void:
	# Khi rải mật độ lớn (28 lông đợt 5), giảm nhẹ khoảng cách tối thiểu để trải đều phủ khắp toàn bộ phòng đấu.
	var spacing := minf(profile.gold_spacing, 1.85) if count >= 22 else profile.gold_spacing
	var spots := gold_spots(count, spacing)
	var origin := center + Vector3.UP * 1.65
	for landing: Vector3 in spots:
		drop_gold(origin, landing)


func trigger_domino_all(origin: Vector3, wave_speed: float, warn_time: float) -> float:
	# Kích nổ toàn bộ lông vàng theo hiệu ứng domino từ trong (gần boss nhất) lan dần ra ngoài.
	var speed := maxf(wave_speed, 1.0)
	var max_total := 0.0
	for feather: PyralonFeather in _gold:
		if not is_instance_valid(feather):
			continue
		var dist := feather.gold_position().slide(Vector3.UP).distance_to(origin.slide(Vector3.UP))
		var delay := dist / speed
		feather.trigger_domino(delay, warn_time)
		max_total = maxf(max_total, delay + warn_time)
	return max_total


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


func gold_spots(count: int, spacing_override: float = -1.0) -> PackedVector3Array:
	var spacing := spacing_override if spacing_override > 0.0 else profile.gold_spacing
	var spots := PackedVector3Array()
	for quadrant: int in 4:
		var goal := ceili((quadrant + 1) * count / 4.0)
		for _attempt: int in 140:
			if spots.size() >= goal:
				break
			var angle := (quadrant + randf()) * PI * 0.5
			var distance := sqrt(randf_range(0.08, 1.0)) * profile.spread_radius
			_try_gold_spot(actor.global_position + Vector3(sin(angle), 0.0, cos(angle)) * distance, spots, spacing)
	if spots.size() < count:
		# Lưới dự phòng giữ đủ điểm khi tường cắt qua nhiều phần của đĩa.
		var step := maxf(spacing, 0.5)
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
