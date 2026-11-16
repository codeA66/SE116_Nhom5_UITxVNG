class_name WindBlastTargetSelector
extends Node
## Chọn nhánh magma theo mép giao với thể tích gió, không theo tâm receiver.

signal selected(receiver: WindReceiverComponent)

const CONTACT_EPSILON: float = 0.00001

@export var blast: Area3D
@export var volume: CollisionShape3D

var _pending: Array[WindReceiverComponent] = []
var _generation: int = 0
var _queued: bool = false


func begin() -> void:
	cancel()


func cancel() -> void:
	_generation += 1
	_pending.clear()
	_queued = false


func handles(receiver: WindReceiverComponent) -> bool:
	return receiver.get_parent() is MagmaHazard or receiver.owner is MagmaHazard


func offer(receiver: WindReceiverComponent) -> void:
	if receiver not in _pending:
		_pending.append(receiver)
	if not _queued:
		_queued = true
		_resolve.call_deferred(_generation)


func _resolve(generation: int) -> void:
	if generation != _generation:
		return
	_queued = false
	# Đợi hết batch signal vật lý rồi mới đọc danh sách overlap hoàn chỉnh.
	for area: Area3D in blast.get_overlapping_areas():
		var receiver: WindReceiverComponent = area as WindReceiverComponent
		if receiver != null and handles(receiver) and receiver not in _pending:
			_pending.append(receiver)
	var best: WindReceiverComponent
	var best_entry: float = INF
	var best_offset: float = INF
	var world_to_volume: Transform3D = volume.global_transform.affine_inverse()
	var box: BoxShape3D = volume.shape as BoxShape3D
	for receiver: WindReceiverComponent in _pending:
		if not is_instance_valid(receiver) or not receiver.enabled or not receiver.monitorable or receiver.owner == blast.owner:
			continue
		var magma: MagmaHazard = receiver.get_parent() as MagmaHazard
		if magma == null:
			magma = receiver.owner as MagmaHazard
		if magma == null or not magma.running:
			continue
		for child: Node in receiver.get_children():
			var shape: CollisionShape3D = child as CollisionShape3D
			if shape == null or shape.disabled or not shape.shape is BoxShape3D:
				continue
			var planes: Array[Plane] = Geometry3D.build_box_planes(box.size * 0.5)
			var receiver_box: BoxShape3D = shape.shape as BoxShape3D
			var relative: Transform3D = world_to_volume * shape.global_transform
			for plane: Plane in Geometry3D.build_box_planes(receiver_box.size * 0.5):
				planes.append(relative * plane)
			var entry: float = INF
			var offset: float = INF
			# Giao hai hộp lồi giữ đúng bề rộng, chiều cao, xoay và scale của cả hai.
			for point: Vector3 in Geometry3D.compute_convex_mesh_points(planes):
				if point.z < entry - CONTACT_EPSILON:
					entry = point.z
					offset = absf(point.x)
				elif absf(point.z - entry) <= CONTACT_EPSILON:
					offset = minf(offset, absf(point.x))
			if entry == INF:
				continue
			var nearer: bool = entry < best_entry - CONTACT_EPSILON
			var tied: bool = absf(entry - best_entry) <= CONTACT_EPSILON
			if nearer or (tied and (offset < best_offset - CONTACT_EPSILON or (is_equal_approx(offset, best_offset) and (best == null or receiver.get_instance_id() < best.get_instance_id())))):
				best = receiver
				best_entry = entry
				best_offset = offset
	_pending.clear()
	if best != null:
		selected.emit(best)
