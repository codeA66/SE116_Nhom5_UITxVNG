class_name PlayerDeathPresentation
extends Node
## Màn player chết: chậm thời gian + camera zoom sát vào cáo, màn xám dần trừ vùng quanh cáo, cáo ngã rồi tan từ chân
## lên đầu thành hạt màu cáo, tan xong tối màn rồi báo finished để state Dead hồi sinh.
## State Dead gọi play() / reset(); không tự nghe health để không chạy hai lần. Chỉ chạy _process trong lúc diễn
## (để giữ vùng có màu bám theo cáo trên màn), xong thì tắt. Mọi mốc dùng thời gian thật, không bị slow-mo kéo dài.

signal finished

## Tham số shader tan biến (assets/shaders/character/dissolve.gdshaderinc)
const DISSOLVE_PARAM := &"dissolve"

@export var data: PlayerDeathData
## Gốc model hiển thị (Model/Visual): mọi material có tham số dissolve bên dưới sẽ tan
@export var visual: Node3D
@export var camera_rig: CameraRig
## Ẩn khi bắt đầu tan (vũ khí gắn ngoài model như cung)
@export var hide_on_dissolve: Array[Node3D] = []

var _playing: bool = false
var _finished: bool = false
var _materials: Array[ShaderMaterial] = []
var _hidden: Array[Node3D] = []
var _tween: Tween
var _origin: Vector3
var _axis: Vector3 = Vector3.UP
var _length: float = 1.0
var _skeleton: Skeleton3D

@onready var _screen: CanvasLayer = $Screen
@onready var _grey: ColorRect = $Screen/Grey
@onready var _grey_material: ShaderMaterial = _grey.material as ShaderMaterial
@onready var _particles: CPUParticles3D = $Particles


func _ready() -> void:
	set_process(false)
	_screen.visible = false
	_particles.emitting = false
	if data:
		_apply_particle_colors()


func is_playing() -> bool:
	return _playing


func is_finished() -> bool:
	return _finished


func play() -> void:
	if data == null or _playing:
		return
	_kill_tween()
	_playing = true
	_finished = false
	HitStop.slow_motion(data.slow_time, data.slow_scale)
	if camera_rig:
		var base := camera_rig.get_base_distance()
		camera_rig.zoom_to(minf(data.zoom_distance / maxf(base, 0.01), 1.0), data.zoom_time)
	_grey_material.set_shader_parameter(&"amount", 0.0)
	_grey_material.set_shader_parameter(&"blackout", 0.0)
	_grey_material.set_shader_parameter(&"focus_radius", data.focus_radius)
	_grey_material.set_shader_parameter(&"focus_softness", data.focus_softness)
	_grey_material.set_shader_parameter(&"edge_darkness", data.edge_darkness)
	_screen.visible = true
	_update_focus()
	set_process(true)
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_method(_set_grey, 0.0, data.grey_amount, data.grey_time).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_callback(_start_dissolve).set_delay(data.dissolve_delay)
	_tween.parallel().tween_method(_set_dissolve, 0.0, 1.0, data.dissolve_time).set_delay(data.dissolve_delay)
	var end_at := data.dissolve_delay + data.dissolve_time
	_tween.parallel().tween_callback(_stop_particles).set_delay(end_at)
	_tween.parallel().tween_method(_set_blackout, 0.0, 1.0, data.end_fade_time).set_delay(end_at + data.end_hold)
	_tween.tween_callback(_finish)


## Về trạng thái thường ngay lập tức (hồi sinh tại chỗ, rời state Dead). Gọi nhiều lần không sao
func reset() -> void:
	if _playing:
		# Hồi sinh khi đang chậm thời gian: chạy lại bình thường ngay, không chờ hết slow-mo
		HitStop.cancel()
	_kill_tween()
	_playing = false
	_finished = false
	set_process(false)
	_screen.visible = false
	_particles.emitting = false
	_set_materials(0.0)
	for node in _hidden:
		if is_instance_valid(node):
			node.visible = true
	_hidden.clear()
	if camera_rig:
		camera_rig.reset_zoom()


func _process(_delta: float) -> void:
	_update_focus()


## Vùng giữ màu bám theo ngực cáo trên màn (camera và cáo đều có thể đang trôi)
func _update_focus() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or visual == null:
		return
	var size := get_viewport().get_visible_rect().size
	var point := visual.global_position + Vector3.UP * 0.5
	if camera.is_position_behind(point):
		return
	_grey_material.set_shader_parameter(&"focus_uv", camera.unproject_position(point) / size)
	_grey_material.set_shader_parameter(&"aspect", size.x / maxf(size.y, 1.0))


