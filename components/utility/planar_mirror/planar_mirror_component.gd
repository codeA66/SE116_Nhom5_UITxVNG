class_name PlanarMirrorComponent
extends Node3D
## Component phản chiếu phẳng thời gian thực (SubViewport + Camera3D ảo) gắn vào mặt gương.
## Hỗ trợ phản chiếu 1 mặt hoặc 2 mặt theo trục -Z/+Z của node cha (Pivot).
##
## GHI CHÚ TỐI ƯU: Hiện dùng real-time planar reflection để phản chiếu thật nhân vật, tia lửa và phòng.
## Trong tương lai, nếu cần tối ưu hiệu năng hơn trên máy yếu hoặc nhiều gương cùng lúc,
## có thể thêm chế độ phản chiếu giả lập (fake/stylized reflection bằng cubemap/shader) vào PlanarMirrorConfig.

const MIRROR_SHADER: Shader = preload("res://assets/shaders/environment/props/planar_mirror.gdshader")
const MIN_VIEWPORT_WIDTH: int = 32
const MIN_VIEWPORT_HEIGHT: int = 16
const MIN_NEAR_PLANE: float = 0.05
const MIN_DIRECTION_LEN_SQ: float = 0.00001

@export var config: PlanarMirrorConfig
@export var target_mesh: MeshInstance3D
@export var use_screen_notifier: bool = true

var _active: bool = true
var _on_screen: bool = true
var _frame_counter: int = 0
var _sub_viewport: SubViewport
var _mirror_camera: Camera3D
var _notifier: VisibleOnScreenNotifier3D
var _shader_material: ShaderMaterial


func _ready() -> void:
	if config == null:
		config = PlanarMirrorConfig.new()
	_setup_viewport()
	_setup_material()
	_setup_screen_notifier()
	_refresh_processing()


func _process(_delta: float) -> void:
	if not _should_update():
		_disable_viewport_update()
		return
	var viewport: Viewport = get_viewport()
	if viewport == null:
		_disable_viewport_update()
		return
	var main_camera: Camera3D = viewport.get_camera_3d()
	if main_camera == null:
		_disable_viewport_update()
		return
	var step: int = maxi(config.update_every_n_frames, 1)
	if step > 1:
		_frame_counter = (_frame_counter + 1) % step
		if _frame_counter != 0:
			return
	var visible_size: Vector2i = Vector2i(viewport.get_visible_rect().size)
	sync_with_camera(main_camera, visible_size)


## Bật/tắt phản chiếu (ví dụ khi cụm gương hạ xuống ẩn đi).
func set_active(active: bool) -> void:
	_active = active
	_refresh_processing()


func is_active() -> bool:
	return _active


func is_rendering_active() -> bool:
	if _sub_viewport == null:
		return false
	return _sub_viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED


func get_sub_viewport() -> SubViewport:
	return _sub_viewport


func get_mirror_camera() -> Camera3D:
	return _mirror_camera


## Cập nhật ngay kích thước SubViewport và transform camera ảo đặt tại mặt trước gương.
func sync_with_camera(main_camera: Camera3D, viewport_size: Vector2i) -> bool:
	if main_camera == null or _sub_viewport == null or _mirror_camera == null:
		_disable_viewport_update()
		return false
	var target_size: Vector2i = compute_square_viewport_size(viewport_size, config.resolution_scale, config.max_resolution)
	if _sub_viewport.size != target_size:
		_sub_viewport.size = target_size

	var plane_origin: Vector3 = global_position
	var plane_normal: Vector3 = -global_basis.z.normalized()
	var reflected: Dictionary = compute_reflected_transform(
		main_camera.global_transform,
		plane_origin,
		plane_normal,
		config.double_sided,
		config.surface_offset,
		config.pitch_flatten
	)
	if not bool(reflected.get("valid", false)):
		_disable_viewport_update()
		return false

	var refl_xform: Transform3D = reflected["transform"]
	_mirror_camera.global_transform = refl_xform
	_mirror_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_mirror_camera.fov = config.reflection_fov
	_mirror_camera.far = main_camera.far
	_mirror_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_mirror_camera.h_offset = 0.0
	_mirror_camera.v_offset = 0.0
	_mirror_camera.near = maxf(main_camera.near, MIN_NEAR_PLANE)
	_apply_cull_mask(main_camera.cull_mask)

	_sub_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ONCE if config.update_every_n_frames > 1 else SubViewport.UPDATE_ALWAYS
	)
	return true


