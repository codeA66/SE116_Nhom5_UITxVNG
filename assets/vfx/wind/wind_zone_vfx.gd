@tool
class_name WindZoneVfx
extends Node3D
## Hình ảnh của WindZone (node cha): nét gió sắc, nét cuộn, lá và hạt bay, hơi mờ, dấu trên mặt đất.
## Mọi chuyển động tính trên GPU theo TIME. Vùng không pulse không chạy script mỗi frame.
## Vùng có pulse chỉ đẩy pha gió vào shader khi đang trên màn hình và còn gió chạy trong vùng.

const DEFAULT_STYLE: WindVfxStyle = preload("res://assets/vfx/wind/wind_vfx_default.tres")
const BRUSH_SHADER: Shader = preload("res://assets/shaders/wind_brush.gdshader")
const LEAF_SHADER: Shader = preload("res://assets/shaders/wind_leaf.gdshader")
const DUST_SHADER: Shader = preload("res://assets/shaders/wind_dust.gdshader")
const GROUND_SHADER: Shader = preload("res://assets/shaders/wind_zone.gdshader")
## Hộp bao rộng thêm (m): nét cuộn và phễu loe ra ngoài vùng một chút, tránh bị camera cắt mất
const BOUNDS_MARGIN := 2.0
## Dò mặt đất xa hơn đáy vùng bấy nhiêu mét
const GROUND_PROBE_EXTRA := 3.0
## Seed khác nhau cho từng lớp để không trùng hoa văn
const STROKE_SEED := 11
const MOTE_SEED := 23
const MIST_SEED := 37
## Cột gió: style.updraft_strokes ứng với tiết diện chuẩn này (m², cột 4x4); to hơn thì thêm nét theo diện tích
const UPDRAFT_REFERENCE_AREA := 16.0
## Giới hạn số nét cột gió để cột rất to không làm nặng máy
const UPDRAFT_MAX_STROKES := 72
const UPDRAFT_MIN_STROKES := 4

## Tắt để editor không vẽ hiệu ứng (đỡ rối khi dựng map)
@export var preview_enabled: bool = true:
	set(value):
		preview_enabled = value
		if is_node_ready():
			_apply_visibility()

var style: WindVfxStyle

var _zone: WindZone
var _vertical: bool = false
var _on_screen: bool = true
var _ground_found: bool = false
var _refresh_pending: bool = false
var _stroke_material: ShaderMaterial
var _mote_material: ShaderMaterial
var _mist_material: ShaderMaterial
var _ground_material: ShaderMaterial
var _flow_materials: Array[ShaderMaterial] = []
var _ground_query: PhysicsRayQueryParameters3D

@onready var _strokes: MultiMeshInstance3D = $Strokes
@onready var _motes: MultiMeshInstance3D = $Motes
@onready var _mist: MultiMeshInstance3D = $Mist
@onready var _ground: MeshInstance3D = $Ground
@onready var _notifier: VisibleOnScreenNotifier3D = $ScreenNotifier


func _ready() -> void:
	set_process(false)
	_zone = get_parent() as WindZone
	if _zone == null:
		push_error("%s phải là con của WindZone" % get_path())
		return
	_stroke_material = _new_material(BRUSH_SHADER)
	_mote_material = _new_material(LEAF_SHADER)
	_mist_material = _new_material(DUST_SHADER)
	_ground_material = _new_material(GROUND_SHADER)
	_flow_materials = [_stroke_material, _mote_material, _mist_material, _ground_material]
	_strokes.material_override = _stroke_material
	_motes.material_override = _mote_material
	_mist.material_override = _mist_material
	_ground.material_override = _ground_material
	_ground.mesh = WindVfxGeometry.plane()
	# Dấu mặt đất luôn nằm ngang theo thế giới dù vùng xoay thế nào
	_ground.top_level = true
	_ground_query = PhysicsRayQueryParameters3D.new()
	_ground_query.collision_mask = 1
	_zone.active_changed.connect(_on_flow_changed.unbind(1))
	_zone.warning_changed.connect(_on_flow_changed.unbind(1))
	_zone.configuration_changed.connect(_queue_refresh)
	_notifier.screen_entered.connect(_on_screen_changed.bind(true))
	_notifier.screen_exited.connect(_on_screen_changed.bind(false))
	_refresh()


