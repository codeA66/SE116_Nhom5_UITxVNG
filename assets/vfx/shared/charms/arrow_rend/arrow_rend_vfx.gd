class_name ArrowRendVfx
extends Node3D

signal finished(visual: ArrowRendVfx)

@export_group("Tên ghim")
@export_range(0.0, 1.0, 0.01) var torso_bias: float = 0.72
@export_range(0.0, 1.0, 0.01) var shaft_pitch: float = 0.17
@export_range(0.0, 0.3, 0.01) var pin_spread: float = 0.16
@export_range(0.0, 30.0, 0.5) var fan_step: float = 7.0

@export_group("Rút tên")
@export_range(0.01, 1.0, 0.01) var retract_time: float = 0.32
@export_range(0.0, 3.0, 0.01) var retract_distance: float = 2.2
@export_range(0.0, 2.0, 0.01) var retract_lift: float = 1.08
@export_range(0.0, 1.5, 0.01) var retract_splay: float = 0.95
@export_range(0.05, 0.95, 0.01) var trail_span: float = 0.43

@export_group("Lóe điểm ghim")
@export_range(0.01, 0.8, 0.01) var flash_time: float = 0.32
@export_range(0.0, 1.0, 0.01) var flash_height: float = 0.38
@export_range(0.5, 2.0, 0.01) var flash_scale: float = 1.0

var _target: Node3D
var _local_pose: Transform3D
var _release_origin: Vector3
var _release_direction: Vector3
var _release_side: Vector3
var _lane: float = 0.0
var _elapsed: float = 0.0
var _retracting: bool = false
var _has_flash: bool = false

@onready var _shaft: Node3D = $Shaft
@onready var _trail: MeshInstance3D = $PullTrail
@onready var _trail_material: ShaderMaterial = _trail.material_override as ShaderMaterial
@onready var _impact: Node3D = $Impact
@onready var _flash: MeshInstance3D = $Impact/Flash
@onready var _flash_material: ShaderMaterial = _flash.material_override as ShaderMaterial
@onready var _shards: CPUParticles3D = $Impact/Shards


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if not _retracting:
		visible = is_instance_valid(_target) and _target.is_visible_in_tree()
		if visible:
			global_transform = _target.get_global_transform_interpolated() * _local_pose
		return
	_elapsed += delta
	var pull_duration: float = maxf(retract_time, 0.01)
	var burst_duration: float = maxf(flash_time, _shards.lifetime) if _has_flash else 0.0
	if _elapsed >= maxf(pull_duration, burst_duration):
		finished.emit(self)
		return
	var progress: float = minf(_elapsed / pull_duration, 1.0)
	_shaft.visible = progress < 1.0
	if _shaft.visible:
		var head: Vector3 = _release_origin + _pull_offset(progress)
		var tail: Vector3 = _release_origin + _pull_offset(maxf(progress - trail_span, 0.0))
		global_position = head
		_shaft.scale = Vector3.ONE * (1.0 - smoothstep(0.54, 1.0, progress))
		_update_trail(tail, head, progress)
	else:
		_trail.hide()
	if _has_flash:
		var flash_progress: float = clampf(_elapsed / maxf(flash_time, 0.01), 0.0, 1.0)
		_flash.visible = flash_progress < 1.0
		_flash_material.set_shader_parameter(&"age", flash_progress)


func pin(target: Node3D, contact: Vector3, torso: Vector3, direction: Vector3, index: int) -> void:
	_target = target
	# Xòe các đuôi tên để còn đếm được khi nhiều phát trúng cùng một chỗ.
	_lane = float((index + 1) >> 1) * (-1.0 if index % 2 == 0 else 1.0)
	var horizontal: Vector3 = Vector3(direction.x, 0.0, direction.z).normalized()
	if horizontal.is_zero_approx():
		horizontal = Vector3.FORWARD
	var heading: Vector3 = horizontal.rotated(Vector3.UP, deg_to_rad(fan_step) * _lane)
	var shaft_direction: Vector3 = (heading - Vector3.UP * (shaft_pitch + _lane * 0.06)).normalized()
	var side: Vector3 = Vector3.UP.cross(horizontal)
	# Va chạm của tên quét có thể ở sát đất dù quái to, nên neo đoạn xuyên vào phần thân.
	var center: Vector3 = contact.lerp(torso, torso_bias) + (side + Vector3.UP * 0.45) * (_lane * pin_spread)
	var pose: Transform3D = Transform3D(Basis.looking_at(shaft_direction, Vector3.UP, true), center)
	_local_pose = target.global_transform.affine_inverse() * pose
	global_transform = pose
	set_process(true)


func retract(toward_player: Vector3, impact_position: Vector3, spent_for_flash: int) -> void:
	if is_instance_valid(_target):
		global_transform = _target.get_global_transform_interpolated() * _local_pose
	_target = null
	_retracting = true
	_release_origin = global_position
	# Kéo theo trục thân tên để đầu tên rời khỏi bề mặt trước khi văng ra.
	var shaft_out: Vector3 = -global_basis.z
	shaft_out.y = 0.0
	_release_direction = shaft_out.normalized().lerp(toward_player, 0.28).normalized()
	if _release_direction.is_zero_approx():
		_release_direction = Vector3.FORWARD
	_release_side = _release_direction.cross(Vector3.UP) * (-1.0 if _lane < 0.0 else 1.0)
	_has_flash = spent_for_flash > 0
	if _has_flash:
		_start_impact(impact_position, spent_for_flash)
	visible = true
	_elapsed = 0.0
	set_process(true)


func pool_released() -> void:
	_target = null
	_retracting = false
	_has_flash = false
	_shaft.show()
	_shaft.scale = Vector3.ONE
	_trail.hide()
	_impact.hide()
	_shards.emitting = false
	set_process(false)


func _pull_offset(progress: float) -> Vector3:
	# Lệch khỏi trục chém và nhấc vệt lên để cáo không che hết tên ở góc chính diện.
	var remaining: float = 1.0 - progress
	var travel: float = 1.0 - remaining * remaining
	var separation: float = 1.0 - remaining * remaining * remaining
	var rise: float = sin(progress * PI * 0.83)
	return _release_direction * (travel * retract_distance) \
		+ _release_side * (separation * retract_splay * (1.0 + absf(_lane) * 0.12)) \
		+ Vector3.UP * (rise * retract_lift)


func _update_trail(tail: Vector3, head: Vector3, progress: float) -> void:
	var segment: Vector3 = head - tail
	var length_m: float = segment.length()
	if length_m < 0.01:
		_trail.hide()
		return
	var axis: Vector3 = segment / length_m
	var side: Vector3 = _release_side.normalized()
	_trail.global_transform = Transform3D(Basis(side, segment, side.cross(axis)), (tail + head) * 0.5)
	_trail_material.set_shader_parameter(&"age", progress)
	_trail.show()


func _start_impact(at: Vector3, spent: int) -> void:
	_impact.global_position = at + Vector3.UP * flash_height
	_flash.scale = Vector3.ONE * (flash_scale * lerpf(1.0, 1.28, clampf(float(spent - 1) / 5.0, 0.0, 1.0)))
	_flash_material.set_shader_parameter(&"age", 0.0)
	_flash.show()
	_impact.show()
	_shards.restart()
