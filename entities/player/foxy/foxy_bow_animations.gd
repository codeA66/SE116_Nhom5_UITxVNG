extends RefCounted
## Thêm clip cung từ clip Idle/Run có sẵn: Idle_Bow, Run_Bow, Bow_Shoot (cung cầm tay cũ) và
## clip kéo / buông của cung vũ khí phụ (tên lấy từ BowData). Clip kéo đi từ tư thế đặt tên lên dây tới kéo đầy,
## Player tua theo độ kéo nên độ dài clip không quan trọng.
## Tên xương và đường dẫn skeleton truyền vào, nên dùng được cho rig có cách đặt tên khác.

## DRAWN: kéo đầy của Bow_Shoot (cung cầm dọc); FULL: kéo đầy khi cầm ngang ở BowHold
enum Pose { REST, NOCKED, DRAWN, FULL }

const SHOT: AttackData = preload("res://resources/combat/attacks/bow/bow_shot.tres")
const BOW: BowData = preload("res://resources/combat/weapons/bow.tres")
const ROLES: Array[StringName] = [&"upper_l", &"fore_l", &"hand_l", &"upper_r", &"fore_r", &"hand_r"]
## Hướng xương theo tư thế, trong không gian rig (+Z là hướng bắn, tay phải ở +X).
## "_l" cho tay trái (cả cánh tay trên nếu không có "upper_l"); "_r" cho cẳng tay và bàn tay phải
const DIRECTIONS: Dictionary = {
	Pose.REST: {&"_l": Vector3(0.1, -0.65, 0.76), &"upper_r": Vector3(0.25, -0.75, 0.65), &"_r": Vector3(-0.65, 0.15, 0.8)},
	Pose.DRAWN: {&"_l": Vector3(0.25, 0.12, 1), &"upper_r": Vector3(0.75, 0.2, -0.25), &"_r": Vector3(-0.8, 0.15, 0.65)},
	# NOCKED / FULL tính theo hướng nhắm (+Z là mục tiêu, người đứng nghiêng), được xoay theo aim_yaw khi dựng.
	# Tay trái duỗi thẳng về phía mục tiêu sát theo vai, nắm phần tay cầm lệch về phía lưng so với đường tên
	# (đường tên ở trước ngực) để mũi tên không xuyên qua tay; tay phải với tới dây
	Pose.NOCKED: {&"_l": Vector3(0.112, 0, 0.994), &"upper_r": Vector3(0.27, 0, 0.96), &"_r": Vector3(0.27, 0, 0.96)},
	# Kéo đầy: khuỷu phải chĩa ra sau ngang vai, bàn tay kéo dây về sát má phải trên đường tên
	Pose.FULL: {&"_l": Vector3(0.112, 0, 0.994), &"upper_r": Vector3(0.5, 0.1, -0.75), &"_r": Vector3(0.165, 0.06, 0.985)},
}
## Mức áp dụng tư thế thân (xoay, nghiêng, cúi đầu) theo từng Pose; Pose không có trong bảng = 0
const BODY_WEIGHT: Dictionary = {Pose.NOCKED: 1.0, Pose.FULL: 1.0}
## Độ dài clip kéo (s); bị tua theo độ kéo nên chỉ cần > 0
const DRAW_CLIP_LENGTH: float = 1.0


## body: {"bones": {spine, chest, neck, head -> tên xương}, "twist", "lean", "head_tilt", "head_turn", "aim_yaw": độ}.
## Rỗng = không đụng thân.
## aim_yaw: góc (quanh trục đứng của rig) giữa mặt nhân vật và hướng nhắm khi đứng nghiêng
static func install(library: AnimationLibrary, skeleton: Skeleton3D, skeleton_path: NodePath, bones: Dictionary,
		body: Dictionary = {}) -> void:
	# Thân xoay kéo theo cả hai tay: trừ phần xoay đó để tay vẫn chĩa đúng hướng nhắm
	var twist := deg_to_rad(float(body.get("twist", 0.0))) * -_right_side_sign(skeleton, bones)
	var arm_yaw := deg_to_rad(float(body.get("aim_yaw", 0.0))) - twist
	for clip: StringName in [&"Idle", &"Run"]:
		if not library.has_animation(clip):
			continue
		var animation := library.get_animation(clip).duplicate() as Animation
		_replace_arm_tracks(animation, skeleton, skeleton_path, bones, [[0.0, Pose.REST], [animation.length, Pose.REST]])
		library.add_animation(StringName("%s_Bow" % clip), animation)
	if not library.has_animation(&"Idle"):
		return
	var shot_length := SHOT.duration * SHOT.anim_speed
	var release := SHOT.active_start * SHOT.anim_speed
	library.add_animation(&"Bow_Shoot", _make_clip(library, skeleton, skeleton_path, bones, shot_length, [
		[0.0, Pose.REST], [release * 0.75, Pose.DRAWN], [release, Pose.DRAWN],
		[lerpf(release, shot_length, 0.55), Pose.REST], [shot_length, Pose.REST],
	]))
	var draw_keys := [[0.0, Pose.NOCKED], [DRAW_CLIP_LENGTH, Pose.FULL]]
	var draw := _make_clip(library, skeleton, skeleton_path, bones, DRAW_CLIP_LENGTH, draw_keys, arm_yaw)
	_replace_body_tracks(draw, skeleton, skeleton_path, bones, body, draw_keys)
	library.add_animation(BOW.draw_animation, draw)
	# Buông: tay phải bật về chỗ dây rồi hạ cung, vừa hết thời gian thu tay
	var recovery := maxf(BOW.release_recovery, 0.05)
	var release_keys := [[0.0, Pose.FULL], [recovery * 0.3, Pose.NOCKED], [recovery, Pose.REST]]
	var release_clip := _make_clip(library, skeleton, skeleton_path, bones, recovery, release_keys, arm_yaw)
	_replace_body_tracks(release_clip, skeleton, skeleton_path, bones, body, release_keys)
	library.add_animation(BOW.release_animation, release_clip)