func _exit_tree() -> void:
	if style and style.changed.is_connected(_queue_refresh):
		style.changed.disconnect(_queue_refresh)


func _process(_delta: float) -> void:
	_push_flow_state()
	if not _zone.active and not _zone.warning and not _zone.has_flow_in_transit():
		# Gió đã ra hết khỏi vùng: ẩn và ngủ tới khi pulse đổi (signal đánh thức lại)
		_set_flow_layers_visible(false)
		set_process(false)


func _queue_refresh() -> void:
	if _refresh_pending or not is_node_ready():
		return
	_refresh_pending = true
	_refresh.call_deferred()


func _refresh() -> void:
	_refresh_pending = false
	if _zone == null or not is_inside_tree():
		return
	if _zone.data == null:
		visible = false
		_ground.visible = false
		set_process(false)
		return
	_use_style(_zone.data.vfx_style if _zone.data.vfx_style else DEFAULT_STYLE)
	_vertical = _zone.is_vertical()
	var size := _zone.size
	_rebuild_instances(size)
	_apply_bounds(size)
	_apply_shared_uniforms(size)
	_apply_stroke_uniforms(size)
	_apply_mote_uniforms()
	_apply_mist_uniforms(size)
	_apply_ground(size)
	_apply_visibility()


func _use_style(next_style: WindVfxStyle) -> void:
	if style == next_style:
		return
	if style and style.changed.is_connected(_queue_refresh):
		style.changed.disconnect(_queue_refresh)
	style = next_style
	style.changed.connect(_queue_refresh)


## Dựng lại MultiMesh chỉ khi số lượng đổi (kéo vùng trong editor không cấp phát lại mỗi lần)
func _rebuild_instances(size: Vector3) -> void:
	var stroke_count: int
	if _vertical:
		var area_ratio := size.x * size.y / UPDRAFT_REFERENCE_AREA
		stroke_count = clampi(roundi(style.updraft_strokes * area_ratio), UPDRAFT_MIN_STROKES, UPDRAFT_MAX_STROKES)
	else:
		# Gió mạnh dày nét hơn: số nét tăng theo căn bậc hai sức gió để không rối
		stroke_count = clampi(ceili(size.x * size.z * style.gust_stroke_density * sqrt(_strength_scale())), 1, style.gust_max_strokes)
	var mote_count := clampi(ceili(size.x * size.y * size.z * _zone.data.particle_density * style.mote_density_ratio), 0, style.max_motes)
	_ensure_multimesh(_strokes, WindVfxGeometry.strip(), stroke_count, STROKE_SEED)
	_ensure_multimesh(_motes, WindVfxGeometry.quad(), mote_count, MOTE_SEED)
	_ensure_multimesh(_mist, WindVfxGeometry.quad(), style.mist_count, MIST_SEED)


func _ensure_multimesh(instance: MultiMeshInstance3D, mesh: Mesh, count: int, seed_value: int) -> void:
	if instance.multimesh and instance.multimesh.instance_count == count and instance.multimesh.mesh == mesh:
		return
	instance.multimesh = WindVfxGeometry.build_multimesh(mesh, count, seed_value + hash(_zone.name))


func _apply_bounds(size: Vector3) -> void:
	var margin := Vector3.ONE * BOUNDS_MARGIN
	var bounds := AABB(-size * 0.5 - margin, size + margin * 2.0)
	for instance: GeometryInstance3D in [_strokes, _motes, _mist]:
		instance.custom_aabb = bounds
	_notifier.aabb = bounds


func _apply_shared_uniforms(size: Vector3) -> void:
	var data := _zone.data
	# Trong editor pulse không chạy: xem trước luôn như gió đang bật
	var pulse := data.pulse_enabled and not Engine.is_editor_hint()
	for material in _flow_materials:
		material.set_shader_parameter(&"pulse_enabled", pulse)
		material.set_shader_parameter(&"on_time", data.on_time)
		material.set_shader_parameter(&"off_time", data.off_time)
		material.set_shader_parameter(&"sweep_time", data.sweep_time)
		material.set_shader_parameter(&"sweep_exponent", data.sweep_exponent)
	for material in [_stroke_material, _mote_material]:
		material.set_shader_parameter(&"zone_size", size)
		material.set_shader_parameter(&"updraft", _vertical)
	_push_flow_state()


