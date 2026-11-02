class_name BurningVfx
extends Node3D
## DONE 2026-10-31: một hệ CPU, ngọn có tiết diện 3D bám vỏ collider và có giới hạn chiều cao.
## NOT DONE: chưa được duyệt mỹ thuật; chưa đo bản export/cache sạch.
## NOTES: đối chứng 32 quái MX230/Compatibility: CPU 57.2, một hệ GPU 44.6 FPS.
@export_group("Wiring")
@export var burnable: BurnableComponent
@export_group("Shape")
@export var flame_height_ratio: float = 0.85
@export var shell_width_ratio: float = 1.18
@export var shoulder_ratio: float = 0.0
@export var missing_shape_size: Vector3 = Vector3.ONE
@export_group("Status Silhouette")
@export var crown_height: float = 0.68
@export var crown_width: float = 0.62
@export var crown_clearance: float = -0.04
@export var tick_expansion: float = 0.38
@export_group("Timing")
@export var fade_time: float = 0.22
@export var pulse_time: float = 0.22
@export var prepare_frames: int = 3
@export_group("Particles")
@export_range(1, 18, 1) var flame_count: int = 6
@export_range(0, 6, 1) var ember_count: int = 3
@export var ember_speed: float = 1.3
@export var particle_size_range: Vector2 = Vector2(0.32, 0.52)
@export var flame_rise_range: Vector2 = Vector2(0.2, 0.4)
@export var max_flame_height: float = 0.36
@export_range(0.1, 1.0, 0.01) var min_flame_scale_ratio: float = 0.65
@export var max_rise_speed: float = 0.65
## Giữ export cũ để scene đã cấu hình không mất thuộc tính; không tạo đèn cho từng mục tiêu.
@export var light_energy: float = 0.0
var _visual_root: Node3D
var _surface_nodes: Array[MeshInstance3D] = []
var _surface_points: PackedVector3Array = PackedVector3Array()
var _emission_points: PackedVector3Array = PackedVector3Array()
var _crown_source: MeshInstance3D
var _crown_point: Vector3
var _attachment_clock: float = 0.0
var _has_visible_surface: bool = true
@export var attachment_interval: float = 0.10
var _crown: MeshInstance3D
var _crown_material: ShaderMaterial
var _lit: bool = false
var _fade: float = 0.0
var _pulse: float = 0.0
@onready var _flames: CPUParticles3D = $Flames
@onready var _material: ShaderMaterial = $Flames.mesh.surface_get_material(0) as ShaderMaterial

## Nối signal sau khi collider của BurnableComponent sẵn sàng.
func _ready() -> void:
	set_process(false)
	_flames.emitting = false
	_flames.hide()
	_build_flame_volume()
	_crown = MeshInstance3D.new()
	_crown.name = "StatusCrown"
	_crown.mesh = _flames.mesh
	_crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_crown_material = _material.duplicate() as ShaderMaterial
	_crown_material.set_shader_parameter(&"status_crown", true)
	_crown_material.set_shader_parameter(&"burning_volume", true)
	_crown_material.set_shader_parameter(&"burning_single_system", false)
	_crown_material.set_shader_parameter(&"tick_expansion", tick_expansion)
	_crown_material.set_shader_parameter(&"opacity", 0.0)
	_crown.material_override = _crown_material
	add_child(_crown)
	_crown.hide()
	var flames: int = clampi(flame_count, 1, 18)
	_flames.amount = flames + clampi(ember_count, 0, 6)
	_material.set_shader_parameter(&"burning_flame_count", flames)
	_material.set_shader_parameter(&"burning_single_system", true)
	_material.set_shader_parameter(&"burning_volume", true)
	_material.set_shader_parameter(&"opacity", 0.0)
	if burnable == null:
		return
	if not burnable.is_node_ready():
		await burnable.ready
	_cache_visual_attachment()
	_fit_target()
	burnable.ignited.connect(_on_ignited)
	burnable.extinguished.connect(_on_extinguished)
	burnable.burn_tick.connect(_on_tick)
	if DisplayServer.get_name() != "headless":
		await _prepare()
	if burnable.is_burning():
		_on_ignited()

