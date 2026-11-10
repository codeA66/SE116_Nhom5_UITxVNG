class_name AcquireAbsorbVisual
extends MeshInstance3D
## Hình của pha Hấp thu: dải năng lượng xoắn từ chỗ sách tan cuốn vào ngực, vòng co quanh người, quả cầu sáng
## nuốt nhân vật cuối pha. Một mesh + một shader (một lần vẽ). Lưới dải dựng lại mỗi lần nhận kỹ năng (vì chỗ sách
## và chỗ đứng mỗi lần khác nhau; chỉ xảy ra một lần mỗi kỹ năng), mỗi frame chỉ đổi uniform.

const SHADER: Shader = preload("res://components/feedback/loot_beam/ability_acquire/phases/charge/absorb/acquire_absorb.gdshader")
const KIND_STREAM := 0.0
const KIND_RING := 1.0
const KIND_ORB := 2.0
## Số đoạn trên mỗi dải / mỗi vòng
const STREAM_SEGMENTS := 28
const RING_SEGMENTS := 40

## Lõi luôn ngả trắng; viền tối lấy từ màu nguyên tố cho dễ đọc trên nền sáng
@export_range(0.0, 1.0) var core_whiten: float = 0.75
@export_range(0.0, 1.0) var rim_darken: float = 0.7
## Bề ngang vòng co (m)
@export var ring_width: float = 0.07

var _material: ShaderMaterial
var _data: AbilityAcquireData


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material_override = _material
	hide()


## Dựng dải từ source (thế giới) tới chest (thế giới), đặt màu theo nguyên tố
func begin(source: Vector3, chest: Vector3, accent: Color, data: AbilityAcquireData) -> void:
	_data = data
	global_transform = Transform3D(Basis.IDENTITY, chest)
	mesh = _build(source - chest, data)
	_material.set_shader_parameter(&"accent_color", accent)
	_material.set_shader_parameter(&"core_color", accent.lerp(Color.WHITE, core_whiten))
	_material.set_shader_parameter(&"rim_color", accent.darkened(rim_darken))
	_material.set_shader_parameter(&"dashes", data.absorb_dashes)
	var reach: float = maxf((source - chest).length(), data.absorb_ring_radius.x) + data.absorb_orb_radius
	custom_aabb = AABB(-Vector3.ONE * reach, Vector3.ONE * reach * 2.0)
	update(0.0, 0.0)
	show()


## progress 0..1 của pha, clock = giây thực đã trôi (chạy cả khi thế giới đang dừng)
func update(progress: float, clock: float) -> void:
	if _data == null:
		return
	var appear: float = smoothstep(0.0, 0.12, progress)
	var orb_t: float = smoothstep(_data.absorb_orb_start, 1.0, progress)
	_material.set_shader_parameter(&"progress", progress)
	_material.set_shader_parameter(&"flow", clock * _data.absorb_flow_speed)
	# Dải và vòng mờ dần khi quả cầu nuốt nhân vật
	_material.set_shader_parameter(&"stream_alpha", appear * (1.0 - orb_t * 0.85))
	var ring_t: float = progress * progress * (3.0 - 2.0 * progress)
	_material.set_shader_parameter(&"ring_radius", lerpf(_data.absorb_ring_radius.x, _data.absorb_ring_radius.y, ring_t))
	_material.set_shader_parameter(&"orb_radius", _data.absorb_orb_radius * (1.0 - pow(1.0 - orb_t, 3.0)))
	_material.set_shader_parameter(&"orb_alpha", orb_t)


func stop() -> void:
	hide()
	_data = null


func _build(source_local: Vector3, data: AbilityAcquireData) -> ArrayMesh:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var axis: Vector3 = source_local.normalized() if not source_local.is_zero_approx() else Vector3.FORWARD
	var side: Vector3 = axis.cross(Vector3.UP).normalized() if absf(axis.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var up: Vector3 = side.cross(axis).normalized()
	for stream: int in data.absorb_stream_count:
		var phase: float = TAU * float(stream) / float(data.absorb_stream_count)
		var points := PackedVector3Array()
		for step: int in STREAM_SEGMENTS + 1:
			var t: float = float(step) / float(STREAM_SEGMENTS)
			# t = 0 ở sách, 1 ở ngực; bán kính xoắn phình ở giữa đường rồi co về 0 ở hai đầu
			var radius: float = data.absorb_stream_radius * sin(PI * t) * (1.0 - t * 0.35)
			var angle: float = phase + TAU * data.absorb_stream_turns * t
			var center: Vector3 = source_local * (1.0 - t)
			points.append(center + (side * cos(angle) + up * sin(angle)) * radius)
		_add_strip(builder, points, data.absorb_stream_width, KIND_STREAM, 0.0)
	for ring: int in data.absorb_ring_count:
		var points := PackedVector3Array()
		var y: float = (float(ring) - float(data.absorb_ring_count - 1) * 0.5) * 0.35
		for step: int in RING_SEGMENTS + 1:
			var a: float = TAU * float(step) / float(RING_SEGMENTS)
			points.append(Vector3(cos(a), y, sin(a)))
		_add_strip(builder, points, ring_width, KIND_RING, float(ring))
	# Quả cầu: một quad, shader tự quay về camera và đặt cỡ
	_add_quad(builder)
	return builder.commit()


## Dải nằm theo points; bề ngang hướng về camera không cố định nên lấy pháp tuyến ngang + đứng xen kẽ đủ đọc từ trên
func _add_strip(builder: SurfaceTool, points: PackedVector3Array, width: float, kind: float, index: float) -> void:
	var last: int = points.size() - 1
	var previous_a := Vector3.ZERO
	var previous_b := Vector3.ZERO
	for step: int in points.size():
		var tangent: Vector3 = (points[mini(step + 1, last)] - points[maxi(step - 1, 0)]).normalized()
		var across: Vector3 = tangent.cross(Vector3.UP)
		across = across.normalized() if across.length_squared() > 0.0001 else Vector3.RIGHT
		var a: Vector3 = points[step] - across * width * 0.5
		var b: Vector3 = points[step] + across * width * 0.5
		if step > 0:
			var u0: float = float(step - 1) / float(last)
			var u1: float = float(step) / float(last)
			_vertex(builder, previous_a, Vector2(u0, 0.0), kind, index)
			_vertex(builder, a, Vector2(u1, 0.0), kind, index)
			_vertex(builder, b, Vector2(u1, 1.0), kind, index)
			_vertex(builder, previous_a, Vector2(u0, 0.0), kind, index)
			_vertex(builder, b, Vector2(u1, 1.0), kind, index)
			_vertex(builder, previous_b, Vector2(u0, 1.0), kind, index)
		previous_a = a
		previous_b = b


func _add_quad(builder: SurfaceTool) -> void:
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
		_vertex(builder, Vector3.ZERO, corner, KIND_ORB, 0.0)


func _vertex(builder: SurfaceTool, point: Vector3, uv: Vector2, kind: float, index: float) -> void:
	builder.set_uv(uv)
	builder.set_uv2(Vector2(index, kind))
	builder.add_vertex(point)
