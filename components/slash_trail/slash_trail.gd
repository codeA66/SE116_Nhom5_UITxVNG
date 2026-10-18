class_name SlashTrail
extends Node3D
## Vệt chém lưỡi liềm đặc đen kiểu Death's Door phía trước nhân vật. Nghe hitbox.activated: mỗi lần đòn bật
## thì quét một vệt (mũi nhọn chạy qua cung, đuôi teo dần tới mũi rồi biến mất), lần sau đổi chiều.
## Có lớp phụ mờ chậm hơn tạo chiều sâu, ngôi sao lóe nhỏ ở mũi và vài mảnh đen bắn ra.
## Đòn cuối combo (finisher_attack) to hơn, sao to hơn. Mesh cung dựng một lần ở _ready.
## _process chỉ chạy lúc đang quét; hướng cung (+Z) lấy theo node follow (thường là Model).
## Không đặt dưới Model của player: fox_player.gd ghi đè material_override của mọi mesh dưới Model.

@export var hitbox: HitboxComponent
## Node cho biết hướng nhìn; vệt xoay theo node này lúc quét. Để trống = giữ hướng của chính SlashTrail
@export var follow: Node3D

@export_group("Shape")
## Bán kính ngoài = tầm hitbox thực tế x hệ số này (vệt không vượt vùng trúng)
@export_range(0.1, 1.5) var reach_ratio: float = 0.95
## Bán kính trong = bán kính ngoài x hệ số này (nhỏ = lưỡi liềm dày)
@export_range(0.0, 0.95) var inner_ratio: float = 0.6
## Dùng khi hitbox chưa có tầm (m)
@export var fallback_reach: float = 1.65
@export var arc_degrees: float = 175.0
## Độ cao mặt phẳng cung so với chân (m): hơi cao hơn mặt đất
@export var height: float = 0.35
## Nghiêng mặt phẳng cung quanh trục hướng nhìn (độ); đổi dấu theo chiều quét
@export var tilt_degrees: float = 16.0
@export var segments: int = 160
## Lớp phụ to hơn lớp chính bấy nhiêu lần
@export var back_layer_scale: float = 1.05

@export_group("Look")
@export var body_color: Color = Color(0.012, 0.018, 0.035)
## Viền sáng ngoài + lưỡi gió (blend_add, HDR để glow toả ra)
@export var edge_color: Color = Color(0.45, 0.8, 1.0)
@export var edge_intensity: float = 2.5
## Số lưỡi gió nhỏ bên trong thân đen (0..5)
@export_range(0, 5) var blade_count: int = 4
@export_range(0.0, 1.0) var back_layer_alpha: float = 0.35

@export_group("Star")
## Kích thước sao lóe ở mũi (m)
@export var star_size: float = 0.4
@export var star_color: Color = Color(1.0, 1.0, 1.0)
@export var star_intensity: float = 2.5

@export_group("Timing")
## Thời gian mũi vệt quét hết cung (s)
@export var sweep_time: float = 0.12
## Thời gian lưỡi liềm teo hết sau khi quét xong (s)
@export var fade_time: float = 0.14
## Lớp phụ chậm hơn lớp chính bấy nhiêu lần
@export var back_layer_lag: float = 1.4

@export_group("Finisher")
## Đòn này (thường là đòn cuối combo) to hơn; để trống = không có đòn đặc biệt
@export var finisher_attack: AttackData
@export var finisher_scale: float = 1.1
@export var finisher_star_scale: float = 1.6

const SPARKLE_POINTS := 6
## Mảnh đen bắn ra từ mép trong: vị trí giữa mép trong và mép ngoài
const INNER_FLECK_T := 0.08
## Mũi sao nằm sát mép ngoài lưỡi
const STAR_RADIUS_T := 0.96

var _age: float = 0.0
var _direction: float = 1.0
var _star_scale: float = 1.0
var _sweeping: bool = false
var _slash_seed: float = 0.0
var _inner_radius: float = 0.0
var _outer_radius: float = 0.0
var _built_reach: float = -1.0
var _fleck_normals: Dictionary[float, PackedVector3Array] = {}

