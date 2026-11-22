class_name FireBeam
extends Node3D
## Truy vết sau sự kiện xoay gương; tái dùng đoạn tia, không chạy khi đường tia đứng yên.

signal path_changed

const MAX_SEGMENTS: int = 33
const MIN_LENGTH: float = 0.0001

var _data: LiPuzzleData
var _source: Node3D
var _segments: Array[MeshInstance3D] = []
var _excluded: Array[RID] = []
var _query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _lit_receiver: BeamReceiver
var _receiver: BeamReceiver
var _auxiliary_receiver: BeamReceiver
var _required_mirrors: Array[RotatingFireMirror] = []
var _enabled: bool = true
var _segment_count: int = 0


func _ready() -> void:
	set_physics_process(false)
	_query.collide_with_areas = true
	_query.collide_with_bodies = true


func _physics_process(_delta: float) -> void:
	set_physics_process(false)
	_trace()


func configure(
	source: Node3D,
	data: LiPuzzleData,
	receiver: BeamReceiver,
	auxiliary_receiver: BeamReceiver,
	mirrors: Array[RotatingFireMirror]
) -> void:
	_source = source
	_data = data
	_receiver = receiver
	_auxiliary_receiver = auxiliary_receiver
	if _receiver.requires_continuous_light:
		_required_mirrors = mirrors
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = data.beam_color
	material.emission_enabled = true
	material.emission = data.beam_color
	material.emission_energy_multiplier = data.beam_emission
	var beam_mesh: BoxMesh = BoxMesh.new()
	beam_mesh.material = material
	beam_mesh.size = Vector3.ONE
	for index: int in range(clampi(data.max_reflections + 1, 1, MAX_SEGMENTS)):
		var segment: MeshInstance3D = MeshInstance3D.new()
		segment.name = "Segment%d" % index
		segment.mesh = beam_mesh
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		segment.visible = false
		add_child(segment)
		_segments.append(segment)
	request_trace()


func request_trace() -> void:
	if _data != null:
		set_physics_process(true)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		_set_lit_receiver(null)
	request_trace()


func get_segment_count() -> int:
	return _segment_count


func get_receiver() -> BeamReceiver:
	return _lit_receiver


func _trace() -> void:
	_segment_count = 0
	var receiver: BeamReceiver = null
	if _enabled and is_instance_valid(_source):
		var origin: Vector3 = _source.global_position
		var direction: Vector3 = -_source.global_basis.z.normalized()
		var remaining: float = maxf(_data.beam_distance, 0.0)
		var route_matches: bool = true
		_excluded.clear()
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		for segment: MeshInstance3D in _segments:
			if remaining < MIN_LENGTH:
				break
			_query.from = origin
			_query.to = origin + direction * remaining
			_query.collision_mask = _data.collision_mask
			_query.exclude = _excluded
			var hit: Dictionary = space.intersect_ray(_query)
			var endpoint: Vector3 = _query.to if hit.is_empty() else hit["position"]
			_draw_segment(segment, origin, endpoint)
			_segment_count += 1
			remaining -= origin.distance_to(endpoint)
			if hit.is_empty():
				break
			var collider: Object = hit["collider"]
			var reflection_index: int = _segment_count - 1
			if collider.has_meta(BeamReceiver.SURFACE_RECEIVER):
				var hit_receiver: BeamReceiver = collider.get_meta(BeamReceiver.SURFACE_RECEIVER) as BeamReceiver
				if hit_receiver == _auxiliary_receiver or (
					hit_receiver == _receiver and (
						_required_mirrors.is_empty() or (route_matches and reflection_index == _required_mirrors.size())
					)
				):
					receiver = hit_receiver
				break
			if not collider is RotatingFireMirror:
				break
			var mirror: RotatingFireMirror = collider as RotatingFireMirror
			if route_matches and not _required_mirrors.is_empty():
				route_matches = (
					reflection_index < _required_mirrors.size()
					and _required_mirrors[reflection_index] == mirror
					and not mirror.is_turning()
				)
			direction = direction.bounce(mirror.get_surface_normal()).normalized()
			var offset: float = maxf(_data.surface_offset, MIN_LENGTH)
			origin = endpoint + direction * offset
			remaining -= offset
			_excluded.resize(1)
			_excluded[0] = mirror.get_rid()
	for index: int in range(_segment_count, _segments.size()):
		_segments[index].visible = false
	_set_lit_receiver(receiver)
	path_changed.emit()


func _draw_segment(segment: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var length: float = from.distance_to(to)
	segment.visible = length > MIN_LENGTH
	if not segment.visible:
		return
	segment.global_position = (from + to) * 0.5
	var direction: Vector3 = from.direction_to(to)
	var up: Vector3 = Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.99 else Vector3.UP
	segment.look_at(to, up)
	var thickness: float = maxf(_data.beam_radius * 2.0, MIN_LENGTH)
	segment.scale = Vector3(thickness, thickness, length)


func _set_lit_receiver(receiver: BeamReceiver) -> void:
	if receiver == _lit_receiver:
		return
	if is_instance_valid(_lit_receiver):
		_lit_receiver.set_illuminated(false)
	_lit_receiver = receiver
	if is_instance_valid(_lit_receiver):
		_lit_receiver.set_illuminated(true)
