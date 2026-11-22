class_name PyralonSkyCrater
extends Node3D
## Bộ VFX riêng biệt cho cú đáp Sky Dive: hố crater 3D nứt lở thật + cột lửa phun trào đa tầng + đá văng + sóng xung kích trang trí.

const SHADER := preload("res://entities/bosses/fire/pyralon/combat/pyralon_sky_vfx.gdshader")
const GEYSER_LIFE := 0.92
const DEBRIS_LIFE := 1.05

static var _crater_mesh: ArrayMesh
static var _geyser_mesh: ArrayMesh
static var _debris_mesh: ArrayMesh
static var _shock_plane: PlaneMesh

var _pool: ObjectPool
var _age: float = 0.0
var _life: float = 3.2
var _shock_life: float = 0.55
var _heavy: bool = false

var _crater: MeshInstance3D
var _geyser: MeshInstance3D
var _debris: MeshInstance3D
var _shock: MeshInstance3D

var _crater_mat: ShaderMaterial
var _geyser_mat: ShaderMaterial
var _debris_mat: ShaderMaterial
var _shock_mat: ShaderMaterial


func _ready() -> void:
	top_level = true
	_pool = get_parent() as ObjectPool
	_ensure_shared_meshes()

	_crater = _make_layer(_crater_mesh, 0)
	_crater_mat = _crater.material_override as ShaderMaterial
	_crater_mat.render_priority = -1
	_geyser = _make_layer(_geyser_mesh, 1)
	_geyser_mat = _geyser.material_override as ShaderMaterial
	_geyser_mat.render_priority = 2
	_debris = _make_layer(_debris_mesh, 2)
	_debris_mat = _debris.material_override as ShaderMaterial
	_debris_mat.render_priority = 1
	_shock = _make_layer(_shock_plane, 3)
	_shock_mat = _shock.material_override as ShaderMaterial
	_shock_mat.render_priority = 0
	_shock.position.y = 0.055
	pool_released()


func play(at: Vector3, radius: float, heavy: bool, crater_life: float = 3.2) -> void:
	_age = 0.0
	_life = maxf(crater_life, 1.2)
	_heavy = heavy
	_shock_life = 0.85 if heavy else 0.55
	var heavy_f := 1.0 if heavy else 0.0

	global_transform = Transform3D(Basis.IDENTITY, at)
	var yaw := randf() * TAU

	_crater.rotation.y = yaw
	_crater.scale = Vector3(radius * 1.12, lerpf(0.85, 1.35, heavy_f), radius * 1.12)
	_crater_mat.set_shader_parameter(&"age", 0.0)
	_crater_mat.set_shader_parameter(&"heavy", heavy_f)
	_crater.show()

	_geyser.rotation.y = yaw * 0.7
	var geyser_h := clampf(radius * (2.20 if heavy else 1.85), 5.6, 10.6)
	_geyser.scale = Vector3(radius * 0.48, geyser_h, radius * 0.48)
	_geyser_mat.set_shader_parameter(&"age", 0.0)
	_geyser_mat.set_shader_parameter(&"heavy", heavy_f)
	_geyser.show()

	_debris.rotation.y = randf() * TAU
	_debris.scale = Vector3.ONE * clampf(radius * 0.36, 0.9, 1.85)
	_debris_mat.set_shader_parameter(&"age", 0.0)
	_debris_mat.set_shader_parameter(&"heavy", heavy_f)
	_debris.show()

	var shock_r := 25.0 if heavy else 14.5
	_shock.scale = Vector3(shock_r, 1.0, shock_r)
	_shock_mat.set_shader_parameter(&"age", 0.0)
	_shock_mat.set_shader_parameter(&"heavy", heavy_f)
	_shock.show()

	show()
	set_physics_process(true)
	reset_physics_interpolation()


func pool_released() -> void:
	set_physics_process(false)
	hide()


