extends RefCounted
## Chỉnh mặt phẳng đỡ của toàn rig, giữ nguyên khớp và chiều dài chi.
const FEET: Array[StringName] = [&"Sabrecat_RightHand_RHnd_", &"Sabrecat_LeftHand_LHnd_", &"Sabrecat_RightFoot_RFot_", &"Sabrecat_LeftFoot_LFot_"]
const FLOOR := 0.005
const MAX_TILT := 0.24
var _positions := PackedVector3Array()
var _joints: Array[PackedInt32Array] = []
var _weights: Array[PackedFloat32Array] = []
var _feet := PackedInt32Array()
var _bind_bones := PackedInt32Array()
var _bind_inverse: Array[Transform3D] = []
var _pelvis: int

func setup(skeleton: Skeleton3D, mesh: MeshInstance3D) -> void:
	_pelvis = skeleton.find_bone(&"Sabrecat__pelv_")
	var bind_feet := PackedInt32Array()
	for bind: int in mesh.skin.get_bind_count():
		var bone := skeleton.find_bone(mesh.skin.get_bind_name(bind))
		_bind_bones.append(bone)
		_bind_inverse.append(mesh.skin.get_bind_pose(bind))
		var foot := -1
		while bone >= 0:
			foot = FEET.find(skeleton.get_bone_name(bone))
			if foot >= 0:
				break
			bone = skeleton.get_bone_parent(bone)
		bind_feet.append(foot)
	var arrays := mesh.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var stride := int(float(joints.size()) / positions.size())
	var unique: Dictionary[Vector3, bool] = {}
	for vertex: int in positions.size():
		if unique.has(positions[vertex]):
			continue
		unique[positions[vertex]] = true
		var influences := Vector4.ZERO
		var binds := PackedInt32Array()
		var amounts := PackedFloat32Array()
		for slot: int in stride:
			var at := vertex * stride + slot
			binds.append(joints[at])
			amounts.append(weights[at])
			var foot := bind_feet[joints[at]]
			if foot >= 0:
				influences[foot] += weights[at]
		var foot := 0
		for candidate: int in range(1, 4):
			if influences[candidate] > influences[foot]:
				foot = candidate
		if influences[foot] >= 0.5:
			_positions.append(positions[vertex])
			_joints.append(binds)
			_weights.append(amounts)
			_feet.append(foot)

func support_transform(poses: Array[Transform3D]) -> Transform3D:
	var transforms: Array[Transform3D] = []
	for bind: int in _bind_bones.size():
		transforms.append(poses[_bind_bones[bind]] * _bind_inverse[bind])
	var contacts: Array[Vector3] = [Vector3(0, INF, 0), Vector3(0, INF, 0), Vector3(0, INF, 0), Vector3(0, INF, 0)]
	for vertex: int in _positions.size():
		var point := Vector3.ZERO
		for slot: int in _joints[vertex].size():
			point += (transforms[_joints[vertex][slot]] * _positions[vertex]) * _weights[vertex][slot]
		var foot := _feet[vertex]
		if point.y < contacts[foot].y:
			contacts[foot] = point
	var front := contacts[0] if contacts[0].y < contacts[1].y else contacts[1]
	var normal := (contacts[3] - contacts[2]).cross(front - contacts[2]).normalized()
	if normal.y < 0.0:
		normal = -normal
	var rotation := Quaternion.IDENTITY
	if not normal.is_zero_approx():
		var angle := normal.angle_to(Vector3.UP)
		rotation = Quaternion.IDENTITY.slerp(Quaternion(normal, Vector3.UP), minf(1.0, MAX_TILT / maxf(angle, 0.001)))
	var basis := Basis(rotation)
	var center := poses[_pelvis].origin
	var correction := Transform3D(basis, center - basis * center)
	var lowest := INF
	for point: Vector3 in contacts:
		lowest = minf(lowest, (correction * point).y)
	correction.origin.y += FLOOR - lowest
	return correction
