class_name TwoHandWeaponGrip
extends SkeletonModifier3D
## Giải IK hai đoạn sau animation: chân vẫn chạy/nhảy, hai tay giữ đúng điểm trên súng.
@export var front_grip: Node3D
@export var rear_grip: Node3D
@export var model: Node3D
var _left: Vector3i
var _right: Vector3i

func _ready() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	_left = Vector3i(skeleton.find_bone("upper_arm.L"),skeleton.find_bone("forearm.L"),skeleton.find_bone("hand.L"))
	_right = Vector3i(skeleton.find_bone("upper_arm.R"),skeleton.find_bone("forearm.R"),skeleton.find_bone("hand.R"))

func _process_modification_with_delta(_delta: float) -> void:
	if not is_instance_valid(front_grip) or not is_instance_valid(rear_grip): return
	var skeleton: Skeleton3D = get_skeleton()
	_solve(skeleton,_left,skeleton.to_local(front_grip.global_position),skeleton.to_local(model.to_global(Vector3(0.6,0.48,0.03))))
	_solve(skeleton,_right,skeleton.to_local(rear_grip.global_position),skeleton.to_local(model.to_global(Vector3(-0.6,0.48,0.03))))

func _solve(skeleton: Skeleton3D, bones: Vector3i, target: Vector3, pole: Vector3) -> void:
	if bones.x < 0 or bones.y < 0 or bones.z < 0: return
	var shoulder: Transform3D = skeleton.get_bone_global_pose(bones.x)
	var elbow: Transform3D = skeleton.get_bone_global_pose(bones.y)
	var hand: Transform3D = skeleton.get_bone_global_pose(bones.z)
	var upper_length: float = shoulder.origin.distance_to(elbow.origin)
	var lower_length: float = elbow.origin.distance_to(hand.origin)
	var offset: Vector3 = target-shoulder.origin
	var distance: float = clampf(offset.length(),absf(upper_length-lower_length)+0.0001,upper_length+lower_length-0.0001)
	var direction: Vector3 = offset.normalized()
	var bend: Vector3 = pole-shoulder.origin
	bend = (bend-direction*bend.dot(direction)).normalized()
	var along: float = (upper_length*upper_length+distance*distance-lower_length*lower_length)/(2*distance)
	var desired_elbow: Vector3 = shoulder.origin+direction*along+bend*sqrt(maxf(upper_length*upper_length-along*along,0))
	var rotate_upper: Quaternion = Quaternion((elbow.origin-shoulder.origin).normalized(),(desired_elbow-shoulder.origin).normalized())
	shoulder.basis = Basis(rotate_upper)*shoulder.basis
	skeleton.set_bone_global_pose(bones.x,shoulder)
	elbow = skeleton.get_bone_global_pose(bones.y); hand = skeleton.get_bone_global_pose(bones.z)
	var rotate_lower: Quaternion = Quaternion((hand.origin-elbow.origin).normalized(),(target-elbow.origin).normalized())
	elbow.basis = Basis(rotate_lower)*elbow.basis; skeleton.set_bone_global_pose(bones.y,elbow)
	hand = skeleton.get_bone_global_pose(bones.z)
	var rest: Basis = skeleton.get_bone_global_rest(bones.z).basis.orthonormalized()
	var finger_direction: Vector3 = (skeleton.global_basis.inverse()*model.global_basis*Vector3(0,-0.5,1)).normalized()
	hand.basis = Basis(Quaternion(rest.y.normalized(),finger_direction))*rest
	skeleton.set_bone_global_pose(bones.z,hand)
