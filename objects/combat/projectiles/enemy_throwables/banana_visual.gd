@tool
extends Node3D
@export var peeled: bool = false
static var _fruit: ArrayMesh
static var _peel: ArrayMesh
static var _material: StandardMaterial3D

func _ready() -> void:
	if _fruit == null: _fruit = BananaGeometry.fruit()
	if _peel == null: _peel = BananaGeometry.peel()
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material.roughness = 0.75
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = _peel if peeled else _fruit
	mesh.material_override = _material
	add_child(mesh)
