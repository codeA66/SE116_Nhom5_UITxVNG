class_name FerryCallPost
extends Node3D
## Trụ gọi thuyền bay: người chơi lại gần bấm tương tác thì trụ bật sáng, phát activated một lần.
## Là nguồn kích hoạt (signal activated + is_active()) nên gán được cho SkyFerry, cổng... qua @export, không phát tín hiệu chung.

signal activated

## Bến có NPC thu phí giữ trụ làm đèn báo, tránh gọi thuyền bằng một lần bấm F khác.
@export var manual_call_enabled: bool = true
## Đèn sáng mờ lúc chờ (gợi ý tương tác được), bừng lên khi đã gọi
@export var idle_energy: float = 0.6
@export var active_energy: float = 2.5
@export var docked_energy: float = 1.6
@export_range(0.05, 3.0, 0.05) var light_up_time: float = 0.4

var _active: bool = false
var _light_tween: Tween

@onready var _interactable: InteractableComponent = $InteractableComponent
@onready var _light: OmniLight3D = $Glow


## Trụ chỉ nhận tương tác trực tiếp ở các bến dùng cơ chế cũ.
func _ready() -> void:
	_light.light_energy = idle_energy
	if manual_call_enabled:
		_interactable.interacted.connect(_on_interacted)
	else:
		_interactable.enabled = false


## Giữ giao kèo nguồn kích hoạt cho các trụ gọi độc lập.
func is_active() -> bool:
	return _active


## Dùng chung hiệu ứng một lần cho cả người chơi bấm trụ và NPC phát tín hiệu.
func activate() -> void:
	if _active:
		return
	_active = true
	_interactable.enabled = false
	_set_light(active_energy)
	activated.emit()


## Giữ ánh đèn ổn định khi bến đã sẵn sàng đón khách.
func indicate_docked() -> void:
	_set_light(docked_energy)


## Khi phà rời bến, đèn về mức chờ để không còn báo lối lên boong.
func indicate_departed() -> void:
	_set_light(idle_energy)


## Cả nguồn gọi cũ và mới dùng chung trạng thái chống kích hoạt lặp.
func _on_interacted(_interactor: Node3D) -> void:
	activate()


## Hủy tween cũ để hai tín hiệu gần nhau không tranh độ sáng.
func _set_light(energy: float) -> void:
	if _light_tween and _light_tween.is_valid():
		_light_tween.kill()
	_light_tween = create_tween()
	_light_tween.tween_property(_light, "light_energy", energy, light_up_time)
