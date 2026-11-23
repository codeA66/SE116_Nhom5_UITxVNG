extends Node3D
## Giữ quyết định chọn vệt ở cùng chỗ để kiếm thường và kiếm ghép không vẽ trùng.

const SNAP_SLOT = preload("res://assets/vfx/shared/charms/song_tram/snap/slash_snap_slot.gd")
# Mesh có chừa mép ngoài cho quầng sáng mà không cần thêm dải hình học.
const MESH_RADII: Vector2 = Vector2(0.12, 1.42)
const MIN_RADIUS: float = 0.001

@export_group("Wiring")
@export var hitbox: HitboxComponent
@export var blade: Node3D
@export var blade_tip_offset: Vector3 = Vector3(0.0, 0.0, 0.342)

@export_group("Shape")
@export_range(16, 128, 1) var segments: int = 64
@export_range(120.0, 230.0) var arc_degrees: float = 198.0
@export_range(0.03, 8.0) var reach_scale: float = 1.35
@export_range(0.0, 0.15) var ground_offset: float = 0.045
@export_range(0.0, 25.0) var side_bias_degrees: float = 12.0

@export_group("Timing")
@export_range(0.0, 0.10) var glint_lead: float = 0.02
@export_range(0.0, 2.0) var hold_time: float = 0.06
@export_range(0.001, 2.0) var breakup_time: float = 0.10
@export_range(0.0, 0.50) var glint_tail: float = 0.02

@export_group("Pool")
@export_range(1, 6, 1) var slot_count: int = 2

@export_group("Shader Preparation")
@export_range(1, 6, 1) var prepare_frames: int = 2
@export_range(0.5, 20.0) var prepare_distance: float = 3.0
@export_range(0.000001, 0.001) var prepare_opacity: float = 0.000001

var _mesh: ArrayMesh
var _primed: SNAP_SLOT
var _routed: bool = false
var _capacity: int

@onready var _pool: ObjectPool = $SlashPool


func _ready() -> void:
	_mesh = _build_arc()
	_pool.configure_instance = _configure_slot
	_capacity = maxi(slot_count, 1)
	_pool.reserve(_capacity)
	if hitbox:
		hitbox.deactivated.connect(_clear_routing)
		hitbox.cancelled.connect(_cancel_all)
	_prepare_shaders.call_deferred()


func anticipate_strike() -> void:
	if not is_instance_valid(blade) or not blade.is_visible_in_tree():
		return
	cancel_anticipation()
	_primed = _take_slot()
	_primed.prime(blade, blade_tip_offset, glint_lead, hold_time + breakup_time + glint_tail)


func cancel_anticipation() -> void:
	if _primed:
		_pool.release(_primed)
		_primed = null


## Gọi trước hitbox.activated để các vệt khác nhường đúng nhát.
func play_strike(origin: Vector3, facing: Vector3, reach: float, _active_time: float, returning: bool) -> void:
	var heading: Vector3 = Vector3(facing.x, 0.0, facing.z)
	if not hitbox or heading.is_zero_approx():
		cancel_anticipation()
		return
	var slot: SNAP_SLOT = _primed if _primed else _take_slot()
	_primed = null
	_routed = true
	var side: float = -1.0 if returning else 1.0
	var facing_basis: Basis = Basis.looking_at(-heading).rotated(Vector3.UP, deg_to_rad(side_bias_degrees) * side)
	var pose: Transform3D = Transform3D(facing_basis, origin + Vector3.UP * ground_offset)
	var radius: float = maxf(reach * reach_scale, MIN_RADIUS)
	slot.strike(pose, radius, returning, hold_time, breakup_time, glint_tail, blade, blade_tip_offset)


func overrides_swing() -> bool:
	return _routed


func _take_slot() -> SNAP_SLOT:
	if _pool.get_active_count() >= _capacity:
		var oldest: Node = _pool.get_oldest_active()
		if oldest == _primed:
			_primed = null
		_pool.release(oldest)
	return _pool.acquire() as SNAP_SLOT


func _configure_slot(node: Node) -> void:
	var slot: SNAP_SLOT = node as SNAP_SLOT
	slot.arc_mesh = _mesh
	slot.radial_limits = MESH_RADII
	slot.finished.connect(_on_slot_finished)


func _on_slot_finished(slot: Node) -> void:
	if slot == _primed:
		_primed = null
	_pool.release(slot)


func _clear_routing() -> void:
	_routed = false


func _cancel_all() -> void:
	_clear_routing()
	_primed = null
	_pool.release_all()


func _prepare_shaders() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not is_instance_valid(camera) or _pool.get_active_count() != 0:
		return
	# Mở đúng pass trong lúc tải để lần chém đầu không đợi biên dịch shader.
	var position_on_camera: Vector3 = camera.global_position - camera.global_basis.z * prepare_distance
	var slot: SNAP_SLOT = _take_slot()
	slot.prepare_shaders(position_on_camera, prepare_opacity)
	for _frame: int in range(prepare_frames):
		await RenderingServer.frame_post_draw
	if slot.is_preparing_shaders():
		_pool.release(slot)


func _build_arc() -> ArrayMesh:
	var steps: int = maxi(segments, 3)
	var half_arc: float = deg_to_rad(arc_degrees) * 0.5
	var vertices: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for i: int in range(steps + 1):
		var u: float = float(i) / float(steps)
		var angle: float = lerpf(-half_arc, half_arc, u)
		var direction: Vector3 = Vector3(sin(angle), 0.0, cos(angle))
		vertices.append(direction * MESH_RADII.x)
		vertices.append(direction * MESH_RADII.y)
		uvs.append(Vector2(u, 0.0))
		uvs.append(Vector2(u, 1.0))
	for i: int in range(steps):
		var base: int = i * 2
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
