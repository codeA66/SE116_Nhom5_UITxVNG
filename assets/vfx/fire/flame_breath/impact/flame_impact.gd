class_name FlameImpact
extends Node3D
## Hiệu ứng trúng lửa tại một mục tiêu: tia lửa + chớp sáng chỗ chạm + phủ cam lên mesh của mục tiêu.
## FlameBreathVfx giữ sẵn vài node này trong ImpactPool và gọi play() mỗi lần hitbox lửa trúng (không instantiate mỗi lần).
##
## TRẠNG THÁI (2026-10-30, đã chạy thử trong tests/fire/sandbox/fire_sandbox.tscn):
## - ĐẠT: tia lửa + chớp ở đúng vị trí mục tiêu; phủ cam rồi tự trả lại; không cấp phát mỗi frame.
## - ĐẠT: danh sách mesh của mỗi mục tiêu chỉ tìm 1 lần rồi lưu lại (trước đây find_children mỗi lần trúng).
## - CHƯA ĐẠT / LƯU Ý: lớp phủ cam dùng chung material_overlay với chớp trúng đòn có sẵn của quái
##   (enemy.gd _flash_hit) và hình nộm (training_dummy.gd _flash). Hai bên ghi đè nhau: cái nào gán sau thì hiện.
##   Đã kiểm tra không kẹt màu (_restore chỉ trả lại khi overlay vẫn là của lửa), nhưng nếu muốn cả hai
##   cùng hiện thì cần một component chớp trúng đòn chung cho mọi entity — chưa làm.

@export_group("Flash")
## Material phủ cam lên mesh mục tiêu (shader flame_hit_flash, blend add)
@export var flash_material: ShaderMaterial
## Tổng thời gian một lượt trúng (tia lửa còn bay); hết thì node rảnh để pool dùng lại
@export var duration: float = 0.32
## Thời gian giữ lớp phủ cam + chớp chỗ chạm, ngắn hơn duration
@export var flash_duration: float = 0.1
## Độ cao chớp so với gốc hurtbox (m), để chớp nằm giữa thân chứ không dưới chân
@export var hit_height: float = 0.85
@export_group("Preparation")
## Vẽ thử ở chỗ khuất ngoài tầm nhìn lúc tải để biên dịch shader trước, tránh giật ở cú trúng đầu tiên
@export var preparation_height: float = 2.5
@export var preparation_scale: float = 0.05

## Thời gian còn lại của lượt hiện tại; FlameBreathVfx đọc để chọn node rảnh trong pool
var remaining: float = 0.0

var _play_generation: int = 0

var _meshes: Array[GeometryInstance3D] = []
var _previous: Array[Material] = []
# instance_id của mục tiêu -> mesh của nó; mục tiêu bị đốt liên tục nên tìm một lần là đủ
var _mesh_cache: Dictionary[int, Array] = {}

@onready var _contact: MeshInstance3D = $ContactFlash
@onready var _sparks: GPUParticles3D = $Sparks


func _ready() -> void:
	set_process(false)
	_contact.hide()
	_sparks.hide()
	_sparks.emitting = false


func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= duration - flash_duration:
		_restore()
		_contact.hide()
	if remaining <= 0.0:
		set_process(false)


func _exit_tree() -> void:
	_restore()


## ĐẠT: phát hiệu ứng tại mục tiêu. Nếu node đang bận (pool hết chỗ) thì lượt cũ bị cắt và trả màu trước.
func play(target: HurtboxComponent) -> void:
	_play_generation += 1
	_sparks.scale = Vector3.ONE
	_sparks.show()
	_restore()
	global_position = target.global_position + Vector3.UP * hit_height
	for mesh: GeometryInstance3D in _get_meshes(target.get_parent()):
		if not is_instance_valid(mesh):
			continue
		_meshes.append(mesh)
		_previous.append(mesh.material_overlay)
		mesh.material_overlay = flash_material
	_contact.position = Vector3.ZERO
	_contact.scale = Vector3.ONE
	_contact.show()
	remaining = duration
	_sparks.restart()
	set_process(true)


## ĐẠT: gọi một lần lúc tải (từ FlameBreathVfx._prepare_render) để biên dịch shader trước.
## Không chạy ở headless vì không có gì để vẽ.
func prepare_render() -> void:
	if remaining > 0.0:
		return
	var generation: int = _play_generation
	_contact.position = Vector3.UP * preparation_height
	_contact.scale = Vector3.ONE * 0.000001
	_contact.show()
	_sparks.scale = Vector3.ONE * 0.000001
	_sparks.show()
	_sparks.restart()
	await RenderingServer.frame_post_draw
	if generation != _play_generation:
		return
	_contact.hide()
	await get_tree().create_timer(duration).timeout
	if generation != _play_generation:
		return
	_sparks.emitting = false
	_sparks.hide()
	_sparks.scale = Vector3.ONE



## ĐẠT: tìm mesh một lần cho mỗi mục tiêu rồi lưu; mục tiêu đã bị xoá thì tìm lại.
## LƯU Ý: nếu mục tiêu đổi model lúc chạy (thêm/bớt mesh) thì danh sách cũ không tự cập nhật.
func _get_meshes(owner_node: Node) -> Array:
	var id := owner_node.get_instance_id()
	var cached: Array = _mesh_cache.get(id, [])
	if not cached.is_empty() and is_instance_valid(cached[0]):
		return cached
	# Chỉ MeshInstance3D: không phủ cam lên particle / sprite của quái
	cached = owner_node.find_children("*", "MeshInstance3D", true, false)
	_mesh_cache[id] = cached
	return cached


## ĐẠT: trả lại overlay cũ, nhưng không đè lên chớp trúng đòn / báo đòn mà quái vừa tự gán sau lửa
func _restore() -> void:
	for i: int in range(_meshes.size()):
		if is_instance_valid(_meshes[i]) and _meshes[i].material_overlay == flash_material:
			_meshes[i].material_overlay = _previous[i]
	_meshes.clear()
	_previous.clear()
