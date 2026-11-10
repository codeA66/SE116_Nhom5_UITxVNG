class_name LootItemBeam
extends Node3D
## Shader tự tạo nhịp sáng; không quét thế giới hay cập nhật CPU mỗi frame.
const BEAM: Shader = preload("res://components/feedback/loot_beam/loot_item_beam.gdshader")
@export var tint: Color = Color("ffd447")
@export_range(0.2, 16.0, 0.1) var height: float = 6.5
@export_range(0.01, 1.0, 0.01) var ground_depth: float = 0.18
@export_range(0.03, 1.0, 0.01) var radius: float = 0.25
@export_range(0.1, 5.0, 0.1) var light_radius: float = 2.0

static func attach_to(item: Node3D, color: Color) -> LootItemBeam:
	var beam: LootItemBeam = LootItemBeam.new()
	beam.name = "LootBeam"; beam.tint = color
	item.add_child(beam)
	beam.hide()
	return beam

func _ready() -> void:
	position.y = -ground_depth
	for core: bool in [false,true]:
		var surface: MeshInstance3D = MeshInstance3D.new()
		var cylinder: CylinderMesh = CylinderMesh.new()
		cylinder.top_radius = radius * (0.1 if core else 0.75)
		cylinder.bottom_radius = radius * (0.13 if core else 1.0)
		cylinder.height = height; cylinder.radial_segments = 12; cylinder.rings = 1
		cylinder.cap_top = false; cylinder.cap_bottom = false
		var material: ShaderMaterial = ShaderMaterial.new(); material.shader = BEAM
		material.set_shader_parameter("tint",tint)
		material.set_shader_parameter("opacity",0.8 if core else 0.19)
		material.set_shader_parameter("energy",2.5 if core else 1.2)
		surface.mesh = cylinder; surface.material_override = material
		surface.position.y = height*0.5
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(surface)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = tint; light.light_energy = 0.65; light.omni_range = light_radius
	light.position.y = 0.25; light.shadow_enabled = false
	add_child(light)
	set_process(false); set_physics_process(false)

func set_active(value: bool) -> void:
	visible = value
