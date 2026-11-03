class_name OfferingPedestal
extends StaticBody3D
## Nguồn activated/is_active để dùng chung cổng đá và các puzzle hiện có.

signal activated

@export var accepted_kind: StringName = &"banana"

var item: Node3D

@onready var interaction: InteractableComponent = $InteractableComponent
@onready var offering_anchor: Node3D = $OfferingAnchor
@onready var status_glow: MeshInstance3D = $StatusGlow


func _ready() -> void:
	interaction.availability_check = _can_offer
	interaction.interacted.connect(_offer)
	status_glow.visible = false
	set_process(false)
	set_physics_process(false)


func is_active() -> bool:
	return item != null


func _can_offer(actor: Node3D) -> bool:
	if item != null:
		return false
	var carry := actor.get_node_or_null(^"CarryComponent") as CarryComponent
	return carry != null and carry.held_item != null and carry.held_item.get("kind") == accepted_kind


func _offer(actor: Node3D) -> void:
	if not _can_offer(actor):
		return
	var carry := actor.get_node(^"CarryComponent") as CarryComponent
	item = carry.place_on(self, offering_anchor)
	if item:
		interaction.enabled = false
		status_glow.visible = true
		activated.emit()
