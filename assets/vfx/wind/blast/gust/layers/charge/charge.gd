extends WindGustSoftLayer
## Lúc gồng: vài cung gió trong suốt bọc quanh người thành một quả cầu xoay (tham khảo lúc gồng Q3 Yasuo),
## co nhẹ vào trước khi lốc phóng ra.

## Tâm quả cầu so với chân người thổi (m)
@export var center_offset: Vector3 = Vector3(0.0, 0.62, 0.1)
## Bán kính quả cầu (m); bị giới hạn bởi vùng đẩy để cú thổi rất nhỏ không có vòng gồng to hơn chính nó
@export var bubble_radius: float = 0.75
@export_range(2, 8) var arc_count: int = 4
## Mỗi cung dài bao nhiêu phần vòng tròn
@export_range(0.1, 1.0) var arc_fraction: float = 0.55
## Bề ngang nét (m)
@export var line_width: float = 0.08
@export_range(8, 48) var segments: int = 20
## Co từ 1 về tỉ lệ này khi gồng xong
@export_range(0.3, 1.0) var end_scale: float = 0.8
## Vòng xoay trong lúc gồng
@export var swirl_turns: float = 0.5


## Các cung nằm trên những vòng tròn nghiêng khác nhau quanh tâm: nhìn chéo vẫn thành khối cầu
func _ready() -> void:
	erode_start = 0.85
	super._ready()
	position = center_offset
	var parts: Array[ArrayMesh] = []
	for index: int in arc_count:
		var tilt := Basis(Vector3.RIGHT, deg_to_rad(lerpf(-55.0, 55.0, float(index) / maxf(float(arc_count - 1), 1.0))))
		var spin := Basis(Vector3.UP, TAU * float(index) / float(arc_count))
		var orient: Basis = spin * tilt
		var points := PackedVector3Array()
		var widths := PackedFloat32Array()
		for step: int in segments + 1:
			var a: float = TAU * arc_fraction * float(step) / float(segments)
			points.append(orient * Vector3(cos(a), 0.0, sin(a)))
			widths.append(line_width / bubble_radius)
		parts.append(build_ribbon(points, widths))
	mesh = merge_ribbons(parts)
	gust.visual_charge.connect(_on_charge)


## Bọc người theo đúng thời gian gồng của kỹ năng
func _on_charge(data: WindBlastData) -> void:
	var r: float = minf(bubble_radius, minf(data.width, data.reach) * 0.5)
	begin_layer(data.active_start, Vector3.ONE * r)


func _update_shape(phase: float) -> void:
	super._update_shape(phase)
	scale = cast_extent * lerpf(1.15, end_scale, phase)
	rotation.y = -phase * TAU * swirl_turns
