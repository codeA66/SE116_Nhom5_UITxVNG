extends RefCounted
## Thêm clip cung (Idle_Bow, Run_Bow, Bow_Shoot) từ clip Idle/Run có sẵn.
## Tên xương và đường dẫn skeleton truyền vào, nên dùng được cho rig có cách đặt tên khác.

const SHOT: AttackData = preload("res://resources/attacks/bow_shot.tres")
const ROLES: Array[StringName] = [&"upper_l", &"fore_l", &"hand_l", &"upper_r", &"fore_r", &"hand_r"]


static func install(library: AnimationLibrary, skeleton: Skeleton3D, skeleton_path: NodePath, bones: Dictionary) -> void:
	for clip: StringName in [&"Idle", &"Run"]:
		if not library.has_animation(clip):
			continue
		var animation := library.get_animation(clip).duplicate() as Animation
		_replace_arm_tracks(animation, skeleton, skeleton_path, bones, false)
		library.add_animation(StringName("%s_Bow" % clip), animation)
	if not library.has_animation(&"Idle"):
		return
	var shot := library.get_animation(&"Idle").duplicate() as Animation
	shot.length = SHOT.duration * SHOT.anim_speed
	shot.loop_mode = Animation.LOOP_NONE
	_replace_arm_tracks(shot, skeleton, skeleton_path, bones, true)
	library.add_animation(&"Bow_Shoot", shot)


static func _replace_arm_tracks(animation: Animation, skeleton: Skeleton3D, skeleton_path: NodePath,
		bones: Dictionary, shooting: bool) -> void:
	# Tư thế trong không gian rig; +Z là hướng bắn
	var poses: Array[Dictionary] = [_arm_pose(skeleton, bones, false), _arm_pose(skeleton, bones, true)]
	for role: StringName in ROLES:
		var bone: StringName = bones[role]
		var path := NodePath("%s:%s" % [skeleton_path, bone])
		var track := animation.find_track(path, Animation.TYPE_ROTATION_3D)
		if track >= 0:
			animation.remove_track(track)
		track = animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, path)
		animation.rotation_track_insert_key(track, 0.0, poses[0][role])
		if shooting:
			var release := SHOT.active_start * SHOT.anim_speed
			animation.rotation_track_insert_key(track, release * 0.75, poses[1][role])
			animation.rotation_track_insert_key(track, release, poses[1][role])
			animation.rotation_track_insert_key(track, lerpf(release, animation.length, 0.55), poses[0][role])
		animation.rotation_track_insert_key(track, animation.length, poses[0][role])


static func _arm_pose(skeleton: Skeleton3D, bones: Dictionary, drawn: bool) -> Dictionary:
	var result := {}
	# Tay phải của rig nằm bên -X thì lật hướng
	var mirror_x := _right_side_sign(skeleton, bones)
	var world_bases := {}
	for role: StringName in ROLES:
		var bone: StringName = bones[role]
		var direction: Vector3
		if String(role).ends_with("_l"):
			direction = Vector3(0.25, 0.12, 1) if drawn else Vector3(0.1, -0.65, 0.76)
		elif role == &"upper_r":
			direction = Vector3(0.75, 0.2, -0.25) if drawn else Vector3(0.25, -0.75, 0.65)
		else:
			direction = Vector3(-0.8, 0.15, 0.65) if drawn else Vector3(-0.65, 0.15, 0.8)
		# Hướng gốc dựng cho rig có tay phải ở +X; rig khác bên thì lật trục X
		direction.x *= mirror_x
		var index := skeleton.find_bone(bone)
		if index < 0:
			push_warning("Thiếu xương %s cho tư thế cung" % bone)
			continue
		var parent := skeleton.get_bone_parent(index)
		var parent_basis: Basis = world_bases.get(parent, skeleton.get_bone_global_rest(parent).basis.orthonormalized())
		var desired: Basis
		if String(role).begins_with("hand"):
			# Bàn tay giữ hướng của cẳng tay
			desired = parent_basis
		else:
			var y_axis := direction.normalized()
			var x_axis := y_axis.cross(Vector3.UP).normalized()
			desired = Basis(x_axis, y_axis, x_axis.cross(y_axis))
		result[role] = (parent_basis.inverse() * desired).get_rotation_quaternion()
		world_bases[index] = desired
	return result


static func _right_side_sign(skeleton: Skeleton3D, bones: Dictionary) -> float:
	var right := skeleton.find_bone(bones[&"upper_r"])
	if right < 0:
		return 1.0
	return 1.0 if skeleton.get_bone_global_rest(right).origin.x >= 0.0 else -1.0
