class_name PyralonFireFx
extends Node3D
## Mesh VFX dùng chung cho vòng nổ, khe đất, cột lửa, vệt chém, sóng xung và áp tường; tự trả lại pool.

const FIRE := preload("res://entities/bosses/fire/pyralon/combat/pyralon_fire.gdshader")

enum Kind {
	FEATHER,
	WARNING,
	BURST,
	SHOCK,
	CRACK,
	ARC,
	GEYSER,
	FISSURE_LOCK,
	FISSURE_HEAD,
	WALL_SPLASH,
	WHITE_IMPACT,
	EMBER_BURST,
	SLAM_BURST,
	FISSURE_CRATER,
	COMMAND_PULSE,
	DIRT_CHIP,
}

static var _plane: PlaneMesh
static var _quad: QuadMesh
static var _pillar_mesh: ArrayMesh
static var _chunk_mesh: ArrayMesh
static var _smoke_mesh: ArrayMesh
static var _spike_mesh: ArrayMesh
static var _spike_material: StandardMaterial3D

var _pool: ObjectPool
var _kind: Kind = Kind.SHOCK
var _age: float
var _life: float
var _base_z_scale: float = 1.0
var _persistent: bool

var _disc: MeshInstance3D
var _arc_crest: MeshInstance3D
var _pillar: MeshInstance3D
var _wall: MeshInstance3D
var _chunks: MeshInstance3D
var _smoke: MeshInstance3D
var _spike: MeshInstance3D

var _disc_mat: ShaderMaterial
var _pillar_mat: ShaderMaterial
var _wall_mat: ShaderMaterial
var _chunk_mat: ShaderMaterial
var _smoke_mat: ShaderMaterial


func _ready() -> void:
	top_level = true
	_pool = get_parent() as ObjectPool
	_ensure_shared_meshes()

	_disc = _make_shader_mesh(_plane)
	_disc_mat = _disc.material_override as ShaderMaterial

	# Lớp lửa thứ hai nhô nhẹ giúp lưỡi liềm có độ dày khi nhìn từ camera chéo.
	_arc_crest = MeshInstance3D.new()
	_arc_crest.mesh = _plane
	_arc_crest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arc_crest.material_override = _disc_mat
	_arc_crest.position.y = 0.07
	add_child(_arc_crest)

	_pillar = _make_shader_mesh(_pillar_mesh)
	_pillar_mat = _pillar.material_override as ShaderMaterial
	_pillar_mat.set_shader_parameter(&"kind", 6)

	_wall = _make_shader_mesh(_quad)
	_wall_mat = _wall.material_override as ShaderMaterial
	_wall_mat.set_shader_parameter(&"kind", 10)

	_chunks = _make_shader_mesh(_chunk_mesh)
	_chunk_mat = _chunks.material_override as ShaderMaterial
	_chunk_mat.set_shader_parameter(&"kind", 11)

	_smoke = _make_shader_mesh(_smoke_mesh)
	_smoke_mat = _smoke.material_override as ShaderMaterial
	_smoke_mat.set_shader_parameter(&"kind", 12)

	_spike = MeshInstance3D.new()
	_spike.mesh = _spike_mesh
	_spike.material_override = _spike_material
	_spike.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_spike)

	pool_released()