## Tính kích thước SubViewport hình vuông tập trung điểm ảnh cho mặt đĩa gương.
static func compute_square_viewport_size(main_size: Vector2i, resolution_scale: float, max_resolution: int) -> Vector2i:
	var min_side: int = maxi(mini(main_size.x, main_size.y), 1)
	var scale_clamped: float = clampf(resolution_scale, 0.05, 1.0)
	var side: int = maxi(int(round(float(min_side) * scale_clamped)), MIN_VIEWPORT_WIDTH)
	if max_resolution > 0:
		side = mini(side, maxi(max_resolution, MIN_VIEWPORT_WIDTH))
	return Vector2i(side, side)


## Tính kích thước SubViewport theo tỉ lệ màn hình chính và giới hạn tối đa.
static func compute_viewport_size(main_size: Vector2i, resolution_scale: float, max_resolution: int) -> Vector2i:
	var safe_main: Vector2i = Vector2i(maxi(main_size.x, 1), maxi(main_size.y, 1))
	var aspect: float = float(safe_main.x) / float(safe_main.y)
	var scale_clamped: float = clampf(resolution_scale, 0.05, 1.0)
	var width: int = maxi(int(round(float(safe_main.x) * scale_clamped)), MIN_VIEWPORT_WIDTH)
	var height: int = maxi(int(round(float(width) / aspect)), MIN_VIEWPORT_HEIGHT)

	if max_resolution > 0:
		var cap_w: int = maxi(max_resolution, MIN_VIEWPORT_WIDTH)
		var cap_h: int = maxi(max_resolution, MIN_VIEWPORT_HEIGHT)
		if width > cap_w:
			width = cap_w
			height = maxi(int(round(float(width) / aspect)), MIN_VIEWPORT_HEIGHT)
		if height > cap_h:
			height = cap_h
			width = maxi(int(round(float(height) * aspect)), MIN_VIEWPORT_WIDTH)
	return Vector2i(width, height)


## Đặt camera ảo tại bề mặt gương nhìn ra phía trước theo tia phản xạ, giữ basis tay phải (det > 0).
static func compute_reflected_transform(
	camera_transform: Transform3D,
	plane_origin: Vector3,
	plane_normal: Vector3,
	double_sided: bool,
	surface_offset: float = 0.1,
	pitch_flatten: float = 0.65
) -> Dictionary:
	var n: Vector3 = plane_normal.normalized()
	if n.length_squared() < MIN_DIRECTION_LEN_SQ:
		return {"valid": false, "transform": Transform3D.IDENTITY, "front_normal": Vector3.FORWARD}

	var cam_pos: Vector3 = camera_transform.origin
	var signed_dist: float = (cam_pos - plane_origin).dot(n)
	if not double_sided and signed_dist <= 0.0:
		return {"valid": false, "transform": Transform3D.IDENTITY, "front_normal": n}

	var front_normal: Vector3 = n if signed_dist >= 0.0 else -n
	var to_mirror: Vector3 = plane_origin - cam_pos
	var incident: Vector3 = to_mirror.normalized() if to_mirror.length_squared() >= MIN_DIRECTION_LEN_SQ else -front_normal
	var refl_dir: Vector3 = (incident - 2.0 * incident.dot(front_normal) * front_normal).normalized()
	if refl_dir.dot(front_normal) < 0.0:
		refl_dir = front_normal

	var flatten: float = clampf(pitch_flatten, 0.0, 1.0)
	if flatten > 0.0:
		var flattened: Vector3 = Vector3(refl_dir.x, refl_dir.y * (1.0 - flatten), refl_dir.z)
		if flattened.length_squared() >= MIN_DIRECTION_LEN_SQ:
			refl_dir = flattened.normalized()

	var refl_pos: Vector3 = plane_origin + front_normal * maxf(surface_offset, 0.01)
	var up_hint: Vector3 = Vector3.UP if absf(refl_dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var refl_basis: Basis = Basis.looking_at(refl_dir, up_hint)
	return {
		"valid": true,
		"transform": Transform3D(refl_basis, refl_pos),
		"front_normal": front_normal,
	}


## Tính near plane đủ lớn để hạn chế vật sau lưng gương che khuất, nhưng không cắt lẹm mặt đĩa gương.
static func compute_safe_near(
	camera_transform: Transform3D,
	plane_origin: Vector3,
	plane_basis: Basis,
	radius: float,
	min_near: float,
	max_far: float,
	margin: float
) -> float:
	var cam_forward: Vector3 = -camera_transform.basis.z.normalized()
	var plane_normal: Vector3 = plane_basis.z.normalized()
	var center_dist: float = (plane_origin - camera_transform.origin).dot(cam_forward)
	var sin_tilt: float = sqrt(maxf(0.0, 1.0 - pow(absf(plane_normal.dot(cam_forward)), 2.0)))
	var safe_radius: float = maxf(radius, 0.0)
	var closest_dist: float = center_dist - safe_radius * sin_tilt - maxf(margin, 0.0)
	var upper_bound: float = maxf(min_near, max_far * 0.5)
	return clampf(closest_dist, maxf(min_near, MIN_NEAR_PLANE), upper_bound)


func _setup_viewport() -> void:
	_sub_viewport = SubViewport.new()
	_sub_viewport.name = &"MirrorViewport"
	_sub_viewport.own_world_3d = false
	_sub_viewport.transparent_bg = false
	_sub_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_sub_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_sub_viewport.use_occlusion_culling = false
	if config.disable_shadows_in_reflection:
		_sub_viewport.positional_shadow_atlas_size = 0
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_sub_viewport)

	_mirror_camera = Camera3D.new()
	_mirror_camera.name = &"MirrorCamera"
	_mirror_camera.current = true
	_mirror_camera.doppler_tracking = Camera3D.DOPPLER_TRACKING_DISABLED
	_sub_viewport.add_child(_mirror_camera)


