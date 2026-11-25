class_name ElephantLava
extends Node3D
## Một đồng hồ cho toàn bộ lava đang chạm chân player. Vũng và vệt dùng chung phần hiển thị.

class Patch:
	var at: Vector3
	var radius: float
	var left: float
	var trail: bool
	var persistent: bool
	var mesh: MeshInstance3D
	var erupt_delay: float = -1.0

class Drop:
	var from: Vector3
	var to: Vector3
	var delay: float
	var time: float
	var elapsed: float
	var height: float
	var radius: float
	var makes_pool: bool
	var hit: bool
	var trunk: ElephantCoat
	var mesh: MeshInstance3D
	var tail: MeshInstance3D
	var warning: MeshInstance3D

class Splash:
	var mesh: MeshInstance3D
	var radius: float
	var age: float
	var floor_y: float
	var activation: bool

class Wave:
	var center: Vector3
	var facing: Vector3
	var distance: float
	var radius: float
	var previous_radius: float
	var hit: bool
	var mesh: MeshInstance3D
	var material: ShaderMaterial
	var touched: Array[Patch]

const SURFACE := preload("res://entities/bosses/fire/elephant/vfx/lava_surface.gdshader")
const MOTION := preload("res://entities/bosses/fire/elephant/vfx/lava_motion.gdshader")
const TELEGRAPH := preload("res://entities/bosses/fire/elephant/vfx/lava_telegraph.gdshader")
const WARNING := preload("res://entities/bosses/fire/elephant/vfx/lava_warning.gdshader")
const WARNING_ICON := preload("res://entities/bosses/fire/elephant/vfx/lava_warning.svg")
const STRIKE_DAMAGE_HEIGHT: float = 1.8
const WAVE_HALF_ANGLE: float = deg_to_rad(46.0)
const WAVE_WIDTH: float = 1.28
const TAIL_SECONDS: float = 0.18
const SPLASH_SECONDS: float = 0.39
const ACTIVATION_SECONDS: float = 0.59
const POOL_HEIGHT: float = 0.028
const TRAIL_HEIGHT: float = 0.085
const PATCH_LAYER_GAP: float = 0.011

@export var arena_size: Vector2 = Vector2(36.0, 32.0)
@export var pool_radius: float = 1.575
@export var pool_lifetime: float = 15.0
## Vũng lava từ chiêu phun mưa (rain) giữ nguyên trên sân cho đến khi voi phun đợt mưa lava tiếp theo mới biến mất.
@export var rain_pools_persist_until_next_rain: bool = true
@export var trail_radius: float = 1.125
@export_range(0.1, 1.0, 0.05) var ground_slow: float = 0.5
@export_range(0.1, 20.0, 0.1) var burn_interval: float = 1.0
@export var wave_speed: float = 4.6
@export var wave_range: float = 13.0
@export var drop_radius: float = 0.65
@export var rain_warning: float = 1.05
@export var eruption_distance: Vector2 = Vector2(2.85, 5.25)

var arena_center: Vector3
var _target: Player
var _hurtbox: HurtboxComponent
var _patches: Array[Patch]
var _drops: Array[Drop]
var _waves: Array[Wave]
var _splashes: Array[Splash]
var _burn: float
var _wet: bool
var _warning: Sprite3D
var _warning_material: ShaderMaterial
var _meshes: ObjectPool
var _tails: ObjectPool
var _impacts: ObjectPool
var _markers: ObjectPool
var _wave_pool: ObjectPool
var _pool_material: ShaderMaterial
var _drop_material: ShaderMaterial
var _ring: ArrayMesh
var _puddle_mesh: ArrayMesh
var _drop_mesh: SphereMesh
var _stomp: MeshInstance3D
var _stomp_vfx: ElephantStompVfx
var _stomp_warning_left: float
var _stomp_warning_duration: float
var _excluded: Array[RID]
var _stomp_hitbox: HitboxComponent
var _stomp_shape: CylinderShape3D


