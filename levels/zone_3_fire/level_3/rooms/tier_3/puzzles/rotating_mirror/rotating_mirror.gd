class_name RotatingFireMirror
extends Area3D
## Một chu kỳ góc có thứ tự; AnimationPlayer nội suy góc và vùng phản xạ cùng nhịp vật lý.

signal orientation_changed

const MIN_DIRECTION_LENGTH: float = 0.0001
const NORMAL_TOLERANCE: float = 0.0001

@export var prompt: String = "XOAY GƯƠNG"
@export var incoming_anchor: Node3D
@export var targets: Array[Node3D] = []
## Hướng từng nấc theo thiết kế phòng, gồm cả hướng đúng và hướng sai.
@export var angle_targets: Array[Node3D] = []

var turn_progress: float = 0.0:
	set(value):
		turn_progress = clampf(value, 0.0, 1.0)
		_apply_pose(_turn_from.lerp(_turn_to, turn_progress))

var _normals: PackedVector3Array = PackedVector3Array()
var _step: int = 0
var _initial_step: int = 0
var _locked: bool = false
var _present: bool = true
var _data: LiPuzzleData
var _pose: Vector3 = Vector3.ZERO
var _turn_from: Vector3 = Vector3.ZERO
var _turn_to: Vector3 = Vector3.ZERO

@onready var _pivot: Node3D = $Pivot
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _interactable: InteractableComponent = $InteractableComponent
@onready var _animation: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_interactable.prompt_text = prompt
	_interactable.interacted.connect(_on_interacted)
	_animation.animation_finished.connect(_on_turn_finished)


func configure(data: LiPuzzleData, initial_step: int) -> void:
	_data = data
	_normals.clear()
	var normals: Array[Vector3] = []
	if incoming_anchor != null and (not angle_targets.is_empty() or not data.angle_offsets.is_empty()):
		var incoming: Vector3 = _point_for(incoming_anchor).direction_to(get_beam_point())
		var configured_targets: Array[Node3D] = targets if angle_targets.is_empty() else angle_targets
		for target: Node3D in configured_targets:
			if target != null:
				var normal: Vector3 = incoming - get_beam_point().direction_to(_point_for(target))
				if normal.length_squared() >= MIN_DIRECTION_LENGTH:
					_append_unique(normals, normal.normalized())
		if angle_targets.is_empty():
			# Bộ gương dùng lại vẫn có thể sinh góc lệch từ dữ liệu chung.
			var solved_normals: Array[Vector3] = normals.duplicate()
			var count: int = maxi(clampi(data.mirror_step_count, 1, 16), solved_normals.size())
			for offset: float in data.angle_offsets:
				for normal: Vector3 in solved_normals:
					if normals.size() < count and is_finite(offset):
						_append_unique(normals, normal.rotated(Vector3.UP, deg_to_rad(offset)))
		normals.sort_custom(_compare_angles)
	_normals = PackedVector3Array(normals)
	_shape.set_deferred(&"disabled", not _present or _normals.is_empty())
	_initial_step = initial_step
	set_step(initial_step)
	_refresh_interaction()


func get_beam_point() -> Vector3:
	return _pivot.global_position


func get_surface_normal() -> Vector3:
	return -_pivot.global_basis.z.normalized()


func get_step() -> int:
	return _step


func step_count() -> int:
	return _normals.size()


func is_turning() -> bool:
	return _animation.is_playing()


func set_step(value: int) -> void:
	_animation.stop()
	if _normals.is_empty():
		_refresh_interaction()
		return
	_step = posmod(value, _normals.size())
	_apply_pose(_pose_for(_normals[_step]))
	_refresh_interaction()


func reset_orientation() -> void:
	set_step(_initial_step)


func set_locked(locked: bool) -> void:
	_locked = locked
	_refresh_interaction()


func set_present(present: bool) -> void:
	_present = present
	if not present:
		_animation.stop(true)
	_shape.set_deferred(&"disabled", not present or _normals.is_empty())
	_refresh_interaction()


func _on_interacted(_actor: Node3D) -> void:
	if is_turning() or _locked or not _present or _normals.is_empty():
		return
	_step = posmod(_step + 1, _normals.size())
	_turn_from = _pose
	_turn_to = _pose_for(_normals[_step])
	# Mỗi lần bấm đi theo cung ngắn nhất, kể cả sau nhiều vòng và khi nạp tiến độ.
	_turn_to.y = _turn_from.y + wrapf(_turn_to.y - _turn_from.y, -PI, PI)
	_interactable.enabled = false
	_animation.play(&"mirror/step", -1.0, 1.0 / maxf(_data.mirror_turn_time, 0.01))
	_animation.advance(0.0)


func _on_turn_finished(_name: StringName) -> void:
	_turn_to.y = wrapf(_turn_to.y, -PI, PI)
	_turn_from = _turn_to
	_animation.stop(true)
	_apply_pose(_turn_to)
	_refresh_interaction()


func _apply_pose(pose: Vector3) -> void:
	if not is_instance_valid(_pivot):
		return
	_pose = pose
	_pivot.rotation = pose
	_shape.rotation = pose
	orientation_changed.emit()


func _pose_for(normal: Vector3) -> Vector3:
	var local_normal: Vector3 = (global_basis.inverse() * normal).normalized()
	return Vector3(asin(clampf(local_normal.y, -1.0, 1.0)), fposmod(atan2(-local_normal.x, -local_normal.z), TAU), 0.0)


func _compare_angles(first: Vector3, second: Vector3) -> bool:
	return _pose_for(first).y < _pose_for(second).y


func _append_unique(normals: Array[Vector3], normal: Vector3) -> void:
	for existing: Vector3 in normals:
		# Hai pháp tuyến đối nhau cho cùng một mặt phẳng phản xạ.
		if absf(existing.dot(normal)) > 1.0 - NORMAL_TOLERANCE:
			return
	# Đảo pháp tuyến vẫn giữ mặt phản xạ, giúp tránh một nấc phải quay gần cả vòng.
	if _angular_spacing(normals, -normal) > _angular_spacing(normals, normal):
		normal = -normal
	normals.append(normal)


func _angular_spacing(normals: Array[Vector3], normal: Vector3) -> float:
	var spacing: float = TAU
	var angle: float = _pose_for(normal).y
	for existing: Vector3 in normals:
		spacing = minf(spacing, absf(wrapf(angle - _pose_for(existing).y, -PI, PI)))
	return spacing


func _refresh_interaction() -> void:
	_interactable.enabled = _present and not _locked and not _normals.is_empty() and not is_turning()


func _point_for(anchor: Node3D) -> Vector3:
	return anchor.get_beam_point() if anchor is RotatingFireMirror else anchor.global_position