func play(kind: Kind, at: Vector3, direction: Vector3, size: Vector2, life: float) -> void:
	_kind = kind
	_life = maxf(life, 0.01)
	_age = 0.0
	_persistent = kind in [Kind.ARC, Kind.FISSURE_HEAD]
	_base_z_scale = size.y

	var lift := 0.035
	if kind in [Kind.WALL_SPLASH, Kind.EMBER_BURST, Kind.ARC, Kind.DIRT_CHIP]:
		lift = 0.0
	elif kind == Kind.FISSURE_CRATER:
		lift = 0.042
	var basis := _basis_for(kind, direction)
	global_transform = Transform3D(basis, at + Vector3.UP * lift)

	_hide_all_layers()
	_disc_mat.set_shader_parameter(&"age", 0.0)
	_disc_mat.set_shader_parameter(&"heat", 0.0)
	_disc_mat.set_shader_parameter(&"white", false)
	_pillar_mat.set_shader_parameter(&"age", 0.0)
	_wall_mat.set_shader_parameter(&"age", 0.0)
	_chunk_mat.set_shader_parameter(&"age", 0.0)
	_chunk_mat.set_shader_parameter(&"white", false)
	_chunk_mat.set_shader_parameter(&"heat", 0.0)
	_smoke_mat.set_shader_parameter(&"age", 0.0)

	match kind:
		Kind.WARNING:
			_disc.visible = true
			_disc.scale = Vector3(size.x, 1.0, size.y)
			_disc_mat.set_shader_parameter(&"kind", 1)
		Kind.FISSURE_LOCK, Kind.FISSURE_CRATER:
			_disc.visible = true
			_disc.scale = Vector3(size.x, 1.0, size.y)
			_disc_mat.set_shader_parameter(&"kind", 8)
		Kind.BURST:
			# Nổ lông vàng mở rộng lõi lửa & khói để phủ đầy vòng tròn cảnh báo hơn.
			_disc.visible = true
			_disc.scale = Vector3(size.x, 1.0, size.y)
			_disc_mat.set_shader_parameter(&"kind", 2)
			_disc_mat.set_shader_parameter(&"white", false)
			_chunks.visible = true
			_chunks.scale = Vector3(size.x * 0.96, size.x * 0.92, size.y * 0.96)
			_smoke.visible = true
			_smoke.scale = Vector3(size.x * 0.88, size.x * 0.82, size.y * 0.88)
		Kind.GEYSER:
			# Ngọn lửa tự nhiên bùng lên to, dày và bự từ hố nứt đất (không vòng tròn đỏ), giữ tầm nhìn boss rõ.
			_disc.visible = true
			_disc.scale = Vector3(size.x * 1.18, 1.0, size.y * 1.18)
			_disc_mat.set_shader_parameter(&"kind", 2)
			_disc_mat.set_shader_parameter(&"white", true)
			_pillar.visible = true
			_pillar.rotation.y = randf() * TAU
			_pillar.scale = Vector3(size.x * 1.12, minf(size.x * 1.05, 3.0), size.y * 1.12)
			_smoke.visible = true
			_smoke.scale = Vector3(size.x * 1.02, minf(size.x * 1.05, 2.85), size.y * 1.02)
		Kind.SLAM_BURST:
			_disc.visible = true
			_disc.scale = Vector3(size.x, 1.0, size.y)
			_disc_mat.set_shader_parameter(&"kind", 3)
			_chunks.visible = true
			_chunks.scale = Vector3(size.x * 0.62, size.x * 0.62, size.y * 0.62)
			_smoke.visible = true
			_smoke.scale = Vector3(size.x * 0.80, size.x * 0.68, size.y * 0.80)
		Kind.COMMAND_PULSE:
			_disc.visible = true
			_disc.scale = Vector3(size.x, 1.0, size.y)
			_disc_mat.set_shader_parameter(&"kind", 13)
		Kind.SHOCK:
			_disc.visible = true
			_disc.scale = Vector3(size.x, 1.0, size.y)
			_disc_mat.set_shader_parameter(&"kind", 3)
		Kind.WHITE_IMPACT:
			_disc.visible = true
			_disc.scale = Vector3(size.x, 1.0, size.y)
			_disc_mat.set_shader_parameter(&"kind", 3)
			_disc_mat.set_shader_parameter(&"white", true)
			_spike.visible = true
			_spike.rotation = Vector3(0.42, randf() * TAU, 0.18)
			_spike.scale = Vector3.ONE * clampf(size.x * 1.18, 0.72, 1.30)
		Kind.EMBER_BURST:
			_chunks.visible = true
			_chunks.scale = Vector3.ONE * size.x
			_chunk_mat.set_shader_parameter(&"white", true)
		Kind.DIRT_CHIP:
			_chunks.visible = true
			_chunks.scale = Vector3.ONE * size.x
			_chunk_mat.set_shader_parameter(&"heat", 1.0)
		Kind.CRACK:
			_disc.visible = true
			_disc.scale = Vector3(size.x, 1.0, size.y)
			_disc_mat.set_shader_parameter(&"kind", 4)
			_disc_mat.set_shader_parameter(&"heat", randf())
		Kind.ARC:
			_disc.visible = true
			_disc.scale = Vector3(size.x, 1.0, size.y)
			_disc_mat.set_shader_parameter(&"kind", 5)
			_arc_crest.visible = true
			_arc_crest.scale = Vector3(size.x * 0.94, 1.0, size.y * 0.88)
		Kind.WALL_SPLASH:
			_wall.visible = true
			_wall.scale = Vector3(size.x, size.y, 1.0)
			_chunks.visible = true
			_chunks.scale = Vector3(size.x * 0.24, size.y * 0.30, 0.20)
			_chunk_mat.set_shader_parameter(&"white", true)
		_:
			_disc.visible = true
			_disc.scale = Vector3(size.x, 1.0, size.y)
			_disc_mat.set_shader_parameter(&"kind", int(kind))

	show()
	set_physics_process(true)
	reset_physics_interpolation()