func _ready() -> void:
	top_level = true
	arena_center = global_position
	global_transform = Transform3D.IDENTITY
	_excluded = [(get_parent() as CollisionObject3D).get_rid()]
	_pool_material = _surface_material(0)
	_drop_material = _surface_material(2)
	_drop_material.set_shader_parameter(&"crust", Color("844027"))
	_puddle_mesh = _make_puddle()
	_drop_mesh = SphereMesh.new()
	_drop_mesh.radius = 0.5
	_drop_mesh.height = 1.0
	_drop_mesh.radial_segments = 8
	_drop_mesh.rings = 3
	_ring = _make_marker()
	var mesh_template := MeshInstance3D.new()
	mesh_template.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh_scene := PackedScene.new()
	mesh_scene.pack(mesh_template)
	mesh_template.free()
	_meshes = _make_pool(mesh_scene, 72)
	_tails = _make_pool(mesh_scene, 28, _configure_motion.bind(_make_tail(), false))
	_impacts = _make_pool(mesh_scene, 16, _configure_motion.bind(_make_splash(), true))
	_markers = _make_pool(mesh_scene, 28, _configure_marker)
	_wave_pool = _make_pool(mesh_scene, 4, _configure_wave.bind(_make_wave()))
	_stomp = MeshInstance3D.new()
	_configure_marker(_stomp)
	add_child(_stomp)
	_stomp.hide()
	_stomp_shape = CylinderShape3D.new()
	_stomp_shape.height = STRIKE_DAMAGE_HEIGHT
	var collision := CollisionShape3D.new()
	collision.name = &"CollisionShape3D"
	collision.shape = _stomp_shape
	_stomp_hitbox = HitboxComponent.new()
	_stomp_hitbox.collision_layer = 0
	_stomp_hitbox.collision_mask = 2
	_stomp_hitbox.add_child(collision)
	add_child(_stomp_hitbox)
	_stomp_hitbox.owner = get_parent()
	_stomp_vfx = ElephantStompVfx.new()
	add_child(_stomp_vfx)
	_warning = Sprite3D.new()
	_warning.texture = WARNING_ICON
	_warning.pixel_size = 0.0094
	_warning_material = ShaderMaterial.new()
	_warning_material.shader = WARNING
	_warning_material.set_shader_parameter(&"icon_mask", WARNING_ICON)
	_warning.material_override = _warning_material
	_warning.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_warning)
	_warning.hide()
	set_process(false)
	set_physics_process(false)


func _exit_tree() -> void:
	_leave_lava()


func set_target(player: Player) -> void:
	if _target != player:
		_leave_lava()
	_target = player
	_hurtbox = player.get_node("HurtboxComponent") as HurtboxComponent if player else null


func rain(trunk: ElephantCoat) -> void:
	if rain_pools_persist_until_next_rain:
		_clear_rain_pools()
	var quadrant := arena_size * 0.5
	var spacing := quadrant / Vector2(3, 2)
	for index: int in 4:
		var corner := -quadrant + Vector2(index % 2, index >> 1) * quadrant
		for cell: int in 6:
			var grid := corner + (Vector2(cell % 3, floorf(cell / 3.0)) + Vector2(0.5, 0.5)) * spacing
			var jitter := Vector2(randf_range(-0.21, 0.21), randf_range(-0.21, 0.21)) * spacing
			var offset := grid + jitter
			var at := _ground(arena_center + Vector3(offset.x, 0.0, offset.y))
			if not at.is_finite():
				at = _ground(arena_center + Vector3(grid.x, 0.0, grid.y))
			if at.is_finite():
				# Phóng toàn bộ 24 vũng dung nham cùng một lúc từ vòi (lệch siêu nhỏ cho tự nhiên).
				_throw(Vector3.ZERO, at, pool_radius, randf_range(0.0, 0.06), rain_warning, 3.8, trunk)


func leave_trail(at: Vector3) -> void:
	var ground := _ground(at)
	if ground.is_finite():
		_add_patch(ground, trail_radius, true)


func warn_stomp(at: Vector3, radius: float, duration: float) -> void:
	_stomp_warning_duration = maxf(0.01, duration)
	_stomp_warning_left = _stomp_warning_duration
	_show_marker(_stomp, at, radius, 2)
	set_physics_process(true)