func _physics_process(delta: float) -> void:
	_age += delta
	var crater_t := clampf(_age / _life, 0.0, 1.0)
	if crater_t >= 1.0:
		if is_instance_valid(_pool):
			_pool.release(self)
		else:
			pool_released()
		return
	_crater_mat.set_shader_parameter(&"age", crater_t)

	var geyser_t := minf(1.0, _age / GEYSER_LIFE)
	_geyser.visible = geyser_t < 1.0
	if _geyser.visible:
		_geyser_mat.set_shader_parameter(&"age", geyser_t)

	var debris_t := minf(1.0, _age / DEBRIS_LIFE)
	_debris.visible = debris_t < 1.0
	if _debris.visible:
		_debris_mat.set_shader_parameter(&"age", debris_t)

	var shock_t := minf(1.0, _age / _shock_life)
	_shock.visible = shock_t < 1.0
	if _shock.visible:
		_shock_mat.set_shader_parameter(&"age", shock_t)


func _make_layer(mesh_data: Mesh, kind_id: int) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh_data
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 12.0
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"kind", kind_id)
	node.material_override = mat
	add_child(node)
	return node


static func _ensure_shared_meshes() -> void:
	if _crater_mesh != null:
		return
	_crater_mesh = _build_crater_mesh()
	_geyser_mesh = _build_geyser_mesh()
	_debris_mesh = _build_debris_mesh()
	_shock_plane = PlaneMesh.new()
	_shock_plane.size = Vector2(2.0, 2.0)


static func _build_crater_mesh() -> ArrayMesh:
	# Hố crater 3D thật với lòng hố lõm tối, vành gờ đá nhô gồ ghề (0.24..0.40m) và chân dốc ôm sát sàn.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGS := 22
	var rng := RandomNumberGenerator.new()
	rng.seed = 8841
	var lip_heights := PackedFloat32Array()
	var rad_jit := PackedFloat32Array()
	for i: int in SEGS:
		lip_heights.append(rng.randf_range(0.22, 0.42))
		rad_jit.append(rng.randf_range(0.90, 1.10))

	# 4 vòng đồng tâm: 0 = tâm lòng hố -> 1 = chân vách trong -> 2 = đỉnh gờ đá vỡ 3D -> 3 = mép ngoài áp sàn.
	var ring_r := [0.0, 0.46, 0.72, 1.00]
	var ring_lip := [0.0, 0.15, 1.00, 0.0]

	var center_v := Vector3(0.0, 0.015, 0.0)
	var center_c := Color(0.0, 0.2, 0.0, 1.0)
	for i: int in SEGS:
		var j := (i + 1) % SEGS
		var a0 := TAU * float(i) / float(SEGS)
		var a1 := TAU * float(j) / float(SEGS)
		var p1a := Vector3(cos(a0) * ring_r[1] * rad_jit[i], 0.025, sin(a0) * ring_r[1] * rad_jit[i])
		var p1b := Vector3(cos(a1) * ring_r[1] * rad_jit[j], 0.025, sin(a1) * ring_r[1] * rad_jit[j])
		var c1a := Color(ring_r[1], 0.35, ring_lip[1], 1.0)
		var c1b := Color(ring_r[1], 0.35, ring_lip[1], 1.0)
		_tri(st, center_v, p1b, p1a, center_c, c1b, c1a)

		var p2a := Vector3(cos(a0) * ring_r[2] * rad_jit[i], lip_heights[i], sin(a0) * ring_r[2] * rad_jit[i])
		var p2b := Vector3(cos(a1) * ring_r[2] * rad_jit[j], lip_heights[j], sin(a1) * ring_r[2] * rad_jit[j])
		var c2a := Color(ring_r[2], lip_heights[i] * 2.0, ring_lip[2], 1.0)
		var c2b := Color(ring_r[2], lip_heights[j] * 2.0, ring_lip[2], 1.0)
		_tri(st, p1a, p1b, p2b, c1a, c1b, c2b)
		_tri(st, p1a, p2b, p2a, c1a, c2b, c2a)

		var p3a := Vector3(cos(a0) * ring_r[3] * rad_jit[i], 0.01, sin(a0) * ring_r[3] * rad_jit[i])
		var p3b := Vector3(cos(a1) * ring_r[3] * rad_jit[j], 0.01, sin(a1) * ring_r[3] * rad_jit[j])
		var c3a := Color(ring_r[3], 0.4, ring_lip[3], 1.0)
		var c3b := Color(ring_r[3], 0.4, ring_lip[3], 1.0)
		_tri(st, p2a, p2b, p3b, c2a, c2b, c3b)
		_tri(st, p2a, p3b, p3a, c2a, c3b, c3a)
	st.generate_normals()
	return st.commit()


