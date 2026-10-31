class_name FireVortexVfx
extends Node3D
## DONE 2026-10-30: phễu xoắn bằng mesh, không dùng orbit_velocity, dừng theo vortex.
## NOTES kiểm tra: Thêm lửa khi gió đã chạy: mean 2.07 -> 2.24 ms, worst 4.73 -> 5.16 ms; đã chụp radius 0.5/8.
## NOT DONE: chưa xác minh bản export/cache sạch; các ghi chú trước dưới đây là mốc triển khai.
## Ghi chú vòng đầu: đang chờ kiểm tra hình ảnh và bán kính cực trị.
## NOTES: không sửa lớp gió, chỉ thêm các dải lửa có khoảng trống nhìn xuyên tâm.
@export_group("Wiring")
@export var fire_vortex: FireVortex
@export_group("Visual")
@export var height_ratio: float = 0.7
@export var fade_time: float = 0.18
@export var ignition_time: float = 0.07
@export var ember_count: int = 28
@export var prepare_frames: int = 3
var _radius: float = 0.01
var _lit: bool = false
var _age: float = 0.0
var _fade: float = 0.0
@onready var _ring: GPUParticles3D = $Ring
@onready var _surface: MeshInstance3D = $FireSurface
@onready var _material: ShaderMaterial = $FireSurface.material_override as ShaderMaterial

## Nghe cả started để bắt đúng bán kính mỗi lần node được pool dùng lại.
func _ready() -> void:
	set_process(false)
	_material.set_shader_parameter(&"opacity", 0.0)
	_ring.emitting = false
	_ring.amount = maxi(1, ember_count)
	if fire_vortex:
		fire_vortex.caught_fire.connect(_on_caught_fire)
		if fire_vortex.vortex:
			fire_vortex.vortex.started.connect(_on_started)
			fire_vortex.vortex.stopped.connect(_on_stopped)
	if DisplayServer.get_name() != "headless":
		await _prepare()

## Chỉ đếm đoạn bùng và đoạn tàn; GPU quay mesh, không cấp phát theo khung.
func _process(delta: float) -> void:
	_age += delta
	if _lit:
		_material.set_shader_parameter(&"opacity", minf(_age / maxf(ignition_time, 0.001), 1.0))
	else:
		_fade = maxf(0.0, _fade - delta)
		_material.set_shader_parameter(&"opacity", _fade / maxf(fade_time, 0.001))
		if _fade <= 0.0:
			set_process(false)

## Cập nhật kích thước khi vortex bắt đầu, trước cả thời điểm bắt lửa.
func _on_started(radius: float, _lifetime: float) -> void:
	_lit = false
	_fade = 0.0
	_radius = maxf(radius, 0.01)
	_ring.emitting = false
	_material.set_shader_parameter(&"opacity", 0.0)
	set_process(false)
	_fit_radius()

## Co đồng bộ phễu và emitter, không dùng bán kính giả khi dữ liệu thay đổi.
func _fit_radius() -> void:
	var height: float = _radius * height_ratio
	_surface.scale = Vector3(_radius * 2.0, height, _radius * 2.0)
	_surface.position.y = height * 0.5
	var process: ParticleProcessMaterial = _ring.process_material as ParticleProcessMaterial
	process.emission_ring_radius = _radius * 0.88
	process.emission_ring_inner_radius = _radius * 0.58
	process.initial_velocity_min = height
	process.initial_velocity_max = height * 1.5
	_ring.visibility_aabb = AABB(Vector3(-_radius, -1.0, -_radius), Vector3(_radius * 2.0, height * 3.0 + 1.0, _radius * 2.0))

## Caught_fire có thể đến từ detector trước listener started, nên đọc lại radius công khai.
func _on_caught_fire() -> void:
	if fire_vortex and fire_vortex.vortex:
		_radius = maxf(fire_vortex.vortex.radius, 0.01)
	_fit_radius()
	_lit = true
	_age = 0.0
	_ring.emitting = true
	set_process(true)

## Chỉ giữ tàn lửa ngắn, không kéo dài thời gian tác dụng của vortex.
func _on_stopped() -> void:
	# Hố gió thuần không có lửa để tàn; không bật lại material lúc stopped.
	if not _lit:
		_ring.emitting = false
		if _fade <= 0.0:
			_material.set_shader_parameter(&"opacity", 0.0)
			set_process(false)
		return
	_lit = false
	_ring.emitting = false
	_fade = fade_time
	set_process(true)

## Vẽ thử trước khi caught_fire, tránh biến thể shader chỉ xuất hiện giữa combat.
func _prepare() -> void:
	_material.set_shader_parameter(&"opacity", 0.001)
	_ring.transparency = 0.999
	_ring.emitting = true
	for frame: int in range(prepare_frames):
		await RenderingServer.frame_post_draw
	_ring.emitting = _lit
	_ring.transparency = 0.0
	if not _lit:
		_material.set_shader_parameter(&"opacity", 0.0)