func set_pose(at: Vector3, direction: Vector3) -> void:
	if not direction.is_zero_approx():
		global_basis = _basis_for(_kind, direction)
	global_position = at


func set_arc_wall_press(press: float, z_ratio: float) -> void:
	var clamped := clampf(press, 0.0, 1.0)
	_disc_mat.set_shader_parameter(&"heat", clamped)
	var z_now := _base_z_scale * maxf(0.10, z_ratio)
	_disc.scale.z = z_now
	_arc_crest.visible = clamped < 0.25
	_arc_crest.scale.z = z_now * 0.88


func pool_released() -> void:
	set_physics_process(false)
	hide()


func _physics_process(delta: float) -> void:
	_age += delta
	var phase := minf(1.0, _age / _life)
	if phase >= 1.0 and not _persistent:
		_pool.release(self)
		return
	if _disc.visible:
		_disc_mat.set_shader_parameter(&"age", phase)
		if _kind in [Kind.WARNING, Kind.FISSURE_LOCK, Kind.FISSURE_CRATER]:
			_disc_mat.set_shader_parameter(&"heat", phase)
	if _pillar.visible:
		_pillar_mat.set_shader_parameter(&"age", phase)
	if _wall.visible:
		_wall_mat.set_shader_parameter(&"age", phase)
	if _chunks.visible:
		_chunk_mat.set_shader_parameter(&"age", phase)
	if _smoke.visible:
		_smoke_mat.set_shader_parameter(&"age", phase)
	if _spike.visible:
		var shrink := 1.0 - smoothstep(0.55, 1.0, phase)
		_spike.scale = Vector3.ONE * (0.98 * maxf(0.01, shrink))


func _hide_all_layers() -> void:
	_disc.visible = false
	_arc_crest.visible = false
	_pillar.visible = false
	_wall.visible = false
	_chunks.visible = false
	_smoke.visible = false
	_spike.visible = false


func _basis_for(kind: Kind, direction: Vector3) -> Basis:
	if direction.is_zero_approx():
		return Basis.IDENTITY
	var dir := direction.normalized()
	if kind == Kind.WHITE_IMPACT:
		if dir.y > 0.85:
			return Basis.IDENTITY
		var tangent := Vector3.UP.cross(dir)
		if tangent.length_squared() < 0.001:
			tangent = Vector3.RIGHT
		tangent = tangent.normalized()
		var bitangent := dir.cross(tangent).normalized()
		return Basis(tangent, dir, bitangent)
	var up := Vector3.RIGHT if absf(dir.dot(Vector3.UP)) > 0.95 else Vector3.UP
	return Basis.looking_at(dir, up, true)


func _make_shader_mesh(geometry: Mesh) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = geometry
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = FIRE
	node.material_override = material
	add_child(node)
	return node


