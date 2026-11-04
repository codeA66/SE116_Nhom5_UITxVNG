class_name FireFlareVfx
extends Node3D
## Hình bùng lửa theo gió: lưỡi lửa phụt dài theo +Z (hướng gió), lõi trắng nóng ở gốc, tàn lửa bắn xa,
## vệt cháy sáng trên sàn rồi nguội dần. Kích thước theo vùng đốt (play(size)), không vượt quá vùng đốt.
## Hạt dựng một lần lúc _ready (texture dùng chung mọi instance; material xử lý riêng vì tốc độ theo kích thước);
## chỉ chạy _process lúc vệt sàn đang nguội. Không đèn (luật hiệu năng), không đổ bóng.

@export_group("Flames")
## Số lưỡi lửa, thời gian sống (s)
@export_range(4, 64) var flame_count: int = 34
@export_range(0.1, 2.0, 0.01) var flame_lifetime: float = 0.38
## Độ toả ra hai bên (độ)
@export_range(0.0, 60.0, 0.5) var flame_spread: float = 13.0
## Cỡ lưỡi lửa so với bề rộng vùng
@export_range(0.1, 2.0, 0.01) var flame_size_ratio: float = 0.55
## Lưỡi lửa đi được bao nhiêu phần chiều dài vùng (giữ < 1 để hình không vượt vùng đốt)
@export_range(0.1, 1.0, 0.01) var flame_reach_ratio: float = 0.85
@export_group("Core")
@export_range(0, 32) var core_count: int = 10
@export_range(0.05, 1.0, 0.01) var core_lifetime: float = 0.2
@export_range(0.05, 2.0, 0.01) var core_size: float = 0.45
@export_group("Embers")
@export_range(0, 48) var ember_count: int = 18
@export_range(0.1, 2.0, 0.01) var ember_lifetime: float = 0.6
@export_range(0.01, 0.5, 0.005) var ember_size: float = 0.07
## Tàn lửa bay xa hơn lưỡi lửa bao nhiêu lần
@export_range(0.5, 3.0, 0.05) var ember_reach_ratio: float = 1.2
## Tàn lửa bốc lên (m/s²)
@export_range(0.0, 10.0, 0.1) var ember_rise: float = 1.2
@export_group("Ground")
## Vệt cháy sáng trên sàn: thời gian nguội (s), độ đậm ban đầu
@export_range(0.0, 3.0, 0.01) var scorch_time: float = 0.7
@export_range(0.0, 1.0, 0.01) var scorch_opacity: float = 0.75
@export_range(0.0, 0.2, 0.005) var scorch_floor_offset: float = 0.04
@export_range(0.5, 10.0, 0.1) var ground_probe_depth: float = 4.0
@export_flags_3d_physics var ground_mask: int = 1
@export_group("Palette")
@export var core_color: Color = Color(1.0, 0.97, 0.82)
@export var hot_color: Color = Color(1.0, 0.72, 0.2)
@export var flame_color: Color = Color(0.95, 0.32, 0.06)
@export var edge_color: Color = Color(0.45, 0.06, 0.03)

static var _puff_texture: GradientTexture2D
static var _streak_texture: GradientTexture2D

var _scorch_left: float = 0.0
var _flames: GPUParticles3D
var _core: GPUParticles3D
var _embers: GPUParticles3D
var _scorch: MeshInstance3D
var _scorch_material: StandardMaterial3D


func _ready() -> void:
	set_process(false)
	_flames = _make_particles(flame_count, flame_lifetime, 0.35,
			_ramp([core_color, hot_color, flame_color, edge_color], [1.0, 0.95, 0.75, 0.0]), _curve(0.45, 1.25, 0.35))
	_core = _make_particles(core_count, core_lifetime, 0.9,
			_ramp([Color.WHITE, core_color, hot_color], [1.0, 0.9, 0.0]), _curve(0.8, 1.0, 0.2))
	_embers = _make_particles(ember_count, ember_lifetime, 0.25,
			_ramp([core_color, hot_color, flame_color], [1.0, 1.0, 0.0]), _curve(1.0, 1.0, 0.3))
	(_embers.process_material as ParticleProcessMaterial).gravity = Vector3.UP * ember_rise
	_build_scorch()


## Phụt lửa theo size = (rộng, cao, dài) trong khung của node (+Z = hướng phụt); trả về thời gian tới khi tàn hết (s)
func play(size: Vector3) -> float:
	var reach := size.z * flame_reach_ratio
	_aim(_flames, reach, flame_lifetime, flame_spread, size.x * flame_size_ratio, Vector3(size.x * 0.2, size.y * 0.2, 0.05))
	_aim(_core, reach * 0.35, core_lifetime, flame_spread * 0.5, core_size, Vector3(size.x * 0.1, size.y * 0.1, 0.02))
	_aim(_embers, reach * ember_reach_ratio, ember_lifetime, flame_spread * 2.2, ember_size, Vector3(size.x * 0.25, size.y * 0.25, 0.05))
	var bounds := AABB(Vector3(-size.x, -size.y, -0.5), Vector3(size.x * 2.0, size.y * 2.0, size.z * ember_reach_ratio + 1.0))
	for particles: GPUParticles3D in [_flames, _core, _embers]:
		particles.visibility_aabb = bounds
		if particles.visible:
			particles.restart()
	_place_scorch(size)
	return maxf(maxf(flame_lifetime, ember_lifetime), scorch_time)


