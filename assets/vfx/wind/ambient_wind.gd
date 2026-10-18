@tool
class_name AmbientWind
extends Node3D
## Không khí gió toàn map: vệt gió mảnh trắng mờ bay ngang + lá/cánh hoa bay theo, phủ quanh follow_target.
## Hai MultiMesh (vệt, lá), mỗi lớp một mesh + một material: tổng 2 draw call, không có hạt CPU/GPU particles.
## Chuyển động tính trên GPU theo TIME với toạ độ thế giới, CPU mỗi frame chỉ chép vị trí của follow_target.
## Đổi thông số chỉ cập nhật uniform hoặc visible_instance_count, không dựng lại buffer.

const STREAK_SHADER: Shader = preload("res://assets/shaders/wind_ambient_streak.gdshader")
const LEAF_SHADER: Shader = preload("res://assets/shaders/wind_ambient_leaf.gdshader")
## Giới hạn cứng để không ai lỡ tay làm nặng máy
const MAX_STREAKS := 40
const MAX_LEAVES := 30
const STREAK_SEED := 131
const LEAF_SEED := 257
## Hộp bao nới thêm theo chiều đứng (m): vệt cuộn và lá chao vượt khỏi dải chiều cao một chút
const BOUNDS_MARGIN := 2.0

@export_group("Đi theo")
## Thường là player. Để trống thì vùng phủ đứng yên tại vị trí node
@export var follow_target: Node3D:
	set(value):
		follow_target = value
		_update_processing()
## Lệch tâm vùng phủ so với target (m), ví dụ đẩy về phía camera nhìn
@export var follow_offset: Vector3 = Vector3.ZERO
## Tốc độ bám theo chiều cao (1/s); 0 = không theo chiều cao, nhảy không làm vệt nhấp nhô
@export_range(0.0, 20.0, 0.1) var vertical_follow_rate: float = 2.0

@export_group("Gió")
## Hướng gió thế giới; thành phần Y chỉ làm nghiêng vệt, không đẩy vùng phủ lên/xuống
@export var wind_direction: Vector3 = Vector3(1.0, 0.0, -0.35):
	set(value):
		wind_direction = value
		_apply_parameters()
## Tốc độ vệt gió (m/s); lá bay chậm hơn theo leaf_speed_ratio
@export_range(0.0, 40.0, 0.1, "or_greater") var wind_speed: float = 9.0:
	set(value):
		wind_speed = value
		_apply_parameters()
## Bán kính vùng phủ quanh tâm (m); nên lớn hơn nửa đường chéo khung hình ở mặt đất
@export_range(2.0, 80.0, 0.5, "or_greater") var coverage_radius: float = 18.0:
	set(value):
		coverage_radius = maxf(value, 1.0)
		_apply_parameters()
## Dải chiều cao so với tâm (m)
@export_range(-5.0, 30.0, 0.1) var height_min: float = 0.6:
	set(value):
		height_min = value
		_apply_parameters()
@export_range(-5.0, 30.0, 0.1) var height_max: float = 3.5:
	set(value):
		height_max = value
		_apply_parameters()
## Nhân chung số vệt và số lá (0 = tắt hẳn)
@export_range(0.0, 1.0, 0.01) var density: float = 1.0:
	set(value):
		density = value
		_apply_parameters()

@export_group("Vệt gió")
@export_range(0, MAX_STREAKS) var streak_count: int = 28:
	set(value):
		streak_count = clampi(value, 0, MAX_STREAKS)
		_apply_parameters()
## Trắng / xanh rất nhạt: màu riêng của gió trong project
@export var streak_color: Color = Color(1.0, 1.0, 1.0, 0.8):
	set(value):
		streak_color = value
		_apply_parameters()
@export var streak_edge_color: Color = Color(0.82, 0.9, 0.97, 0.45):
	set(value):
		streak_edge_color = value
		_apply_parameters()
@export_range(0.0, 1.0, 0.01) var streak_opacity: float = 1.0:
	set(value):
		streak_opacity = value
		_apply_parameters()