func erupt_all(at: Vector3, skill: ElephantSkill) -> void:
	var radius := skill.effect_radius
	_stomp.hide()
	_stomp_warning_left = 0.0
	_stomp_hitbox.global_position = at + Vector3.UP * (STRIKE_DAMAGE_HEIGHT * 0.5)
	_stomp_shape.radius = radius
	_stomp_hitbox.activate(skill, skill.active_end - skill.active_start)
	_stomp_vfx.play(at, radius)
	for patch: Patch in _patches:
		if not patch.trail:
			var quadrant := int(patch.at.x >= arena_center.x) + int(patch.at.z >= arena_center.z) * 2
			_queue_eruption(patch, quadrant * 0.13 + randf_range(0.0, 0.12))
	set_physics_process(true)


func cancel_stomp() -> void:
	_stomp.hide()
	_stomp_warning_left = 0.0
	if _stomp_hitbox.is_active():
		_stomp_hitbox.deactivate()


func send_wave(at: Vector3, forward: Vector3) -> void:
	var wave := Wave.new()
	wave.center = at
	wave.facing = forward
	wave.radius = 1.0
	wave.previous_radius = wave.radius
	wave.mesh = _wave_pool.acquire() as MeshInstance3D
	wave.material = wave.mesh.material_override as ShaderMaterial
	wave.mesh.global_position = at + Vector3.UP * 0.14
	wave.mesh.rotation.y = atan2(forward.x, forward.z)
	wave.mesh.reset_physics_interpolation()
	_set_wave_visual(wave, wave.radius)
	_waves.append(wave)
	set_process(true)
	set_physics_process(true)


func clear() -> void:
	_leave_lava()
	cancel_stomp()
	_stomp_vfx.stop()
	_meshes.release_all()
	_tails.release_all()
	_impacts.release_all()
	_markers.release_all()
	_wave_pool.release_all()
	_drops.clear()
	_patches.clear()
	_waves.clear()
	_splashes.clear()
	set_process(false)
	set_physics_process(false)


func _process(_delta: float) -> void:
	var interpolation := Engine.get_physics_interpolation_fraction()
	for wave: Wave in _waves:
		_set_wave_visual(wave, lerpf(wave.previous_radius, wave.radius, interpolation))


func _physics_process(delta: float) -> void:
	for i: int in range(_drops.size() - 1, -1, -1):
		_update_drop(_drops[i], i, delta)
	for i: int in range(_waves.size() - 1, -1, -1):
		_update_wave(_waves[i], i, delta)
	for i: int in range(_splashes.size() - 1, -1, -1):
		_update_splash(_splashes[i], i, delta)
	var wet := false
	for i: int in range(_patches.size() - 1, -1, -1):
		var patch := _patches[i]
		if not patch.persistent:
			patch.left -= delta
		if patch.erupt_delay >= 0.0:
			patch.erupt_delay = (patch.erupt_delay - delta) if patch.persistent else minf(patch.erupt_delay - delta, patch.left)
			if patch.erupt_delay <= 0.0:
				patch.erupt_delay = -1.0
				_erupt(patch)
		if not patch.persistent and patch.left <= 0.0:
			_meshes.release(patch.mesh)
			_patches.remove_at(i)
			continue
		wet = wet or _player_at(patch.at, patch.radius, 0.65)
	_update_burn(wet, delta)
	if _stomp_warning_left > 0.0:
		_stomp_warning_left = maxf(_stomp_warning_left - delta, 0.0)
		_marker_progress(_stomp, 1.0 - _stomp_warning_left / _stomp_warning_duration)
	if _patches.is_empty() and _drops.is_empty() and _waves.is_empty() and _splashes.is_empty() and _stomp_warning_left <= 0.0:
		set_physics_process(false)


func _update_burn(wet: bool, delta: float) -> void:
	if not wet:
		_leave_lava()
		return
	_warning.global_position = _target.global_position + Vector3.UP * 2.58
	if not _wet:
		_target.set_terrain_speed(self, ground_slow)
		_warning.reset_physics_interpolation()
		_warning.show()
		_wet = true
	_burn += delta
	if _burn >= burn_interval:
		_burn = 0.0
		_deal_hit()
		if not _valid_target():
			_leave_lava()
			return
	_warning_material.set_shader_parameter(&"fill", _burn / burn_interval)


func _leave_lava() -> void:
	if not _wet:
		return
	_wet = false
	_burn = 0.0
	if is_instance_valid(_target):
		_target.set_terrain_speed(self, 1.0)
	_warning.hide()
	_warning_material.set_shader_parameter(&"fill", 0.0)