@onready var _arc: MeshInstance3D = $Arc
@onready var _arc_back: MeshInstance3D = $ArcBack
@onready var _arc_glow: MeshInstance3D = $ArcGlow
@onready var _star: MeshInstance3D = $Star
@onready var _sparkles: CPUParticles3D = $Sparkles
@onready var _arc_material: ShaderMaterial = _arc.material_override as ShaderMaterial
@onready var _back_material: ShaderMaterial = _arc_back.material_override as ShaderMaterial
@onready var _glow_material: ShaderMaterial = _arc_glow.material_override as ShaderMaterial
@onready var _star_material: ShaderMaterial = _star.material_override as ShaderMaterial


func _ready() -> void:
	rebuild()
	_sparkles.color_ramp = FxUtil.make_alpha_gradient([[0.0, 1.0], [0.7, 1.0], [1.0, 0.0]])
	_sparkles.scale_amount_curve = FxUtil.make_curve([Vector2(0.0, 1.0), Vector2(1.0, 0.3)])
	for material: ShaderMaterial in [_arc_material, _back_material]:
		material.set_shader_parameter(&"body_color", body_color)
	_glow_material.set_shader_parameter(&"edge_color", edge_color)
	_glow_material.set_shader_parameter(&"edge_intensity", edge_intensity)
	_glow_material.set_shader_parameter(&"core_intensity", edge_intensity * 1.4)
	_glow_material.set_shader_parameter(&"blade_intensity", edge_intensity * 0.75)
	_glow_material.set_shader_parameter(&"blade_count", blade_count)
	_back_material.set_shader_parameter(&"layer_alpha", back_layer_alpha)
	_star_material.set_shader_parameter(&"tint", star_color)
	_star_material.set_shader_parameter(&"intensity", star_intensity)
	_arc.visible = false
	_arc_back.visible = false
	_arc_glow.visible = false
	_star.visible = false
	set_process(false)
	if hitbox:
		hitbox.activated.connect(_on_activated)
	else:
		push_error("%s cần hitbox" % get_path())


func _process(delta: float) -> void:
	_sync_facing()
	_age += delta
	var head := _update_layer(_arc_material, _arc, sweep_time, fade_time)
	_update_layer(_back_material, _arc_back, sweep_time * back_layer_lag, fade_time * back_layer_lag)
	_update_layer(_glow_material, _arc_glow, sweep_time, fade_time)
	_update_star(head)
	if _age >= total_time():
		_sweeping = false
		_arc.visible = false
		_arc_back.visible = false
		_arc_glow.visible = false
		set_process(false)


## Dựng lại mesh cung + điểm hạt (gọi khi đổi thông số hình dạng lúc chạy)
func rebuild() -> void:
	_fit_to_reach(true)


func _build_mesh_and_points() -> void:
	var mesh := _build_arc_mesh()
	_arc.mesh = mesh
	_arc_back.mesh = mesh
	_arc_glow.mesh = mesh
	_arc_back.scale = Vector3(back_layer_scale, 1.0, back_layer_scale)
	_arc.position.y = height
	_arc_back.position.y = height - 0.01
	_arc_glow.position.y = height + 0.01
	_sparkles.position.y = height
	_sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_DIRECTED_POINTS
	_sparkles.emission_points = _build_arc_points(SPARKLE_POINTS, INNER_FLECK_T)
	_fleck_normals[1.0] = _build_tangents(SPARKLE_POINTS, 1.0)
	_fleck_normals[-1.0] = _build_tangents(SPARKLE_POINTS, -1.0)


## Tổng thời gian một lần chém (lớp phụ chậm hơn nên dài nhất)
func total_time() -> float:
	return (sweep_time + fade_time) * back_layer_lag


func is_sweeping() -> bool:
	return _sweeping


## Bán kính ngoài hiện tại của lưỡi (m)
func get_outer_radius() -> float:
	return _outer_radius


