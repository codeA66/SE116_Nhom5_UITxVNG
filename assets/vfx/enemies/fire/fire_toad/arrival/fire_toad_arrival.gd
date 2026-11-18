extends Node3D
## Đồng bộ đường cắt giữa các vật liệu để cả model hiện ra thành một khối.

class RevealSurface:
	var mesh: MeshInstance3D
	var index: int
	var original: Material
	var reveal: ShaderMaterial

class RevealMesh:
	var mesh: MeshInstance3D
	var overlay: Material

const REVEAL_SHADER: Shader = preload("res://assets/shaders/fire/fire_toad_vfx/arrival/reveal.gdshader")

@export_group("Vị trí khe nứt")
@export_range(0.1, 15.0, 0.1) var reveal_height: float = 5.4
@export_range(0.0, 10.0, 0.1) var rift_center_height: float = 1.8
@export_range(0.1, 15.0, 0.1) var rift_depth: float = 0.5
@export_group("Nhịp mở")
@export_range(0.0, 1.0, 0.01) var opening_start: float = 0.06
@export_range(0.05, 1.0, 0.01) var fully_open_at: float = 0.52

var _model: Node3D
var _ground_shadow: Node3D
var _surfaces: Array[RevealSurface] = []
var _meshes: Array[RevealMesh] = []
var _materials: Array[ShaderMaterial] = []
var _prepared: bool
var _revealing: bool

@onready var _rift_material: ShaderMaterial = $Rift.material_override as ShaderMaterial


func bind_model(model: Node3D, ground_shadow: Node3D) -> void:
	_model = model
	_ground_shadow = ground_shadow


func set_model_visible(value: bool) -> void:
	_model.visible = value
	if _ground_shadow != null:
		_ground_shadow.visible = value


func begin(feet: Vector3) -> void:
	stop()
	set_model_visible(false)
	if not _prepared:
		_prepare_surfaces()
	# Chỉ lấy hướng ngang của camera để khe luôn dựng đứng trong thế giới.
	var camera: Camera3D = get_viewport().get_camera_3d()
	var normal: Vector3 = camera.global_basis.z if camera != null else Vector3.BACK
	normal.y = 0.0
	if normal.is_zero_approx():
		normal = Vector3.BACK
	normal = normal.normalized()
	var alignment: Basis = Basis(Vector3.UP.cross(normal), Vector3.UP, normal)
	global_transform = Transform3D(alignment, feet + Vector3.UP * rift_center_height - alignment.z * rift_depth)
	reset_physics_interpolation()
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"feet_y", feet.y)
		material.set_shader_parameter(&"reveal_height", reveal_height)
	draw_crack(0.0)
	show()


func draw_crack(progress: float) -> void:
	_rift_material.set_shader_parameter(&"fracture", progress)
	_rift_material.set_shader_parameter(&"opening", opening_start * progress)
	_rift_material.set_shader_parameter(&"closure", 0.0)


func draw_reveal(progress: float) -> void:
	var starting: bool = not _revealing
	if starting:
		for surface: RevealSurface in _surfaces:
			surface.mesh.set_surface_override_material(surface.index, surface.reveal)
		_revealing = true
		defer_model_overlay()
	_rift_material.set_shader_parameter(&"opening", lerpf(opening_start, 1.0, smoothstep(0.0, fully_open_at, progress)))
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"reveal_progress", progress)
	if starting:
		_model.show()


func draw_close(progress: float) -> void:
	if _revealing:
		_restore_model_materials()
		set_model_visible(true)
	_rift_material.set_shader_parameter(&"opening", 1.0 - smoothstep(0.0, 1.0, progress))
	_rift_material.set_shader_parameter(&"closure", progress)


func stop() -> void:
	_restore_model_materials()
	hide()


func defer_model_overlay() -> void:
	if not _revealing:
		return
	# Lớp cuồng nộ chưa qua đường cắt sẽ làm lộ cả thân trước khi khe mở xong.
	for entry: RevealMesh in _meshes:
		if entry.mesh.material_overlay != null:
			entry.overlay = entry.mesh.material_overlay
			entry.mesh.material_overlay = null


func _prepare_surfaces() -> void:
	# Giữ texture gốc của các bề mặt và chỉ tạo một bản shader cho từng vật liệu.
	var cache: Dictionary[BaseMaterial3D, ShaderMaterial] = {}
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var reveal_mesh: RevealMesh = RevealMesh.new()
		reveal_mesh.mesh = mesh
		_meshes.append(reveal_mesh)
		for index: int in range(mesh.mesh.get_surface_count()):
			var source: BaseMaterial3D = mesh.get_active_material(index) as BaseMaterial3D
			if source == null:
				continue
			var material: ShaderMaterial = cache.get(source)
			if material == null:
				material = ShaderMaterial.new()
				material.shader = REVEAL_SHADER
				material.set_shader_parameter(&"skin_texture", source.albedo_texture)
				material.set_shader_parameter(&"skin_color", source.albedo_color)
				material.set_shader_parameter(&"skin_metallic", source.metallic)
				material.set_shader_parameter(&"skin_roughness", source.roughness)
				cache[source] = material
				_materials.append(material)
			var entry: RevealSurface = RevealSurface.new()
			entry.mesh = mesh
			entry.index = index
			entry.original = mesh.get_surface_override_material(index)
			entry.reveal = material
			_surfaces.append(entry)
	_prepared = true


func _restore_model_materials() -> void:
	if not _revealing:
		return
	for surface: RevealSurface in _surfaces:
		surface.mesh.set_surface_override_material(surface.index, surface.original)
	for entry: RevealMesh in _meshes:
		if entry.overlay != null:
			entry.mesh.material_overlay = entry.overlay
			entry.overlay = null
	_revealing = false