func _clear_rain_pools() -> void:
	for i: int in range(_patches.size() - 1, -1, -1):
		var patch := _patches[i]
		if patch.trail:
			continue
		_meshes.release(patch.mesh)
		_patches.remove_at(i)


func _add_patch(at: Vector3, radius: float, trail: bool) -> void:
	var patch := Patch.new()
	patch.at = at
	patch.radius = radius
	patch.trail = trail
	patch.persistent = rain_pools_persist_until_next_rain and not trail
	patch.left = INF if patch.persistent else pool_lifetime
	patch.mesh = _take_mesh(_puddle_mesh, _pool_material)
	patch.mesh.scale = Vector3(radius, 1.0, radius)
	patch.mesh.rotation.y = randf_range(0.0, TAU)
	var draw_at := at
	draw_at.y = _patch_draw_height(at, radius, trail)
	patch.mesh.global_position = draw_at
	patch.mesh.reset_physics_interpolation()
	_patches.append(patch)
	set_physics_process(true)


func _patch_draw_height(at: Vector3, radius: float, trail: bool) -> float:
	# Xếp các mặt dung nham chồng nhau lên cao độ khác nhau để tránh nhấp nháy theo góc camera.
	var height := at.y + (TRAIL_HEIGHT if trail else POOL_HEIGHT)
	var occupied := true
	while occupied:
		occupied = false
		for other: Patch in _patches:
			if other.trail != trail or (other.at - at).slide(Vector3.UP).length_squared() >= (other.radius + radius) ** 2:
				continue
			var other_height := other.mesh.global_position.y
			if absf(height - other_height) < PATCH_LAYER_GAP * 0.9:
				height = other_height + PATCH_LAYER_GAP
				occupied = true
				break
	return height


func _throw(from: Vector3, at: Vector3, radius: float, delay: float, time: float, height: float,
		trunk: ElephantCoat = null) -> void:
	var drop := Drop.new()
	drop.from = from
	drop.to = at
	drop.radius = radius
	drop.delay = delay
	drop.time = time
	drop.height = height
	drop.makes_pool = trunk != null
	drop.trunk = trunk
	_drops.append(drop)
	set_physics_process(true)


func _update_drop(drop: Drop, index: int, delta: float) -> void:
	drop.elapsed += delta
	if drop.elapsed < drop.delay:
		return
	var launched := drop.mesh == null
	if launched:
		if is_instance_valid(drop.trunk):
			drop.from = drop.trunk.trunk_tip()
		drop.mesh = _take_mesh(_drop_mesh, _drop_material)
		drop.mesh.scale = Vector3.ONE * (drop.radius * 0.78)
		drop.mesh.global_position = drop.from
		drop.tail = _tails.acquire() as MeshInstance3D
		drop.warning = _markers.acquire() as MeshInstance3D
		_show_marker(drop.warning, drop.to, drop.radius, 0 if drop.makes_pool else 1)
	var t := clampf((drop.elapsed - drop.delay) / drop.time, 0.0, 1.0)
	_marker_progress(drop.warning, t)
	var previous := drop.mesh.global_position
	var flight := drop.to + Vector3.UP * 0.06 - drop.from
	var at := drop.from + flight * t + Vector3.UP * (4.0 * t * (1.0 - t) * drop.height)
	drop.mesh.global_position = at
	_update_tail(drop, at, flight + Vector3.UP * (4.0 * drop.height * (1.0 - 2.0 * t)), t)
	if launched:
		drop.mesh.reset_physics_interpolation()
		drop.tail.reset_physics_interpolation()
	if not drop.makes_pool and not drop.hit and _valid_target():
		var chest := _target.global_position + Vector3.UP * 0.8
		var nearest := Geometry3D.get_closest_point_to_segment(chest, previous, at)
		if nearest.distance_squared_to(chest) <= pow(drop.radius * 0.43 + 0.35, 2.0):
			drop.hit = true
			_deal_hit()
	if t < 1.0:
		return
	if not drop.hit and _player_at(drop.to, drop.radius, STRIKE_DAMAGE_HEIGHT):
		_deal_hit()
	if drop.makes_pool:
		_add_patch(drop.to, drop.radius, false)
	_spawn_splash(drop.to, drop.radius * (1.0 if drop.makes_pool else 0.76))
	_markers.release(drop.warning)
	_meshes.release(drop.mesh)
	_tails.release(drop.tail)
	_drops.remove_at(index)