func _setup_material() -> void:
	if target_mesh == null:
		return
	var layer_index: int = clampi(config.mirror_visual_layer, 1, 20)
	# Đặt mesh CHỈ thuộc layer riêng để camera phản chiếu (loại layer này) không tự render lại chính mặt gương.
	target_mesh.layers = 1 << (layer_index - 1)

	# Mỗi gương có ViewportTexture riêng nên phải tạo ShaderMaterial riêng cho từng instance.
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = MIRROR_SHADER
	_shader_material.set_shader_parameter(&"reflection_tex", _sub_viewport.get_texture())
	_shader_material.set_shader_parameter(&"mirror_local_axis", config.mirror_local_axis)
	_shader_material.set_shader_parameter(&"mirror_radius", config.mirror_radius)
	_shader_material.set_shader_parameter(&"reflection_strength", config.reflection_strength)
	_shader_material.set_shader_parameter(&"tint_color", config.tint_color)
	_shader_material.set_shader_parameter(&"base_color", config.base_color)
	_shader_material.set_shader_parameter(&"edge_color", config.edge_color)
	_shader_material.set_shader_parameter(&"fresnel_power", config.fresnel_power)
	_shader_material.set_shader_parameter(&"fresnel_boost", config.fresnel_boost)
	_shader_material.set_shader_parameter(&"metallic_value", config.metallic)
	_shader_material.set_shader_parameter(&"roughness_value", config.roughness)
	_shader_material.set_shader_parameter(&"flip_y", config.flip_y)
	target_mesh.material_override = _shader_material


func _setup_screen_notifier() -> void:
	if not use_screen_notifier:
		_on_screen = true
		return
	var r: float = maxf(config.mirror_radius, 0.2)
	_notifier = VisibleOnScreenNotifier3D.new()
	_notifier.name = &"ScreenNotifier"
	_notifier.aabb = AABB(Vector3(-r, -r, -0.25), Vector3(r * 2.0, r * 2.0, 0.5))
	_notifier.screen_entered.connect(_on_screen_entered)
	_notifier.screen_exited.connect(_on_screen_exited)
	add_child(_notifier)
	_on_screen = true


func _on_screen_entered() -> void:
	_on_screen = true
	_refresh_processing()


func _on_screen_exited() -> void:
	_on_screen = false
	_refresh_processing()


func _should_update() -> bool:
	return _active and _on_screen and is_visible_in_tree()


func _refresh_processing() -> void:
	var enabled: bool = _active and _on_screen
	set_process(enabled)
	if not enabled:
		_disable_viewport_update()


func _disable_viewport_update() -> void:
	if _sub_viewport != null and _sub_viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		_sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _apply_cull_mask(main_cull_mask: int) -> void:
	var layer_index: int = clampi(config.mirror_visual_layer, 1, 20)
	var mask: int = main_cull_mask & ~(1 << (layer_index - 1))
	_mirror_camera.cull_mask = mask
