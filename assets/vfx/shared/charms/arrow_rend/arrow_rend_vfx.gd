class_name ArrowRendVfx
extends Node3D

signal finished(visual: ArrowRendVfx)

@export_group("Tên ghim")
@export_range(0.0, 1.0, 0.01) var torso_bias: float = 0.72
@export_range(0.0, 1.0, 0.01) var shaft_pitch: float = 0.17
@export_range(0.0, 0.3, 0.01) var pin_spread: float = 0.16
@export_range(0.0, 30.0, 0.5) var fan_step: float = 7.0

@export_group("Rút tên")
@export_range(0.01, 1.0, 0.01) var retract_time: float = 0.19
@export_range(0.0, 3.0, 0.01) var retract_distance: float = 1.35
@export_range(0.0, 2.0, 0.01) var retract_lift: float = 0.42

var _target: Node3D
var _local_pose: Transform3D
var _release_pose: Transform3D
var _release_direction: Vector3
var _elapsed: float = 0.0
var _retracting: bool = false

@onready var _shaft: Node3D = $Shaft
@onready var _spark: MeshInstance3D = $Spark


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if not _retracting:
		visible = is_instance_valid(_target) and _target.is_visible_in_tree()
		if visible:
			global_transform = _target.get_global_transform_interpolated() * _local_pose
		return
	_elapsed += delta
	var progress: float = clampf(_elapsed / maxf(retract_time, 0.01), 0.0, 1.0)
	if progress >= 1.0:
		finished.emit(self)
		return
	var travel: float = 1.0 - (1.0 - progress) * (1.0 - progress)
	global_position = _release_pose.origin + _release_direction * (travel * retract_distance) + Vector3.UP * (travel * retract_lift)
	_shaft.scale = Vector3.ONE * (1.0 - smoothstep(0.30, 1.0, progress))
	_spark.scale = Vector3.ONE * lerpf(1.0, 0.02, progress)


func pin(target: Node3D, contact: Vector3, torso: Vector3, direction: Vector3, index: int) -> void:
	_target = target
	# Xòe các đuôi tên để còn đếm được khi nhiều phát trúng cùng một chỗ.
	var lane: float = float((index + 1) >> 1) * (-1.0 if index % 2 == 0 else 1.0)
	var horizontal: Vector3 = Vector3(direction.x, 0.0, direction.z).normalized()
	if horizontal.is_zero_approx():
		horizontal = Vector3.FORWARD
	var heading: Vector3 = horizontal.rotated(Vector3.UP, deg_to_rad(fan_step) * lane)
	var shaft_direction: Vector3 = (heading - Vector3.UP * (shaft_pitch + lane * 0.06)).normalized()
	var side: Vector3 = Vector3.UP.cross(horizontal)
	# Va chạm của tên quét có thể ở sát đất dù quái to, nên neo đoạn xuyên vào phần thân.
	var center: Vector3 = contact.lerp(torso, torso_bias) + (side + Vector3.UP * 0.45) * (lane * pin_spread)
	var pose: Transform3D = Transform3D(Basis.looking_at(shaft_direction, Vector3.UP, true), center)
	_local_pose = target.global_transform.affine_inverse() * pose
	global_transform = pose
	set_process(true)


func retract(toward_player: Vector3) -> void:
	if is_instance_valid(_target):
		global_transform = _target.get_global_transform_interpolated() * _local_pose
	_target = null
	_retracting = true
	_release_pose = global_transform
	# Kéo theo trục thân tên để đầu tên rời khỏi bề mặt trước khi văng ra.
	var shaft_out: Vector3 = -global_basis.z.normalized()
	_release_direction = shaft_out.lerp(toward_player, 0.3).normalized()
	var spark_basis: Basis = Basis.looking_at(_release_direction, Vector3.UP, true)
	_spark.global_basis = Basis(spark_basis.x, spark_basis.z, -spark_basis.y)
	_spark.visible = true
	visible = true
	_elapsed = 0.0
	set_process(true)


func pool_released() -> void:
	_target = null
	_retracting = false
	_shaft.scale = Vector3.ONE
	_spark.visible = false
	_spark.scale = Vector3.ONE
	set_process(false)
