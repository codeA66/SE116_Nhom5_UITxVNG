class_name ChanGateReceiver
extends Node3D
## Máy thu mạch mở cửa. Sáng xanh vân mạch khi nhận tín hiệu 1 và mở cửa khi player tương tác.

signal activated

@export var prompt_text: String = "MỞ CỬA"

var _powered: bool = false
var _opened: bool = false

@onready var _interact: InteractableComponent = $Interactable
@onready var _veins_copper: Node3D = $VeinsCopper
@onready var _veins_live: Node3D = $VeinsLive
@onready var _ready_light: OmniLight3D = $ReadyLight


func _ready() -> void:
	_interact.prompt_text = prompt_text
	_interact.availability_check = _can_activate
	_interact.interacted.connect(_on_interacted)
	_refresh_visual()


func set_powered(value: bool) -> void:
	_powered = value
	_refresh_visual()


func set_opened(value: bool) -> void:
	_opened = value
	_refresh_visual()


func set_interaction_enabled(enabled: bool) -> void:
	_interact.enabled = enabled and _powered and not _opened


func reset(completed: bool = false) -> void:
	_powered = completed
	_opened = completed
	_refresh_visual()


func is_powered() -> bool:
	return _powered


func is_opened() -> bool:
	return _opened


func _can_activate(actor: Node3D) -> bool:
	return actor is Player and _powered and not _opened


func _on_interacted(_actor: Node3D) -> void:
	if not _powered or _opened:
		return
	_opened = true
	_refresh_visual()
	activated.emit()


func _refresh_visual() -> void:
	_veins_copper.visible = not _powered
	_veins_live.visible = _powered
	_ready_light.visible = _powered
	_interact.enabled = _powered and not _opened
