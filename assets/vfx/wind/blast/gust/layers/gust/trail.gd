extends WindGustSoftLayer
## Hàng chấm sáng trên sàn dọc đường lốc đi qua (tham khảo vệt chấm sau lốc Q3 Yasuo): đầu hàng bám theo lốc,
## đuôi ở chỗ người thổi; lốc dừng thì hàng chấm còn lại một lúc rồi tan.

## Khoảng cách giữa hai chấm (m) và cỡ chấm (m)
@export var dot_spacing: float = 0.35
@export var dot_size: Vector2 = Vector2(0.11, 0.21)
## Số chấm tối đa (đường dài hơn thì chấm thưa ra)
@export_range(4, 64) var max_dots: int = 32
@export var floor_lift: float = 0.04
@export_group("Motion")
## Khớp với lốc: phần thời gian lốc lướt tới
@export_range(0.1, 1.0) var travel_ratio: float = 0.86

var _built_length: float = -1.0
var _radius: float = 0.0


func _ready() -> void:
	erode_start = 0.6
	super._ready()
	position.y = floor_lift
	gust.visual_burst.connect(_on_burst)


func _on_burst(data: WindBlastData, span: float) -> void:
	var actor: CharacterBody3D = gust.get_parent() as CharacterBody3D
	if actor != null and not actor.is_on_floor():
		return
	_radius = minf(data.width * 0.5, data.reach * 0.5)
	var length: float = maxf(data.reach - _radius, MIN_SPAN)
	# Chiều dài phụ thuộc cả bề ngang vì chấm cuối bám theo tâm lốc.
	if not is_equal_approx(_built_length, length):
		_built_length = length
		mesh = _build(length)
	begin_layer(span + gust.linger_time, Vector3.ONE)


## Hàng chấm dựng sẵn theo mét thật từ z = 0 tới z = length; lúc chạy chỉ co theo trục z để đầu hàng bám lốc
func _update_shape(phase: float) -> void:
	super._update_shape(phase)
	var travel: float = clampf(phase / travel_ratio, 0.0, 1.0)
	var advance: float = lerpf(_radius / maxf(_built_length, MIN_SPAN), 1.0, travel)
	scale = Vector3(1.0, 1.0, maxf(advance, MIN_SPAN))
	position.z = 0.0


func _build(length: float) -> ArrayMesh:
	var count: int = clampi(int(length / maxf(dot_spacing, MIN_SPAN)), 1, max_dots)
	var parts: Array[ArrayMesh] = []
	for index: int in count:
		# Đặt phần rộng của mỗi chấm về phía đầu để đọc được hướng bay.
		var z: float = length * float(index + 1) / float(count)
		var points := PackedVector3Array([Vector3(0.0, 0.0, z - dot_size.y), Vector3(0.0, 0.0, z - dot_size.y * 0.32), Vector3(0.0, 0.0, z)])
		var widths := PackedFloat32Array([0.0, dot_size.x, 0.0])
		parts.append(build_ribbon(points, widths))
	return merge_ribbons(parts)
