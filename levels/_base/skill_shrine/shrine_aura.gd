class_name ShrineAura
extends MeshInstance3D
## Một mesh giữ danh tính từng đốm sáng từ cột bệ tới lúc bùng (tham khảo cảnh nhận phép của Hollow Knight):
## đốm bốc lên ở bệ → nổ ra phủ màn hình → bị hút thành vệt về ngực → cụm sáng → quầng sáng mềm bùng ra.
## Dải gió chỉ thuộc cột chờ và tan trong Lift để lúc nghi thức chỉ còn một ngôn ngữ hình.

const SHADER: Shader = preload("res://levels/_base/skill_shrine/shrine_aura.gdshader")
const Renderer = preload("res://components/feedback/loot_beam/ability_acquire/core/ability_acquire_renderer.gd")
const IDLE_PHASE: int = -1
const SEGMENTS: int = 10
const KIND_ORB: float = 1.0
const KIND_MOTE: float = 3.0
const MIN_TWEEN_TIME: float = 0.001
const QUAD: Array[Vector2] = [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.ZERO, Vector2.ONE, Vector2.DOWN]

@export_group("Cột gió")
@export_range(1, 32) var wisp_count: int = 26
@export var radius_range: Vector2 = Vector2(0.34, 0.79)
@export_range(0.05, 6.0) var column_height: float = 2.45
@export_range(0.005, 0.3) var wisp_width: float = 0.14
@export_range(0.08, 2.0) var wisp_span: float = 1.12
@export_range(0.0, 5.0) var spin_speed: float = 0.92
@export_group("Đốm sáng")
@export_range(8, 400) var mote_count: int = 200
@export_range(0.01, 0.5) var mote_size: float = 0.17
## Tốc độ đốm bốc lên trong cột lúc chờ (vòng/giây theo chiều cao cột)
@export_range(0.0, 1.0) var mote_rise_speed: float = 0.14
## Nửa bề rộng / nửa chiều cao mây đốm trong mặt phẳng camera (m); đủ lớn để phủ khung hình
@export var scatter_spread: Vector2 = Vector2(7.5, 4.4)
@export_range(0.0, 5.0) var scatter_depth: float = 1.5
## Tỉ lệ đốm sát camera (to, mờ) tạo chiều sâu như tiền cảnh
@export_range(0.0, 1.0) var foreground_ratio: float = 0.12
@export_range(0.0, 10.0) var foreground_depth: float = 4.0
@export_range(1.0, 6.0) var foreground_scale: float = 2.6
## Phần đầu pha Scatter dành cho cú nổ, phần còn lại đốm lơ lửng
@export_range(0.05, 1.0) var explode_portion: float = 0.32
@export_range(0.0, 2.0) var wander_amplitude: float = 0.35
@export_range(0.0, 5.0) var wander_speed: float = 0.7
@export_group("Hút vào")
## Độ lệch nhịp xuất phát giữa các đốm (phần của pha) và thời gian bay mỗi đốm
@export_range(0.0, 0.9) var absorb_delay: float = 0.5
@export_range(0.05, 1.0) var absorb_span: float = 0.36
@export_range(0.05, 3.0) var cluster_radius: float = 0.55
@export_range(0.0, 10.0) var absorb_streak: float = 1.3
@export_group("Bùng nổ")
@export_range(0.05, 4.0) var orb_radius: float = 1.2
## Quầng sáng nở thêm bao nhiêu lần bán kính khi bùng
@export_range(0.0, 6.0) var orb_burst_scale: float = 2.2
## Đặt quầng trước model để thân cáo tan trong ánh sáng từ đúng góc camera
@export_range(0.0, 3.0) var orb_camera_offset: float = 0.85
@export_range(0.05, 12.0) var burst_radius: float = 4.5
@export_range(0.0, 30.0) var burst_streak: float = 7.0
@export_range(0.0, 5.0) var streak_max: float = 1.6
@export_group("Lắng xuống")
## Tỉ lệ đốm còn bốc lên như khói sau khi bùng
@export_range(0.0, 1.0) var settle_ratio: float = 0.25
@export_range(0.0, 5.0) var settle_rise: float = 1.6

var _material: ShaderMaterial
var _tween: Tween
var _phase: int = IDLE_PHASE


