class_name HandTorch
extends Node3D
## Đuốc cầm tay: gậy lấy ở bó gậy, châm ở lửa trại thì cháy burn_time giây (đèn bám theo player).
## Đang cháy thì chạm vào vật đốt được (đuốc tường, rào gỗ...) sẽ châm lửa cho vật đó. Hết giờ thì tắt, về lửa trại châm lại.
## Gắn vào node Model của player (xoay theo hướng nhìn); không khóa đánh / kỹ năng.
## Hiệu năng: đồng hồ cháy là Timer; vùng châm lửa chỉ bật monitoring khi đang cháy, nghe area_entered.

signal lit
signal burned_out

const NODE_NAME: StringName = &"HandTorch"

@export_range(1.0, 600.0, 1.0) var burn_time: float = 90.0
@export var light_energy: float = 2.6
@export var light_range: float = 8.0
@export var light_color: Color = Color(1.0, 0.6, 0.28)
## Những giây cuối lửa lập loè mạnh để báo sắp tắt
@export_range(0.0, 60.0, 0.5) var fade_warning: float = 10.0
@export_group("Gợi ý khi tắt")
@export var burned_out_hint: String = "Về lửa trại châm lại"
@export_range(0.5, 10.0, 0.1) var burned_out_hint_time: float = 3.0

var is_lit: bool = false

var _tween: Tween

@onready var _feedback: FlameFeedback = $FlameFeedback
@onready var _hint: WorldHint = $BurnOutHint
@onready var _light: OmniLight3D = $Light
# Ngọn lửa là node con tên bắt đầu bằng "Flame" trong model (glTF có thể thêm hậu tố)
@onready var _flame: Node3D = $Model.find_child("Flame*", true, false) as Node3D
@onready var _igniter: Area3D = $IgniteArea
@onready var _timer: Timer = $BurnTimer


## Tìm đuốc đang cầm trên actor (player); null nếu chưa có
static func find_on(actor: Node) -> HandTorch:
	var model: Node = actor.get_node_or_null(^"Model")
	var holder: Node = model if model else actor
	return holder.get_node_or_null(NodePath(String(NODE_NAME))) as HandTorch


## Gắn gậy (chưa cháy) vào actor; đã có thì trả về cái đang có
static func give_to(actor: Node3D, scene: PackedScene) -> HandTorch:
	var existing: HandTorch = find_on(actor)
	if existing:
		return existing
	var torch: HandTorch = scene.instantiate() as HandTorch
	torch.name = NODE_NAME
	var model: Node = actor.get_node_or_null(^"Model")
	(model if model else actor).add_child(torch)
	return torch


func _ready() -> void:
	_light.light_color = light_color
	_light.omni_range = light_range
	_timer.one_shot = true
	_timer.timeout.connect(_on_burned_out)
	_igniter.area_entered.connect(_on_area_entered)
	_feedback.setup(_flame, _light, light_energy)
	_set_lit_visual(false)


## Châm (hoặc châm lại cho đầy giờ)
func light_up() -> void:
	is_lit = true
	_set_lit_visual(true)
	_timer.start(burn_time)
	if _tween:
		_tween.kill()
	_feedback.ignite()
	# Lửa nhỏ dần theo thời gian còn lại để người chơi nhìn là biết; giây cuối thì lập loè
	var warning: float = minf(fade_warning, burn_time)
	_tween = create_tween()
	_tween.tween_property(_feedback, ^"intensity", 0.0, maxf(burn_time - warning, 0.01))
	if warning > 0.0:
		_tween.tween_callback(func() -> void: _feedback.sputter = true)
	lit.emit()


func time_left() -> float:
	return _timer.time_left if is_lit else 0.0


func _on_burned_out() -> void:
	is_lit = false
	if _tween:
		_tween.kill()
	_feedback.extinguish()
	_set_lit_visual(false)
	if not burned_out_hint.is_empty():
		_hint.flash(burned_out_hint, burned_out_hint_time)
	burned_out.emit()


func _set_lit_visual(on: bool) -> void:
	_flame.visible = on
	_light.visible = on
	# Bật / tắt monitoring trong callback vật lý phải hoãn; bật lại thì vật đang chạm sẵn cũng báo area_entered
	_igniter.set_deferred(&"monitoring", on)


func _on_area_entered(area: Area3D) -> void:
	if is_lit and area is BurnableComponent:
		(area as BurnableComponent).ignite(get_parent())
