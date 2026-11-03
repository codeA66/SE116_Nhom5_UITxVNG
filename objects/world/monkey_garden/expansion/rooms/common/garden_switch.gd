class_name GardenSwitch
extends StaticBody3D
signal activated
@export var interaction: InteractableComponent
@export var glow: MeshInstance3D
var active: bool = false

func _ready() -> void:
	interaction.interacted.connect(_press)

func is_active() -> bool:
	return active

func _press(_actor: Node3D) -> void:
	if active: return
	active = true; interaction.enabled = false
	var material: StandardMaterial3D = glow.material_override as StandardMaterial3D
	material.albedo_color = Color("8effb5"); material.emission_enabled = true; material.emission = Color("28b772")
	GardenCombatEffects.pulse(get_parent(),global_position+Vector3.UP*0.1,1.2,Color("8effb5")); activated.emit()
