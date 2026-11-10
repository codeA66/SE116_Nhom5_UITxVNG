class_name FireArrowHitVfx
extends Node3D
## Bùng lửa chỗ tên Cung Lửa trúng (quái, tường, sàn), kiểu hoạt hình: chớp sao, cụm lửa phồng, lưỡi lửa vút lên,
## tia lửa, khói, vết cháy trên sàn. Một mesh hai bề mặt (lửa vẽ đè + vết cháy có thử độ sâu), không đèn,
## không node phát sinh. Dùng object pool: xong tự phát finished, chỉ chạy _process trong lúc đang hiện.

signal finished

const FIRE_SHADER: Shader = preload("res://assets/vfx/fire/fire_arrow/impact/fire_arrow_hit_vfx.gdshader")
const SCORCH_SHADER: Shader = preload("res://assets/vfx/fire/fire_arrow/impact/fire_arrow_scorch.gdshader")
## Mã loại lớp trong UV2.y, khớp với shader
const KIND_FLASH := 0
const KIND_BLOB := 1
const KIND_LICK := 2
const KIND_SPARK := 3
const KIND_SMOKE := 4
const KIND_SHOCK := 5

@export_group("Counts")
@export_range(0, 12, 1) var blob_count: int = 7
@export_range(0, 8, 1) var lick_count: int = 3
@export_range(0, 24, 1) var spark_count: int = 16
@export_range(0, 8, 1) var smoke_count: int = 4
@export_group("Shape")
## Cỡ hình theo bán kính vùng đốt: 1 = cụm lửa rộng bằng bán kính
@export var size_per_radius: float = 1.5
## Lửa / tia / khói lệch về hướng tên bay bấy nhiêu
@export var forward_bias: float = 0.5
@export var flash_scale: float = 1.8
@export var star_points: float = 8.0
@export var blob_scale: float = 0.62
@export var blob_spread: float = 0.6
@export var blob_rise: float = 0.55
@export var lick_height: float = 1.1
@export var lick_width: float = 0.3
@export var spark_speed: float = 3.0
@export var spark_gravity: float = 6.0
@export var spark_length: float = 0.22
@export var spark_width: float = 0.06
@export var smoke_scale: float = 0.42
@export var smoke_rise: float = 0.9
@export var scorch_scale: float = 1.1
## Vòng xung kích lúc trúng: đường kính tối đa theo cỡ hình, độ dày (tỉ lệ bán kính)
@export var shock_scale: float = 2.2
@export_range(0.05, 1.0, 0.01) var shock_width: float = 0.35
@export_group("Palette")
@export var core_color: Color = Color("fff3b0")
@export var body_color: Color = Color("ff891e")
## Viền đậm để lửa đọc được trên sàn sáng
@export var edge_color: Color = Color("8c2513")
@export_range(0.0, 0.5, 0.01) var edge_width: float = 0.2
@export var smoke_color: Color = Color(0.42, 0.35, 0.33)
@export var smoke_shadow: Color = Color(0.24, 0.19, 0.19)
@export var scorch_color: Color = Color(0.13, 0.08, 0.06)
@export_range(0.0, 1.0, 0.01) var scorch_alpha: float = 0.75
@export_group("Timing")
## Số nấc tan (kiểu hoạt hình: tan giật từng nấc thay vì mờ trơn)
@export_range(1.0, 12.0, 1.0) var dissolve_steps: float = 4.0
@export var flash_time: float = 0.07
@export var blob_time: float = 0.34
@export var lick_time: float = 0.28
@export var spark_time: float = 0.4
@export var smoke_start: float = 0.12
@export var smoke_time: float = 0.6
@export var shock_time: float = 0.16
@export var scorch_time: float = 1.2
## Viền than hồng của vết cháy nguội hết sau bấy nhiêu giây
@export var glow_time: float = 0.4
@export_group("Ground")
## Dò sàn xuống tối đa bấy nhiêu mét để đặt vết cháy
@export var ground_probe_depth: float = 4.0
@export_flags_3d_physics var ground_mask: int = 1
@export var scorch_floor_offset: float = 0.04
@export_group("Warmup")
@export var prepare_frames: int = 3
@export var prepare_opacity: float = 0.000001

static var _mesh_cache: Dictionary[Vector4i, ArrayMesh] = {}
static var _warmup_done: bool = false

var _fire: ShaderMaterial
var _scorch: ShaderMaterial
var _age: float = 0.0
var _total: float = 0.0
var _epoch: int = 0

@onready var _mesh: MeshInstance3D = $Burst


## Uniform riêng mỗi slot pool; hình học cùng cấu hình dùng chung
func _ready() -> void:
	top_level = true
	_fire = ShaderMaterial.new()
	_fire.shader = FIRE_SHADER
	_scorch = ShaderMaterial.new()
	_scorch.shader = SCORCH_SHADER
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build()
	_mesh.set_surface_override_material(0, _fire)
	_mesh.set_surface_override_material(1, _scorch)
	_apply_style()
	pool_released()
	_prepare.call_deferred()


## Chỉ chạy trong lúc đang hiện; lớp sống lâu nhất xong thì báo pool
func _process(delta: float) -> void:
	_age += delta
	if _age >= _total:
		pool_released()
		finished.emit()
		return
	_set_age(_age)


