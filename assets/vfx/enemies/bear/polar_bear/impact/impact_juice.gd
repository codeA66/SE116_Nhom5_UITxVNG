extends Node3D
const RING = preload("res://assets/vfx/enemies/bear/polar_bear/impact/impact_ring.gdshader")
const SPARKS = preload("res://assets/vfx/enemies/bear/polar_bear/impact/impact_sparks.gdshader")
@export var burst_height := 1.3
var materials: Array[ShaderMaterial] = []

func _ready() -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = QuadMesh.new()
	ring.mesh.size = Vector2.ONE * 4.5
	ring.rotation.x = -PI / 2
	ring.position.y = 0.04
	ring.material_override = _material(RING)
	add_child(ring)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = QuadMesh.new()
	mm.instance_count = 48
	var rng := RandomNumberGenerator.new()
	rng.seed = 329
	for index in mm.instance_count:
		mm.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(0, burst_height, 0.65)))
		mm.set_instance_custom_data(index, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf()))
	var sparks := MultiMeshInstance3D.new()
	sparks.multimesh = mm
	sparks.material_override = _material(SPARKS)
	sparks.custom_aabb = AABB(Vector3(-4, -2, -3), Vector3(8, 8, 6))
	add_child(sparks)
	seek(-1.0)

func _material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	materials.append(material)
	return material

func seek(seconds: float) -> void:
	visible = seconds >= 0.0 and seconds < 0.7
	for material in materials: material.set_shader_parameter("age", seconds)
