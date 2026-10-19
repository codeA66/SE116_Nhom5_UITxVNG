class_name SunMotes
extends Node3D
## Bụi bắt nắng lơ lửng quanh player: hạt sinh trong một hộp quanh follow_target, nhưng sống trong toạ độ
## thế giới (local_coords tắt) nên player đi qua thì bụi đứng yên, không kéo theo người.
## Nối ZoneRoot.player_spawned vào set_follow_target trong scene khu. Không có target thì không chạy _process.

## Lệch tâm vùng sinh so với target (m)
@export var follow_offset: Vector3 = Vector3(0.0, 1.2, 0.0)

var _target: Node3D

@onready var _particles: CPUParticles3D = $Particles


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	if not is_instance_valid(_target):
		_particles.emitting = false
		set_process(false)
		return
	global_position = _target.global_position + follow_offset


func set_follow_target(target: Node3D) -> void:
	_target = target
	if is_instance_valid(_target):
		global_position = _target.global_position + follow_offset
		_particles.restart()
		_particles.emitting = true
		set_process(true)