func _update_tail(drop: Drop, at: Vector3, velocity: Vector3, t: float) -> void:
	var forward := velocity.normalized()
	if forward.is_zero_approx():
		return
	var axis := Vector3.FORWARD if absf(forward.y) > 0.98 else Vector3.UP
	var right := axis.cross(forward).normalized()
	var up := forward.cross(right)
	var fraction := minf(t, TAIL_SECONDS / drop.time)
	var width := drop.radius * 0.45
	var size := Vector3(width, width, maxf(0.005, velocity.length() * fraction))
	drop.tail.global_transform = Transform3D(Basis(right, up, forward).scaled_local(size), at)
	var material := drop.tail.material_override as ShaderMaterial
	material.set_shader_parameter(&"bend", 4.0 * drop.height * fraction * fraction * up.y / width)


func _spawn_splash(at: Vector3, radius: float, activation: bool = false) -> void:
	var splash := Splash.new()
	splash.mesh = _impacts.acquire() as MeshInstance3D
	splash.radius = radius
	splash.floor_y = at.y
	splash.activation = activation
	splash.mesh.global_position = at + Vector3.UP * 0.095
	splash.mesh.rotation.y = randf_range(0.0, TAU)
	splash.mesh.scale = Vector3.ONE * splash.radius * 0.3
	splash.mesh.reset_physics_interpolation()
	var material := splash.mesh.material_override as ShaderMaterial
	material.set_shader_parameter(&"activation", activation)
	material.set_shader_parameter(&"fade", 0.0 if activation else 1.0)
	_splashes.append(splash)


func _update_splash(splash: Splash, index: int, delta: float) -> void:
	splash.age += delta
	var t := splash.age / (ACTIVATION_SECONDS if splash.activation else SPLASH_SECONDS)
	if t >= 1.0:
		_impacts.release(splash.mesh)
		_splashes.remove_at(index)
		return
	var spread := lerpf(0.36, 1.0, 1.0 - pow(1.0 - t, 3.0)) * splash.radius
	var fade := 1.0 - smoothstep(0.22, 1.0, t)
	if splash.activation:
		splash.mesh.scale = Vector3(spread, splash.radius * 0.47, spread)
		splash.mesh.global_position.y = splash.floor_y + lerpf(0.095, 0.45, t)
		fade *= smoothstep(0.0, 0.17, t)
	else:
		var lift := sin(pow(t, 0.62) * PI)
		splash.mesh.scale = Vector3(spread, (0.24 + lift) * splash.radius, spread)
	(splash.mesh.material_override as ShaderMaterial).set_shader_parameter(&"fade", fade)


func _update_wave(wave: Wave, index: int, delta: float) -> void:
	wave.previous_radius = wave.radius
	wave.distance += wave_speed * delta
	wave.radius = 1.0 + wave.distance
	if not wave.hit and _valid_target() and _target.global_position.y - wave.center.y < STRIKE_DAMAGE_HEIGHT:
		if _wave_touches(wave, _target.global_position, 0.4):
			wave.hit = true
			_deal_hit()
	for patch: Patch in _patches:
		if not patch.trail and patch not in wave.touched and _wave_touches(wave, patch.at, patch.radius):
			wave.touched.append(patch)
			_queue_eruption(patch, randf_range(0.03, 0.16))
	if wave.distance >= wave_range:
		_wave_pool.release(wave.mesh)
		_waves.remove_at(index)
		if _waves.is_empty():
			set_process(false)


func _wave_touches(wave: Wave, at: Vector3, padding: float) -> bool:
	var arena_offset := Vector2(at.x - arena_center.x, at.z - arena_center.z).abs()
	var arena_edge := arena_size * 0.5
	if arena_offset.x > arena_edge.x or arena_offset.y > arena_edge.y:
		return false
	var offset := (at - wave.center).slide(Vector3.UP)
	var distance := offset.length()
	var angle := absf(wave.facing.signed_angle_to(offset, Vector3.UP))
	if distance > wave.radius + padding or angle > WAVE_HALF_ANGLE + atan2(padding, distance):
		return false
	var taper := pow(maxf(0.0, cos(0.5 * PI * angle / WAVE_HALF_ANGLE)), 0.62)
	var depth := minf(WAVE_WIDTH, wave.previous_radius * 0.44) * taper
	return distance >= wave.previous_radius - depth - padding


