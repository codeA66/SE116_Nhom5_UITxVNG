class_name HorizontalWallMotion
extends Node
@export var left_stop: StaticBody3D
@export var right_stop: StaticBody3D
@export var speed: float=1.8
@export var initial_direction: float=1.0
var minimum_x: float
var maximum_x: float
var direction: float
var _wall: StaticBody3D
func _ready() -> void:
	_wall=get_parent() as StaticBody3D
	var own_bounds: AABB=bounds(_wall)
	var half: float=own_bounds.size.x*0.5
	minimum_x=bounds(left_stop).end.x+half+0.015
	maximum_x=bounds(right_stop).position.x-half-0.015
	direction=signf(initial_direction)
	if direction==0: direction=1
func _physics_process(delta: float) -> void:
	if maximum_x<=minimum_x: return
	var next: float=_wall.position.x+direction*speed*delta
	if next>=maximum_x: next=maximum_x; direction=-1
	elif next<=minimum_x: next=minimum_x; direction=1
	_wall.position.x=next
static func bounds(body: StaticBody3D) -> AABB:
	for child: Node in body.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			var size: Vector3=(child.shape as BoxShape3D).size
			return (body.transform*child.transform)*AABB(-size*0.5,size)
	return AABB(body.position,Vector3.ZERO)