func _on_activated(attack: AttackData) -> void:
	_fit_to_reach()
	_direction = -_direction
	_slash_seed = randf() * 10.0
	_age = 0.0
	_sweeping = true
	var finisher := finisher_attack != null and attack == finisher_attack
	scale = Vector3.ONE * (finisher_scale if finisher else 1.0)
	_star_scale = finisher_star_scale if finisher else 1.0
	_sync_facing()
	var tilt := deg_to_rad(tilt_degrees) * _direction
	for node: Node3D in [_arc, _arc_back, _arc_glow, _sparkles]:
		node.rotation.z = tilt
	for material: ShaderMaterial in [_arc_material, _back_material, _glow_material]:
		material.set_shader_parameter(&"direction", _direction)
		material.set_shader_parameter(&"seed", _slash_seed)
		material.set_shader_parameter(&"head", 0.0)
		material.set_shader_parameter(&"dissolve", 0.0)
	_arc.visible = true
	_arc_back.visible = true
	_arc_glow.visible = true
	_sparkles.emission_normals = _fleck_normals[_direction]
	_sparkles.restart()
	set_process(true)
	_process(0.0)


func _sync_facing() -> void:
	if follow:
		global_basis = follow.global_basis * Basis.from_scale(scale)


## Mũi quét theo ease-out; lưỡi teo (dissolve) sau khi quét xong. Trả về vị trí mũi (0..1)
func _update_layer(material: ShaderMaterial, node: MeshInstance3D, sweep: float, fade: float) -> float:
	var t := clampf(_age / maxf(sweep, 0.0001), 0.0, 1.0)
	var head := 1.0 - pow(1.0 - t, 3.0)
	material.set_shader_parameter(&"head", head)
	var d := clampf((_age - sweep) / maxf(fade, 0.0001), 0.0, 1.0)
	material.set_shader_parameter(&"dissolve", d * d)
	if d >= 1.0:
		node.visible = false
	return head


## Sao lóe bám mũi vệt: phình theo sin trong lúc quét rồi tắt
func _update_star(head: float) -> void:
	var t := clampf(_age / maxf(sweep_time * 1.5, 0.0001), 0.0, 1.0)
	_star.visible = t < 1.0
	if not _star.visible:
		return
	var half := deg_to_rad(arc_degrees) * 0.5
	var u_mesh := head if _direction > 0.0 else 1.0 - head
	var angle := lerpf(-half, half, u_mesh)
	var radius := lerpf(_inner_radius, _outer_radius, STAR_RADIUS_T)
	var local := Basis(Vector3.BACK, deg_to_rad(tilt_degrees) * _direction) * (Vector3(sin(angle), 0.0, cos(angle)) * radius)
	_star.position = local + Vector3.UP * height
	_star.scale = Vector3.ONE * star_size * _star_scale * sin(PI * t)
	_star_material.set_shader_parameter(&"spin", deg_to_rad(10.0) * _direction)


func _build_arc_mesh() -> ArrayMesh:
	var count := maxi(segments, 3)
	var half := deg_to_rad(arc_degrees) * 0.5
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in count + 1:
		var u := float(i) / float(count)
		var angle := lerpf(-half, half, u)
		var dir := Vector3(sin(angle), 0.0, cos(angle))
		vertices.append(dir * _inner_radius)
		uvs.append(Vector2(u, 0.0))
		vertices.append(dir * _outer_radius)
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


func _build_arc_points(point_count: int, radius_t: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	var half := deg_to_rad(arc_degrees) * 0.5
	var radius := lerpf(_inner_radius, _outer_radius, radius_t)
	for i in point_count:
		var angle := lerpf(-half, half, float(i) / float(maxi(point_count - 1, 1)))
		points.append(Vector3(sin(angle), 0.0, cos(angle)) * radius)
	return points


## Bán kính theo tầm hitbox lúc này; chỉ dựng lại mesh khi tầm đổi (đổi vũ khí)
func _fit_to_reach(force: bool = false) -> void:
	var reach := hitbox.get_reach() if hitbox else 0.0
	if reach <= 0.0:
		reach = fallback_reach
	if not force and absf(reach - _built_reach) < 0.01:
		return
	_built_reach = reach
	_outer_radius = reach * reach_ratio
	_inner_radius = _outer_radius * inner_ratio
	_build_mesh_and_points()


## Tiếp tuyến cung theo chiều quét (mảnh vụn bay dọc theo lưỡi)
func _build_tangents(point_count: int, sweep_direction: float) -> PackedVector3Array:
	var normals := PackedVector3Array()
	var half := deg_to_rad(arc_degrees) * 0.5
	for i in point_count:
		var angle := lerpf(-half, half, float(i) / float(maxi(point_count - 1, 1)))
		normals.append(Vector3(cos(angle), 0.0, -sin(angle)) * sweep_direction)
	return normals
