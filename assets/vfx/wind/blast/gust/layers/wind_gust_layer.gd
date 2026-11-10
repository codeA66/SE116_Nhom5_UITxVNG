class_name WindGustLayer
extends MeshInstance3D
## Ghi đường nét và màu vào mesh để dùng vật liệu chuẩn của Compatibility.
const MIN_SPAN: float = 0.001
const STROKE_WIDTH_PROFILE: float = 0.65

@export_group("Ink")
@export var white_core: Color = Color("#d8faff")
@export var cyan_edge: Color = Color("#91e9f5")
@export var dark_teal: Color = Color("#235662")
@export_group("Sound")
@export var phase_sound: AudioStream
@export var loop_sound: bool = false

static var _shared_material: StandardMaterial3D

var gust: WindBlastGust
var cast_extent: Vector3
var _age: float
var _span: float
var _audio: AudioStreamPlayer3D

## Chuẩn bị mesh trước khi chơi để lúc bấm E chỉ cần cập nhật transform.
func _ready() -> void:
	gust = get_parent() as WindBlastGust
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material_override = ink_material()
	_audio = get_node_or_null(^"Audio") as AudioStreamPlayer3D
	if _audio != null:
		_audio.stream = phase_sound
		if loop_sound:
			_audio.finished.connect(_repeat_sound)
	gust.visual_reset.connect(stop_layer)
	stop_layer()

## Hình chỉ thay đổi transform trong lúc pha đang hoạt động.
func _process(delta: float) -> void:
	_age += delta
	if _age >= _span:
		stop_layer()
		return
	_update_shape(_age / _span)

## Các lớp ngừng xử lý cùng lúc với hình để lượt sau không mang đuôi cũ.
func stop_layer() -> void:
	hide()
	set_process(false)
	if _audio != null:
		_audio.stop()

## Hộp thiết kế lưu riêng vì một số lớp co lại trong khi bay.
func begin_layer(span: float, extent: Vector3) -> void:
	_age = 0.0
	_span = maxf(span, MIN_SPAN)
	cast_extent = extent.max(Vector3.ONE * MIN_SPAN)
	_update_shape(0.0)
	show()
	set_process(true)
	if _audio != null and _audio.stream != null:
		_audio.play()

## Cùng một biến thể vật liệu cho cả nét chính lẫn impact.
static func ink_material() -> StandardMaterial3D:
	if _shared_material == null:
		_shared_material = StandardMaterial3D.new()
		_shared_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_shared_material.vertex_color_use_as_albedo = true
		_shared_material.vertex_color_is_srgb = true
	return _shared_material

## Các dải màu dùng chung mặt phẳng để biên sắc và tránh lớp trong suốt chồng lên nhau.
static func add_stroke(builder: SurfaceTool, points: PackedVector3Array, width: float,
		core: Color, edge: Color, outline: Color, bank: float = 0.0) -> void:
	var last: int = points.size() - 1
	var offsets: PackedFloat32Array = PackedFloat32Array([-0.5, -0.35, 0.08, 0.39, 0.5])
	var colors: Array[Color] = [outline, edge, core, outline]
	var previous: PackedVector3Array = PackedVector3Array()
	for index: int in points.size():
		var t: float = float(index) / float(last)
		var direction: Vector3 = points[mini(index + 1, last)] - points[maxi(index - 1, 0)]
		var normal: Vector3 = Vector3.UP.cross(direction).normalized()
		normal = (normal + Vector3.UP * bank).normalized()
		var half_span: float = width * pow(maxf(sin(PI * t), MIN_SPAN), STROKE_WIDTH_PROFILE)
		var row: PackedVector3Array = PackedVector3Array()
		for offset: float in offsets:
			row.append(points[index] + normal * offset * half_span)
		if index > 0:
			for band: int in colors.size():
				_add_triangle(builder, previous[band], row[band], row[band + 1], colors[band])
				_add_triangle(builder, previous[band], row[band + 1], previous[band + 1], colors[band])
		previous = row

## Nét thay đổi bề dày qua các điểm trên một đường cong vẽ tay.
static func stroke_curve(start: Vector3, handle_a: Vector3, handle_b: Vector3,
		end: Vector3, segments: int) -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	for step: int in range(segments + 1):
		points.append(start.bezier_interpolate(handle_a, handle_b, end, float(step) / float(segments)))
	return points

## Mảnh bụi dùng cùng surface để không cần hệ particle hoặc material riêng.
static func add_chip(builder: SurfaceTool, center: Vector3, span: Vector2, color: Color) -> void:
	_add_triangle(builder, center + Vector3(-span.x, 0.0, -span.y),
		center + Vector3(span.x, span.x, -span.y * 0.4), center + Vector3(0.0, 0.0, span.y), color)

## Các lớp có thể dùng kích thước cố định hoặc đổi theo tuổi của pha.
func _update_shape(_phase: float) -> void:
	scale = cast_extent

## Giữ âm thanh tại lớp tương ứng khi có stream do người dùng gán.
func _repeat_sound() -> void:
	if visible and _audio.stream != null:
		_audio.play()

## Ghi màu riêng cho mỗi tam giác để giữ nét viền sắc.
static func _add_triangle(builder: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	builder.set_color(color)
	builder.add_vertex(a)
	builder.add_vertex(b)
	builder.add_vertex(c)

