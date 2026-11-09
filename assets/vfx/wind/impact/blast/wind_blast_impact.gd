extends WindImpactVfx
## Chớp tiếp xúc rồi quét gió qua mục tiêu bằng hai mesh dùng chung material.

@export_group("Nhịp va chạm")
@export_range(0.01, 0.12) var flash_time: float = 0.052
@export_range(0.0, 1.0) var slide_fraction: float = 0.58
@export_range(0.04, 1.0) var end_scale: float = 0.12
@export_range(6, 24) var segments: int = 10

static var _cached_mesh: ArrayMesh
static var _cached_flash: ArrayMesh
static var _cached_style: WindBurstStyle
static var _cached_segments: int

var _flash: ArrayMesh
var _wake: ArrayMesh

@onready var _shape: MeshInstance3D = $Ink

## Bỏ khởi tạo material của scene gốc vì impact chỉ dùng lưới đã dựng.
func _ready() -> void:
	if _cached_mesh == null or _cached_style != style or _cached_segments != segments:
		_cached_mesh = _build_ink()
		_cached_flash = _build_flash()
		_cached_style = style
		_cached_segments = segments
	_flash = _cached_flash
	_wake = _cached_mesh
	_shape.mesh = _flash
	_shape.material_override = WindGustLayer.ink_material()
	# Scene kế thừa bụi gió cũ: các lớp hạt cũ không được khởi tạo (không gọi super._ready) nên phải ẩn hẳn,
	# nếu không chúng hiện ở gốc toạ độ thế giới với material rỗng
	for legacy: Node3D in [_strokes, _motes, _ring, _charge, _mist]:
		legacy.hide()
	stop()

## Dời nét theo hướng lực đã truyền và trả lại slot đúng một lần.
func _process(delta: float) -> void:
	_age += delta
	var phase: float = _age / maxf(style.duration, WindGustLayer.MIN_SPAN)
	if phase >= 1.0:
		stop()
		finished.emit()
		return
	if _age >= flash_time and _shape.mesh != _wake:
		_shape.mesh = _wake
	_apply_shape(phase)

## WindImpactPool vẫn phát qua play_at() và nhận finished như các preset khác.
func play(_has_ground: bool = true) -> void:
	_age = 0.0
	playing = true
	_shape.mesh = _flash
	_apply_shape(0.0)
	_shape.show()
	set_process(true)

## Đặt slot về trạng thái sạch trước khi phát lại.
func stop() -> void:
	playing = false
	_shape.hide()
	set_process(false)

## Chớp bám đúng điểm trúng, chỉ phần gió sau va mới trượt theo hướng đẩy.
func _apply_shape(phase: float) -> void:
	if _shape.mesh == _flash:
		_shape.position = Vector3.ZERO
		var flash_phase: float = clampf(_age / maxf(flash_time, WindGustLayer.MIN_SPAN), 0.0, 1.0)
		_shape.scale = Vector3.ONE * lerpf(0.83, 1.06, flash_phase)
		return
	var sweep: float = smoothstep(flash_time / maxf(style.duration, WindGustLayer.MIN_SPAN), 1.0, phase)
	_shape.position.z = style.reach * slide_fraction * sweep
	_shape.scale = Vector3(lerpf(1.0, end_scale, sweep), lerpf(1.0, end_scale, sweep), lerpf(0.82, 1.04, sweep))

## Hai mép chớp lệch nhau mở ngang qua thân để dấu trúng hiện rõ quanh silhouette.
func _build_flash() -> ArrayMesh:
	var builder: SurfaceTool = SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h: float = style.shot_height
	var edge: Color = style.edge_color.lerp(style.core_color, 0.48)
	WindGustLayer.add_stroke(builder, WindGustLayer.stroke_curve(
		Vector3(-0.67, h - 0.10, 0.21), Vector3(-0.52, h + 0.39, -0.33),
		Vector3(0.08, h + 0.51, -0.46), Vector3(0.39, h + 0.18, -0.12), segments),
		style.width * 1.55, style.core_color, edge, style.edge_color, 0.64)
	WindGustLayer.add_stroke(builder, WindGustLayer.stroke_curve(
		Vector3(-0.26, h + 0.14, 0.02), Vector3(0.12, h - 0.32, -0.40),
		Vector3(0.58, h - 0.16, -0.11), Vector3(0.70, h - 0.07, 0.35), segments),
		style.width * 1.28, style.core_color, edge, style.edge_color, -0.70)
	WindGustLayer.add_chip(builder, Vector3(-0.67, h + 0.17, 0.25), Vector2(0.055, 0.14), style.core_color)
	WindGustLayer.add_chip(builder, Vector3(0.58, h + 0.16, 0.52), Vector2(0.065, 0.16), style.core_color)
	var contact: Vector3 = Vector3(0.0, h + 0.47, -0.43)
	_add_contact_ray(builder, contact, Vector3(-0.46, 0.40, -0.12), style.width * 0.74)
	_add_contact_ray(builder, contact, Vector3(0.63, 0.14, 0.13), style.width * 0.86)
	_add_contact_ray(builder, contact, Vector3(0.12, 0.50, 0.44), style.width * 0.60)
	return builder.commit()

## Nét nhọn cùng xuất phát tại điểm chạm để cú lóe vẫn đọc được khi thân che vòng gió.
func _add_contact_ray(builder: SurfaceTool, origin: Vector3, ray: Vector3, width: float) -> void:
	var across: Vector3 = Vector3.UP.cross(ray).normalized() * width
	var shoulder: Vector3 = origin + ray * 0.33
	builder.set_color(style.core_color)
	builder.add_vertex(origin - across * 0.6)
	builder.add_vertex(shoulder + across)
	builder.set_color(style.core_color.lerp(style.edge_color, 0.37))
	builder.add_vertex(origin + ray)

## Nét sau va thấp hơn, lệch về trước để nối với hướng bật của mục tiêu.
func _build_ink() -> ArrayMesh:
	var builder: SurfaceTool = SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var height: float = style.shot_height * 0.47
	var reach: float = style.reach
	var edge: Color = style.core_color.lerp(style.edge_color, 0.45)
	WindGustLayer.add_stroke(builder, WindGustLayer.stroke_curve(
		Vector3(-0.52, height, 0.0), Vector3(-0.39, height + 0.10, reach * 0.43),
		Vector3(0.34, height + 0.24, reach * 0.83), Vector3(0.45, height + 0.12, reach * 0.46), segments),
		style.width, style.core_color, edge, style.edge_color, 0.64)
	WindGustLayer.add_stroke(builder, WindGustLayer.stroke_curve(
		Vector3(-0.32, height * 0.35, reach * 0.14), Vector3(-0.20, height * 0.54, reach * 0.47),
		Vector3(0.11, height * 0.64, reach * 0.62), Vector3(0.19, height * 0.51, reach * 0.44), segments),
		style.width * 0.62, style.core_color, edge, style.edge_color, 0.3)
	WindGustLayer.add_chip(builder, Vector3(-0.28, height * 0.4, reach * 0.45), Vector2(0.04, 0.09), edge)
	WindGustLayer.add_chip(builder, Vector3(0.32, height * 0.3, reach * 0.55), Vector2(0.045, 0.075), style.edge_color)
	WindGustLayer.add_chip(builder, Vector3(0.08, height * 0.8, reach * 0.65), Vector2(0.035, 0.07), style.core_color)
	return builder.commit()