func _start_dissolve() -> void:
	_collect_materials()
	_measure_body()
	for material in _materials:
		material.set_shader_parameter(&"dissolve_origin", _origin)
		material.set_shader_parameter(&"dissolve_axis", _axis)
		material.set_shader_parameter(&"dissolve_length", _length)
		material.set_shader_parameter(&"dissolve_edge_color", data.edge_color)
		material.set_shader_parameter(&"dissolve_edge_width", data.edge_width)
		material.set_shader_parameter(&"dissolve_noise", data.edge_noise)
		material.set_shader_parameter(&"dissolve_noise_scale", data.noise_scale)
		material.set_shader_parameter(&"dissolve_edge_glow", data.edge_glow)
	# Lớp nháy (đỏ khi trúng bẫy, chớp khi bị đánh) phủ lên thân sẽ không tan theo: bỏ đi
	for mesh in _meshes():
		mesh.material_overlay = null
	for node in hide_on_dissolve:
		if is_instance_valid(node) and node.visible:
			node.visible = false
			_hidden.append(node)
	_particles.amount = maxi(data.particle_amount, 1)
	_particles.global_position = _origin
	_particles.emitting = true


func _set_dissolve(value: float) -> void:
	_set_materials(value)
	# Hạt bật ra đúng chỗ mép đang tan
	_particles.global_position = _origin + _axis * (_length * clampf(value, 0.0, 1.0))


func _set_materials(value: float) -> void:
	for material in _materials:
		material.set_shader_parameter(DISSOLVE_PARAM, value)


func _set_grey(value: float) -> void:
	_grey_material.set_shader_parameter(&"amount", value)


func _set_blackout(value: float) -> void:
	_grey_material.set_shader_parameter(&"blackout", value)


func _stop_particles() -> void:
	_particles.emitting = false


func _finish() -> void:
	set_process(false)
	_finished = true
	finished.emit()


## Trục chân -> đầu lấy từ xương lúc cáo đã nằm; thiếu xương thì dùng chiều đứng
func _measure_body() -> void:
	var feet := visual.global_position if visual else Vector3.ZERO
	var head := feet + Vector3.UP
	var skeleton := _find_skeleton()
	if skeleton:
		var foot_sum := Vector3.ZERO
		var count := 0
		for bone_name in data.foot_bones:
			var index := skeleton.find_bone(bone_name)
			if index >= 0:
				foot_sum += skeleton.to_global(skeleton.get_bone_global_pose(index).origin)
				count += 1
		var head_index := skeleton.find_bone(data.head_bone)
		if count > 0 and head_index >= 0:
			feet = foot_sum / float(count)
			head = skeleton.to_global(skeleton.get_bone_global_pose(head_index).origin)
	var span := head - feet
	if span.length() < 0.05:
		span = Vector3.UP
	_axis = span.normalized()
	_origin = feet - _axis * data.body_margin
	_length = span.length() + data.body_margin * 2.0


func _find_skeleton() -> Skeleton3D:
	if is_instance_valid(_skeleton):
		return _skeleton
	if visual:
		var found := visual.find_children("*", "Skeleton3D", true, false)
		if not found.is_empty():
			_skeleton = found[0] as Skeleton3D
	return _skeleton


func _collect_materials() -> void:
	_materials.clear()
	for mesh in _meshes():
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_surface_override_material(surface) as ShaderMaterial
			if material and material.shader and not _materials.has(material) and _has_dissolve(material.shader):
				_materials.append(material)


func _meshes() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if visual:
		for node in visual.find_children("*", "MeshInstance3D", true, false):
			result.append(node as MeshInstance3D)
	return result


func _has_dissolve(shader: Shader) -> bool:
	for uniform: Dictionary in shader.get_shader_uniform_list():
		if uniform.get("name") == String(DISSOLVE_PARAM):
			return true
	return false


func _apply_particle_colors() -> void:
	if data.particle_colors.is_empty():
		return
	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var step := 1.0 / float(data.particle_colors.size())
	var offsets := PackedFloat32Array()
	for index in data.particle_colors.size():
		offsets.append(step * index)
	gradient.offsets = offsets
	gradient.colors = data.particle_colors
	_particles.color_initial_ramp = gradient


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
