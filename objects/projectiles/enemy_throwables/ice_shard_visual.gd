@tool
extends Node3D
static var _mesh: ArrayMesh
static var _material: ShaderMaterial

func _ready() -> void:
	if _mesh == null: _mesh = IceCrystalGeometry.build()
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://objects/projectiles/enemy_throwables/ice_shard.gdshader")
	var crystal: MeshInstance3D = MeshInstance3D.new()
	crystal.mesh = _mesh
	crystal.material_override = _material
	crystal.rotation.x = PI * 0.5
	crystal.scale = Vector3(0.22, 1.05, 0.22)
	crystal.position.z = -0.5
	add_child(crystal)
