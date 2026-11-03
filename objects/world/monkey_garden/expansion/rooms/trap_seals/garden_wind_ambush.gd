class_name GardenWindAmbush
extends Node3D
## Tái sử dụng một cột gió của gấu, khóa vị trí lúc báo trước để người chơi có thể né.
@export_range(2.5, 30, 0.1) var interval: float = 5.0
@export var hazard: EnemyHazard
@export var attack: EnemySkillData
@export_range(0.3, 5.0, 0.1) var column_radius: float = 1.3
@export_range(1.0, 8.0, 0.1) var column_height: float = 3.0
@export_range(0.2, 3.0, 0.05) var warning_duration: float = 0.966667
@export_range(0.3, 4.0, 0.1) var tail_duration: float = 2.2
@export_range(0.0, 2.0, 0.05) var gentle_pull_speed: float = 0.65
@export_range(0.5, 6.0, 0.1) var attraction_radius: float = 2.3
var _timer: Timer
var _target: WeakRef

func _ready() -> void:
	var shape: CylinderShape3D = hazard.get_node("Hitbox/CollisionShape3D").shape as CylinderShape3D
	shape.radius = column_radius
	hazard.visual.scale = Vector3(column_radius/2.5,column_height/5.8,column_radius/2.5)
	# Một đồng hồ cho toàn bộ cảnh báo, hất lên và tan xoáy; kết thúc phải trả hiệu ứng về trạng thái ẩn.
	hazard.visual.set("burst_time",warning_duration)
	hazard.visual.set("tail_duration",tail_duration)
	hazard.active_start = warning_duration
	hazard.active_end = warning_duration+0.25
	hazard.lifetime = hazard.visual.call("total_duration")
	hazard.set("pull_speed",gentle_pull_speed)
	hazard.set("pull_during_tail",true)
	var pull_shape: CylinderShape3D = hazard.get_node("Attraction/CollisionShape3D").shape.duplicate() as CylinderShape3D
	pull_shape.radius = attraction_radius
	hazard.get_node("Attraction/CollisionShape3D").shape = pull_shape
	hazard.finished.connect(hazard.pool_released)
	_timer = Timer.new(); _timer.wait_time = interval; _timer.timeout.connect(_cast); add_child(_timer)

func begin(player: Player) -> void:
	_target = weakref(player); _timer.start(maxf(interval,hazard.lifetime+0.1))

func stop() -> void:
	_timer.stop(); _target = null
	hazard.cancel(); hazard.pool_released()

func _cast() -> void:
	var player: Player = _target.get_ref() as Player if _target else null
	if not is_instance_valid(player) or player.health.is_dead(): return
	var point: Vector3 = player.global_position
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point+Vector3.UP,point+Vector3.DOWN*20,1)
	var ground: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if not ground.is_empty(): point = ground.position
	hazard.start(attack,point,Vector3.FORWARD)
