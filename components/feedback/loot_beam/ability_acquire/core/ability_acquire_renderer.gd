class_name AbilityAcquireRenderer
extends Node3D
## Hạt dùng slot cố định trong MultiMesh; shader chạy chuyển động, CPU chỉ gửi thời gian.
const Tuning = preload("res://resources/feedback/ability_acquire/ability_acquire_data.gd")
const MOTE_SHADER: Shader = preload("res://assets/shaders/screen/ability_acquire/spatial/acquire_motes.gdshader")
const RAY_SHADER: Shader = preload("res://assets/shaders/screen/ability_acquire/spatial/acquire_rays.gdshader")
const RING_SHADER: Shader = preload("res://assets/shaders/screen/ability_acquire/spatial/acquire_ring.gdshader")
const BOOK_SHADER: Shader = preload("res://assets/shaders/screen/ability_acquire/book/acquire_book.gdshader")
const MAX_RAYS: int = 12
@export var data: Tuning = preload("res://resources/feedback/ability_acquire/ability_acquire_default.tres")
static var _quad: QuadMesh
static var _ray_meshes: Dictionary[int, ArrayMesh] = {}
static var _live_count: int = 0
var motes: MultiMeshInstance3D
var rays: MeshInstance3D
var ring: MeshInstance3D
var _mote_mat: ShaderMaterial
var _ray_mat: ShaderMaterial
var _ring_mat: ShaderMaterial
var _warmup: Node3D
var _source: Node3D
var _source_transform: Transform3D
var _source_visible: bool = true
var _meshes: Array[MeshInstance3D] = []
var _originals: Array[Material] = []
var _dissolves: Array[ShaderMaterial] = []
var _emitters: Array[GeometryInstance3D] = []
var _emitter_states: PackedByteArray = PackedByteArray()
var _emitter_visibility: PackedByteArray = PackedByteArray()
var _actor_visual: Node3D
var _active_slots: int = 0
var _accent: Color
## Tạo tất cả slot và material trước màn nhận kỹ năng, không tạo ở nhịp bùng.
func _ready() -> void:
	_live_count += 1
	top_level = true
	set_process(false)
	_warmup = Node3D.new()
	_warmup.name = "WarmupSources"
	_warmup.hide()
	add_child(_warmup)
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	_mote_mat = _make_material(MOTE_SHADER)
	_ray_mat = _make_material(RAY_SHADER)
	_ring_mat = _make_material(RING_SHADER)
	motes = MultiMeshInstance3D.new()
	motes.name = "Motes"
	motes.multimesh = MultiMesh.new()
	motes.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	motes.multimesh.use_custom_data = true
	motes.multimesh.mesh = _quad
	motes.multimesh.instance_count = clampi(data.pool_capacity, 1, 96)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = data.particle_seed
	for index: int in range(motes.multimesh.instance_count):
		motes.multimesh.set_instance_transform(index, Transform3D.IDENTITY)
		motes.multimesh.set_instance_custom_data(index, Color(random.randf(),random.randf(),random.randf(),1))
	motes.material_override = _mote_mat
	motes.custom_aabb = AABB(-Vector3.ONE * data.gather_radius * 4.0, Vector3.ONE * data.gather_radius * 8.0)
	_add_mesh(motes)
	rays = MeshInstance3D.new()
	rays.name = "StreamsAndRays"
	rays.mesh = _get_rays(data.ray_segments)
	rays.material_override = _ray_mat
	rays.custom_aabb = motes.custom_aabb
	_add_mesh(rays)
	ring = MeshInstance3D.new()
	ring.name = "GroundRing"
	ring.mesh = _quad
	ring.material_override = _ring_mat
	ring.custom_aabb = motes.custom_aabb
	_add_mesh(ring)
	_prepare_parameters()
	_add_probe(motes, 1)
	_add_probe(rays, 2)
	_add_probe(ring, 2)
	clear_visuals()