## Hệ số sáng (>1 để trắng không bị tonemap AgX kéo về xám so với sàn được nắng chiếu)
@export_range(0.0, 4.0, 0.05) var streak_brightness: float = 1.8:
	set(value):
		streak_brightness = value
		_apply_parameters()
@export_range(0.005, 0.5, 0.005) var streak_width: float = 0.12:
	set(value):
		streak_width = value
		_apply_parameters()
@export_range(0.2, 20.0, 0.1) var streak_length: float = 3.5:
	set(value):
		streak_length = value
		_apply_parameters()
## Thời gian một vệt hiện ra rồi tan (s)
@export_range(0.2, 10.0, 0.05) var streak_lifetime: float = 2.2:
	set(value):
		streak_lifetime = value
		_apply_parameters()
## Biên độ uốn lượn của vệt (m)
@export_range(0.0, 2.0, 0.01) var streak_wave: float = 0.25:
	set(value):
		streak_wave = value
		_apply_parameters()
## Tỉ lệ vệt có đầu cuộn vòng
@export_range(0.0, 1.0, 0.01) var curl_fraction: float = 0.3:
	set(value):
		curl_fraction = value
		_apply_parameters()
@export_range(0.05, 3.0, 0.01) var curl_radius: float = 0.45:
	set(value):
		curl_radius = value
		_apply_parameters()

@export_group("Lá và cánh hoa")
@export_range(0, MAX_LEAVES) var leaf_count: int = 16:
	set(value):
		leaf_count = clampi(value, 0, MAX_LEAVES)
		_apply_parameters()
## Tông ít bão hoà để không lấn màu gió và màu quái
@export var leaf_color: Color = Color(0.72, 0.6, 0.38):
	set(value):
		leaf_color = value
		_apply_parameters()
@export var leaf_color_alt: Color = Color(0.6, 0.62, 0.4):
	set(value):
		leaf_color_alt = value
		_apply_parameters()
@export var petal_color: Color = Color(0.9, 0.8, 0.74):
	set(value):
		petal_color = value
		_apply_parameters()
## Tỉ lệ cánh hoa trong số lá
@export_range(0.0, 1.0, 0.01) var petal_fraction: float = 0.35:
	set(value):
		petal_fraction = value
		_apply_parameters()
@export_range(0.02, 1.0, 0.01) var leaf_size: float = 0.24:
	set(value):
		leaf_size = value
		_apply_parameters()
## Lá bay bằng bao nhiêu lần tốc độ vệt gió
@export_range(0.0, 2.0, 0.01) var leaf_speed_ratio: float = 0.55:
	set(value):
		leaf_speed_ratio = value
		_apply_parameters()
@export_range(0.5, 20.0, 0.1) var leaf_lifetime: float = 6.0:
	set(value):
		leaf_lifetime = value
		_apply_parameters()
## Biên độ chao lượn (m)
@export_range(0.0, 2.0, 0.01) var leaf_flutter: float = 0.5:
	set(value):
		leaf_flutter = value
		_apply_parameters()
@export_range(0.0, 20.0, 0.1) var leaf_tumble_speed: float = 5.0:
	set(value):
		leaf_tumble_speed = value
		_apply_parameters()

var _streak_material: ShaderMaterial
var _leaf_material: ShaderMaterial

@onready var _streaks: MultiMeshInstance3D = $Streaks
@onready var _leaves: MultiMeshInstance3D = $Leaves


func _ready() -> void:
	_streak_material = _new_material(STREAK_SHADER)
	_leaf_material = _new_material(LEAF_SHADER)
	_streaks.material_override = _streak_material
	_leaves.material_override = _leaf_material
	# Buffer dựng một lần với số tối đa; density/count chỉ đổi visible_instance_count
	_streaks.multimesh = WindVfxGeometry.build_multimesh(WindVfxGeometry.strip(), MAX_STREAKS, STREAK_SEED)
	_leaves.multimesh = WindVfxGeometry.build_multimesh(WindVfxGeometry.quad(), MAX_LEAVES, LEAF_SEED)
	_apply_parameters()
	_snap_to_target()
	_update_processing()


