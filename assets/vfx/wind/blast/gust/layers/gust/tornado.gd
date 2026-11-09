extends WindGustSoftLayer
## Cơn lốc của cú Thổi Gió (tham khảo Q3 Yasuo): cột đứng gồm các vòng xoáy, mọc lên trước mặt lúc vùng đẩy bật,
## lướt thẳng tới hết tầm với cỡ không đổi, cuối tầm phình ra và tan. Cùng một script cho ba lớp chồng nhau
## (vòng ngoài trắng, lõi xanh sáng, quầng dưới chân) bằng cách đổi thông số trong scene, không cần code mới.
## Đường kính lốc = bề ngang vùng đẩy, chiều cao = chiều cao vùng đẩy.

@export_group("Rings")
@export_range(1, 12) var ring_count: int = 5
## Bán kính vòng dưới cùng / trên cùng (tỉ lệ bề ngang vùng đẩy; 0.5 = mép vùng)
@export_range(0.02, 0.8) var bottom_radius: float = 0.34
@export_range(0.02, 0.8) var top_radius: float = 0.5
## Độ cao vòng dưới cùng / trên cùng (tỉ lệ chiều cao vùng đẩy)
@export_range(0.0, 1.5) var bottom_height: float = 0.08
@export_range(0.0, 1.5) var top_height: float = 1.0
## Mỗi vòng hở bao nhiêu phần (1 = khép kín): vòng hở thì xoay mới thấy được
@export_range(0.1, 1.0) var arc_fraction: float = 0.72
## Bề cao dải (tỉ lệ chiều cao vùng đẩy) và độ loe mép trên
@export_range(0.01, 0.6) var band_height: float = 0.14
@export_range(0.0, 0.3) var band_flare: float = 0.04
## Chênh độ cao của nét xoắn và độ gợn quanh thân, tính theo chiều cao cột.
@export_range(0.0, 0.45) var strand_rise: float = 0.28
@export_range(0.0, 0.16) var strand_warp: float = 0.075
## Vòng nằm phẳng trên sàn (quầng dưới chân) thay vì đứng quanh thân
@export var ground_ring: bool = false
@export_range(12, 64) var segments: int = 32
@export var random_seed: int = 3
## Chiều cao cột = bề ngang × hệ số này (cột lốc phải cao hơn bề ngang mới đọc ra cột khi nhìn chéo từ trên);
## 0 = lấy chiều cao vùng đẩy
@export_range(0.0, 3.0) var height_per_width: float = 1.18
@export_group("Motion")
## Tất cả lớp dùng cùng tâm thay vì suy tâm từ bán kính riêng của từng lớp.
@export_range(0.05, 0.5) var travel_radius: float = 0.5
## Vòng / giây quanh trục đứng
@export var spin_speed: float = 3.5
## Lúc mọc lên: cao từ tỉ lệ này lên đủ
@export_range(0.0, 1.0) var rise_from: float = 0.35
@export_range(0.0, 0.5) var rise_time: float = 0.12
## Cuối lượt phình ra bấy nhiêu lần khi tan
@export var dissolve_growth: float = 1.15

var _reach: float = 1.0
var _travel_time: float = MIN_SPAN


func _ready() -> void:
	super._ready()
	if volume_mode:
		mesh = _build_volume()
		gust.visual_burst.connect(_on_burst)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var parts: Array[ArrayMesh] = []
	for index: int in ring_count:
		var t: float = 0.0 if ring_count == 1 else float(index) / float(ring_count - 1)
		var radius: float = lerpf(bottom_radius, top_radius, t)
		var y: float = lerpf(bottom_height, top_height, t)
		var start: float = rng.randf() * TAU
		var sweep: float = arc_fraction * rng.randf_range(0.72, 1.0)
		var slope: float = strand_rise * rng.randf_range(0.56, 1.0)
		var strand_width: float = band_height * rng.randf_range(0.64, 1.16)
		if index % 3 == 1:
			slope *= -0.6
		var points := PackedVector3Array()
		var widths := PackedFloat32Array()
		for step: int in segments + 1:
			var u: float = float(step) / float(segments)
			var a: float = start + TAU * sweep * u
			var curl: float = sin(a * 2.0 + start)
			var level: float = maxf(y + (u - 0.5) * slope + strand_warp * curl, 0.04)
			var radial: float = radius * (1.0 + curl * 0.10)
			points.append(Vector3(cos(a) * radial, level, sin(a) * radial + level * band_flare))
			widths.append(strand_width * lerpf(0.24, 1.0, sin(PI * u)))
		parts.append(build_ribbon(points, widths, band_flare, not ground_ring))
	mesh = merge_ribbons(parts)
	gust.visual_burst.connect(_on_burst)


func _on_burst(data: WindBlastData, span: float) -> void:
	# Hộp tròn đều theo bề ngang: lốc không bị kéo thành elip khi tầm dài
	_reach = data.reach
	_travel_time = maxf(minf(data.active_time, span), MIN_SPAN)
	var column_height: float = data.width * height_per_width if height_per_width > 0.0 else data.height
	begin_layer(span + gust.linger_time, Vector3(data.width, column_height, minf(data.width, data.reach)))


func _update_shape(phase: float) -> void:
	super._update_shape(phase)
	var travel: float = clampf(_age / _travel_time, 0.0, 1.0)
	var advance: float = 1.0 - pow(1.0 - travel, 3.0)
	var radius_m: float = travel_radius * cast_extent.z
	# Tâm lốc đi từ ngay trước mặt (mép sau chạm người thổi) tới cuối tầm (mép trước chạm cuối vùng đẩy)
	var center: float = lerpf(radius_m, _reach - radius_m, advance)
	var age_s: float = phase * _span
	var rise: float = lerpf(rise_from, 1.0, clampf(age_s / maxf(rise_time, MIN_SPAN), 0.0, 1.0))
	# Lốc đi nhanh cùng cửa sổ đẩy, đuôi vẫn tan theo thời lượng hiệu ứng.
	var grow: float = lerpf(1.0, dissolve_growth, smoothstep(erode_start, 1.0, phase))
	var extent: Vector3 = cast_extent * Vector3(grow, rise, grow)
	var spin: Basis = Basis(Vector3.UP, -phase * _span * spin_speed * TAU)
	transform = Transform3D(spin.scaled(extent), Vector3(0.0, 0.0, center))


## Lưới mỏng dùng UV dọc thân để chân sáng và phần trên thấy xuyên được.
func _build_volume() -> ArrayMesh:
	var profile: PackedFloat32Array = PackedFloat32Array([0.0, 0.18, 0.42, 0.70, 1.0])
	var vertices: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for row: int in profile.size():
		var v: float = profile[row]
		var radius: float = lerpf(bottom_radius, top_radius, sqrt(v))
		for step: int in range(segments + 1):
			var u: float = float(step) / float(segments)
			var angle: float = TAU * u
			var radial: float = radius * (1.0 + 0.12 * sin(angle * 2.0 + v * TAU))
			vertices.append(Vector3(cos(angle) * radial, lerpf(bottom_height, top_height, v), sin(angle) * radial + v * band_flare))
			uv.append(Vector2(u, v))
			if row > 0 and step > 0:
				var current: int = vertices.size() - 1
				var upper: int = current - segments - 1
				indices.append_array(PackedInt32Array([upper - 1, upper, current, upper - 1, current, current - 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var result: ArrayMesh = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
