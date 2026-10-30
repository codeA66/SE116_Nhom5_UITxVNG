@tool
class_name WindShrineVisual
extends Node3D
## Chỉ đổi hình ảnh; không truy cập tiến trình hoặc ghi save.

const DEFAULT_STYLE: WindShrineStyle = preload("res://resources/world/wind/wind/wind_shrine_default.tres")
const CRYSTAL_SHADER: Shader = preload("res://assets/shaders/wind/shrine/wind_shrine_crystal.gdshader")
const AURA_SHADER: Shader = preload("res://assets/shaders/wind/shrine/wind_shrine_aura.gdshader")
const RIBBON_SHADER: Shader = preload("res://assets/shaders/wind/shrine/wind_shrine_ribbon.gdshader")
const STONE_SHADER: Shader = preload("res://assets/shaders/wind/shrine/wind_shrine_stone.gdshader")

static var _stone_material_cache: Dictionary[String, BaseMaterial3D] = {}

@export var style: WindShrineStyle = DEFAULT_STYLE:
	set(value):
		style = value
		if is_node_ready():
			_apply_style()
@export var preview_active: bool = false:
	set(value):
		preview_active = value
		if is_node_ready() and Engine.is_editor_hint():
			set_active(value, null, _spin_degrees, true)

var active_level: float = 0.0
var _spin_degrees: float = 12.0
var _active_color: Color
var _crystal_material: ShaderMaterial
var _aura_material: ShaderMaterial
var _ribbon_material: ShaderMaterial
var _inlay_material: ShaderMaterial
var _stone_overlay: ShaderMaterial
var _materials: Array[ShaderMaterial] = []
var _transition: Tween
var _last_target: bool = false

@onready var _crystal: MeshInstance3D = $Model/Wind_Shrine/Crystal
@onready var _inlay: MeshInstance3D = $Model/Wind_Shrine/Inlay
@onready var _ribbons: MeshInstance3D = $Model/Wind_Shrine/WindRibbons
@onready var _aura: MeshInstance3D = $Aura
@onready var _stone_meshes: Array[MeshInstance3D] = [$Model/Wind_Shrine/StoneBase, $Model/Wind_Shrine/StoneRing, $Model/Wind_Shrine/Moss]


func _ready() -> void:
	_crystal_material = _make_material(CRYSTAL_SHADER)
	_aura_material = _make_material(AURA_SHADER)
	_ribbon_material = _make_material(RIBBON_SHADER)
	_inlay_material = _make_material(RIBBON_SHADER)
	_stone_overlay = _make_material(STONE_SHADER)
	_crystal.material_override = _crystal_material
	_aura.material_override = _aura_material
	_ribbons.material_override = _ribbon_material
	# Giữ đường khắc tối ở trạng thái ngủ, chỉ phủ ánh sáng khi bật.
	_inlay.material_overlay = _inlay_material
	_stone_meshes[0].material_overlay = _stone_overlay
	_stone_meshes[1].material_overlay = _stone_overlay
	_crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ribbons.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_inlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_apply_style()
	set_active(preview_active if Engine.is_editor_hint() else false, null, _spin_degrees, true)
	set_process(false)
	set_physics_process(false)


func set_active(enabled: bool, legacy_material: Material = null, spin_degrees: float = 12.0, immediate: bool = false) -> void:
	_spin_degrees = spin_degrees
	var settings: WindShrineStyle = style if style else DEFAULT_STYLE
	_active_color = settings.active_color
	if legacy_material is BaseMaterial3D:
		_active_color = (legacy_material as BaseMaterial3D).albedo_color
	_crystal_material.set_shader_parameter(&"active_color", _active_color)
	_crystal_material.set_shader_parameter(&"spin_speed", deg_to_rad(_spin_degrees))
	_ribbon_material.set_shader_parameter(&"spin_speed", deg_to_rad(_spin_degrees))
	if enabled == _last_target and not immediate:
		return
	_last_target = enabled
	if _transition:
		_transition.kill()
	var target: float = 1.0 if enabled else 0.0
	if immediate or settings.activation_time <= 0.0:
		_set_level(target)
		return
	if enabled:
		_aura.show()
		_ribbons.show()
	_transition = create_tween()
	_transition.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_method(_set_level, active_level, target, settings.activation_time)


func _make_material(shader: Shader) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	_materials.append(material)
	return material


func _apply_style() -> void:
	var settings: WindShrineStyle = style if style else DEFAULT_STYLE
	_apply_stone_brightness(settings.stone_brightness)
	_crystal_material.set_shader_parameter(&"dormant_color", settings.dormant_color)
	_crystal_material.set_shader_parameter(&"active_color", settings.active_color)
	_crystal_material.set_shader_parameter(&"edge_color", settings.edge_color)
	_crystal_material.set_shader_parameter(&"emission_energy", settings.emission_energy)
	_crystal_material.set_shader_parameter(&"edge_energy", settings.edge_energy)
	_crystal_material.set_shader_parameter(&"edge_width", settings.edge_width)
	for material: ShaderMaterial in [_crystal_material, _aura_material, _ribbon_material]:
		material.set_shader_parameter(&"float_amplitude", settings.float_amplitude)
		material.set_shader_parameter(&"float_speed", settings.float_speed)
	_aura_material.set_shader_parameter(&"aura_color", settings.edge_color)
	_aura_material.set_shader_parameter(&"opacity", settings.aura_opacity)
	_ribbon_material.set_shader_parameter(&"wind_color", settings.edge_color)
	_ribbon_material.set_shader_parameter(&"opacity", settings.ribbon_opacity)
	_inlay_material.set_shader_parameter(&"wind_color", settings.edge_color)
	_inlay_material.set_shader_parameter(&"opacity", settings.inlay_opacity)
	_inlay_material.set_shader_parameter(&"is_inlay", true)
	_stone_overlay.set_shader_parameter(&"active_color", settings.stone_active_color)
	_stone_overlay.set_shader_parameter(&"tint_strength", settings.stone_tint_strength)
	_stone_overlay.set_shader_parameter(&"center_tint", settings.stone_center_tint)
	_aura.scale = Vector3.ONE * settings.aura_size


func _apply_stone_brightness(brightness: float) -> void:
	# Dùng chung bản material đã cân sáng, không nhân bản theo từng checkpoint.
	for mesh_instance: MeshInstance3D in _stone_meshes:
		for surface: int in range(mesh_instance.mesh.get_surface_count()):
			var source: BaseMaterial3D = mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null:
				continue
			var key: String = "%d:%.4f" % [source.get_instance_id(), brightness]
			if not _stone_material_cache.has(key):
				var material: BaseMaterial3D = source.duplicate() as BaseMaterial3D
				material.albedo_color = source.albedo_color * Color(brightness, brightness, brightness, 1.0)
				_stone_material_cache[key] = material
			mesh_instance.set_surface_override_material(surface, _stone_material_cache[key])


func _set_level(value: float) -> void:
	active_level = clampf(value, 0.0, 1.0)
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"active_level", active_level)
	_aura.visible = active_level > 0.001
	_ribbons.visible = active_level > 0.001
