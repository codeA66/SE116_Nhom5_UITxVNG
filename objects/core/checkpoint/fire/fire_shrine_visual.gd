@tool
class_name FireShrineVisual
extends ShrineVisual
## Bệ checkpoint Lửa (checkpoint_shrine_fire.glb): tắt thì chỉ còn đá, sáng thì lửa, vòng rune hiện và đèn bừng lên.
## Chỉ đổi hình ảnh; không truy cập tiến trình hoặc ghi save. Hiệu năng: chỉ tween khi đổi trạng thái.

@export var lit_energy: float = 2.5
@export_range(0.0, 3.0, 0.05) var activation_time: float = 0.6
@export_group("Hiệu ứng kích hoạt")
## Độ sáng đèn lúc chớp khi vừa kích hoạt (rồi hạ về lit_energy)
@export var flash_energy: float = 6.0
@export_range(0.0, 1.0, 0.01) var flash_time: float = 0.12
## Vòng sáng toả ra từ giữa bệ: thời gian và hệ số phóng to cuối
@export_range(0.1, 3.0, 0.05) var ring_time: float = 0.7
@export var ring_end_scale: float = 1.7
@export_group("")
## Xem trước trạng thái sáng trong editor
@export var preview_active: bool = false:
	set(value):
		preview_active = value
		if is_node_ready() and Engine.is_editor_hint():
			set_active(value, null, 0.0, true)

var _last_target: bool = false
var _tween: Tween
var _fx_tween: Tween

@onready var _light: OmniLight3D = $Light
# glTF có thể thêm hậu tố vào tên node ngọn lửa
@onready var _flame: Node3D = $Model.find_child("Flame*", true, false) as Node3D
# Vòng rune + ký hiệu trên mặt bệ: chỉ hiện khi đã kích hoạt
@onready var _burst: GPUParticles3D = $ActivateBurst
@onready var _ring: MeshInstance3D = $PulseRing
@onready var _sfx: AudioStreamPlayer3D = $ActivateSfx
@onready var _glow: Node3D = $Model.find_child("Glow*", true, false) as Node3D


func _ready() -> void:
	set_active(preview_active if Engine.is_editor_hint() else false, null, 0.0, true)


func set_active(enabled: bool, _legacy_material: Material = null, _spin_degrees: float = 12.0, immediate: bool = false) -> void:
	if not is_node_ready():
		return
	if enabled == _last_target and not immediate:
		return
	_last_target = enabled
	if _tween:
		_tween.kill()
	if _flame:
		_flame.visible = enabled
	if _glow:
		_glow.visible = enabled
	var target: float = lit_energy if enabled else 0.0
	if immediate or activation_time <= 0.0:
		_light.light_energy = target
		_light.visible = enabled
		return
	_light.visible = true
	_tween = create_tween()
	if enabled:
		# Chớp sáng rồi hạ về mức thường
		_tween.tween_property(_light, ^"light_energy", flash_energy, flash_time)
		_play_activation_fx()
	_tween.tween_property(_light, ^"light_energy", target, activation_time)
	if not enabled:
		_tween.tween_callback(_light.hide)


## Hạt, vòng sáng và âm thanh khi kích hoạt. Chỉ chạy một lần theo sự kiện, không xử lý mỗi frame.
func _play_activation_fx() -> void:
	if Engine.is_editor_hint():
		return
	_burst.restart()
	_sfx.play()  # chưa gắn stream thì không phát gì; chừa sẵn chỗ cắm âm thanh
	if _fx_tween:
		_fx_tween.kill()
	_ring.visible = true
	_ring.scale = Vector3(0.5, 1.0, 0.5)
	var ring_mat: StandardMaterial3D = _ring.material_override as StandardMaterial3D
	ring_mat.albedo_color.a = 0.8
	_fx_tween = create_tween().set_parallel(true)
	_fx_tween.tween_property(_ring, ^"scale", Vector3(ring_end_scale, 1.0, ring_end_scale), ring_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_fx_tween.tween_property(ring_mat, ^"albedo_color:a", 0.0, ring_time)
	_fx_tween.tween_callback(_ring.hide).set_delay(ring_time)
