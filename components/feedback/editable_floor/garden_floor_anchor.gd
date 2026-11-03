@tool
class_name GardenFloorAnchor
extends Node
## Material riêng cho instance map: test ở gốc và tier 3 đặt trong level 1 vẫn giữ đúng mảng đất.
const FLOOR: Shader = preload("res://assets/shaders/environment/monkey_garden/stable_floor.gdshader")
@export var map_root: Node3D

func _ready() -> void:
	if map_root==null: return
	var materials: Dictionary[int,ShaderMaterial] = {}
	var origin: Vector2 = Vector2(map_root.global_position.x,map_root.global_position.z)
	for node: Node in map_root.find_children("*","GeometryInstance3D",true,false):
		var visual: GeometryInstance3D = node as GeometryInstance3D
		var material: ShaderMaterial = visual.material_override as ShaderMaterial
		if material==null or material.shader!=FLOOR: continue
		var id: int = material.get_instance_id()
		if not materials.has(id):
			var copy: ShaderMaterial = material.duplicate() as ShaderMaterial
			copy.set_shader_parameter("map_offset",origin); materials[id] = copy
		visual.material_override = materials[id]
	set_process(false); set_physics_process(false)
