class_name TonFlameStation
extends Node3D
## Cùng một thao tác cho nguồn đầu, đuốc chiếu sáng và bệ ấn.

signal used(player: Player, station: TonFlameStation)

enum Role { SOURCE, TORCH, SEAL }

@export var role: Role = Role.TORCH
@export var shaped_lights: Node3D

@onready var _interaction: InteractableComponent = $Interactable
@onready var _flame: MeshInstance3D = $Flame
@onready var _light: OmniLight3D = $Light
@onready var _feedback: FlameFeedback = $FireFeedback


func _ready() -> void:
	_interaction.interacted.connect(_on_interacted)
	_feedback.setup(null, null, 0.0)
	set_lit(role == Role.SOURCE)


func configure(allowed: Callable) -> void:
	_interaction.availability_check = allowed.bind(self)


func is_lit() -> bool:
	return _flame.visible


func set_lit(lit: bool) -> void:
	_flame.visible = lit
	_light.visible = lit and shaped_lights == null
	if shaped_lights:
		shaped_lights.visible = lit
	if lit and not _feedback.is_burning:
		_feedback.start_quiet()
	elif not lit:
		_feedback.extinguish()


func _on_interacted(body: Node3D) -> void:
	var player := body as Player
	if player:
		used.emit(player, self)