func _process(delta: float) -> void:
	if not is_instance_valid(follow_target):
		set_process(false)
		return
	var target := follow_target.global_position + follow_offset
	var y := global_position.y
	if vertical_follow_rate > 0.0:
		y = lerpf(y, target.y, 1.0 - exp(-vertical_follow_rate * delta))
	global_position = Vector3(target.x, y, target.z)


## Gán target lúc chạy (player do ZoneRoot tạo sau, nối qua signal ZoneRoot.player_spawned) và nhảy tới ngay
func set_follow_target(target: Node3D) -> void:
	follow_target = target
	_snap_to_target()


## Đặt tâm vùng phủ ngay tại target (dùng khi dịch chuyển/hồi sinh để chiều cao không trễ)
func snap_to_target() -> void:
	_snap_to_target()


func _snap_to_target() -> void:
	if follow_target != null and is_inside_tree() and follow_target.is_inside_tree():
		global_position = follow_target.global_position + follow_offset


func _update_processing() -> void:
	if not is_node_ready():
		return
	# Editor không bám target: tránh script @tool ghi đè vị trí khi đang dựng map
	set_process(follow_target != null and not Engine.is_editor_hint())


func _new_material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _apply_parameters() -> void:
	if _streak_material == null:
		return
	var direction := wind_direction.normalized() if wind_direction.length_squared() > 0.0001 else Vector3.RIGHT
	var low := minf(height_min, height_max)
	var high := maxf(height_min, height_max)
	var shared: Array[ShaderMaterial] = [_streak_material, _leaf_material]
	for material in shared:
		material.set_shader_parameter("wind_direction", direction)
		material.set_shader_parameter("coverage_radius", coverage_radius)
		material.set_shader_parameter("height_min", low)
		material.set_shader_parameter("height_max", high)
	_streak_material.set_shader_parameter("travel_speed", wind_speed)
	_streak_material.set_shader_parameter("core_color", streak_color)
	_streak_material.set_shader_parameter("edge_color", streak_edge_color)
	_streak_material.set_shader_parameter("opacity", streak_opacity)
	_streak_material.set_shader_parameter("brightness", streak_brightness)
	_streak_material.set_shader_parameter("width", streak_width)
	_streak_material.set_shader_parameter("stroke_length", streak_length)
	_streak_material.set_shader_parameter("lifetime", streak_lifetime)
	_streak_material.set_shader_parameter("wave_amplitude", streak_wave)
	_streak_material.set_shader_parameter("curl_fraction", curl_fraction)
	_streak_material.set_shader_parameter("curl_radius", curl_radius)
	_leaf_material.set_shader_parameter("travel_speed", wind_speed * leaf_speed_ratio)
	_leaf_material.set_shader_parameter("leaf_color", leaf_color)
	_leaf_material.set_shader_parameter("leaf_color_alt", leaf_color_alt)
	_leaf_material.set_shader_parameter("petal_color", petal_color)
	_leaf_material.set_shader_parameter("petal_fraction", petal_fraction)
	_leaf_material.set_shader_parameter("leaf_size", leaf_size)
	_leaf_material.set_shader_parameter("lifetime", leaf_lifetime)
	_leaf_material.set_shader_parameter("flutter", leaf_flutter)
	_leaf_material.set_shader_parameter("tumble_speed", leaf_tumble_speed)
	var streaks_visible := roundi(streak_count * density)
	var leaves_visible := roundi(leaf_count * density)
	_streaks.multimesh.visible_instance_count = streaks_visible
	_leaves.multimesh.visible_instance_count = leaves_visible
	# Mật độ 0: ẩn hẳn để khỏi tốn draw call
	_streaks.visible = streaks_visible > 0
	_leaves.visible = leaves_visible > 0
	var bounds := AABB(
		Vector3(-coverage_radius, low - BOUNDS_MARGIN, -coverage_radius),
		Vector3(coverage_radius * 2.0, high - low + BOUNDS_MARGIN * 2.0, coverage_radius * 2.0)
	)
	_streaks.custom_aabb = bounds
	_leaves.custom_aabb = bounds