## Bùng tại point, lệch theo direction (chỉ lấy phần nằm ngang), cỡ theo radius vùng đốt
func play(point: Vector3, direction: Vector3, radius: float) -> void:
	_epoch += 1
	var flat := Vector3(direction.x, 0.0, direction.z)
	var facing := Basis.IDENTITY if flat.length_squared() < 0.0001 else Basis.looking_at(flat.normalized(), Vector3.UP, true)
	global_transform = Transform3D(facing, point)
	var size := maxf(radius, 0.05) * size_per_radius
	_fire.set_shader_parameter(&"size", size)
	_scorch.set_shader_parameter(&"size", size)
	_scorch.set_shader_parameter(&"floor_y", _ground_below(point).y + scorch_floor_offset - point.y)
	_fire.set_shader_parameter(&"opacity", 1.0)
	_scorch.set_shader_parameter(&"opacity", 1.0)
	# Khung bao: tia lửa bay xa nhất + độ sâu dò sàn; vẽ đè nên không cần chính xác, chỉ cần không bị cắt
	var extent := size * (2.0 + spark_speed * spark_time * 2.0 + forward_bias) + ground_probe_depth
	_mesh.custom_aabb = AABB(-Vector3.ONE * extent, Vector3.ONE * extent * 2.0)
	_total = maxf(maxf(flash_time, blob_time + 0.04), maxf(maxf(lick_time + 0.07, spark_time), maxf(smoke_start + smoke_time + 0.08, scorch_time)))
	_age = 0.0
	_set_age(0.0)
	show()
	set_process(true)


## Pool nhả slot (kể cả nhả giữa chừng khi đổi khu): ẩn và dừng hẳn
func pool_released() -> void:
	_epoch += 1
	set_process(false)
	hide()


func _set_age(value: float) -> void:
	_fire.set_shader_parameter(&"age", value)
	_scorch.set_shader_parameter(&"age", value)


func _apply_style() -> void:
	for key: StringName in [&"forward_bias", &"flash_scale", &"star_points", &"blob_scale", &"blob_spread", &"blob_rise",
			&"lick_height", &"lick_width", &"spark_speed", &"spark_gravity", &"spark_length", &"spark_width",
			&"smoke_scale", &"smoke_rise", &"core_color", &"body_color", &"edge_color", &"edge_width",
			&"smoke_color", &"smoke_shadow", &"dissolve_steps", &"flash_time", &"blob_time", &"lick_time",
			&"spark_time", &"smoke_start", &"smoke_time", &"shock_time", &"shock_scale", &"shock_width"]:
		_fire.set_shader_parameter(key, get(key))
	for key: StringName in [&"blob_count", &"lick_count", &"smoke_count"]:
		_fire.set_shader_parameter(key, float(get(key)))
	_scorch.set_shader_parameter(&"glow_color", body_color)
	_scorch.set_shader_parameter(&"glow_edge", edge_color)
	for key: StringName in [&"scorch_color", &"scorch_alpha", &"scorch_scale", &"scorch_time", &"glow_time"]:
		_scorch.set_shader_parameter(key, get(key))


## Điểm sàn ngay dưới chỗ trúng (một tia mỗi lần bùng); không thấy sàn thì đặt vết ngang chỗ trúng
func _ground_below(from: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.2, from + Vector3.DOWN * ground_probe_depth, ground_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else from


## Dựng lưới một lần cho mỗi cấu hình số lượng: phát lại chỉ đổi uniform
func _build() -> void:
	var key := Vector4i(blob_count, lick_count, spark_count, smoke_count)
	if _mesh_cache.has(key):
		_mesh.mesh = _mesh_cache[key]
		return
	var mesh := ArrayMesh.new()
	var fire: Array[Vector2] = [Vector2(0, KIND_SHOCK), Vector2(0, KIND_FLASH)]
	for count_kind: Vector2i in [Vector2i(blob_count, KIND_BLOB), Vector2i(lick_count, KIND_LICK),
			Vector2i(spark_count, KIND_SPARK), Vector2i(smoke_count, KIND_SMOKE)]:
		for index in count_kind.x:
			fire.append(Vector2(index, count_kind.y))
	_add_quads(mesh, fire)
	var scorch: Array[Vector2] = [Vector2.ZERO]
	_add_quads(mesh, scorch)
	_mesh_cache[key] = mesh
	_mesh.mesh = mesh


## Một bề mặt gồm các quad; tag = (chỉ số trong lớp, loại lớp) ghi vào UV2. Đỉnh để 0: shader tự đặt vị trí
static func _add_quads(mesh: ArrayMesh, tags: Array[Vector2]) -> void:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var indices := PackedInt32Array()
	for tag: Vector2 in tags:
		var base := vertices.size()
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			vertices.append(Vector3.ZERO)
			uv.append(corner)
			uv2.append(tag)
		indices.append_array(PackedInt32Array([base, base + 2, base + 1, base + 1, base + 2, base + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## Vẽ thử một lần ở độ mờ gần 0 để biên dịch shader trước trận (tránh giật ở phát trúng đầu tiên)
func _prepare() -> void:
	if _warmup_done or DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	_warmup_done = true
	var epoch := _epoch
	_fire.set_shader_parameter(&"opacity", prepare_opacity)
	_scorch.set_shader_parameter(&"opacity", prepare_opacity)
	_set_age(0.1)
	_mesh.custom_aabb = AABB(-Vector3.ONE * 4.0, Vector3.ONE * 8.0)
	show()
	for frame in prepare_frames:
		await RenderingServer.frame_post_draw
	if epoch == _epoch:
		hide()
	_fire.set_shader_parameter(&"opacity", 1.0)
	_scorch.set_shader_parameter(&"opacity", 1.0)