static func _ensure_shared_meshes() -> void:
	if _plane != null:
		return
	_plane = PlaneMesh.new()
	_plane.size = Vector2(2.0, 2.0)

	_quad = QuadMesh.new()
	_quad.size = Vector2(2.0, 2.0)

	_pillar_mesh = _build_pillar_mesh()
	_chunk_mesh = _build_chunk_mesh()
	_smoke_mesh = _build_smoke_mesh()
	_spike_mesh = _build_spike_mesh()

	_spike_material = StandardMaterial3D.new()
	_spike_material.vertex_color_use_as_albedo = true
	_spike_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_spike_material.emission_enabled = true
	_spike_material.emission = Color("#ffe5b3")
	_spike_material.emission_energy_multiplier = 0.40


static func _build_pillar_mesh() -> ArrayMesh:
	# Bốn mặt đứng cắt nhau 45 độ giúp khối lửa bùng nở to dày từ mọi góc camera chơi.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in 4:
		var angle := PI * index / 4.0
		var right := Vector3(cos(angle), 0.0, sin(angle))
		var bl := -right
		var br := right
		var tl := -right + Vector3.UP * 2.55
		var tr := right + Vector3.UP * 2.55
		surface.set_uv(Vector2(0.0, 1.0))
		surface.add_vertex(bl)
		surface.set_uv(Vector2(1.0, 1.0))
		surface.add_vertex(br)
		surface.set_uv(Vector2(1.0, 0.0))
		surface.add_vertex(tr)
		surface.set_uv(Vector2(0.0, 1.0))
		surface.add_vertex(bl)
		surface.set_uv(Vector2(1.0, 0.0))
		surface.add_vertex(tr)
		surface.set_uv(Vector2(0.0, 0.0))
		surface.add_vertex(tl)
	surface.generate_normals()
	return surface.commit()


static func _build_chunk_mesh() -> ArrayMesh:
	# 12 mảnh lửa hình chóp góc cạnh bung tỏa theo vòng tròn (boom lông vàng / đá vỡ đất).
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4109
	const COUNT := 12
	for i: int in COUNT:
		var angle_norm := (float(i) + rng.randf_range(-0.28, 0.28)) / float(COUNT)
		var angle := angle_norm * TAU
		var speed := rng.randf_range(0.45, 1.0)
		var lift := rng.randf_range(0.35, 1.0)
		var w := rng.randf_range(0.16, 0.27)
		var h := rng.randf_range(0.36, 0.62)
		var fwd := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-fwd.z, 0.0, fwd.x)
		var base_c := Color(fposmod(angle_norm, 1.0), speed, lift, 0.0)
		var mid_c := Color(fposmod(angle_norm, 1.0), speed, lift, 0.45)
		var tip_c := Color(fposmod(angle_norm, 1.0), speed, lift, 1.0)
		var p_bot := -fwd * (w * 0.35)
		var p_l := side * w + Vector3.UP * (h * 0.36)
		var p_r := -side * w + Vector3.UP * (h * 0.36)
		var p_f := fwd * (w * 1.1) + Vector3.UP * (h * 0.30)
		var p_top := fwd * (w * 0.55) + Vector3.UP * h
		_tri_colored(surface, p_bot, p_l, p_top, base_c, mid_c, tip_c)
		_tri_colored(surface, p_bot, p_top, p_r, base_c, tip_c, mid_c)
		_tri_colored(surface, p_l, p_f, p_top, mid_c, mid_c, tip_c)
		_tri_colored(surface, p_f, p_r, p_top, mid_c, mid_c, tip_c)
	surface.generate_normals()
	return surface.commit()


