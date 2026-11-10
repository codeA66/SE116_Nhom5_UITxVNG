class_name CarryComponent
extends Node3D
## Một vật trên tay, giao tiếp qua API của vật; F vẫn đi qua Interactor như các tương tác khác.

signal holding_changed(item: Node3D)

@export var hold_offset: Vector3 = Vector3(0.0, 2.25, 0.0)
@export var drop_distance: float = 1.5
@export_flags_3d_physics var ground_mask: int = 1 | 256

var held_item: Node3D
var _player: Player
var _anchor: Node3D
var _drop_interaction: InteractableComponent


func _ready() -> void:
	_player = get_parent() as Player
	assert(_player != null, "CarryComponent cần gắn trực tiếp dưới Player")
	_anchor = Node3D.new()
	_anchor.name = "CarryAnchor"
	_anchor.position = hold_offset
	# Neo theo body để squash/animation của model không kéo vật xuyên đầu.
	_player.add_child(_anchor)
	_drop_interaction = InteractableComponent.new()
	_drop_interaction.name = "DropInteraction"
	_drop_interaction.collision_layer = 32
	_drop_interaction.collision_mask = 0
	_drop_interaction.interaction_priority = -100
	_drop_interaction.prompt_text = "Thả chuối"
	_drop_interaction.prompt_offset = Vector3(0, 1.6, 0)
	_drop_interaction.enabled = false
	_drop_interaction.availability_check = _can_drop
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	shape.shape = sphere
	shape.position.y = 0.9
	_drop_interaction.add_child(shape)
	add_child(_drop_interaction)
	_drop_interaction.interacted.connect(_on_drop_requested)
	set_process(false)
	set_physics_process(false)


func can_take() -> bool:
	return held_item == null and not _player.health.is_dead() \
		and _player.state_machine.current_state != null \
		and _player.state_machine.current_state.name in [&"Idle", &"Run"]


func take(item: Node3D) -> bool:
	if not can_take():
		return false
	held_item = item
	_player.set_combat_locked(self, true)
	item.reparent(_anchor, false)
	item.position = Vector3.ZERO
	item.rotation = Vector3.ZERO
	item.call(&"on_carried", self)
	_drop_interaction.enabled = true
	holding_changed.emit(held_item)
	return true


func place_on(pedestal: Node3D, anchor: Node3D) -> Node3D:
	if held_item == null:
		return null
	var item := held_item
	item.reparent(anchor, false)
	item.position = Vector3.ZERO
	item.rotation = Vector3.ZERO
	item.call(&"on_offered", pedestal)
	_release()
	return item


func drop() -> void:
	if held_item == null:
		return
	var facing := _player.get_facing_direction()
	var destination := _player.global_position + facing * drop_distance
	var space := get_world_3d().direct_space_state
	var wall_query := PhysicsRayQueryParameters3D.create(_player.global_position + Vector3.UP, destination + Vector3.UP, ground_mask)
	wall_query.exclude = [_player.get_rid()]
	var wall := space.intersect_ray(wall_query)
	if not wall.is_empty():
		destination = wall.position - facing * 0.4
	var floor_query := PhysicsRayQueryParameters3D.create(destination + Vector3.UP * 2, destination - Vector3.UP * 4, ground_mask)
	floor_query.exclude = [_player.get_rid()]
	var floor_hit := space.intersect_ray(floor_query)
	if floor_hit.is_empty():
		destination = _player.global_position
	else:
		destination = floor_hit.position
	held_item.call(&"return_to_world", destination)
	_release()


func _release() -> void:
	held_item = null
	_player.set_combat_locked(self, false)
	_drop_interaction.enabled = false
	holding_changed.emit(null)


func _can_drop(actor: Node3D) -> bool:
	return actor == _player and held_item != null


func _on_drop_requested(_actor: Node3D) -> void:
	drop()