## Chỉ chạy trong pulse hoặc đoạn tàn; node particle native xử lý chuyển động hạt.
func _process(delta: float) -> void:
	if is_instance_valid(_visual_root):
		global_transform = _visual_root.global_transform
		visible = _visual_root.is_visible_in_tree() and _has_visible_surface
		if is_instance_valid(_crown_source):
			_crown.global_position = _crown_source.global_transform * _crown_point + Vector3.UP * crown_clearance
		_attachment_clock -= delta
		if _attachment_clock <= 0.0 or (not _has_visible_surface and _visual_root.is_visible_in_tree()):
			_attachment_clock = maxf(attachment_interval, 0.02)
			_refresh_surface_points()
	_pulse = maxf(0.0, _pulse - delta)
	var pulse: float = _pulse / maxf(pulse_time, 0.001)
	_material.set_shader_parameter(&"pulse", pulse)
	_crown_material.set_shader_parameter(&"pulse", pulse)
	if not _lit:
		_fade = maxf(0.0, _fade - delta)
		var opacity: float = _fade / maxf(fade_time, 0.001)
		_material.set_shader_parameter(&"opacity", opacity)
		_crown_material.set_shader_parameter(&"opacity", opacity)
		if _fade <= 0.0:
			_crown.hide()
			_flames.hide()
	if _pulse <= 0.0 and ((_lit and _visual_root == null) or (not _lit and _fade <= 0.0)):
		set_process(false)

## Dùng shape thật và transform của nó để hỗ trợ cả collider lệch tâm, to nhỏ khác nhau.
func _fit_target() -> void:
	var shape: CollisionShape3D = burnable.match_shape_of
	if shape == null:
		for child: Node in burnable.get_children():
			if child is CollisionShape3D:
				shape = child as CollisionShape3D
				break
	var bounds: AABB = AABB(-missing_shape_size * 0.5, missing_shape_size)
	if shape and shape.shape:
		bounds = (global_transform.affine_inverse() * shape.global_transform) * shape.shape.get_debug_mesh().get_aabb()
	var height: float = maxf(bounds.size.y * flame_height_ratio, 0.01)
	_flames.position = bounds.get_center() + Vector3.UP * bounds.size.y * shoulder_ratio
	_flames.emission_box_extents = Vector3(bounds.size.x * 0.5 * shell_width_ratio, bounds.size.y * 0.22, bounds.size.z * 0.5 * shell_width_ratio)
	# Bám quanh vỏ collider thay vì phát hạt bên trong thân khiến lửa bị che.
	var points: PackedVector3Array = PackedVector3Array()
	for band: int in range(2):
		for side: int in range(6):
			var angle: float = float(side) / 6.0 * TAU + float(band) * 0.5
			points.append(Vector3(cos(angle) * bounds.size.x * 0.54, (float(band) - 0.5) * bounds.size.y * 0.4, sin(angle) * bounds.size.z * 0.54))
	_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	_flames.emission_points = points
	_flames.initial_velocity_min = minf(height * flame_rise_range.x, max_rise_speed)
	_flames.initial_velocity_max = minf(height * flame_rise_range.y, max_rise_speed)
	# Cỡ lửa theo bề ngang và có trần: quái cao không biến thành một đám cháy khổng lồ.
	var width: float = maxf(minf(bounds.size.x, bounds.size.z), 0.01)
	var mesh_height: float = _flames.mesh.get_aabb().size.y
	# Owner phóng lớn cũng không nhân chiều cao ngọn lửa vượt trần thế giới.
	var owner_scale: float = maxf(global_basis.x.length(), maxf(global_basis.y.length(), global_basis.z.length()))
	var world_height: float = minf(maxf(bounds.size.y * owner_scale * 0.4, 0.22), maxf(crown_height, 0.01))
	_crown.scale = Vector3(maxf(crown_width, 0.01), world_height / mesh_height, maxf(crown_width, 0.01)) / maxf(owner_scale, 0.01)
	_crown.position = Vector3(bounds.get_center().x, bounds.end.y + crown_clearance / maxf(owner_scale, 0.01), bounds.get_center().z)
	_crown_material.set_shader_parameter(&"phase", float(get_instance_id() % 100) * 0.13)
	var max_scale: float = maxf(max_flame_height, 0.01) / maxf(mesh_height * owner_scale, 0.01)
	_flames.scale_amount_min = minf(width * particle_size_range.x, max_scale * min_flame_scale_ratio)
	_flames.scale_amount_max = minf(width * particle_size_range.y, max_scale)
	_flames.visibility_aabb = AABB(-bounds.size * 2.0, bounds.size * 4.0)
	if not _surface_nodes.is_empty():
		_flames.position = Vector3.ZERO
		_refresh_surface_points()
		if is_instance_valid(_crown_source):
			_crown.global_position = _crown_source.global_transform * _crown_point + Vector3.UP * crown_clearance
	_material.set_shader_parameter(&"burning_ember_rise", ember_speed)
	_material.set_shader_parameter(&"phase", float(get_instance_id() % 100) * 0.13)

