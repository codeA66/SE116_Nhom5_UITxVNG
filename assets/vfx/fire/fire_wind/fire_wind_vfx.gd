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
var _age: float = 0.0
var _start: float = INF
var _end: float = 0.0
@onready var _trail: GPUParticles3D = $Trail
@onready var _surface: MeshInstance3D = $FireSurface
@onready var _material: ShaderMaterial = $FireSurface.material_override as ShaderMaterial

## Giữ cách nối fired để mọi scene hiện có tiếp tục dùng được.
func _ready() -> void:
	set_process(false)
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
	_material.set_shader_parameter(&"front", minf(1.0, _age / maxf(travel_time, 0.001)))
	_material.set_shader_parameter(&"tail", clampf((_age - duration + fade_time) / maxf(fade_time, 0.001), 0.0, 1.0))
	if _age >= duration:
		_material.set_shader_parameter(&"opacity", 0.0)
		_start = INF
		set_process(false)

## Gộp các lần mở rộng trong cùng lượt, không phát chồng nhiều hệ hạt.
func _on_fired(start: float, length: float, width: float) -> void:
	if not is_processing() or is_inf(_start) or start >= _end:
		_start = start
		_end = start + length
	else:
		_start = minf(_start, start)
		_end = maxf(_end, start + length)
	var span: float = maxf(_end - _start, 0.01)
	_surface.position = Vector3(0.0, surface_height, _start + span * 0.5)
	_surface.scale = Vector3(maxf(width, 0.01), 1.0, span)
	_material.set_shader_parameter(&"height_scale", minf(max_flame_height, maxf(flame_height, width * height_per_width)))
	_material.set_shader_parameter(&"opacity", 1.0)
	_material.set_shader_parameter(&"front", 0.0)
	_material.set_shader_parameter(&"tail", 0.0)
	_trail.position = _surface.position
	var process: ParticleProcessMaterial = _trail.process_material as ParticleProcessMaterial
	process.emission_box_extents = Vector3(width * 0.4, flame_height * 0.25, span * 0.4)
	process.initial_velocity_min = span * 0.1 / _trail.lifetime
	process.initial_velocity_max = span * 0.2 / _trail.lifetime
	_trail.visibility_aabb = AABB(Vector3(-width, -2.0, -span), Vector3(width * 2.0, 5.0, span * 2.0))
	_trail.restart()
	_age = 0.0
	set_process(true)

## Chỉ chuẩn bị biến thể shader của hiệu ứng này, không quét scene.
func _prepare() -> void:
	_material.set_shader_parameter(&"opacity", 0.001)
	_trail.transparency = 0.999
	_trail.restart()
	for frame: int in range(prepare_frames):
		await RenderingServer.frame_post_draw
	_trail.transparency = 0.0
	if not is_processing():
		_trail.emitting = false
		_material.set_shader_parameter(&"opacity", 0.0)


## Mỗi gust mới có phạm vi độc lập, không gộp nhầm với tàn lửa của lượt trước.
func _on_new_gust(_data: WindBlastData) -> void:
	_start = INF
	_end = 0.0
