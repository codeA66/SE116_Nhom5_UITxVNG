@tool
class_name Water
extends Node3D
## Vùng nước: mặt nước nhấp nhô (shader) và vùng chết bên dưới (KillZone bật Lethal).
## Gốc node là tâm mặt nước. Không xoay hay scale node: sóng tính theo tọa độ thế giới.
## Vật nổi (thuyền) gọi get_height_at() để nhấp nhô khớp với mặt nước.

const SURFACE_SHADER: Shader = preload("res://assets/shaders/environment/water/water.gdshader")
## Giới hạn số ô lưới mỗi cạnh để vùng nước rất to không làm nặng máy
const MAX_SUBDIVISIONS := 200

@export var data: WaterData:
	set(value):
		if data and data.changed.is_connected(_refresh):
			data.changed.disconnect(_refresh)
		data = value
		if data:
			data.changed.connect(_refresh)
		update_configuration_warnings()
		if is_node_ready():
			_refresh()
## x = bề ngang, y = độ sâu vùng chết bên dưới mặt nước, z = chiều dài (m)
@export var size: Vector3 = Vector3(8.0, 4.0, 30.0):
	set(value):
		if size == value:
			return
		size = value
		if is_node_ready():
			_refresh()

var _material: ShaderMaterial
var _mesh: PlaneMesh
var _wave_time: float = 0.0

@onready var _surface: MeshInstance3D = $Surface
@onready var _kill_zone: KillZone = $KillZone
@onready var _notifier: VisibleOnScreenNotifier3D = $ScreenNotifier


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SURFACE_SHADER
	_mesh = PlaneMesh.new()
	_surface.mesh = _mesh
	_surface.material_override = _material
	_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Chỉ đẩy thời gian sóng khi mặt nước đang trên màn hình
	_notifier.screen_entered.connect(set_process.bind(true))
	_notifier.screen_exited.connect(set_process.bind(false))
	_refresh()


func _process(delta: float) -> void:
	_wave_time += delta
	_material.set_shader_parameter(&"wave_time", _wave_time)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if data == null:
		warnings.append("Chưa gán WaterData: kéo một file trong resources/world/water/ vào ô Data.")
	if not basis.is_equal_approx(Basis.IDENTITY):
		warnings.append("Không xoay hay scale node Water: sóng tính theo tọa độ thế giới. Đổi kích thước bằng ô Size.")
	return warnings


## Độ cao mặt nước (tọa độ thế giới) tại vị trí xz, đúng công thức của shader
func get_height_at(world_position: Vector3) -> float:
	var height := global_position.y
	if data == null:
		return height
	var waves := data.get_waves()
	var speeds := data.get_wave_speeds()
	var xz := Vector2(world_position.x, world_position.z)
	for i in waves.size():
		var wave := waves[i]
		var direction := Vector2(wave.x, wave.y).normalized()
		var k := TAU / maxf(wave.z, 0.01)
		height += wave.w * sin(k * (direction.dot(xz) - speeds[i] * _wave_time))
	return height


func _refresh() -> void:
	if data == null:
		_surface.visible = false
		return
	_surface.visible = true
	_mesh.size = Vector2(size.x, size.z)
	_mesh.subdivide_width = clampi(ceili(size.x / maxf(data.grid_spacing, 0.05)), 1, MAX_SUBDIVISIONS)
	_mesh.subdivide_depth = clampi(ceili(size.z / maxf(data.grid_spacing, 0.05)), 1, MAX_SUBDIVISIONS)
	var amplitude_sum := 0.0
	for wave in data.get_waves():
		amplitude_sum += absf(wave.w)
	# Hộp bao rộng thêm theo biên độ sóng để camera không cắt mất đỉnh sóng
	_surface.custom_aabb = AABB(Vector3(-size.x * 0.5, -amplitude_sum, -size.z * 0.5), Vector3(size.x, amplitude_sum * 2.0, size.z))
	_notifier.aabb = _surface.custom_aabb
	var m := _material
	m.set_shader_parameter(&"shallow_color", data.shallow_color)
	m.set_shader_parameter(&"deep_color", data.deep_color)
	m.set_shader_parameter(&"crest_color", data.crest_color)
	m.set_shader_parameter(&"foam_color", data.foam_color)
	m.set_shader_parameter(&"shallow_opacity", data.shallow_opacity)
	m.set_shader_parameter(&"deep_opacity", data.deep_opacity)
	m.set_shader_parameter(&"depth_fade_distance", data.depth_fade_distance)
	m.set_shader_parameter(&"foam_width", data.foam_width)
	m.set_shader_parameter(&"edge_foam_width", data.edge_foam_width)
	m.set_shader_parameter(&"plane_size", Vector2(size.x, size.z))
	m.set_shader_parameter(&"foam_line_distance", data.foam_line_distance)
	m.set_shader_parameter(&"foam_line_width", data.foam_line_width)
	m.set_shader_parameter(&"foam_noise_scale", data.foam_noise_scale)
	m.set_shader_parameter(&"foam_speed", data.foam_speed)
	m.set_shader_parameter(&"patch_scale", data.patch_scale)
	m.set_shader_parameter(&"patch_opacity", data.patch_opacity)
	m.set_shader_parameter(&"sparkle_density", data.sparkle_density)
	m.set_shader_parameter(&"wave_amplitude_sum", amplitude_sum)
	m.set_shader_parameter(&"wave_1", data.wave_1)
	m.set_shader_parameter(&"wave_2", data.wave_2)
	m.set_shader_parameter(&"wave_3", data.wave_3)
	m.set_shader_parameter(&"wave_speeds", Vector3(data.wave_1_speed, data.wave_2_speed, data.wave_3_speed))
	# Vùng chết ngay dưới mặt nước, đúng bề ngang và chiều dài vùng nước
	_kill_zone.size = Vector3(size.x, size.y, size.z)
	_kill_zone.position = Vector3(0.0, -data.kill_depth_offset - size.y * 0.5, 0.0)
	update_configuration_warnings()
