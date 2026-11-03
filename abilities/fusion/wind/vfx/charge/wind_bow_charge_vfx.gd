class_name WindBowChargeVfx
extends Node3D
## DONE: dải gió xoắn 3D quanh thân tên, chỉ nhận wind từ hook generic.
## NOT DONE: chưa gắn Player production; chờ duyệt mỹ thuật trong màn chơi.
## NOTES: một surface, không hạt/đèn/node phát sinh trong combat; nghỉ hoàn toàn khi idle.
enum Phase { IDLE, DRAWING, RELEASED, CANCELLING }
const SHADER: Shader = preload("res://abilities/fusion/wind/vfx/charge/wind_bow_charge.gdshader")
@export_group("Wiring")
@export var player: Player
@export_group("Arrow Tip")
@export var tip_offset_rest: Vector3 = Vector3(0.0, 0.0, 0.429116)
@export var tip_offset_full: Vector3 = Vector3(0.0, 0.0, 0.009116)
@export_group("Streaks")
@export_range(1, 12, 1) var streak_count: int = 3
@export_range(8, 96, 1) var segments: int = 48
@export var streak_length_min: float = 1.0
@export var streak_length_max: float = 1.80
@export var orbit_radius: float = 0.28
@export var spin_speed_min: float = 3.0
@export var spin_speed_max: float = 12.0
@export var thickness: float = 0.25
@export var turns: float = 0.70
@export var taper_power: float = 0.55
@export var tip_fade_fraction: float = 0.12
@export var edge_feather: float = 0.30
@export var texture_influence: float = 0.20
@export var texture_uv_y: Vector2 = Vector2(0.40, 0.61)
@export_group("Timing")
@export var appear_time: float = 0.06
@export var fade_time: float = 0.14
@export var release_time: float = 0.16
@export var release_distance: float = 0.32
@export var ready_time: float = 0.18
@export var ready_expansion: float = 0.25
@export var minimum_duration: float = 0.001
@export var prepare_on_ready: bool = true
@export_range(1, 6, 1) var prepare_frames: int = 3
@export var prepare_scale: float = 0.000001
@export_group("Palette")
@export var color: Color = Color(0.78, 0.95, 1.0, 1.0)
@export var edge_color: Color = Color(0.20, 0.43, 0.50, 1.0)
@export var brightness_min: float = 0.85
@export var brightness_max: float = 1.0
@export var streak_texture: Texture2D = preload("res://abilities/fusion/wind/vfx/textures/wind_streak.png")
static var _mesh_cache: Dictionary[Vector2i, ArrayMesh] = {}
var _material: ShaderMaterial
var _phase: Phase = Phase.IDLE
var _amount: float = 0.0
var _age: float = 0.0
var _spin: float = 0.0
var _ready_age: float = 0.0
var _ready_latched: bool = false
var _ready_active: bool = false
var _opacity: float = 0.0
var _fade_start: float = 0.0
var _release_origin: Transform3D
var _epoch: int = 0
@onready var _ribbons: MeshInstance3D = $Ribbons

## Dải dùng chung mesh/material trong một instance; không cấp phát khi signal draw tới mỗi frame.
func _ready() -> void:
	top_level = true
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_ribbons.material_override = _material
	_ribbons.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_mesh()
	_configure()
	reset()
	if is_instance_valid(player):
		player.fusion_bow_draw.connect(_on_draw)
		player.fusion_bow_released.connect(_on_released)
		player.fusion_bow_aim_ended.connect(_on_aim_ended)
	if prepare_on_ready and DisplayServer.get_name() != "headless":
		_prepare()

## Chỉ cập nhật scalar và transform trong lúc có hình.
func _process(delta: float) -> void:
	if not is_instance_valid(player):
		reset()
		return
	_age += delta
	_spin = fposmod(_spin + lerpf(spin_speed_min, spin_speed_max, _amount) * delta, TAU)
	if _phase == Phase.DRAWING:
		_sync_tip()
		_opacity = smoothstep(0.0, maxf(appear_time, minimum_duration), _age)
	else:
		var duration: float = release_time if _phase == Phase.RELEASED else fade_time
		var t: float = clampf(_age / maxf(duration, minimum_duration), 0.0, 1.0)
		_opacity = _fade_start * (1.0 - t)
		if _phase == Phase.RELEASED:
			global_transform = _release_origin
			global_position += _release_origin.basis.z * release_distance * t
		if t >= 1.0:
			reset()
			return
	var pulse: float = 0.0
	if _ready_active:
		_ready_age += delta
		pulse = sin(clampf(_ready_age / maxf(ready_time, minimum_duration), 0.0, 1.0) * PI)
		if _ready_age >= ready_time:
			_ready_active = false
	_material.set_shader_parameter(&"phase", _spin)
	_material.set_shader_parameter(&"opacity", _opacity)
	_material.set_shader_parameter(&"ready_pulse", pulse)