## Cache dùng chung được nhả khi khu cuối cùng có hiệu ứng này rời cây.
func _exit_tree() -> void:
	_live_count -= 1
	if _live_count <= 0:
		_quad = null
		_ray_meshes.clear()
## Nguồn sách được chuẩn bị từ ready của pickup, trước ShaderWarmup của khu.
func prepare_source(source: Node3D) -> void:
	if source == _source: return
	_source = source
	if not is_instance_valid(source): return
	for node: Node in source.find_children("*", "", true, false):
		if node is MeshInstance3D:
			var mesh: MeshInstance3D = node as MeshInstance3D
			if mesh.mesh == null: continue
			_meshes.append(mesh)
			_originals.append(mesh.material_override)
			var material: ShaderMaterial = _make_material(BOOK_SHADER)
			var base: Color = data.book_fallback
			var old: Material = mesh.get_active_material(0)
			if old is BaseMaterial3D: base = (old as BaseMaterial3D).albedo_color
			elif old is ShaderMaterial:
				var old_color: Variant = (old as ShaderMaterial).get_shader_parameter(&"book_color")
				if old_color is Color: base = old_color
			material.set_shader_parameter(&"base_color", base)
			material.set_shader_parameter(&"grain_scale", data.book_grain)
			material.set_shader_parameter(&"edge_width", data.book_edge)
			_dissolves.append(material)
			var probe: MeshInstance3D = MeshInstance3D.new()
			probe.mesh = mesh.mesh
			probe.material_override = material.duplicate() as ShaderMaterial
			(probe.material_override as ShaderMaterial).set_shader_parameter(&"dissolve", 0.3)
			probe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_warmup.add_child(probe)
		elif node is CPUParticles3D or node is GPUParticles3D:
			_emitters.append(node as GeometryInstance3D)
			_emitter_states.append(1 if bool(node.get("emitting")) else 0)
			_emitter_visibility.append(1 if (node as GeometryInstance3D).visible else 0)
## Tham chiếu model được cache một lần, không tìm cây trong mỗi frame.
func bind_actor(actor: Node3D, visual: Node3D, ability: AbilityData) -> void:
	global_transform = Transform3D(Basis.IDENTITY, actor.global_position)
	_actor_visual = visual
	_accent = ability.accent_color if ability != null else data.fallback_accent
	for material: ShaderMaterial in [_mote_mat, _ray_mat, _ring_mat]:
		material.set_shader_parameter(&"accent", _accent)
	_mote_mat.set_shader_parameter(&"textured", ability.particle_texture != null)
	if ability.particle_texture != null: _mote_mat.set_shader_parameter(&"mote_texture", ability.particle_texture)
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null: _mote_mat.set_shader_parameter(&"toward_camera", camera.global_basis.z.normalized())
	if is_instance_valid(_source):
		_source_transform = _source.global_transform
		_source_visible = _source.visible
		for index: int in range(_meshes.size()):
			_meshes[index].material_override = _dissolves[index]
			_dissolves[index].set_shader_parameter(&"accent", _accent)
			_dissolves[index].set_shader_parameter(&"dissolve", 0.0)
		for emitter: GeometryInstance3D in _emitters:
			emitter.set(&"emitting", false)
			emitter.hide()
## Chuyển số slot một lần khi vào pha; số không luôn có nghĩa là không vẽ hạt.
func enter_phase(phase: int) -> void:
	clear_visuals()
	var count: int = data.mote_count
	if phase == 2: count = data.spark_count
	elif phase == 3: count = data.dust_count
	if phase == 2 and data.burst_intensity <= 0.0: count = 0
	_active_slots = clampi(count, 0, motes.multimesh.instance_count)
	motes.multimesh.visible_instance_count = _active_slots
	motes.visible = _active_slots > 0
	rays.visible = phase <= 2 and (phase != 2 or data.burst_intensity > 0.0)
	ring.visible = phase == 2 and data.burst_intensity > 0.0
	_mote_mat.set_shader_parameter(&"phase", phase)
	_mote_mat.set_shader_parameter(&"total_count",maxi(_active_slots,1))
	_ray_mat.set_shader_parameter(&"phase", phase)
	_ray_mat.set_shader_parameter(&"ray_count", float(data.ray_count if phase == 2 else data.stream_count))
	update_phase(phase, 0.0, 0.0)