static func _build_geyser_mesh() -> ArrayMesh:
	# 3 lớp ống lửa phun trào đồng tâm (lõi trong rực trắng-vàng -> thân lửa cam -> vỏ khói lửa ngoài).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGS := 16
	const RINGS := 12
	var radii := [0.36, 0.72, 1.04]
	var shells := [0.0, 0.50, 1.0]
	for layer: int in 3:
		var base_r: float = radii[layer]
		var shell_t: float = shells[layer]
		var layer_seed := float(layer) * 0.37
		for r_i: int in RINGS:
			var v0 := float(r_i) / float(RINGS)
			var v1 := float(r_i + 1) / float(RINGS)
			var rad0 := base_r * (1.0 + sin(v0 * PI) * 0.28)
			var rad1 := base_r * (1.0 + sin(v1 * PI) * 0.28)
			for s_i: int in SEGS:
				var u0 := float(s_i) / float(SEGS)
				var u1 := float(s_i + 1) / float(SEGS)
				var a0 := u0 * TAU
				var a1 := u1 * TAU
				var p00 := Vector3(cos(a0) * rad0, v0, sin(a0) * rad0)
				var p10 := Vector3(cos(a1) * rad0, v0, sin(a1) * rad0)
				var p11 := Vector3(cos(a1) * rad1, v1, sin(a1) * rad1)
				var p01 := Vector3(cos(a0) * rad1, v1, sin(a0) * rad1)
				var col := Color(layer_seed, u0, shell_t, 1.0)
				_tri_uv(st, p00, p10, p11, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), col)
				_tri_uv(st, p00, p11, p01, Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1), col)
	st.generate_normals()
	return st.commit()


static func _build_debris_mesh() -> ArrayMesh:
	# 24 mảnh đá bazan góc cạnh & cục nham thạch nóng văng parabol quanh miệng hố.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6213
	const COUNT := 24
	for i: int in COUNT:
		var ang_n := fposmod((float(i) + rng.randf_range(-0.35, 0.35)) / float(COUNT), 1.0)
		var spd := rng.randf()
		var up_v := rng.randf()
		var lava_flag := rng.randf()
		var col := Color(ang_n, spd, up_v, lava_flag)
		var sx := rng.randf_range(0.14, 0.34)
		var sy := rng.randf_range(0.10, 0.26)
		var sz := rng.randf_range(0.14, 0.32)
		var px := Vector3(sx, 0.0, 0.0)
		var nx := Vector3(-sx * 0.85, 0.0, 0.0)
		var py := Vector3(0.0, sy, 0.0)
		var ny := Vector3(0.0, -sy * 0.75, 0.0)
		var pz := Vector3(0.0, 0.0, sz)
		var nz := Vector3(0.0, 0.0, -sz * 0.85)
		_tri(st, px, py, pz, col, col, col)
		_tri(st, pz, py, nx, col, col, col)
		_tri(st, nx, py, nz, col, col, col)
		_tri(st, nz, py, px, col, col, col)
		_tri(st, px, pz, ny, col, col, col)
		_tri(st, pz, nx, ny, col, col, col)
		_tri(st, nx, nz, ny, col, col, col)
		_tri(st, nz, px, ny, col, col, col)
	st.generate_normals()
	return st.commit()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


static func _tri_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, col: Color) -> void:
	st.set_color(col)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_color(col)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_color(col)
	st.set_uv(uc)
	st.add_vertex(c)
