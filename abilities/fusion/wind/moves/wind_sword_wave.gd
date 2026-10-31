class_name WindSwordWave
extends FusionMove
## Lưỡi liềm gió bay thẳng, dùng texture nét cọ và đuôi mờ riêng cho fusion.
## Kiếm + Gió phóng ra ở nhát cuối combo. Mỗi nhát xuyên quái (mỗi quái chỉ trúng một lần mỗi nhát), gây sát thương
## và đẩy lùi; chạm tường / vật cản thì tan. Trúng thì bung vài nét gió nhỏ (pool), không có lá cho đỡ rối mắt.
## Va chạm theo signal của Area3D; chỉ chạy _physics_process khi còn nhát đang bay hoặc hiệu ứng chưa tắt.

@export_group("Waves")
@export_range(1, 10) var wave_count: int = 3
## Khoảng cách thời gian giữa hai nhát (s)
@export_range(0.0, 1.0, 0.01) var interval: float = 0.12
@export var speed: float = 16.0
## Quãng đường tối đa mỗi nhát (m)
@export var max_distance: float = 9.0
## Rộng x cao x dày của vùng trúng (m)
@export var wave_size: Vector3 = Vector3(2.4, 1.2, 0.6)
## Độ cao tâm nhát gió so với chân người tung (m)
@export var height: float = 0.9

@export_group("Collision")
## Thế giới (chặn) + hurtbox quái (trúng)
@export_flags_3d_physics var collision_mask: int = 5
@export_flags_3d_physics var world_mask: int = 1

@export_group("Look")
## Bán kính trong / ngoài của lưỡi liềm và độ mở cung (độ)
@export var inner_radius: float = 1.0
@export var outer_radius: float = 1.6
@export var arc_degrees: float = 120.0
@export var style: FusionWindStyle = preload("res://abilities/fusion/wind/vfx/style/fusion_wind_style.tres")
## Lưỡi liềm bắt đầu tan khi bay được tỉ lệ này của quãng đường
@export_range(0.0, 1.0) var dissolve_from: float = 0.45
## Giữ node thêm bấy nhiêu giây sau nhát cuối để cú bung / bụi trúng chạy hết
@export var linger: float = 0.6

var _user: Character
var _attack: AttackData
var _direction: Vector3
var _spawned: int = 0
var _clock: float = 0.0
var _done_at: float = -1.0
## Mỗi phần tử: {area, travelled, hit, materials}
var _waves: Array[Dictionary] = []
var _shape: BoxShape3D
var _arc_mesh: ArrayMesh
var _wake_mesh: ArrayMesh

@onready var _impacts: WindImpactPool = $ImpactPool


func _ready() -> void:
	set_physics_process(false)


## Chuẩn bị cả pool va chạm và đúng vertex format của chiêu, không gọi perform/gây damage.
func prepare_shader_warmup() -> void:
	var mesh_key := "%s|%s|%s|%s" % [inner_radius, outer_radius, arc_degrees, wave_size]
	var arc := style.cached_mesh("arc|" + mesh_key, _build_arc_mesh)
	var wake := style.cached_mesh("wake|" + mesh_key, _build_wake_mesh)
	for mode: int in [0, 1, 7, 9, 10]:
		var visual := MeshInstance3D.new()
		visual.mesh = wake if mode == 1 else arc
		visual.material_override = style.create_material(mode)
		(visual.material_override as ShaderMaterial).set_shader_parameter(&"age", 0.04)
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(visual)
	var particles := _create_particles(style.sword_particle_count, style.sword_particle_lifetime, false)
	particles.preprocess = minf(particles.lifetime * 0.5, 0.05)
	particles.emitting = false


