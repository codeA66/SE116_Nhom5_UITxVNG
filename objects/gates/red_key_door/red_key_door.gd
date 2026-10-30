class_name RedKeyDoor
extends Node3D
## Cửa có ổ khóa liền thân: đúng chìa -> cắm chìa -> tan cửa -> mở lối.

signal opened
signal unlock_started
signal denied

@export var key_id: StringName
@export var persistent_id: StringName
@export_range(0.1, 3.0, 0.05) var insert_time: float = 0.7
@export_range(0.2, 5.0, 0.1) var dissolve_time: float = 1.8
@export var dissolve_material: ShaderMaterial

var is_open: bool = false
var _dissolve: ShaderMaterial
var _deny_tween: Tween

@onready var state_machine: StateMachine = $StateMachine
@onready var interaction: InteractableComponent = $InteractableComponent
@onready var key_visual: Node3D = $InsertedKey
@onready var barrier: CollisionShape3D = $Barrier/CollisionShape3D
@onready var door_panels: MeshInstance3D = $Model.find_child("DoorPanels", true, false) as MeshInstance3D
@onready var lock_light: OmniLight3D = $LockLight

func _ready() -> void:
	if dissolve_material:
		_dissolve = dissolve_material.duplicate() as ShaderMaterial
		door_panels.material_override = _dissolve
	interaction.interacted.connect(_on_interacted)
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)

func has_key() -> bool:
	return not key_id.is_empty() and GameState.has_flag(key_id)

func was_opened() -> bool:
	return not persistent_id.is_empty() and GameState.has_flag(persistent_id)

func deny() -> void:
	denied.emit()
	if _deny_tween:
		_deny_tween.kill()
	_deny_tween = create_tween()
	_deny_tween.tween_property(lock_light, "light_energy", 2.0, 0.08)
	_deny_tween.tween_property(lock_light, "light_energy", 0.6, 0.25)

func begin_insert() -> void:
	interaction.enabled = false
	key_visual.visible = true
	key_visual.position = Vector3(0, 1.58, 1.28)
	key_visual.rotation = Vector3(PI * 0.5, 0, 0)
	unlock_started.emit()

func update_insert(progress: float) -> void:
	var eased: float = smoothstep(0.0, 1.0, progress)
	key_visual.position.z = lerpf(1.28, 0.46, eased)
	key_visual.rotation.z = lerpf(0.0, PI * 0.5, smoothstep(0.6, 1.0, progress))
	lock_light.light_energy = lerpf(0.6, 2.2, progress)

func begin_dissolve() -> void:
	key_visual.visible = false
	var motes: GPUParticles3D = get_node_or_null("DissolveMotes") as GPUParticles3D
	if motes:
		motes.restart()

func update_dissolve(progress: float) -> void:
	if _dissolve:
		_dissolve.set_shader_parameter(&"dissolve", progress)
	lock_light.light_energy = lerpf(2.2, 0.0, progress)
	if progress >= 0.85:
		barrier.set_deferred(&"disabled", true)

func finish_open(remember: bool) -> void:
	is_open = true
	interaction.enabled = false
	key_visual.visible = false
	door_panels.visible = false
	barrier.set_deferred(&"disabled", true)
	lock_light.light_energy = 0.0
	set_physics_process(false)
	if remember:
		if not persistent_id.is_empty():
			GameState.set_flag(persistent_id)
		opened.emit()

func _on_interacted(interactor: Node3D) -> void:
	if interactor is Player:
		(state_machine.current_state as RedKeyDoorState).interact()
