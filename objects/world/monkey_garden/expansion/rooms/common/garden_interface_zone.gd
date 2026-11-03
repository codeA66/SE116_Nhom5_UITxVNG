class_name GardenInterfaceZone
extends Area3D
@export var interface: CanvasLayer
@export var tier_root: Node3D

func _ready() -> void:
	if tier_root.get("standalone_test"):
		monitoring = false; return
	interface.hide()
	body_entered.connect(_entered); body_exited.connect(_exited)

func _entered(body: Node3D) -> void:
	if body is Player: interface.show()

func _exited(body: Node3D) -> void:
	if body is Player: interface.hide()