func perform(user: Character, attack: AttackData, direction: Vector3) -> void:
	_user = user
	_attack = attack
	_direction = direction.normalized()
	global_transform = Transform3D(Basis.looking_at(_direction, Vector3.UP), user.global_position + Vector3.UP * height)
	_shape = BoxShape3D.new()
	_shape.size = wave_size
	var mesh_key := "%s|%s|%s|%s" % [inner_radius, outer_radius, arc_degrees, wave_size]
	_arc_mesh = style.cached_mesh("arc|" + mesh_key, _build_arc_mesh)
	_wake_mesh = style.cached_mesh("wake|" + mesh_key, _build_wake_mesh)
	_spawn_wave()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_clock += delta
	while _spawned < wave_count and _clock >= interval * _spawned:
		_spawn_wave()
	var step := speed * delta
	for i in range(_waves.size() - 1, -1, -1):
		var wave: Dictionary = _waves[i]
		var area := wave.area as Area3D
		area.global_position += _direction * step
		wave.travelled += step
		var particles: CPUParticles3D = wave.particles
		particles.global_transform = area.global_transform
		var life := clampf(wave.travelled / max_distance, 0.0, 1.0)
		var dissolve := clampf((life - dissolve_from) / maxf(1.0 - dissolve_from, 0.001), 0.0, 1.0)
		var materials: Array[ShaderMaterial] = wave.materials
		for material in materials:
			material.set_shader_parameter(&"dissolve", dissolve * dissolve)
			material.set_shader_parameter(&"age", _clock - float(wave.born_at))
		if wave.travelled >= max_distance:
			_remove_wave(i)
	if _spawned >= wave_count and _waves.is_empty():
		if _done_at < 0.0:
			_done_at = _clock
		elif _clock - _done_at >= linger:
			queue_free()


func _spawn_wave() -> void:
	_spawned += 1
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = collision_mask
	area.monitorable = false
	var cs := CollisionShape3D.new()
	cs.shape = _shape
	area.add_child(cs)
	var materials: Array[ShaderMaterial] = []
	# Một lưỡi chính, đuôi kéo dọc hướng bay; không lặp cung tròn song song.
	for layer in 4:
		var mode := layer if layer < 2 else (9 if layer == 2 else 10)
		var material := style.create_material(mode)
		material.set_shader_parameter(&"seed", float(_spawned + layer) * 0.37)
		material.set_shader_parameter(&"travel_duration", max_distance / maxf(speed, 0.001))
		if layer == 1:
			material.set_shader_parameter(&"layer_opacity", style.wake_opacity)
		if layer == 0:
			material.render_priority = 1
		materials.append(material)
		var visual := MeshInstance3D.new()
		visual.mesh = _wake_mesh if layer == 1 else _arc_mesh
		visual.material_override = material
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Lưỡi liềm nằm ngang, lùi về sau để mép cong phía trước trùng mặt trước vùng trúng
		if layer != 1:
			visual.position.z = outer_radius - wave_size.z * 0.5
			visual.rotation.z = deg_to_rad(style.blade_roll_degrees)
		if layer == 2:
			visual.position.y = -style.blade_depth * 0.4
			material.set_shader_parameter(&"layer_opacity", 0.45)
		if layer == 3:
			visual.scale = Vector3.ONE * (1.0 + style.glow_expand)
			visual.position.y = -style.blade_depth * 0.6
			material.set_shader_parameter(&"layer_opacity", style.glow_opacity)
			material.render_priority = -1
		area.add_child(visual)
	add_child(area)
	area.global_transform = Transform3D(Basis.looking_at(_direction, Vector3.UP), global_position)
	var flash := MeshInstance3D.new()
	var flash_mesh := QuadMesh.new()
	flash_mesh.size = Vector2.ONE * style.launch_flash_size
	flash.mesh = flash_mesh
	var flash_material := style.create_material(7)
	flash.material_override = flash_material
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	area.add_child(flash)
	flash.position = Vector3(-wave_size.x * 0.44, 0.12, outer_radius * 0.55)
	var camera := get_viewport().get_camera_3d()
	if camera:
		flash.look_at(camera.global_position)
	materials.append(flash_material)
	var particles := _create_particles(style.sword_particle_count, style.sword_particle_lifetime, false)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(wave_size.x * 0.35, 0.05, 0.08)
	particles.global_transform = area.global_transform
	particles.emitting = style.sword_particle_count > 0
	var burst := _create_particles(style.launch_particle_count, style.sword_particle_lifetime, true)
	burst.global_transform = area.global_transform
	burst.position.x -= wave_size.x * 0.44
	if style.launch_particle_count > 0:
		burst.restart()
		burst.emitting = true
	var wave := {"area": area, "travelled": 0.0, "born_at": _clock, "hit": [] as Array[HurtboxComponent], "materials": materials, "particles": particles}
	_waves.append(wave)
	area.area_entered.connect(_on_area_entered.bind(wave))
	area.body_entered.connect(_on_body_entered.bind(wave))


