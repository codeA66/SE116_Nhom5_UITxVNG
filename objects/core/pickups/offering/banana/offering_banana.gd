class_name OfferingBanana
extends Node3D
## Vật cúng có thể mang, thả hoặc đặt lên bục; không ghi tiến trình trong scene thử.

enum Location { WORLD, CARRIED, OFFERED }
signal navigation_changed

@export var kind: StringName = &"banana"
@export var available: bool = true
@export var float_height: float = 0.65
@export var bob_amplitude: float = 0.09
@export var bob_speed: float = 2.2
@export var spin_speed: float = 0.65
@export var visual_scale: float = 1.2

var location: Location = Location.WORLD
var was_rewarded: bool = false
var _clock: float = 0.0
var _world_parent: Node

@onready var visual: Node3D = $Visual
@onready var interaction: InteractableComponent = $InteractableComponent


func _ready() -> void:
	_world_parent = get_parent()
	visual.scale = Vector3.ONE * visual_scale
	_clock = global_position.x * 0.13 + global_position.z * 0.11
	interaction.enabled = available
	interaction.availability_check = _can_pick_up
	interaction.interacted.connect(_pick_up)
	set_available(available)
	set_physics_process(false)


func _process(delta: float) -> void:
	_clock += delta
	visual.position.y = (0.12 if location == Location.CARRIED else float_height) + sin(_clock * bob_speed) * bob_amplitude
	visual.rotation.y += spin_speed * delta


func set_available(value: bool) -> void:
	available = value
	visible = value
	if is_instance_valid(interaction): interaction.enabled = value and location == Location.WORLD
	set_process(value)
	navigation_changed.emit()


func on_carried(_carrier: CarryComponent) -> void:
	location = Location.CARRIED
	interaction.enabled = false
	navigation_changed.emit()


func on_offered(_pedestal: Node3D) -> void:
	location = Location.OFFERED
	interaction.enabled = false
	navigation_changed.emit()


func return_to_world(at: Vector3) -> void:
	reparent(_world_parent, true)
	global_position = at
	location = Location.WORLD
	interaction.enabled = available
	navigation_changed.emit()


func _can_pick_up(actor: Node3D) -> bool:
	var carry := actor.get_node_or_null(^"CarryComponent") as CarryComponent
	return location == Location.WORLD and carry != null and carry.can_take()


func _pick_up(actor: Node3D) -> void:
	var carry := actor.get_node_or_null(^"CarryComponent") as CarryComponent
	if carry:
		carry.take(self)
