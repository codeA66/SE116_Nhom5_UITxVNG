@tool
class_name LightShaft
extends Node3D
## Cột nắng xiên giả (god ray) rơi xuống khu quan trọng. Chân các dải nằm ở mặt phẳng y = 0 của node,
## dải nghiêng về phía +X cục bộ (xoay node quanh Y để đổi hướng nắng).
## Mọi dải gộp trong một ArrayMesh + một material: một draw call. Gợn và bụi tính trên GPU theo TIME,
## script không chạy mỗi frame; chỉ dựng lại mesh khi đổi thông số hình dạng.

const SHADER: Shader = preload("res://assets/shaders/light_shaft.gdshader")
const MAX_SHAFTS := 32
## Mép hộp bao cộng thêm (m) để dải quay theo camera không bị cull sớm
const BOUNDS_MARGIN := 0.5

@export_group("Hình dạng")
## Chiều cao đỉnh dải so với chân (m)
@export_range(0.5, 60.0, 0.1, "or_greater") var height: float = 8.0:
	set(value):
		height = maxf(value, 0.1)
		_queue_rebuild()
## Bề rộng dải ở đỉnh (m)
@export_range(0.05, 20.0, 0.05, "or_greater") var width: float = 1.2:
	set(value):
		width = maxf(value, 0.01)
		_queue_rebuild()
## Chân dải rộng hơn đỉnh bao nhiêu lần (nắng loe ra khi xuống)
@export_range(0.2, 4.0, 0.05) var bottom_width_ratio: float = 1.5:
	set(value):
		bottom_width_ratio = value
		_queue_rebuild()
## Góc nghiêng so với phương thẳng đứng (độ); đỉnh lệch về +X
@export_range(0.0, 75.0, 0.5) var tilt_degrees: float = 25.0:
	set(value):
		tilt_degrees = value
		_queue_rebuild()
@export_range(1, MAX_SHAFTS) var shaft_count: int = 4:
	set(value):
		shaft_count = clampi(value, 1, MAX_SHAFTS)
		_queue_rebuild()
## Chiều dài vùng trải các dải theo trục Z cục bộ (m)
@export_range(0.0, 60.0, 0.1, "or_greater") var spread: float = 3.5:
	set(value):
		spread = maxf(value, 0.0)
		_queue_rebuild()
## Lệch ngẫu nhiên theo X cục bộ (m) để các dải không thẳng hàng
@export_range(0.0, 10.0, 0.05, "or_greater") var jitter: float = 0.6:
	set(value):
		jitter = value
		_queue_rebuild()
## Tỉ lệ rút ngắn ngẫu nhiên của từng dải (0 = dài bằng nhau)
@export_range(0.0, 0.8, 0.01) var length_variation: float = 0.25:
	set(value):
		length_variation = value
		_queue_rebuild()
## Độ sáng ngẫu nhiên giữa các dải (0 = đều nhau)
@export_range(0.0, 1.0, 0.01) var brightness_variation: float = 0.45:
	set(value):
		brightness_variation = value
		_queue_rebuild()
@export var random_seed: int = 7:
	set(value):
		random_seed = value
		_queue_rebuild()

@export_group("Màu")
## Vàng ấm nhạt; không dùng trắng/xanh nhạt vì đó là màu riêng của gió
@export var color: Color = Color(1.0, 0.88, 0.64):
	set(value):
		color = value
		_apply_material()
@export_range(0.0, 4.0, 0.01, "or_greater") var intensity: float = 0.14:
	set(value):
		intensity = value
		_apply_material()
@export_range(0.02, 1.0, 0.01) var edge_softness: float = 0.6:
	set(value):
		edge_softness = value
		_apply_material()
## Tỉ lệ chiều dài mờ dần ở đỉnh / ở chân
@export_range(0.0, 1.0, 0.01) var top_fade: float = 0.4:
	set(value):
		top_fade = value
		_apply_material()
@export_range(0.0, 1.0, 0.01) var bottom_fade: float = 0.15:
	set(value):
		bottom_fade = value
		_apply_material()

@export_group("Chuyển động")
## Tốc độ gợn trôi dọc dải (vòng nhiễu / giây)
@export_range(0.0, 3.0, 0.01, "or_greater") var ripple_speed: float = 0.25:
	set(value):
		ripple_speed = value
		_apply_material()
@export_range(0.0, 1.0, 0.01) var ripple_strength: float = 0.35:
	set(value):
		ripple_strength = value
		_apply_material()
## Độ dài một gợn (m)
@export_range(0.1, 20.0, 0.1, "or_greater") var ripple_scale: float = 2.5:
	set(value):
		ripple_scale = value
		_apply_material()
