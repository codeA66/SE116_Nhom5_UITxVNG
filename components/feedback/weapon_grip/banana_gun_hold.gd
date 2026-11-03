class_name BananaGunHold
extends Node3D
@export var hold_offset: Vector3 = Vector3(0.03,0.37,0.18)
@export var display_scale: float = 0.5
var front_grip: Marker3D
var rear_grip: Marker3D
var muzzle: Marker3D
var modifier: TwoHandWeaponGrip

func configure(actor: Player, visual: Node3D) -> void:
	name = "BananaGunHold"; position = hold_offset
	if visual.get_parent(): visual.reparent(self,false)
	else: add_child(visual)
	visual.position = Vector3(0,0,0.15); visual.scale *= display_scale
	front_grip = _marker("FrontGrip",Vector3(0.07,0.3,0.04))
	rear_grip = _marker("RearGrip",Vector3(-0.09,0.22,-0.1))
	muzzle = _marker("Muzzle",Vector3(0,0.29,0.51))
	var skeleton: Skeleton3D = actor.model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	modifier = TwoHandWeaponGrip.new(); modifier.active = false
	modifier.front_grip = front_grip; modifier.rear_grip = rear_grip; modifier.model = actor.model
	skeleton.add_child(modifier)

func set_held(value: bool) -> void:
	visible = value
	if is_instance_valid(modifier): modifier.active = value

func _marker(label: String, at: Vector3) -> Marker3D:
	var marker: Marker3D = Marker3D.new(); marker.name = label; marker.position = at; add_child(marker)
	return marker

func _exit_tree() -> void:
	if is_instance_valid(modifier): modifier.queue_free()