func _apply_stroke_uniforms(size: Vector3) -> void:
	var m := _stroke_material
	var tint := _zone.data.updraft_color if _vertical else _zone.data.particle_color
	m.set_shader_parameter(&"core_color", tint)
	m.set_shader_parameter(&"edge_color", style.edge_color)
	m.set_shader_parameter(&"opacity", style.stroke_opacity)
	if _vertical:
		m.set_shader_parameter(&"width", style.updraft_width)
		m.set_shader_parameter(&"stroke_length", style.updraft_stroke_length)
		m.set_shader_parameter(&"travel_speed", style.updraft_rise_speed)
	else:
		m.set_shader_parameter(&"width", style.gust_width * _width_scale())
		m.set_shader_parameter(&"stroke_length", style.gust_stroke_length / maxf(size.z, 0.01))
		m.set_shader_parameter(&"travel_speed", style.gust_travel_speed * _strength_scale())
	m.set_shader_parameter(&"wave_amplitude", style.blocking_wave if _is_blocking() else style.gust_wave)
	m.set_shader_parameter(&"curl_fraction", style.blocking_curl_fraction if _is_blocking() else style.gust_curl_fraction)
	m.set_shader_parameter(&"curl_radius", style.gust_curl_radius)
	m.set_shader_parameter(&"curl_turns", style.gust_curl_turns)
	m.set_shader_parameter(&"funnel_bottom", style.funnel_bottom)
	m.set_shader_parameter(&"funnel_top", style.funnel_top)
	m.set_shader_parameter(&"twist_turns", style.updraft_twist_turns)
	m.set_shader_parameter(&"spin_speed", style.updraft_spin_speed)
	m.set_shader_parameter(&"rise_acceleration", style.rise_acceleration)


func _apply_mote_uniforms() -> void:
	var m := _mote_material
	m.set_shader_parameter(&"leaf_fraction", style.leaf_fraction)
	m.set_shader_parameter(&"leaf_color", style.leaf_color)
	m.set_shader_parameter(&"leaf_color_alt", style.leaf_color_alt)
	m.set_shader_parameter(&"vein_color", style.vein_color)
	m.set_shader_parameter(&"speck_color", style.speck_color)
	m.set_shader_parameter(&"leaf_size", style.leaf_size)
	m.set_shader_parameter(&"speck_size", style.speck_size)
	m.set_shader_parameter(&"travel_speed", style.mote_speed * (1.0 if _vertical else _strength_scale()))
	m.set_shader_parameter(&"flutter", style.mote_flutter)
	m.set_shader_parameter(&"tumble_speed", style.leaf_tumble_speed * (style.blocking_tumble_multiplier if _is_blocking() else 1.0))
	m.set_shader_parameter(&"funnel_bottom", style.funnel_bottom)
	m.set_shader_parameter(&"funnel_top", style.funnel_top)
	m.set_shader_parameter(&"spin_speed", style.updraft_spin_speed)


func _apply_mist_uniforms(size: Vector3) -> void:
	var m := _mist_material
	# Cột gió: hơi mờ dồn ở chân cột (1/3 dưới); gió ngang: trải dọc cả luồng
	var box := Vector3(size.x, size.y, size.z * (0.35 if _vertical else 1.0))
	m.set_shader_parameter(&"box_size", box)
	m.set_shader_parameter(&"tint", style.mist_color)
	m.set_shader_parameter(&"opacity", style.mist_opacity)
	m.set_shader_parameter(&"puff_size", style.mist_size)
	m.set_shader_parameter(&"drift_speed", style.mist_speed * (1.0 if _vertical else _strength_scale()))
	_mist.position = Vector3(0.0, 0.0, size.z * 0.325) if _vertical else Vector3.ZERO


