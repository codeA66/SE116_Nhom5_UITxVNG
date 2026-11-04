class_name PickupVfx
extends Node3D
## Hiệu ứng ngắn khi tiền rơi ra / khi nhặt: vòng sáng (node Ring, tuỳ chọn) nở ra rồi mờ, mọi hạt con phát một lần.
## Hình nằm trong scene (màu, texture, số hạt chỉnh trong editor); script chỉ lo nở / mờ và báo xong để về pool.
## Không hiện chữ số (kiểu Death's Door: không có số bay lên khi quái chết).
## Chỉ chạy _process trong lúc phát. Không đèn, không đổ bóng.

## Chạy xong (pool nối để nhả node về)
signal finished

## Thời gian vòng nở rồi mờ (s)
@export_range(0.05, 3.0, 0.01) var ring_time: float = 0.35
## Vòng nở từ cỡ này tới cỡ kia (m, đường kính)
@export var ring_start_size: float = 0.2
@export var ring_end_size: float = 1.4
## Vòng nằm phẳng trên sàn (rơi) hay quay về camera (nhặt)
@export var ring_flat: bool = true

var _age: float = 0.0
var _total: float = 0.0
var _ring_material: StandardMaterial3D
var _ring_color: Color
var _particles: Array[CPUParticles3D] = []

@onready var _ring: MeshInstance3D = get_node_or_null(^"Ring") as MeshInstance3D


func _ready() -> void:
	top_level = true
	visible = false
	set_process(false)
	for child in get_children():
		if child is CPUParticles3D:
			_particles.append(child)
	if _ring:
		# Material vòng local_to_scene trong scene: mỗi bản trong pool có bản riêng, đổi alpha không lây sang nhau
		_ring_material = _ring.material_override as StandardMaterial3D
		if _ring_material:
			_ring_color = _ring_material.albedo_color


func play(at: Vector3) -> void:
	global_position = at
	visible = true
	_age = 0.0
	_total = ring_time
	for particles in _particles:
		particles.restart()
		particles.emitting = true
		_total = maxf(_total, particles.lifetime)
	_process(0.0)
	set_process(true)


## Pool nhả về: tắt hẳn
func pool_released() -> void:
	set_process(false)
	for particles in _particles:
		particles.emitting = false


func _process(delta: float) -> void:
	_age += delta
	if _ring:
		var t := clampf(_age / maxf(ring_time, 0.001), 0.0, 1.0)
		var size := lerpf(ring_start_size, ring_end_size, 1.0 - pow(1.0 - t, 3.0))
		_ring.scale = Vector3(size, 1.0, size) if ring_flat else Vector3(size, size, 1.0)
		_ring.visible = t < 1.0
		if _ring_material:
			_ring_material.albedo_color = Color(_ring_color, _ring_color.a * (1.0 - t))
	if _age >= _total:
		set_process(false)
		finished.emit()
