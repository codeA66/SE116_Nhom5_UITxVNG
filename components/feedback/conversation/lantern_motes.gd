extends "res://components/feedback/conversation/conversation_particles.gd"
## Đốm hổ phách bay chậm quanh tay cầm đèn, không tạo đèn động.

@export var radius: float = 0.45
@export var rise_height: float = 0.9
@export var mote_size: float = 0.085
@export var lantern_origin: Vector3 = Vector3(-0.45, 0.85, 0.15)

@onready var _visual: Node3D = get_parent().get_node("Visual")


func particle_transform(index: int, time: float) -> Transform3D:
	var seed_value := float(index)
	var angle := seed_value * 2.4 + time * 0.28
	var height := fposmod(seed_value * 0.137 + time * 0.09, 1.0)
	var point := Vector3(cos(angle) * radius, height * rise_height, sin(angle) * radius)
	var scale_value := mote_size * sin(height * PI)
	# Bám hướng quay của người giữ bến; không để đốm sáng trôi sang tay đối diện.
	point += lantern_origin
	if is_instance_valid(_visual):
		point = _visual.transform * point
	return Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_value), point)
