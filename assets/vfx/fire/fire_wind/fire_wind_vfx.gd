class_name FireWindVfx
extends Node3D
## DONE 2026-10-30: các dải lửa chạy xuôi đúng đoạn fired, tái dùng mesh và hạt.
## NOTES kiểm tra: Lượt lặp mean 2.50 -> 2.53 ms, worst 6.12 -> 5.94 ms; đã chụp length 0.5/12, width 0.5/8.
## NOT DONE: chưa xác minh bản export/cache sạch; các ghi chú trước dưới đây là mốc triển khai.
## Ghi chú vòng đầu: đang chờ kiểm tra start thu ngắn và kích thước cực trị.
## NOTES: không tạo vùng sát thương, không có đèn.
@export_group("Wiring")
@export var fire_wind: FireWind
@export_group("Visual")
@export var duration: float = 0.34
@export var travel_time: float = 0.10
@export var fade_time: float = 0.12
@export var surface_height: float = 0.55
@export var flame_height: float = 0.35
@export var height_per_width: float = 0.2
@export var max_flame_height: float = 1.2
@export var ember_count: int = 20
@export var prepare_frames: int = 3
@export var downwind_lean: float = 0.65
var _age: float = 0.0
var _start: float = INF
var _end: float = 0.0
@onready var _trail: GPUParticles3D = $Trail
@onready var _surface: MeshInstance3D = $FireSurface
@onready var _material: ShaderMaterial = $FireSurface.material_override as ShaderMaterial

## Giữ cách nối fired để mọi scene hiện có tiếp tục dùng được.
func _ready() -> void:
	set_process(false)
	_surface.hide()
	_trail.hide()
	_build_swept_ribbons()
	_trail.emitting = false
	_trail.amount = maxi(1, ember_count)
	if fire_wind:
		fire_wind.fired.connect(_on_fired)
		if fire_wind.wind_area:
			fire_wind.wind_area.blast_started.connect(_on_new_gust)
	if DisplayServer.get_name() != "headless":
		await _prepare()

## Dùng mặt tiến và đuôi rút để gió mang lửa đi, không bật đồng loạt cả hình hộp.
func _process(delta: float) -> void:
	_age += delta
	_material.set_shader_parameter(&"wind_clock", _age)
	_material.set_shader_parameter(&"front", minf(1.0, _age / maxf(travel_time, 0.001)))
	_material.set_shader_parameter(&"tail", clampf((_age - duration + fade_time) / maxf(fade_time, 0.001), 0.0, 1.0))
	if _age >= duration:
		_material.set_shader_parameter(&"opacity", 0.0)
		_start = INF
		_surface.hide()
		set_process(false)

## Gộp các lần mở rộng trong cùng lượt, không phát chồng nhiều hệ hạt.
func _on_fired(start: float, length: float, width: float) -> void:
	_material.set_shader_parameter(&"prewarm_scale", 1.0)
	_surface.show()
	_trail.scale = Vector3.ONE
	_trail.show()
	if not is_processing() or is_inf(_start) or start >= _end:
		_start = start
		_end = start + length
	else:
		_start = minf(_start, start)
		_end = maxf(_end, start + length)
	var span: float = maxf(_end - _start, 0.01)
	_surface.position = Vector3(0.0, surface_height, _start + span * 0.5)
	_surface.scale = Vector3(maxf(width, 0.01), 1.0, span)
	_material.set_shader_parameter(&"wind_lean", downwind_lean / span)
	_material.set_shader_parameter(&"wind_clock", 0.0)
	_material.set_shader_parameter(&"height_scale", minf(max_flame_height, maxf(flame_height, width * height_per_width)))
	_material.set_shader_parameter(&"opacity", 1.0)
	_material.set_shader_parameter(&"front", 0.0)
	_material.set_shader_parameter(&"tail", 0.0)
	_trail.position = Vector3(0.0, surface_height, _start + span * 0.12)
	var process: ParticleProcessMaterial = _trail.process_material as ParticleProcessMaterial
	process.emission_box_extents = Vector3(width * 0.4, flame_height * 0.25, span * 0.08)
	process.initial_velocity_min = span * 0.65 / _trail.lifetime
	process.initial_velocity_max = span * 0.95 / _trail.lifetime
	_trail.visibility_aabb = AABB(Vector3(-width, -2.0, -span), Vector3(width * 2.0, 5.0, span * 2.0))
	_trail.emitting = true
	_trail.restart()
	_age = 0.0
	set_process(true)