func _apply_ground(size: Vector3) -> void:
	# Cột gió không có dấu dưới chân (chân cột sẽ do model 3D của map đảm nhận)
	if _vertical:
		_ground_found = false
		return
	var m := _ground_material
	m.set_shader_parameter(&"tint", style.ground_color)
	var ground_opacity := style.blocking_ground_opacity if _is_blocking() else style.ground_opacity
	m.set_shader_parameter(&"opacity", ground_opacity)
	m.set_shader_parameter(&"arrows", _is_blocking())
	m.set_shader_parameter(&"fill_opacity", style.ground_fill_opacity)
	m.set_shader_parameter(&"zone_length", size.z)
	m.set_shader_parameter(&"zone_width", size.x)
	m.set_shader_parameter(&"line_width", style.ground_line_width)
	m.set_shader_parameter(&"dash_speed", style.ground_dash_speed * _strength_scale())
	var rows := size.x * style.ground_rows_per_meter / (style.arrow_row_span if _is_blocking() else 1.0)
	m.set_shader_parameter(&"row_count", maxf(roundf(rows), 1.0))
	var center := _zone.global_position
	var scale_xz := Vector2(size.x, size.z)
	var forward := _zone.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if not forward.is_zero_approx() else Vector3.BACK
	var floor_y := _find_floor_y(center, size)
	_ground_found = not is_nan(floor_y)
	if not _ground_found:
		return
	var ground_basis := Basis.looking_at(-forward, Vector3.UP) * Basis.from_scale(Vector3(scale_xz.x, 1.0, scale_xz.y))
	_ground.global_transform = Transform3D(ground_basis, Vector3(center.x, floor_y + style.ground_offset, center.z))


## Độ cao mặt đất dưới vùng; NAN nếu không có đất. Editor không dò vật lý, lấy đáy vùng
func _find_floor_y(center: Vector3, size: Vector3) -> float:
	var bottom := _zone.to_global(Vector3(0.0, -size.y * 0.5, 0.0)).y
	if Engine.is_editor_hint() or not is_inside_tree():
		return bottom
	_ground_query.from = Vector3(center.x, center.y + 0.5, center.z)
	_ground_query.to = Vector3(center.x, bottom - GROUND_PROBE_EXTRA, center.z)
	var hit := get_world_3d().direct_space_state.intersect_ray(_ground_query)
	return (hit.position as Vector3).y if not hit.is_empty() else NAN


func _apply_visibility() -> void:
	if _zone == null or _zone.data == null:
		return
	var allowed := not Engine.is_editor_hint() or preview_enabled
	visible = allowed
	_ground.visible = allowed and _ground_found
	var flowing := _zone.active or _zone.warning or _zone.has_flow_in_transit()
	_set_flow_layers_visible(allowed and flowing)
	_push_flow_state()
	var needs_update := allowed and _zone.data.pulse_enabled and not Engine.is_editor_hint() and _on_screen and flowing
	set_process(needs_update)


func _push_flow_state() -> void:
	if _zone == null or _zone.data == null:
		return
	var active := 1.0 if _zone.active or Engine.is_editor_hint() else 0.0
	var warning := 1.0 if _zone.warning else 0.0
	for material in _flow_materials:
		material.set_shader_parameter(&"flow_active", active)
		material.set_shader_parameter(&"cycle_time", _zone.get_flow_phase())
		material.set_shader_parameter(&"flow_age", _zone.flow_age)
	_ground_material.set_shader_parameter(&"warning", warning)


func _set_flow_layers_visible(value: bool) -> void:
	_strokes.visible = value
	_motes.visible = value
	_mist.visible = value


func _new_material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _on_flow_changed() -> void:
	_apply_visibility()


func _on_screen_changed(on_screen: bool) -> void:
	_on_screen = on_screen
	_apply_visibility()


## Gió ngang đánh dấu chặn người chơi (cột gió luôn dùng kiểu thường)
func _is_blocking() -> bool:
	return not _vertical and _zone.data.blocks_player


## Tỉ lệ sức gió so với sức gió gốc của style: nét và hạt chạy nhanh hơn theo đúng tỉ lệ này
func _strength_scale() -> float:
	return clampf(_zone.data.strength / maxf(style.reference_strength, 0.01), 0.5, style.max_strength_scale)


func _width_scale() -> float:
	return maxf(1.0 + log(_strength_scale()) / log(2.0) * style.width_per_strength, 0.5)