## Clip một lần (không lặp) dựa trên Idle, chỉ thay track tay
static func _make_clip(library: AnimationLibrary, skeleton: Skeleton3D, skeleton_path: NodePath, bones: Dictionary,
		length: float, keys: Array, aim_yaw: float = 0.0) -> Animation:
	var animation := library.get_animation(&"Idle").duplicate() as Animation
	animation.length = length
	animation.loop_mode = Animation.LOOP_NONE
	_replace_arm_tracks(animation, skeleton, skeleton_path, bones, keys, aim_yaw)
	return animation


## keys: mảng [thời điểm, Pose]; aim_yaw (rad) xoay các tư thế nhắm (có trong BODY_WEIGHT) về hướng nhắm
static func _replace_arm_tracks(animation: Animation, skeleton: Skeleton3D, skeleton_path: NodePath,
		bones: Dictionary, keys: Array, aim_yaw: float = 0.0) -> void:
	var poses := {}
	for key: Array in keys:
		var pose: Pose = key[1]
		if not poses.has(pose):
			poses[pose] = _arm_pose(skeleton, bones, pose, aim_yaw if BODY_WEIGHT.has(pose) else 0.0)
	for role: StringName in ROLES:
		var bone: StringName = bones[role]
		var path := NodePath("%s:%s" % [skeleton_path, bone])
		var track := animation.find_track(path, Animation.TYPE_ROTATION_3D)
		if track >= 0:
			animation.remove_track(track)
		track = animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, path)
		for key: Array in keys:
			var pose_bones: Dictionary = poses[key[1]]
			if pose_bones.has(role):
				animation.rotation_track_insert_key(track, key[0], pose_bones[role])


## Thân xoay sang trái (chia đều spine / chest), spine nghiêng tới trước, cổ + đầu quay về mục tiêu, đầu cúi.
## Góc cộng thêm vào tư thế nghỉ của xương, quanh trục của rig nên không phụ thuộc cách đặt trục từng xương
static func _replace_body_tracks(animation: Animation, skeleton: Skeleton3D, skeleton_path: NodePath,
		arm_bones: Dictionary, body: Dictionary, keys: Array) -> void:
	if body.is_empty():
		return
	var body_bones: Dictionary = body.get("bones", {})
	# Bên trái nhân vật ngược phía tay phải: rig có tay phải ở -X thì bên trái là +X
	var left_sign := -_right_side_sign(skeleton, arm_bones)
	var twist := deg_to_rad(float(body.get("twist", 0.0))) * left_sign
	var lean := deg_to_rad(float(body.get("lean", 0.0)))
	var tilt := deg_to_rad(float(body.get("head_tilt", 0.0)))
	# Cùng quy ước với aim_yaw: dương = quay về +X của rig
	var turn := deg_to_rad(float(body.get("head_turn", 0.0)))
	# role -> [trục quay trong không gian rig, góc]: nghiêng tới trước = đỉnh đổ về +Z = quay quanh +X.
	# Quay đầu chia cho cổ và đầu để cổ không gãy gập
	var rotations := {
		&"spine": [[Vector3.UP, twist * 0.5], [Vector3.RIGHT, lean]],
		&"chest": [[Vector3.UP, twist * 0.5]],
		&"neck": [[Vector3.UP, turn * 0.4]],
		&"head": [[Vector3.UP, turn * 0.6], [Vector3.RIGHT, tilt]],
	}
	for role: StringName in rotations:
		var bone: StringName = body_bones.get(role, &"")
		var index := skeleton.find_bone(bone)
		if index < 0:
			push_warning("Thiếu xương %s cho tư thế giương cung" % bone)
			continue
		var global_rest := skeleton.get_bone_global_rest(index).basis.orthonormalized()
		var rest := skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
		var path := NodePath("%s:%s" % [skeleton_path, bone])
		var track := animation.find_track(path, Animation.TYPE_ROTATION_3D)
		if track >= 0:
			animation.remove_track(track)
		track = animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, path)
		for key: Array in keys:
			var weight: float = BODY_WEIGHT.get(key[1], 0.0)
			var extra := Quaternion.IDENTITY
			for spec: Array in rotations[role]:
				var axis: Vector3 = (global_rest.inverse() * (spec[0] as Vector3)).normalized()
				extra = extra * Quaternion(axis, float(spec[1]) * weight)
			animation.rotation_track_insert_key(track, key[0], rest * extra)


static func _arm_pose(skeleton: Skeleton3D, bones: Dictionary, pose: Pose, yaw: float = 0.0) -> Dictionary:
	var result := {}
	var table: Dictionary = DIRECTIONS[pose]
	# Tay phải của rig nằm bên -X thì lật hướng
	var mirror_x := _right_side_sign(skeleton, bones)
	var world_bases := {}
	for role: StringName in ROLES:
		var bone: StringName = bones[role]
		var direction: Vector3
		if role == &"upper_l" and table.has(&"upper_l"):
			# Có hướng riêng cho cánh tay trên trái = tay trái gập khuỷu
			direction = table[&"upper_l"]
		elif String(role).ends_with("_l"):
			direction = table[&"_l"]
		elif role == &"upper_r":
			direction = table[&"upper_r"]
		else:
			direction = table[&"_r"]
		# Hướng gốc dựng cho rig có tay phải ở +X; rig khác bên thì lật trục X
		direction.x *= mirror_x
		direction = direction.rotated(Vector3.UP, yaw)
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
