class_name HealBurstVfx
extends Node3D
## Hiệu ứng hồi máu tại checkpoint: vòng sáng (Ring) nở ra dưới chân + đốm sáng (Motes) bay lên, chạy xong tự tắt.
## Hình nằm trong scene (màu, texture, số hạt, hướng bay chỉnh trong editor); script chỉ lo nở vòng, mờ dần và tắt.
## Chỉ chạy _process trong lúc đang phát. Không đèn, không đổ bóng.

## Bán kính cuối của vòng (m) và thời gian nở rồi mờ (s)
@export var ring_radius: float = 1.4
@export_range(0.05, 3.0, 0.01) var ring_time: float = 0.7
## Âm thanh hồi máu (để trống nếu chưa có file)
@export var sound: AudioStream

var _left: float = 0.0
var _total: float = 0.0
var _ring_material: StandardMaterial3D
## Màu vòng lấy từ material trong scene; alpha giảm dần từ giá trị này
var _ring_color: Color
var _sound: AudioStreamPlayer3D

@onready var _ring: MeshInstance3D = $Ring
@onready var _motes: CPUParticles3D = $Motes


func _ready() -> void:
	top_level = true
	visible = false
	set_process(false)
	# Material vòng đặt local_to_scene trong scene: mỗi checkpoint có bản riêng, đổi alpha không lây sang nhau
	_ring_material = _ring.material_override as StandardMaterial3D
	# Chụp màu gốc một lần: chạm lại khi vòng đang mờ dở không làm alpha gốc giảm dần qua các lần
	if _ring_material:
		_ring_color = _ring_material.albedo_color
	if sound:
		_sound = AudioStreamPlayer3D.new()
		_sound.stream = sound
		add_child(_sound)


## Chạy hiệu ứng ở chân người được hồi máu
func play(at: Vector3) -> void:
	global_position = at
	visible = true
	_total = maxf(ring_time, _motes.lifetime)
	_left = _total
	_motes.restart()
	_motes.emitting = true
	if _sound:
		_sound.play()
	_process(0.0)
	set_process(true)


## Đúng khi hiệu ứng đang chạy (test)
func is_playing() -> bool:
	return is_processing()


func _process(delta: float) -> void:
	_left -= delta
	var t := clampf((_total - _left) / maxf(ring_time, 0.001), 0.0, 1.0)
	var grow := maxf(1.0 - pow(1.0 - t, 3.0), 0.05)
	_ring.scale = Vector3(ring_radius * 2.0 * grow, 1.0, ring_radius * 2.0 * grow)
	if _ring_material:
		_ring_material.albedo_color = Color(_ring_color, _ring_color.a * (1.0 - t))
	_ring.visible = t < 1.0
	if _left <= 0.0:
		_motes.emitting = false
		visible = false
		# Trả alpha gốc để lần chạm sau vòng sáng như cũ
		if _ring_material:
			_ring_material.albedo_color = _ring_color
		set_process(false)