## Dọn cả trạng thái và hình, không để shader opacity bằng không vẫn tốn draw.
func reset() -> void:
	_epoch += 1
	_phase = Phase.IDLE
	_opacity = 0.0
	_ready_active = false
	_ready_latched = false
	_ready_age = 0.0
	_spin = 0.0
	_ribbons.hide()
	set_process(false)

## Bỏ draw(0) sau buông, chỉ wind được kích hoạt scene.
func _on_draw(element_id: StringName, amount: float) -> void:
	if element_id != &"wind" or not is_instance_valid(player):
		return
	if _phase != Phase.IDLE and _phase != Phase.DRAWING and amount <= 0.0:
		return
	if _phase != Phase.DRAWING:
		_epoch += 1
		_phase = Phase.DRAWING
		_age = 0.0
		_ready_latched = false
		_ready_active = false
		_material.set_shader_parameter(&"warm_scale", 1.0)
		_material.set_shader_parameter(&"opacity", 0.0)
		_ribbons.show()
	_amount = clampf(amount, 0.0, 1.0)
	if _amount >= 1.0 and not _ready_latched:
		_ready_latched = true
		_ready_active = true
		_ready_age = 0.0
	_material.set_shader_parameter(&"streak_length", maxf(lerpf(streak_length_min, streak_length_max, _amount), minimum_duration))
	_material.set_shader_parameter(&"charge", _amount)
	_sync_tip()
	set_process(true)

## Burst giữ transform lúc buông, không trở thành flying trail hoặc sinh đạn.
func _on_released(element_id: StringName) -> void:
	if element_id != &"wind" or _phase != Phase.DRAWING:
		return
	_sync_tip()
	_release_origin = global_transform
	_fade_start = _opacity
	_phase = Phase.RELEASED
	_age = 0.0
	_ready_active = false

## Aim ended sau release không được cắt burst; cancel thật thì fade từ opacity hiện tại.
func _on_aim_ended(element_id: StringName) -> void:
	if element_id != &"wind" or _phase == Phase.IDLE or _phase == Phase.RELEASED:
		return
	_phase = Phase.CANCELLING
	_fade_start = _opacity
	_age = 0.0
	_ready_active = false

## Chỉ dùng API world grip đã duyệt; không đọc node private của cung.
func _sync_tip() -> void:
	var grip: Transform3D = player.get_bow_grip_transform()
	global_transform = Transform3D(grip.basis.orthonormalized(), grip * tip_offset_rest.lerp(tip_offset_full, _amount))

## Thông số shader lấy từ export; không sửa tài nguyên style gió dùng chung.
func _configure() -> void:
	for key: StringName in [&"orbit_radius", &"thickness", &"turns", &"edge_color", &"brightness_min", &"brightness_max", &"ready_expansion", &"streak_texture", &"taper_power", &"tip_fade_fraction", &"edge_feather", &"texture_influence", &"texture_uv_y"]:
		_material.set_shader_parameter(key, get(key))
	_material.set_shader_parameter(&"wind_color", color)
	_material.set_shader_parameter(&"count", float(streak_count))
	var extent: float = maxf(absf(streak_length_min), absf(streak_length_max)) + absf(orbit_radius) + absf(thickness) + absf(release_distance)
	_ribbons.custom_aabb = AABB(-Vector3.ONE * extent, Vector3.ONE * extent * 2.0)

## Dải mẫu dựng một lần; shader uốn thành helix ba chiều quanh trục tên.
func _build_mesh() -> void:
	var key: Vector2i = Vector2i(streak_count, segments)
	if _mesh_cache.has(key):
		_ribbons.mesh = _mesh_cache[key]
		return
	var vertices: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var uv2: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for strand: int in range(streak_count):
		var base: int = vertices.size()
		for index: int in range(segments + 1):
			for side: int in range(2):
				vertices.append(Vector3.ZERO)
				uv.append(Vector2(float(index) / segments, float(side)))
				uv2.append(Vector2(float(strand), 0.0))
		for index: int in range(segments):
			var a: int = base + index * 2
			indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_ribbons.mesh = mesh
	_mesh_cache[key] = mesh

## Chuẩn bị pipeline ở kích thước không thấy được, không dùng transparency của GeometryInstance.
func _prepare() -> void:
	var epoch: int = _epoch
	_material.set_shader_parameter(&"warm_scale", prepare_scale)
	_material.set_shader_parameter(&"opacity", 1.0)
	_material.set_shader_parameter(&"streak_length", streak_length_max)
	_ribbons.show()
	for frame: int in range(prepare_frames):
		await RenderingServer.frame_post_draw
	if epoch == _epoch:
		reset()
		_material.set_shader_parameter(&"warm_scale", 1.0)
