class_name FerryCallPost
extends Node3D
## Trụ gọi thuyền bay: người chơi lại gần bấm tương tác thì trụ bật sáng, phát activated một lần.
## Là nguồn kích hoạt (signal activated + is_active()) nên gán được cho SkyFerry, cổng... qua @export, không phát tín hiệu chung.

signal activated

## Đèn sáng mờ lúc chờ (gợi ý tương tác được), bừng lên khi đã gọi
@export var idle_energy: float = 0.6
@export var active_energy: float = 2.5
@export_range(0.05, 3.0, 0.05) var light_up_time: float = 0.4

var _active: bool = false

@onready var _interactable: InteractableComponent = $InteractableComponent
@onready var _light: OmniLight3D = $Glow


func _ready() -> void:
	_light.light_energy = idle_energy
	_interactable.interacted.connect(_on_interacted)


func is_active() -> bool:
	return _active


func _on_interacted(_interactor: Node3D) -> void:
	if _active:
		return
	_active = true
	_interactable.enabled = false
	create_tween().tween_property(_light, "light_energy", active_energy, light_up_time)
	activated.emit()
