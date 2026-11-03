class_name EchoPad
extends Area3D
signal stepped(index: int)
@export var index: int = 0
@export var color: Color = Color.CYAN
@export var surface: MeshInstance3D
var _tween: Tween

func _ready() -> void:
	body_entered.connect(_entered)
	var material: StandardMaterial3D = surface.material_override as StandardMaterial3D
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; material.albedo_color = color*0.65

func pulse() -> void:
	var material: StandardMaterial3D = surface.material_override as StandardMaterial3D
	material.albedo_color = color
	if _tween: _tween.kill()
	_tween = create_tween(); _tween.tween_property(material,"albedo_color",color*0.65,0.5)

func _entered(body: Node3D) -> void:
	if body is Player: stepped.emit(index)
