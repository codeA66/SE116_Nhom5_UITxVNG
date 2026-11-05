class_name GardenSwitch
extends StaticBody3D
signal activated
@export var interaction: InteractableComponent
@export var glow: MeshInstance3D
@export var inactive_color: Color = Color("c9cdd1")
@export var active_color: Color = Color("ffdc37")
var _light: OmniLight3D
var _meshes: Array[Node3D] = []
var _scales: Array[Vector3] = []
var _pop_tween: Tween
var active: bool = false

func _ready() -> void:
	for child: Node in get_children():
		if child is MeshInstance3D:
			_meshes.append(child as Node3D); _scales.append((child as Node3D).scale)
	var material: StandardMaterial3D = glow.material_override.duplicate() as StandardMaterial3D
	material.albedo_color = inactive_color; material.emission_enabled = false
	glow.material_override = material
	_light = OmniLight3D.new(); _light.name = "ActivationGlow"
	_light.light_color = active_color; _light.light_energy = 1.2; _light.omni_range = 2.4
	_light.position.y = 0.18; glow.add_child(_light); _light.hide()
	interaction.interacted.connect(_press)

func is_active() -> bool:
	return active

func play_teleport_pop() -> void:
	# Chỉ nảy mesh hiển thị; collider/cảm biến giữ scale 1 để Jolt không phải nội suy shape.
	if _pop_tween: _pop_tween.kill()
	_pop_tween = create_tween().set_parallel(true)
	for index: int in _meshes.size():
		_meshes[index].scale = _scales[index]*Vector3(0.75,1.0,0.75)
		_pop_tween.tween_property(_meshes[index],"scale",_scales[index],0.18).set_trans(Tween.TRANS_BACK)

func _press(_actor: Node3D) -> void:
	if active: return
	active = true; interaction.enabled = false
	var material: StandardMaterial3D = glow.material_override as StandardMaterial3D
	material.albedo_color = active_color; material.emission_enabled = true; material.emission = active_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_energy_multiplier = 0.3; _light.show()
	GardenCombatEffects.pulse(get_parent(),global_position+Vector3.UP*0.1,0.8,active_color); activated.emit()