func _configure_wave(node: MeshInstance3D, mesh: Mesh) -> void:
	var material := _surface_material(1)
	material.set_shader_parameter(&"crust", Color("723721"))
	material.set_shader_parameter(&"wave_half_angle", WAVE_HALF_ANGLE)
	material.set_shader_parameter(&"wave_width", WAVE_WIDTH)
	material.set_shader_parameter(&"arena_center", Vector2(arena_center.x, arena_center.z))
	material.set_shader_parameter(&"arena_extent", arena_size * 0.5)
	node.mesh = mesh
	node.material_override = material
	var extent := 2.0 + wave_range
	node.custom_aabb = AABB(Vector3(-extent, -0.4, -0.5), Vector3(extent * 2.0, 1.8, extent + 0.5))


func _set_wave_visual(wave: Wave, radius: float) -> void:
	var distance := radius - 1.0
	wave.material.set_shader_parameter(&"wave_radius", radius)
	wave.material.set_shader_parameter(&"wave_age", distance / maxf(wave_speed, 0.01))
	wave.material.set_shader_parameter(&"wave_fade", 1.0 - smoothstep(maxf(0.0, wave_range - 1.1), wave_range, distance))


func _queue_eruption(patch: Patch, delay: float) -> void:
	if patch.erupt_delay < 0.0:
		patch.erupt_delay = delay


func _erupt(patch: Patch) -> void:
	_spawn_splash(patch.at, patch.radius, true)
	var heading := randf_range(0.0, TAU)
	var landings := PackedVector3Array()
	var extent := arena_size * 0.5 - Vector2.ONE * (drop_radius + 0.25)
	for i: int in 3:
		var distance := randf_range(eruption_distance.x, eruption_distance.y)
		var at := _eruption_destination(patch.at, heading, distance, extent, landings)
		heading += TAU / 3.0
		landings.append(at)
		_throw(patch.at + Vector3.UP * 0.12, at, drop_radius, i * 0.09, 0.86, 2.5)


func _eruption_destination(origin: Vector3, heading: float, distance: float, extent: Vector2,
		landings: PackedVector3Array) -> Vector3:
	var min_separation := (drop_radius * 2.0) ** 2
	for step: int in 12:
		# Thử các hướng gần nhất trước để các giọt cạnh tường vẫn bay xa vào sân.
		var side := 1.0 if step % 2 == 0 else -1.0
		var angle := heading + side * ceilf(step * 0.5) * (TAU / 12.0)
		var candidate := origin + Vector3(sin(angle), 0.0, cos(angle)) * distance
		var offset := candidate - arena_center
		if absf(offset.x) > extent.x or absf(offset.z) > extent.y:
			continue
		var separated := true
		for prior: Vector3 in landings:
			if prior.distance_squared_to(candidate) < min_separation:
				separated = false
				break
		if not separated:
			continue
		var at := _ground(candidate)
		if at.is_finite():
			return at
	return origin


func _valid_target() -> bool:
	return is_instance_valid(_target) and not _target.health.is_dead()


func _player_at(at: Vector3, radius: float, height: float) -> bool:
	if not _valid_target():
		return false
	var offset := _target.global_position - at
	return absf(offset.y) <= height and Vector2(offset.x, offset.z).length_squared() <= radius * radius


func _deal_hit() -> void:
	if not _valid_target():
		return
	var info := DamageInfo.new(1, DamageInfo.Type.FIRE, Vector3.ZERO, get_parent())
	info.staggers = false
	_hurtbox.receive_hit(info)


func _ground(at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at - Vector3.UP * 5.0, 1, _excluded)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.7 or absf((hit.position as Vector3).y - arena_center.y) > 0.9:
		return Vector3.INF
	return hit.position


func _make_pool(scene: PackedScene, initial: int, configure: Callable = Callable()) -> ObjectPool:
	var pool := ObjectPool.new()
	pool.scene = scene
	pool.initial_size = initial
	pool.configure_instance = configure
	add_child(pool)
	return pool


func _take_mesh(mesh: Mesh, material: Material = null) -> MeshInstance3D:
	var instance := _meshes.acquire() as MeshInstance3D
	instance.mesh = mesh
	instance.material_override = material
	instance.transform = Transform3D.IDENTITY
	return instance


