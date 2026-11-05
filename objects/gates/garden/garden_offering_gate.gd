class_name GardenOfferingGate
extends StoneGate
## Giữ giao thức Sources; hai lá cửa trượt sang bên, khung ở lại và khóa biến mất.
var _materials: Array[ShaderMaterial] = []

func _ready() -> void:
	for child: MeshInstance3D in $Visual.find_children("*", "MeshInstance3D", true, false):
		if child.material_override is ShaderMaterial:
			var mat: ShaderMaterial = child.material_override.duplicate() as ShaderMaterial
			child.material_override = mat
			_materials.append(mat)
	super()

func _sink() -> void:
	if _sinking: return
	_sinking = true
	for name: String in ["Interactive_Cyan_Lock","LockBase"]:
		var lock_part: Node3D = $Visual/OldGardenDoor.get_node_or_null(name)
		if lock_part: lock_part.hide()
	unlock_started.emit()
	var tween: Tween = create_tween().set_parallel(true)
	var model: Node3D=$Visual/OldGardenDoor
	for name: String in ["DoorLeaf_Left_004","DoorLeaf_Right_004"]:
		var leaf: Node3D=model.get_node(name)
		tween.tween_property(leaf,"position:x",leaf.position.x+(-1.8 if "Left" in name else 1.8),open_time)
	tween.chain().tween_callback(_complete_dissolve)
	if open_trauma > 0.0: ScreenShake.add_trauma(open_trauma)

func _set_dissolve(value: float) -> void:
	for mat: ShaderMaterial in _materials: mat.set_shader_parameter("dissolve", value)
	if flash_light: flash_light.light_energy = (1.0-value)*2.0

func _complete_dissolve() -> void:
	for name: String in ["DoorLeaf_Left_004","DoorLeaf_Right_004","Interactive_Cyan_Lock","LockBase"]:
		var part: Node3D=$Visual/OldGardenDoor.get_node_or_null(name)
		if part: part.hide()
	_collision.set_deferred("disabled", true)
	opened.emit()
