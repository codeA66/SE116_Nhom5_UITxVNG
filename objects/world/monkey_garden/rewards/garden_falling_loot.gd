class_name GardenFallingLoot
extends Node3D
## Chuyển động rơi có điểm đích cố định và bước chốt; không phụ thuộc tween/animation của model nhập.
@export var fall_duration: float=2.2
var landing: Vector3
var pickup: InteractableComponent
var _origin: Vector3
var _elapsed: float=0.0
func start(at: Vector3, interaction: InteractableComponent) -> void:
	landing=at; pickup=interaction; pickup.enabled=false
	top_level=true; global_position=at+Vector3.UP*8; _origin=global_position; _elapsed=0
	reset_physics_interpolation()
	set_physics_process(true)
func settle(at: Vector3, interaction: InteractableComponent) -> void:
	landing=at; pickup=interaction
	top_level=true; global_position=at; pickup.enabled=true
	reset_physics_interpolation()
	set_physics_process(false)
func _physics_process(delta: float) -> void:
	_elapsed+=delta
	var t: float=clampf(_elapsed/maxf(fall_duration,0.01),0,1)
	global_position=_origin.lerp(landing,sin(t*PI*0.5))
	if t>=1:
		global_position=landing; pickup.enabled=true; set_physics_process(false)
