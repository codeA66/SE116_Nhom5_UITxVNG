class_name IgnitableBrazier
extends Node3D
## Lò / đuốc tắt: Phun lửa (hoặc nguồn lửa bất kỳ) trúng thì thắp sáng mãi, rọi một vùng quanh nó.
## Dùng làm nguồn kích hoạt cho cổng (có signal activated + is_active() như ổ đá của StoneGate).
## Có persistent_id thì nhớ đã thắp qua lần chơi sau.
## Lúc tắt còn đốm than hồng + tàn lửa để thấy được trong bóng tối; lại gần thì có gợi ý cách thắp.
## Hiệu năng: chỉ nghe signal ignited của BurnableComponent; thắp xong thì tắt luôn vùng bắt lửa, than hồng và gợi ý.

signal activated

## Cờ lưu trạng thái đã thắp. Để trống = mỗi lần vào khu lại tắt
@export var persistent_id: StringName
@export var lit_energy: float = 3.5
@export var light_range: float = 11.0
@export var light_color: Color = Color(1.0, 0.55, 0.22)
@export_group("Gợi ý lúc tắt")
@export var hint_with_torch: String = "Chạm đuốc để thắp"
@export var hint_without_torch: String = "Cần một ngọn lửa"
@export_range(0.5, 5.0, 0.1) var message_time: float = 1.6

var is_lit: bool = false

@onready var _burnable: BurnableComponent = $BurnableComponent
@onready var _light: OmniLight3D = $Light
@onready var _flame: Node3D = $Model.find_child("Flame", true, false) as Node3D
@onready var _feedback: FlameFeedback = $FlameFeedback
@onready var _ember_light: OmniLight3D = $EmberLight
@onready var _embers: GPUParticles3D = $Embers
@onready var _hint: WorldHint = $Hint


func _ready() -> void:
	_light.light_color = light_color
	_light.omni_range = light_range
	_feedback.setup(_flame, _light, lit_energy)
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		_light_up(true)
		return
	_light.light_energy = 0.0
	_light.visible = false
	if _flame:
		_flame.visible = false
	_hint.text_provider = _hint_for
	_burnable.ignited.connect(_on_ignited)


func is_active() -> bool:
	return is_lit


## Hiện một câu ngắn nổi trên đuốc (vd. tiến độ "2/4" do BrazierGroup gọi)
func show_message(message: String) -> void:
	_hint.flash(message, message_time)


func _hint_for(actor: Node3D) -> String:
	if is_lit:
		return ""
	var torch: HandTorch = HandTorch.find_on(actor)
	return hint_with_torch if torch != null and torch.is_lit else hint_without_torch


func _on_ignited() -> void:
	if is_lit:
		return
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	_light_up(false)


func _light_up(instant: bool) -> void:
	is_lit = true
	_burnable.set_enabled(false)
	_ember_light.visible = false
	_embers.emitting = false
	_embers.visible = false
	_hint.monitoring = false
	_hint.refresh()
	if _flame:
		_flame.visible = true
	_light.visible = true
	if instant:
		_feedback.start_quiet()
	else:
		_feedback.ignite()
	activated.emit()