## Làm sáng một nhịp khi bắt cháy, không khởi động lại hạt khi chỉ làm mới thời gian.
func _on_ignited() -> void:
	if is_instance_valid(_visual_root):
		global_transform = _visual_root.global_transform
		visible = _visual_root.is_visible_in_tree() and _has_visible_surface
		_refresh_surface_points()
	_material.set_shader_parameter(&"prewarm_scale", 1.0)
	_flames.show()
	if not _lit:
		_flames.restart()
	_lit = true
	_crown.show()
	_crown_material.set_shader_parameter(&"opacity", 1.0)
	_flames.emitting = true
	_material.set_shader_parameter(&"opacity", 1.0)
	_pulse = pulse_time
	_crown_material.set_shader_parameter(&"pulse", 1.0)
	set_process(true)

## Tắt phát hạt, giữ đuôi lửa ngắn rồi trả node về trạng thái nghỉ.
func _on_extinguished() -> void:
	if not _lit:
		return
	_lit = false
	_flames.emitting = false
	_fade = fade_time
	set_process(true)

## Pulse chỉ mang tính hình ảnh, không thay đổi sát thương hoặc thời gian cháy.
func _on_tick(_damage_taken: int) -> void:
	if not _lit:
		return
	_pulse = pulse_time
	_crown_material.set_shader_parameter(&"pulse", 1.0)
	set_process(true)

## Compatibility cần vẽ thật; opacity rất nhỏ vẫn tạo lệnh vẽ để biên dịch trước.
func _prepare() -> void:
	if _lit:
		return
	_material.set_shader_parameter(&"prewarm_scale", 0.000001)
	_material.set_shader_parameter(&"opacity", 1.0)
	_flames.show()
	_flames.emitting = true
	for frame: int in range(prepare_frames):
		await RenderingServer.frame_post_draw
	if _lit:
		return
	_flames.emitting = false
	_flames.hide()
	_material.set_shader_parameter(&"prewarm_scale", 1.0)
	_material.set_shader_parameter(&"opacity", 0.0)