## Chỉ chuẩn bị biến thể shader của hiệu ứng này, không quét scene.
func _prepare() -> void:
	if is_processing():
		return
	_material.set_shader_parameter(&"prewarm_scale", 0.000001)
	_material.set_shader_parameter(&"opacity", 1.0)
	_surface.show()
	_trail.scale = Vector3.ONE * 0.000001
	_trail.show()
	_trail.emitting = true
	_trail.restart()
	for frame: int in range(prepare_frames):
		await RenderingServer.frame_post_draw
	# fired có thể đến khi đang chờ frame; không thu nhỏ hoặc dọn mất đòn thật.
	if is_processing():
		return
	_material.set_shader_parameter(&"prewarm_scale", 1.0)
	_material.set_shader_parameter(&"opacity", 0.0)
	_surface.hide()
	_trail.emitting = false
	_trail.hide()
	_trail.scale = Vector3.ONE



## Mỗi gust mới có phạm vi độc lập, không gộp nhầm với tàn lửa của lượt trước.
func _on_new_gust(_data: WindBlastData) -> void:
	_start = INF
	_end = 0.0


## Ngọn cong xuôi gió có đầu nhọn lệch nhau; dựng một lần, không cấp phát lúc thổi.
func _build_swept_ribbons() -> void:
	var vertices: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	const LANES: int = 7
	const STEPS: int = 10
	for lane: int in range(LANES):
		var lane_seed: float = float(lane)
		var center: float = sin(lane_seed * 1.37 - 1.2) * 0.36
		var start: float = fmod(lane_seed * 0.137, 0.34)
		var end: float = 0.78 + fmod(lane_seed * 0.173, 0.22)
		for layer: int in range(2):
			var base: int = vertices.size()
			for step: int in range(STEPS + 1):
				var h: float = float(step) / STEPS
				var taper: float = pow(maxf(sin(h * PI), 0.0), 0.7)
				var lift: float = sin(h * PI) * (0.55 + fmod(lane_seed * 0.23, 0.45))
				for side: int in range(2):
					var across: float = float(side) * 2.0 - 1.0
					var x: float = center + sin(h * 4.0 + lane_seed) * 0.04 + across * taper * (0.12 + fmod(lane_seed * 0.037, 0.05))
					var y: float = lift if layer == 0 else lift + across * taper * 0.23
					vertices.append(Vector3(x, y, lerpf(start, end, h) - 0.5))
					uvs.append(Vector2(float(side), h))
					colors.append(Color(lane_seed / LANES, h, 0.0, 1.0))
			for step: int in range(STEPS):
				var a: int = base + step * 2
				indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	# Mặt đầu cong chạy bằng shader, dùng chung draw call với các ngọn kéo sau.
	var front_base: int = vertices.size()
	for step: int in range(STEPS + 1):
		var u: float = float(step) / STEPS
		for side: int in range(2):
			vertices.append(Vector3((u - 0.5) * 0.96, 0.20 * sin(u * PI), (float(side) - 0.5) * 0.14 - pow(u - 0.5, 2.0) * 0.28))
			uvs.append(Vector2(u, float(side)))
			colors.append(Color(0.0, 0.0, 1.0, 1.0))
	for step: int in range(STEPS):
		var a: int = front_base + step * 2
		indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_surface.mesh = mesh