static func _build_smoke_mesh() -> ArrayMesh:
	# 8 khối khói than low-poly hình bát diện bốc lên phía trên lửa nổ.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	const COUNT := 8
	for i: int in COUNT:
		var angle_norm := (float(i) + rng.randf_range(-0.3, 0.3)) / float(COUNT)
		var rad := rng.randf_range(0.25, 1.0)
		var rise := rng.randf_range(0.40, 1.0)
		var r := rng.randf_range(0.26, 0.42)
		var bot_c := Color(fposmod(angle_norm, 1.0), rad, rise, 0.0)
		var mid_c := Color(fposmod(angle_norm, 1.0), rad, rise, 0.5)
		var top_c := Color(fposmod(angle_norm, 1.0), rad, rise, 1.0)
		var px := Vector3(r, 0.0, 0.0)
		var nx := Vector3(-r, 0.0, 0.0)
		var pz := Vector3(0.0, 0.0, r)
		var nz := Vector3(0.0, 0.0, -r)
		var py := Vector3(0.0, r * 0.85, 0.0)
		var ny := Vector3(0.0, -r * 0.65, 0.0)
		_tri_colored(surface, px, py, pz, mid_c, top_c, mid_c)
		_tri_colored(surface, pz, py, nx, mid_c, top_c, mid_c)
		_tri_colored(surface, nx, py, nz, mid_c, top_c, mid_c)
		_tri_colored(surface, nz, py, px, mid_c, top_c, mid_c)
		_tri_colored(surface, px, pz, ny, mid_c, mid_c, bot_c)
		_tri_colored(surface, pz, nx, ny, mid_c, mid_c, bot_c)
		_tri_colored(surface, nx, nz, ny, mid_c, mid_c, bot_c)
		_tri_colored(surface, nz, px, ny, mid_c, mid_c, bot_c)
	surface.generate_normals()
	return surface.commit()


static func _build_spike_mesh() -> ArrayMesh:
	# Lông trắng chi tiết thuôn dài cắm nghiêng xuống sàn khi đập trúng (đồng bộ design lông trắng mới).
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ivory := Color("#fffcf2")
	var cream := Color("#eef1f5")
	var barb := Color("#c6cdd7")
	var vein := Color("#838b98")

	var q0 := Vector3(0.0, 0.0, 0.0)
	var s0 := Vector3(0.0, 0.24, 0.01)
	var s1 := Vector3(0.0, 0.56, 0.02)
	var s2 := Vector3(0.01, 0.86, 0.025)
	var tip := Vector3(0.03, 1.18, 0.03)

	var l0 := Vector3(-0.08, 0.34, 0.0)
	var l1 := Vector3(-0.15, 0.58, 0.0)
	var ln := Vector3(-0.08, 0.64, 0.01)
	var l2 := Vector3(-0.13, 0.84, 0.0)
	var l3 := Vector3(-0.06, 1.04, 0.0)

	var r0 := Vector3(0.06, 0.32, 0.0)
	var r1 := Vector3(0.12, 0.62, 0.0)
	var rn := Vector3(0.07, 0.68, 0.01)
	var r2 := Vector3(0.10, 0.90, 0.0)

	# Cuống cắm.
	_tri_colored(surface, q0 + Vector3(-0.015, 0, 0), q0 + Vector3(0.015, 0, 0), s0, vein, vein, vein)
	# Phiến trái.
	_tri_colored(surface, s0, l0, s1, vein, barb, vein)
	_tri_colored(surface, l0, l1, s1, barb, ivory, vein)
	_tri_colored(surface, l1, ln, s1, ivory, barb, vein)
	_tri_colored(surface, s1, ln, s2, vein, barb, vein)
	_tri_colored(surface, ln, l2, s2, barb, ivory, vein)
	_tri_colored(surface, l2, l3, s2, ivory, cream, vein)
	_tri_colored(surface, l3, tip, s2, cream, ivory, vein)
	# Phiến phải.
	_tri_colored(surface, s0, s1, r0, vein, vein, barb)
	_tri_colored(surface, s1, r1, r0, vein, cream, barb)
	_tri_colored(surface, s1, rn, r1, vein, barb, cream)
	_tri_colored(surface, s1, s2, rn, vein, vein, barb)
	_tri_colored(surface, s2, r2, rn, vein, ivory, barb)
	_tri_colored(surface, s2, tip, r2, vein, ivory, ivory)
	surface.generate_normals()
	return surface.commit()


static func _tri_colored(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	ca: Color,
	cb: Color,
	cc: Color
) -> void:
	surface.set_color(ca)
	surface.add_vertex(a)
	surface.set_color(cb)
	surface.add_vertex(b)
	surface.set_color(cc)
	surface.add_vertex(c)