## Các uniform thay đổi theo frame đều là scalar; không dựng lại mảng hoặc mesh.
func update_phase(phase: int, progress: float, clock: float) -> void:
	var focus: float = data.focus_height
	if is_instance_valid(_actor_visual): focus += _actor_visual.global_position.y - global_position.y
	var strength: float = clampf(data.burst_intensity, 0.0, data.maximum_intensity) if phase == 2 else 1.0
	var alpha: float = strength
	_mote_mat.set_shader_parameter(&"clock", clock)
	_mote_mat.set_shader_parameter(&"progress", progress)
	_mote_mat.set_shader_parameter(&"focus_height", focus)
	_mote_mat.set_shader_parameter(&"opacity", alpha)
	_ray_mat.set_shader_parameter(&"clock", clock)
	_ray_mat.set_shader_parameter(&"progress", progress)
	_ray_mat.set_shader_parameter(&"focus_height", focus)
	if is_instance_valid(_source): _ray_mat.set_shader_parameter(&"source_point", _source.global_position-global_position)
	_ray_mat.set_shader_parameter(&"opacity", alpha * (1.0 - progress if phase == 2 else 1.0))
	_ring_mat.set_shader_parameter(&"progress", progress)
	_ring_mat.set_shader_parameter(&"opacity", strength)
## Sách thật đi lên rồi bị xói, thay vì biến mất ngay khi bấm nhặt.
func update_book(progress: float) -> void:
	if not is_instance_valid(_source): return
	_source.global_position = _source_transform.origin + Vector3.UP * data.book_rise * progress
	for material: ShaderMaterial in _dissolves:
		material.set_shader_parameter(&"dissolve", progress)
	if progress >= 1.0: _source.hide()
## Không để mesh alpha bằng không vẫn tốn draw ở trạng thái nghỉ.
func clear_visuals() -> void:
	_active_slots = 0
	if is_instance_valid(motes):
		motes.hide()
		motes.multimesh.visible_instance_count = 0
	if is_instance_valid(rays): rays.hide()
	if is_instance_valid(ring): ring.hide()
## Trả lại material và transform cũ, kể cả khi dừng ở giữa lúc sách đang tan.
func restore_source(consumed: bool) -> void:
	clear_visuals()
	if not is_instance_valid(_source): return
	_source.global_transform = _source_transform
	_source.visible = _source_visible and not consumed
	for index: int in range(_meshes.size()):
		if is_instance_valid(_meshes[index]): _meshes[index].material_override = _originals[index]
	for index: int in range(_emitters.size()):
		if is_instance_valid(_emitters[index]):
			_emitters[index].visible = _emitter_visibility[index] == 1 and not consumed
			_emitters[index].set(&"emitting", _emitter_states[index] == 1 and not consumed)
## API kiểm tra pool cố định mà không truy cập biến riêng.
func get_active_slot_count() -> int:
	return _active_slots
## Nguồn warmup gồm cả biến thể instancing và material sách đã chuẩn bị.
func get_shader_warmup_sources() -> Array[Node]:
	return [self]
## Tất cả hình nhỏ đều bỏ bóng trước khi được thêm vào renderer.
func _add_mesh(mesh: GeometryInstance3D) -> void:
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.hide()
	add_child(mesh)
