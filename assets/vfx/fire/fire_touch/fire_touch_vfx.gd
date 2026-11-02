class_name FireTouchVfx
extends Node3D
## VFX TẠM cho vùng lửa ngắn (nhát cuối Kiếm Lửa, chỗ tên Cung Lửa trúng): vòng lửa trên sàn bùng ra đúng kích thước vùng
## rồi mờ dần, cùng một chùm lửa + tàn lửa bắn lên. Chỉ nghe signal fired của FireTouch; chỉ chạy _process trong lúc
## vòng đang mờ, xong tự tắt.
##
## TRẠNG THÁI (2026-10-31): bản tạm để nhìn thấy rõ vùng bị đốt. CHƯA ĐẠT về thẩm mỹ: sẽ giao AI VFX làm bản đẹp
## (giữ nguyên cách nối signal, không đụng FireTouch). Kiếm bốc lửa / tên bốc lửa lúc bay cũng chưa làm.

@export var touch: FireTouch
@export_group("Ground ring")
## Thời gian vòng lửa trên sàn bùng ra rồi mờ hết (s)
@export var ring_time: float = 0.4
## Vòng bắt đầu ở tỉ lệ này của bán kính rồi nở ra đủ
@export var ring_start_scale: float = 0.5
## Nâng vòng khỏi sàn một chút để không nhấp nháy với sàn
@export var ring_floor_offset: float = 0.05
## Dò sàn xuống tối đa bấy nhiêu mét dưới tâm vùng; lớp va chạm coi là sàn
@export var ground_probe_depth: float = 4.0
@export_flags_3d_physics var ground_mask: int = 1
@export_group("Burst")
## Tốc độ hạt theo tỉ lệ kích thước vùng (vùng to thì lửa bắn xa hơn)
@export var burst_speed_per_meter: float = 2.5

var _ring_left: float = 0.0
var _ring_size: Vector2 = Vector2.ONE

@onready var _burst: GPUParticles3D = $Burst
@onready var _ring: MeshInstance3D = $Ring
@onready var _ring_mat: StandardMaterial3D = $Ring.material_override as StandardMaterial3D


## Nối signal; mặc định tắt
func _ready() -> void:
	set_process(false)
	_burst.emitting = false
	_ring.hide()
	if touch:
		touch.fired.connect(_on_fired)


## Chỉ chạy lúc vòng đang mờ: nở ra rồi nhạt dần, hết thì ẩn và tắt xử lý
func _process(delta: float) -> void:
	_ring_left -= delta
	var t := 1.0 - clampf(_ring_left / maxf(ring_time, 0.001), 0.0, 1.0)
	var grow := lerpf(ring_start_scale, 1.0, 1.0 - pow(1.0 - t, 3.0))
	_ring.scale = Vector3(_ring_size.x * grow, 1.0, _ring_size.y * grow)
	_ring_mat.albedo_color.a = 1.0 - t
	if _ring_left <= 0.0:
		_ring.hide()
		set_process(false)


## Vùng lửa bật: chùm lửa phủ đúng vùng + vòng trên sàn đúng kích thước vùng
func _on_fired(size: Vector3, sphere: bool) -> void:
	var mat := _burst.process_material as ParticleProcessMaterial
	var extent := size.x if sphere else maxf(size.x, size.z) * 0.5
	if sphere:
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = size.x * 0.6
		_ring_size = Vector2(size.x, size.x) * 2.0
	else:
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = size * 0.4
		_ring_size = Vector2(size.x, size.z)
	mat.initial_velocity_min = extent * burst_speed_per_meter * 0.5
	mat.initial_velocity_max = extent * burst_speed_per_meter
	_burst.restart()
	# Vòng nằm sát sàn ngay dưới tâm vùng (tên trúng ngang người, nhát chém đặt cao ngang hông)
	_ring.global_position = _ground_below(global_position) + Vector3.UP * ring_floor_offset
	_ring.global_rotation = Vector3(0.0, global_rotation.y, 0.0)
	_ring.show()
	_ring_left = ring_time
	set_process(true)


## Điểm sàn ngay dưới `from` (dò tia một lần mỗi lần bùng, chỉ lớp world); không thấy sàn thì giữ nguyên chỗ
func _ground_below(from: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.2, from + Vector3.DOWN * ground_probe_depth, ground_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else from
