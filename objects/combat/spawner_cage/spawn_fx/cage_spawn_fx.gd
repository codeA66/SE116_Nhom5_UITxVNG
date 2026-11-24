class_name CageSpawnFx
extends Node3D
## Hiệu ứng lồng sinh quái: lồng chớp sáng → tia lửa bay vòng cung từ lồng tới chỗ quái → chạm đất thì bùng tia lửa,
## vòng sóng lan trên sàn và đèn chớp. Phát landed lúc chạm đất, finished khi tắt hẳn (pool nhận lại).
## Dùng qua ObjectPool của SpawnerCage: play(từ, tới). Hiệu năng: không có _process; chuỗi pha là Tween,
## hạt một lần, không bóng đổ.

signal landed
signal finished

@export var data: CageSpawnFxData

var _from: Vector3
var _to: Vector3
var _tween: Tween

@onready var _bolt: MeshInstance3D = $Bolt
@onready var _trail: GPUParticles3D = $Bolt/Trail
@onready var _burst: GPUParticles3D = $Burst
@onready var _ring: MeshInstance3D = $Ring
@onready var _flash: OmniLight3D = $Flash
@onready var _cage_flash: OmniLight3D = $CageFlash


func _ready() -> void:
	_reset()


## Pool lấy ra / nhả về: tắt hết, không còn tween chạy dở
func pool_acquired() -> void:
	_reset()


func pool_released() -> void:
	_reset()
	visible = false


## from: chân lồng, to: chỗ quái sẽ hiện (toàn cục)
func play(from: Vector3, to: Vector3) -> void:
	_reset()
	visible = true
	global_position = to
	_from = from + Vector3.UP * data.launch_height
	_to = to + Vector3.UP * 0.3
	_cage_flash.global_position = _from
	_cage_flash.light_energy = data.cage_flash_energy
	_bolt.visible = true
	_bolt.global_position = _from
	_trail.emitting = true
	_tween = create_tween()
	_tween.tween_method(_move_bolt, 0.0, 1.0, data.travel_time)
	_tween.parallel().tween_property(_cage_flash, ^"light_energy", 0.0, data.travel_time)
	_tween.tween_callback(_land)


func _move_bolt(t: float) -> void:
	# Vòng cung parabol: cao nhất giữa đường
	_bolt.global_position = _from.lerp(_to, t) + Vector3.UP * data.arc_height * 4.0 * t * (1.0 - t)


func _land() -> void:
	_bolt.visible = false
	_trail.emitting = false
	_burst.restart()
	_ring.visible = true
	_ring.scale = Vector3.ONE * 0.2
	var ring_mat: ShaderMaterial = _ring.get_active_material(0) as ShaderMaterial
	if ring_mat:
		ring_mat.set_shader_parameter(&"intensity", 1.3)
	_flash.light_energy = data.flash_energy
	if data.land_trauma > 0.0:
		ScreenShake.add_trauma(data.land_trauma)
	landed.emit()
	_tween = create_tween().set_parallel()
	_tween.tween_property(_ring, ^"scale", Vector3.ONE * data.ring_scale, data.ring_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if ring_mat:
		_tween.tween_property(ring_mat, ^"shader_parameter/intensity", 0.0, data.ring_time)
	_tween.tween_property(_flash, ^"light_energy", 0.0, data.ring_time)
	# Chờ hạt bùng bay hết rồi mới báo xong (pool nhận lại)
	_tween.chain().tween_interval(maxf(_burst.lifetime - data.ring_time, 0.0))
	_tween.tween_callback(_done)


func _done() -> void:
	_ring.visible = false
	finished.emit()


func _reset() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	if not is_node_ready():
		return
	_bolt.visible = false
	_trail.emitting = false
	_ring.visible = false
	_flash.light_energy = 0.0
	_cage_flash.light_energy = 0.0