## Tắt hẳn (pool nhả về)
func stop() -> void:
	for particles: GPUParticles3D in [_flames, _core, _embers]:
		particles.emitting = false
	_scorch.hide()
	_scorch_left = 0.0
	set_process(false)


## Chỉ chạy lúc vệt sàn đang nguội
func _process(delta: float) -> void:
	_scorch_left -= delta
	var t := clampf(_scorch_left / maxf(scorch_time, 0.001), 0.0, 1.0)
	_scorch_material.albedo_color = Color(hot_color.r, hot_color.g, hot_color.b, scorch_opacity * t * t)
	if _scorch_left <= 0.0:
		_scorch.hide()
		set_process(false)


## Tốc độ + giảm tốc để hạt đi đúng reach rồi dừng: với giảm tốc d = v / L, quãng = v * L / 2 -> v = 2 * reach / L
func _aim(particles: GPUParticles3D, reach: float, lifetime: float, spread: float, size: float, box: Vector3) -> void:
	var material := particles.process_material as ParticleProcessMaterial
	var life := maxf(lifetime, 0.001)
	var speed := 2.0 * reach / life
	material.initial_velocity_min = speed * 0.8
	material.initial_velocity_max = speed
	material.damping_min = speed / life * 0.8
	material.damping_max = speed / life
	material.spread = spread
	material.emission_box_extents = box
	material.scale_min = size * 0.75
	material.scale_max = size


func _make_particles(count: int, lifetime: float, explosiveness: float, ramp: GradientTexture1D, curve: CurveTexture) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = maxi(count, 1)
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = explosiveness
	particles.emitting = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, 0.0, 1.0)
	material.gravity = Vector3.ZERO
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.angle_min = -180.0
	material.angle_max = 180.0
	material.color_ramp = ramp
	material.scale_curve = curve
	particles.process_material = material
	particles.draw_pass_1 = _quad()
	# count 0 = tắt hẳn lớp này (vẫn tạo node để code không phải rẽ nhánh)
	particles.visible = count > 0
	add_child(particles)
	return particles


## Quad billboard; màu lấy từ ramp của hạt
func _quad() -> QuadMesh:
	var mesh := QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _get_puff_texture()
	mesh.material = material
	return mesh


func _build_scorch() -> void:
	_scorch = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	_scorch.mesh = plane
	_scorch_material = StandardMaterial3D.new()
	_scorch_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_scorch_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_scorch_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_scorch_material.albedo_texture = _get_streak_texture()
	_scorch.material_override = _scorch_material
	_scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scorch.top_level = true
	_scorch.hide()
	add_child(_scorch)


## Vệt sàn nằm sát sàn dưới gốc lửa, dài theo hướng phụt; dò tia một lần mỗi lần bùng
func _place_scorch(size: Vector3) -> void:
	if scorch_time <= 0.0 or scorch_opacity <= 0.0:
		return
	var origin := global_position
	var query := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 0.2, origin + Vector3.DOWN * ground_probe_depth, ground_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var floor_y: float = (hit["position"] as Vector3).y if not hit.is_empty() else origin.y - size.y * 0.5
	var forward := global_basis.z.normalized()
	var side := Vector3.UP.cross(forward).normalized()
	var center := origin + forward * size.z * 0.5
	center.y = floor_y + scorch_floor_offset
	_scorch.global_transform = Transform3D(Basis(side * size.x * 0.8, Vector3.UP, forward * size.z), center)
	_scorch_left = scorch_time
	_scorch.show()
	_process(0.0)
	set_process(true)


func _ramp(colors: Array[Color], alphas: Array[float]) -> GradientTexture1D:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var packed := PackedColorArray()
	for i in colors.size():
		offsets.append(float(i) / float(colors.size() - 1))
		packed.append(Color(colors[i].r, colors[i].g, colors[i].b, alphas[i]))
	gradient.offsets = offsets
	gradient.colors = packed
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


## Cỡ hạt theo tuổi: start -> peak (ở 30% đời) -> end
func _curve(start: float, peak: float, end: float) -> CurveTexture:
	var curve := Curve.new()
	curve.max_value = maxf(maxf(start, peak), maxf(end, 1.0))
	curve.add_point(Vector2(0.0, start))
	curve.add_point(Vector2(0.3, peak))
	curve.add_point(Vector2(1.0, end))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


## Đốm tròn mềm cho lưỡi lửa (dùng chung mọi instance)
static func _get_puff_texture() -> GradientTexture2D:
	if _puff_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		_puff_texture = GradientTexture2D.new()
		_puff_texture.gradient = gradient
		_puff_texture.width = 32
		_puff_texture.height = 32
		_puff_texture.fill = GradientTexture2D.FILL_RADIAL
		_puff_texture.fill_from = Vector2(0.5, 0.5)
		_puff_texture.fill_to = Vector2(0.5, 0.0)
	return _puff_texture


## Vệt sàn: sáng ở gốc lửa, nhạt dần về cuối và hai mép (dùng chung mọi instance)
static func _get_streak_texture() -> GradientTexture2D:
	if _streak_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
		_streak_texture = GradientTexture2D.new()
		_streak_texture.gradient = gradient
		_streak_texture.width = 32
		_streak_texture.height = 64
		_streak_texture.fill = GradientTexture2D.FILL_RADIAL
		_streak_texture.fill_from = Vector2(0.5, 0.05)
		_streak_texture.fill_to = Vector2(1.0, 0.05)
	return _streak_texture