## Ngọn có tiết diện 3D, dựng một lần và dùng chung cho chín hạt, không thêm emitter.
func _build_flame_volume() -> void:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	const RINGS: int = 6
	const SIDES: int = 8
	for tongue: int in range(3):
		var base: int = vertices.size()
		var height: float = 1.35 if tongue == 0 else (0.90 if tongue == 1 else 0.72)
		var shift: Vector2 = Vector2.ZERO if tongue == 0 else Vector2(-0.22 if tongue == 1 else 0.22, 0.07)
		for ring: int in range(RINGS + 1):
			var h: float = float(ring) / RINGS
			var radius: float = maxf(0.004, sin(pow(h, 0.65) * PI) * (0.26 if tongue == 0 else 0.15))
			for side: int in range(SIDES + 1):
				var angle: float = float(side) / SIDES * TAU
				vertices.append(Vector3(cos(angle) * radius + h * h * 0.20 + shift.x, h * height, sin(angle) * radius + shift.y))
				normals.append(Vector3(cos(angle), 0.3, sin(angle)).normalized())
				uvs.append(Vector2(float(side) / SIDES, h))
		for ring: int in range(RINGS):
			for side: int in range(SIDES):
				var a: int = base + ring * (SIDES + 1) + side
				var b: int = a + SIDES + 1
				indices.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _material)
	_flames.mesh = mesh


## Chỉ quét mesh một lần. Không dùng hộp hurtbox để suy ra bề mặt model.
func _cache_visual_attachment() -> void:
	var host: Node = burnable.get_parent()
	_visual_root = host.get_node_or_null(^"Model/Visual") as Node3D
	if _visual_root == null:
		_visual_root = host.get_node_or_null(^"Visual") as Node3D
	if _visual_root == null:
		_visual_root = host as Node3D
	if _visual_root == null or _visual_root == self:
		_visual_root = null
		return
	var top: float = -INF
	for node: Node in _visual_root.find_children("*", "MeshInstance3D", true, false):
		var part: MeshInstance3D = node as MeshInstance3D
		if part.mesh == null or is_ancestor_of(part) or not _locally_visible_part(part):
			continue
		for surface: int in range(part.mesh.get_surface_count()):
			var arrays: Array = part.mesh.surface_get_arrays(surface)
			if arrays.is_empty():
				continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if vertices.is_empty():
				continue
			for vertex: Vector3 in vertices:
				var height: float = (_visual_root.global_transform.affine_inverse() * part.global_transform * vertex).y
				if height > top:
					top = height
					_crown_source = part
					_crown_point = vertex
			# Điểm thật trên mesh; không rải lên đường tròn ngoài khoảng trống.
			if _surface_nodes.size() < 48:
				_surface_nodes.append(part)
				_surface_points.append(vertices[0])
				_surface_nodes.append(part)
				# Chia lấy phần nguyên là cố ý: lấy đỉnh nằm giữa mảng
				@warning_ignore("integer_division")
				_surface_points.append(vertices[vertices.size() / 2])
	if _surface_nodes.is_empty():
		_visual_root = null
		return
	_emission_points.resize(_surface_nodes.size())
	global_transform = _visual_root.global_transform


## Cập nhật mảng đã giữ sẵn theo từng phần model, không quét scene hoặc dựng lại mesh lúc cháy.
func _refresh_surface_points() -> void:
	if _surface_nodes.is_empty():
		return
	var first_visible: int = -1
	for i: int in range(_surface_nodes.size()):
		if is_instance_valid(_surface_nodes[i]) and _surface_nodes[i].is_visible_in_tree():
			first_visible = i
			break
	_has_visible_surface = first_visible >= 0
	visible = _has_visible_surface
	if not _has_visible_surface:
		return
	var inverse: Transform3D = global_transform.affine_inverse()
	for i: int in range(_surface_nodes.size()):
		var index: int = i if is_instance_valid(_surface_nodes[i]) and _surface_nodes[i].is_visible_in_tree() else first_visible
		_emission_points[i] = inverse * _surface_nodes[index].global_transform * _surface_points[index]
	_flames.emission_points = _emission_points
	if _lit and is_instance_valid(_crown_source):
		_crown.visible = _crown_source.is_visible_in_tree()


## Vẫn ghi nhớ mesh khi cả model đang ẩn, nhưng bỏ phần trang trí vốn tắt sẵn trong rig.
func _locally_visible_part(part: MeshInstance3D) -> bool:
	var current: Node = part
	while current != null and current != _visual_root:
		if current is Node3D and not (current as Node3D).visible:
			return false
		current = current.get_parent()
	return true