## Cung lưỡi liềm nằm ngang, phình về phía trước (-Z). UV.x dọc cung, UV.y từ mép trong ra mép ngoài
func _build_arc_mesh() -> ArrayMesh:
	var count := maxi(style.segments, 2)
	var half := deg_to_rad(arc_degrees) * 0.5
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in count + 1:
		var u := float(i) / float(count)
		var angle := lerpf(-half, half, u)
		var dir := Vector3(sin(angle), 0.0, -cos(angle))
		var taper := pow(maxf(sin(u * PI), 0.0), 0.65) * lerpf(0.50, 1.50, u)
		var thickness := (outer_radius - inner_radius) * style.blade_thickness * taper
		# Tăng bề dày về phía sau, không để bán kính âm làm lưỡi tự cắt qua chính nó.
		var inner := dir * maxf(outer_radius - thickness, 0.15)
		inner.z += maxf(thickness - outer_radius + 0.15, 0.0)
		inner.y = sin(u * PI) * style.blade_depth
		vertices.append(inner)
		uvs.append(Vector2(u, 0.0))
		vertices.append(dir * outer_radius)
		uvs.append(Vector2(u, 1.0))
	for i in count:
		var a := i * 2
		indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_wake_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var count := maxi(style.segments / 2, 4)
	for strand in 3:
		var start := vertices.size()
		for i in count + 1:
			var u := float(i) / float(count)
			var angle := lerpf(-deg_to_rad(arc_degrees) * 0.52, deg_to_rad(arc_degrees) * (0.30 + float(strand) * 0.05), u)
			var radial := Vector3(sin(angle), 0.0, -cos(angle))
			var radius := inner_radius - float(strand) * 0.14 + u * 0.22
			var center := radial * radius
			center.z += outer_radius - wave_size.z * 0.5 + u * u * style.wake_length * 0.30
			center.y = -0.04 + float(strand) * 0.04
			var width := (0.14 + float(strand) * 0.025) * pow(maxf(sin(u * PI), 0.0), 0.65)
			vertices.append(center - radial * width)
			vertices.append(center + radial * width)
			uvs.append(Vector2(u, 0.0))
			uvs.append(Vector2(u, 1.0))
		for i in count:
			var a := start + i * 2
			indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _create_particles(count: int, duration: float, burst: bool) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	style.configure_particles(particles, count, minf(duration, maxf(linger, 0.01)), burst)
	# Đặt ngoài Area để hạt còn sống không bị cắt khi lưỡi chạm tường hoặc hết tầm.
	add_child(particles)
	return particles


func _on_area_entered(other: Area3D, wave: Dictionary) -> void:
	var hurtbox := other as HurtboxComponent
	var hit: Array[HurtboxComponent] = wave.hit
	if hurtbox == null or hurtbox in hit or not hurtbox.is_alive():
		return
	if is_instance_valid(_user) and hurtbox.owner == _user:
		return
	hit.append(hurtbox)
	var source: Node = _user if is_instance_valid(_user) else null
	var info := DamageInfo.new(_attack.damage, _attack.damage_type, _direction * _attack.knockback, source)
	info.direction = _direction
	info.attack = _attack
	hurtbox.receive_hit(info)
	_impacts.play_at(hurtbox.global_position, _direction)


func _on_body_entered(body: Node3D, wave: Dictionary) -> void:
	# Chỉ vật cản thế giới làm tan nhát gió; thân quái (CharacterBody) đã xử lý qua hurtbox
	if body is CollisionObject3D and (body as CollisionObject3D).collision_layer & world_mask != 0 and not body is Character:
		var index := _waves.find(wave)
		if index >= 0:
			_impacts.play_at((wave.area as Area3D).global_position, _direction)
			_remove_wave(index)


func _remove_wave(index: int) -> void:
	(_waves[index].particles as CPUParticles3D).emitting = false
	(_waves[index].area as Area3D).queue_free()
	_waves.remove_at(index)
