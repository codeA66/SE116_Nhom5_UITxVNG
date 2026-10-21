extends RefCounted
## Thêm clip cung từ các clip hiện có, không sửa file GLB/Blender.

const ARM_BONES := [&"UpperArm_L", &"Forearm_L", &"Hand_L", &"UpperArm_R", &"Forearm_R", &"Hand_R"]
const SHOT: AttackData = preload("res://resources/attacks/bow_shot.tres")


static func install(library: AnimationLibrary, skeleton: Skeleton3D) -> void:
	for clip: StringName in [&"Idle", &"Run"]:
		var animation := library.get_animation(clip).duplicate() as Animation
		_replace_arm_tracks(animation, skeleton, false)
		library.add_animation(StringName("%s_Bow" % clip), animation)
	var shot := library.get_animation(&"Idle").duplicate() as Animation
	shot.length = SHOT.duration * SHOT.anim_speed
	shot.loop_mode = Animation.LOOP_NONE
	_replace_arm_tracks(shot, skeleton, true)
	library.add_animation(&"Bow_Shoot", shot)


static func _replace_arm_tracks(animation: Animation, skeleton: Skeleton3D, shooting: bool) -> void:
	# Tư thế trong không gian rig; +Z là hướng bắn.
	var poses: Array[Dictionary] = [_arm_pose(skeleton, false), _arm_pose(skeleton, true)]
	for bone: StringName in ARM_BONES:
		var path := NodePath("FoxRig/Skeleton3D:%s" % bone)
		var track := animation.find_track(path, Animation.TYPE_ROTATION_3D)
		if track >= 0:
			animation.remove_track(track)
		track = animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, path)
		animation.rotation_track_insert_key(track, 0.0, poses[0][bone])
		if shooting:
			var release := SHOT.active_start * SHOT.anim_speed
			animation.rotation_track_insert_key(track, release * 0.75, poses[1][bone])
			animation.rotation_track_insert_key(track, release, poses[1][bone])
			animation.rotation_track_insert_key(track, lerpf(release, animation.length, 0.55), poses[0][bone])
		animation.rotation_track_insert_key(track, animation.length, poses[0][bone])


static func _arm_pose(skeleton: Skeleton3D, drawn: bool) -> Dictionary:
	var result := {}
	var world_bases := {}
	for bone: StringName in ARM_BONES:
		var direction: Vector3
		if String(bone).ends_with("_L"):
			direction = Vector3(0.25, 0.12, 1) if drawn else Vector3(0.1, -0.65, 0.76)
		elif String(bone).begins_with("UpperArm"):
			direction = Vector3(0.75, 0.2, -0.25) if drawn else Vector3(0.25, -0.75, 0.65)
		else:
			direction = Vector3(-0.8, 0.15, 0.65) if drawn else Vector3(-0.65, 0.15, 0.8)
		var y_axis := direction.normalized()
		var x_axis := y_axis.cross(Vector3.UP).normalized()
		var desired := Basis(x_axis, y_axis, x_axis.cross(y_axis))
		if String(bone).begins_with("Hand"):
			desired = Basis.IDENTITY
		var index := skeleton.find_bone(bone)
		var parent := skeleton.get_bone_parent(index)
		var parent_name := StringName(skeleton.get_bone_name(parent))
		var parent_basis: Basis = world_bases.get(parent_name, skeleton.get_bone_global_rest(parent).basis)
		result[bone] = (parent_basis.inverse() * desired).get_rotation_quaternion()
		world_bases[bone] = desired
	return result