## Dựng hình một lần lúc tải phòng; mọi chuyển động chạy trên GPU.
func _ready() -> void:
	set_process(false)
	hide()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	var parameters: Dictionary[StringName, Variant] = {
		&"intensity": 0.0, &"phase": IDLE_PHASE, &"wisp_count": float(wisp_count), &"column_radius": radius_range,
		&"column_height": column_height, &"wisp_width": wisp_width, &"wisp_span": wisp_span, &"spin_speed": spin_speed,
		&"mote_total": float(mote_count), &"mote_size": mote_size, &"mote_rise_speed": mote_rise_speed,
		&"scatter_spread": scatter_spread, &"scatter_depth": scatter_depth, &"foreground_ratio": foreground_ratio,
		&"foreground_depth": foreground_depth, &"foreground_scale": foreground_scale, &"explode_portion": explode_portion,
		&"wander_amplitude": wander_amplitude, &"wander_speed": wander_speed, &"absorb_delay": absorb_delay,
		&"absorb_span": absorb_span, &"cluster_radius": cluster_radius, &"absorb_streak": absorb_streak,
		&"burst_streak": burst_streak, &"streak_max": streak_max, &"burst_radius": burst_radius,
		&"settle_ratio": settle_ratio, &"settle_rise": settle_rise, &"orb_radius": orb_radius,
		&"orb_burst_scale": orb_burst_scale, &"orb_camera_offset": orb_camera_offset,
	}
	for key: StringName in parameters:
		_material.set_shader_parameter(key, parameters[key])
	material_override = _material
	mesh = _build_mesh()
	_update_bounds()


## Màu lõi; mặc định trắng tinh như Hollow Knight, kỹ năng khác có thể pha màu.
func set_color(color: Color) -> void:
	_material.set_shader_parameter(&"core_color", color)


## Chỗ sách tan (toạ độ local của Aura): đốm gom về đây trong Lift rồi nổ ra từ đây.
func set_source(local_point: Vector3) -> void:
	_material.set_shader_parameter(&"source", local_point)


## Ẩn cả mesh khi tắt để không giữ một lượt vẽ trong phòng đã học.
func set_intensity(value: float, time: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	if value <= 0.0 and not visible:
		_apply_intensity(0.0)
		return
	if value > 0.0:
		show()
	_tween = create_tween()
	var previous: float = float(_material.get_shader_parameter(&"intensity"))
	_tween.tween_method(_apply_intensity, previous, value, maxf(time, MIN_TWEEN_TIME))
	if value <= 0.0:
		_tween.tween_callback(hide)


## Dùng đồng hồ của FSM để nhịp nén và bung đứng cùng lúc với nhân vật và camera.
func set_ceremony_frame(phase: int, progress: float, focus: Vector3) -> void:
	if _phase == IDLE_PHASE:
		if _tween and _tween.is_valid():
			_tween.kill()
		show()
	if _phase != phase:
		_phase = phase
		_material.set_shader_parameter(&"phase", phase)
	_material.set_shader_parameter(&"phase_progress", progress)
	# Lõi vừa vỡ đứng yên trong không gian; không kéo quầng sáng theo cáo lúc hạ xuống.
	if phase != Renderer.PHASE_BURST and phase != Renderer.PHASE_SETTLE:
		_material.set_shader_parameter(&"chest", to_local(focus))


## Màn đen hoặc hủy lượt trả mesh về pha chờ và tắt lượt vẽ ngay.
func end_ceremony() -> void:
	_phase = IDLE_PHASE
	_material.set_shader_parameter(&"phase", IDLE_PHASE)
	_material.set_shader_parameter(&"phase_progress", 0.0)
	_apply_intensity(0.0)
	hide()


## Shader dời đỉnh ra mặt phẳng camera; bounds bao trọn mây đốm để không bị cull giữa chừng.
func _update_bounds() -> void:
	var extent: float = maxf(maxf(scatter_spread.x, scatter_spread.y), burst_radius + streak_max)
	extent += maxf(foreground_depth, orb_radius * (1.0 + orb_burst_scale) + orb_camera_offset)
	custom_aabb = AABB(-Vector3.ONE * extent, Vector3.ONE * extent * 2.0)


func _apply_intensity(value: float) -> void:
	_material.set_shader_parameter(&"intensity", value)


## Gộp dải gió, đốm và quầng vào một surface; UV2 giữ loại hình và mã ổn định.
func _build_mesh() -> ArrayMesh:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(wisp_count):
		for segment: int in range(SEGMENTS):
			for corner: Vector2 in QUAD:
				builder.set_uv(Vector2((float(segment) + corner.x) / float(SEGMENTS), corner.y))
				builder.set_uv2(Vector2(float(index), 0.0))
				builder.add_vertex(Vector3.ZERO)
	for index: int in range(mote_count):
		_add_quad(builder, float(index), KIND_MOTE)
	_add_quad(builder, 0.0, KIND_ORB)
	return builder.commit()


func _add_quad(builder: SurfaceTool, id: float, kind: float) -> void:
	for corner: Vector2 in QUAD:
		builder.set_uv(corner)
		builder.set_uv2(Vector2(id, kind))
		builder.add_vertex(Vector3.ZERO)