## Tỉ lệ ô có hạt bụi (0 = tắt bụi)
@export_range(0.0, 1.0, 0.01) var dust_density: float = 0.22:
	set(value):
		dust_density = value
		_apply_material()
@export_range(0.0, 0.25, 0.005) var dust_size: float = 0.05:
	set(value):
		dust_size = value
		_apply_material()
## Tốc độ bụi trôi xuống (m/s)
@export_range(0.0, 3.0, 0.01, "or_greater") var dust_speed: float = 0.15:
	set(value):
		dust_speed = value
		_apply_material()
@export_range(0.0, 5.0, 0.05) var dust_brightness: float = 1.6:
	set(value):
		dust_brightness = value
		_apply_material()

@export_group("Mờ khi camera lại gần")
## Khoảng cách camera (m) dải tắt hẳn / bắt đầu mờ
@export_range(0.0, 50.0, 0.1) var near_fade_start: float = 3.0:
	set(value):
		near_fade_start = value
		_apply_material()
@export_range(0.0, 80.0, 0.1) var near_fade_end: float = 8.0:
	set(value):
		near_fade_end = value
		_apply_material()

var _material: ShaderMaterial
var _rebuild_pending: bool = false

@onready var _shafts: MeshInstance3D = $Shafts


func _ready() -> void:
	set_process(false)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_shafts.material_override = _material
	_shafts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_apply_material()
	_rebuild()


func _queue_rebuild() -> void:
	# Gộp nhiều setter đổi cùng lúc (load scene, kéo slider) thành một lần dựng
	if not is_node_ready() or _rebuild_pending:
		return
	_rebuild_pending = true
	_rebuild.call_deferred()


func _apply_material() -> void:
	if _material == null:
		return
	var tilt := deg_to_rad(tilt_degrees)
	# Trục từ đỉnh xuống chân: đỉnh lệch +X nên trục đi về -X và xuống
	_material.set_shader_parameter("axis_direction", Vector3(-sin(tilt), -cos(tilt), 0.0))
	_material.set_shader_parameter("shaft_color", color)
	_material.set_shader_parameter("intensity", intensity)
	_material.set_shader_parameter("edge_softness", edge_softness)
	_material.set_shader_parameter("top_fade", top_fade)
	_material.set_shader_parameter("bottom_fade", bottom_fade)
	_material.set_shader_parameter("ripple_speed", ripple_speed)
	_material.set_shader_parameter("ripple_strength", ripple_strength)
	_material.set_shader_parameter("ripple_scale", ripple_scale)
	_material.set_shader_parameter("dust_density", dust_density)
	_material.set_shader_parameter("dust_size", dust_size)
	_material.set_shader_parameter("dust_speed", dust_speed)
	_material.set_shader_parameter("dust_brightness", dust_brightness)
	_material.set_shader_parameter("near_fade_start", minf(near_fade_start, near_fade_end))
	_material.set_shader_parameter("near_fade_end", maxf(near_fade_start, near_fade_end))


func _rebuild() -> void:
	_rebuild_pending = false
	_apply_material()
	var tilt := deg_to_rad(tilt_degrees)
	var up_axis := Vector3(sin(tilt), cos(tilt), 0.0)
	var full_length := height / maxf(cos(tilt), 0.01)
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var bounds := AABB()
	var top_half := width * 0.5
	var bottom_half := top_half * bottom_width_ratio
	var max_half := maxf(top_half, bottom_half) * 1.3
	for index in shaft_count:
		var slot := (float(index) + 0.5) / shaft_count - 0.5
		var base := Vector3(rng.randf_range(-jitter, jitter), 0.0, slot * spread + rng.randf_range(-0.3, 0.3) * spread / shaft_count)
		var shaft_length := full_length * (1.0 - length_variation * rng.randf())
		var top := base + up_axis * shaft_length
		var shaft_width := rng.randf_range(0.7, 1.3)
		var brightness := 1.0 - brightness_variation * rng.randf()
		var shade := Color(brightness, 0.0, 0.0, rng.randf())
		var first := vertices.size()
		for corner in 4:
			var at_bottom := corner >= 2
			vertices.append(base if at_bottom else top)
			uv.append(Vector2(float(corner % 2), 1.0 if at_bottom else 0.0))
			uv2.append(Vector2((bottom_half if at_bottom else top_half) * shaft_width, shaft_length))
			colors.append(shade)
		indices.append_array(PackedInt32Array([first, first + 1, first + 2, first + 1, first + 3, first + 2]))
		if index == 0:
			bounds = AABB(base, Vector3.ZERO)
		bounds = bounds.expand(base).expand(top)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_shafts.mesh = mesh
	# Mesh chỉ có điểm trên trục, bề rộng do shader thêm: nới hộp bao để không bị cull
	_shafts.custom_aabb = bounds.grow(max_half + BOUNDS_MARGIN)