## Material chỉ tạo khi chuẩn bị, không ở nhịp bùng.
func _make_material(shader: Shader) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material
## Ghi tham số cố định một lần để giữ vòng lặp nóng nhỏ.
func _prepare_parameters() -> void:
	_mote_mat.set_shader_parameter(&"hot_color", data.hot_color)
	_mote_mat.set_shader_parameter(&"landing_start", data.landing_start)
	_mote_mat.set_shader_parameter(&"dust_size", data.dust_size)
	_mote_mat.set_shader_parameter(&"dust_height", data.dust_height)
	_mote_mat.set_shader_parameter(&"radius", data.gather_radius)
	_mote_mat.set_shader_parameter(&"height_spread", data.gather_height)
	_mote_mat.set_shader_parameter(&"spin", data.gather_spin)
	_mote_mat.set_shader_parameter(&"gather_acceleration",data.gather_acceleration)
	_mote_mat.set_shader_parameter(&"gather_stagger",data.gather_stagger)
	_mote_mat.set_shader_parameter(&"mote_stretch",data.mote_stretch)
	_mote_mat.set_shader_parameter(&"mote_size", data.mote_size)
	_mote_mat.set_shader_parameter(&"foreground_size", data.foreground_size)
	_mote_mat.set_shader_parameter(&"foreground_depth", data.foreground_depth)
	_mote_mat.set_shader_parameter(&"foreground_spread", data.foreground_spread)
	_mote_mat.set_shader_parameter(&"foreground_count", clampi(data.foreground_count, 0, data.mote_count))
	_mote_mat.set_shader_parameter(&"spark_radius", data.spark_radius)
	_mote_mat.set_shader_parameter(&"dust_radius", data.dust_radius)
	_ray_mat.set_shader_parameter(&"hot_color", data.hot_color)
	_ray_mat.set_shader_parameter(&"ray_length", data.ray_length)
	_ray_mat.set_shader_parameter(&"ray_width", data.ray_width)
	_ray_mat.set_shader_parameter(&"core_size", data.core_size)
	_ray_mat.set_shader_parameter(&"charge_core_ratio",data.charge_core_ratio)
	_ray_mat.set_shader_parameter(&"charge_power",data.charge_power)
	_ray_mat.set_shader_parameter(&"ray_length_variation",data.ray_length_variation)
	_ray_mat.set_shader_parameter(&"ray_curl",data.ray_curl)
	_ray_mat.set_shader_parameter(&"stream_width", data.stream_width)
	_ray_mat.set_shader_parameter(&"stream_radius", data.stream_radius)
	_ray_mat.set_shader_parameter(&"stream_height", data.stream_height)
	_ring_mat.set_shader_parameter(&"radius", data.ring_radius)
	_ring_mat.set_shader_parameter(&"width", data.ring_width)
	_ring_mat.set_shader_parameter(&"floor_height", data.ring_floor)
## Proxy vẽ thật dưới màn đen; không dùng transparency của GeometryInstance với shader tự viết.
func _add_probe(source: GeometryInstance3D, phase: int) -> void:
	var probe: GeometryInstance3D
	if source is MultiMeshInstance3D:
		var multi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		multi.multimesh = (source as MultiMeshInstance3D).multimesh
		probe = multi
	else:
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.mesh = (source as MeshInstance3D).mesh
		probe = mesh
	var material: ShaderMaterial = (source.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	material.set_shader_parameter(&"phase", phase)
	material.set_shader_parameter(&"progress", 0.35)
	material.set_shader_parameter(&"opacity", 1.0)
	probe.material_override = material
	probe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_warmup.add_child(probe)
## Mesh ray dùng chung giữa các pickup có cùng độ chia.
static func _get_rays(segments: int) -> ArrayMesh:
	segments = clampi(segments, 4, 32)
	if _ray_meshes.has(segments): return _ray_meshes[segments]
	var vertices: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var uv2: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for ray: int in range(MAX_RAYS+1):
		var offset: int = vertices.size()
		for step: int in range(segments + 1):
			for side: int in range(2):
				vertices.append(Vector3.ZERO)
				uv.append(Vector2(float(step)/segments, float(side)))
				uv2.append(Vector2(ray, 1 if ray == MAX_RAYS else 0))
		for step: int in range(segments):
			var a: int = offset + step * 2
			indices.append_array(PackedInt32Array([a,a+2,a+1,a+1,a+2,a+3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_ray_meshes[segments] = mesh
	return mesh