func _surface_material(style: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SURFACE
	material.set_shader_parameter(&"style", style)
	return material


func _configure_marker(node: MeshInstance3D) -> void:
	var material := ShaderMaterial.new()
	material.shader = TELEGRAPH
	material.render_priority = 3
	node.mesh = _ring
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _show_marker(node: MeshInstance3D, at: Vector3, radius: float, kind: int) -> void:
	node.scale = Vector3(radius, 1.0, radius)
	node.global_position = at + Vector3.UP * 0.17
	node.reset_physics_interpolation()
	(node.material_override as ShaderMaterial).set_shader_parameter(&"kind", kind)
	_marker_progress(node, 0.0)
	node.show()


func _marker_progress(node: MeshInstance3D, progress: float) -> void:
	(node.material_override as ShaderMaterial).set_shader_parameter(&"progress", progress)


func _configure_motion(node: MeshInstance3D, mesh: Mesh, splash: bool) -> void:
	var material := ShaderMaterial.new()
	material.shader = MOTION
	material.set_shader_parameter(&"splash", splash)
	node.mesh = mesh
	node.material_override = material
	node.extra_cull_margin = 1.0


func _make_puddle() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 24:
		var a := _puddle_edge(i)
		var b := _puddle_edge(i + 1)
		for point: Vector3 in [Vector3.ZERO, a, b]:
			surface.set_uv(Vector2(point.x, point.z) * 0.5 + Vector2(0.5, 0.5))
			surface.add_vertex(point)
	return surface.commit()


func _puddle_edge(index: int) -> Vector3:
	var angle := (index % 24) * TAU / 24.0
	var rim := 0.94 + sin(angle * 5.0) * 0.055 + cos(angle * 9.0) * 0.035
	return Vector3(cos(angle) * rim, 0.0, sin(angle) * rim)


func _make_wave() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bands := [0.0, 0.12, 0.27, 0.48, 0.72, 1.0, 1.22]
	for i: int in 56:
		for band: int in range(bands.size() - 1):
			for corner: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.ZERO, Vector2i.ONE, Vector2i.DOWN]:
				var u := (i + corner.x) / 56.0
				var v: float = bands[band + corner.y]
				surface.set_uv(Vector2(u, v))
				surface.add_vertex(Vector3(u, 0.0, v))
	return surface.commit()


func _make_marker() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners: Array[Vector2] = [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.ZERO, Vector2.ONE, Vector2.DOWN]
	for corner: Vector2 in corners:
		surface.set_uv(corner)
		surface.set_uv2(Vector2.ZERO)
		surface.add_vertex(Vector3(corner.x - 0.5, 0.0, corner.y - 0.5) * 2.2)
	for segment: int in 56:
		for corner: Vector2 in corners:
			var unit := (segment + corner.x) / 56.0
			var angle := TAU * unit
			surface.set_uv(Vector2(unit, corner.y))
			surface.set_uv2(Vector2.RIGHT)
			surface.add_vertex(Vector3(cos(angle) * 0.98, corner.y, sin(angle) * 0.98))
	return surface.commit()


func _make_tail() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i: int in 9:
		for side: int in 2:
			var along := i / 8.0
			surface.set_uv(Vector2(along, side))
			surface.add_vertex(Vector3(side - 0.5, 0.0, -along))
	return surface.commit()


func _make_splash() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.ZERO, Vector2i.ONE, Vector2i.DOWN]
	for segment: int in 64:
		for band: int in 5:
			for corner: Vector2i in corners:
				var u := (segment + corner.x) / 64.0
				var across := (band + corner.y) / 5.0
				var angle := u * TAU
				var lobe := 0.5 + 0.5 * sin(angle * 7.0 + sin(angle * 3.0) * 0.87)
				var profile := sin(PI * across) ** 0.85 if across < 1.0 else 0.0
				var height := profile * (0.085 + 0.24 * smoothstep(0.0, 0.83, lobe))
				var radius := lerpf(0.11, 0.92 + 0.061 * sin(angle * 5.0), across)
				surface.set_uv(Vector2(u, across))
				surface.add_vertex(Vector3(cos(angle) * radius, height, sin(angle) * radius))
	return surface.commit()
