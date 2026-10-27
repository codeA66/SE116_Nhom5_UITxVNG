extends SceneTree
## Chạy một lần sau import; ghi thư viện có đường dẫn đúng và tách tiến ngang khỏi model.
const BASE: String = "res://assets/models/enemies/blenderimport/"
const MODELS: Dictionary[String, String] = {
	"monkey_chieftain": "Monkey_Chieftain", "monkey_grunt": "Monkey_Grunt", "armored_polar_bear": "Armored_Polar_Bear_Large",
}
var _report: Dictionary = {}

func _initialize() -> void:
	_bake.call_deferred()

func _find(root_node: Node, type_name: String) -> Node:
	if root_node.is_class(type_name): return root_node
	for child: Node in root_node.get_children():
		var found: Node = _find(child, type_name)
		if found != null: return found
	return null

func _bake() -> void:
	for kind: String in MODELS:
		var path: String = BASE + kind + "/" + MODELS[kind] + ".glb"
		var model: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		var skeleton: Skeleton3D = _find(model, "Skeleton3D") as Skeleton3D
		var output: String = BASE + kind + "/animations"
		DirAccess.make_dir_recursive_absolute(output)
		var groups: Array[String] = []
		groups.assign([""] if kind != "armored_polar_bear" else ["General", "MovementBasic", "MovementAdvanced", "CombatMelee", "Simulation", "Special"])
		var clips: Dictionary = {}
		for group: String in groups:
			var source: Node3D = model
			if not group.is_empty():
				source = (load(BASE + kind + "/rig_large/Rig_Large_" + group + ".glb") as PackedScene).instantiate() as Node3D
				root.add_child(source)
			var player: AnimationPlayer = _find(source, "AnimationPlayer") as AnimationPlayer
			var source_skeleton: Skeleton3D = _find(source, "Skeleton3D") as Skeleton3D
			var anim_root: Node = player.get_node(player.root_node)
			var library: AnimationLibrary = AnimationLibrary.new()
			for clip: StringName in player.get_animation_list():
				if clip == &"RESET": continue
				var normalized: String = String(clip).trim_suffix("_Loop")
				if player.has_animation(&"RESET"):
					player.play(&"RESET"); player.seek(0.0, true); player.advance(0.0)
				player.play(clip); player.seek(0.0, true); player.advance(0.0)
				var start: Vector3 = source_skeleton.global_position
				var animation: Animation = player.get_animation(clip).duplicate(true) as Animation
				var motion: Curve = Curve.new()
				motion.min_value = -100.0; motion.max_value = 100.0
				var samples: int = maxi(2, ceili(animation.length * 60.0) + 1)
				for i: int in range(samples):
					var ratio: float = float(i) / float(samples - 1)
					player.seek(animation.length * ratio, true); player.advance(0.0)
					motion.add_point(Vector2(ratio, source_skeleton.global_position.z - start.z), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
				animation.set_meta(&"root_forward_curve", motion)
				animation.set_meta(&"root_forward_distance", motion.sample(1.0))
				for track: int in range(animation.get_track_count()):
					var old_path: NodePath = animation.track_get_path(track)
					var source_node: Node = anim_root.get_node_or_null(NodePath(old_path.get_concatenated_names()))
					assert(source_node != null, str(old_path))
					var target_path: String
					if source_node is Skeleton3D and old_path.get_subname_count() == 1:
						assert(skeleton.find_bone(old_path.get_subname(0)) >= 0)
						target_path = "Visual/Rig/" + str(model.get_path_to(skeleton)) + ":" + str(old_path.get_subname(0))
					else:
						target_path = "Visual/Rig/" + str(source.get_path_to(source_node))
						if animation.track_get_type(track) == Animation.TYPE_POSITION_3D:
							var initial: Vector3 = animation.track_get_key_value(track, 0)
							for key: int in range(animation.track_get_key_count(track)):
								var value: Vector3 = animation.track_get_key_value(track, key)
								value.x = initial.x; value.z = initial.z
								animation.track_set_key_value(track, key, value)
					animation.track_set_path(track, NodePath(target_path))
				var loop: bool = "Idle" in normalized or "Walking" in normalized or "Running" in normalized or "Locomotion" in normalized or normalized.ends_with("Fast") or normalized.ends_with("RootMotion") or normalized == "Gorilla_ChestBeat"
				animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
				library.add_animation(normalized, animation)
				clips[(group + "/" if not group.is_empty() else "") + normalized] = {"length": animation.length, "root_distance": motion.sample(1.0)}
			var save_path: String = output + "/" + ("all" if group.is_empty() else group.to_snake_case()) + ".tres"
			assert(ResourceSaver.save(library, save_path) == OK)
			if source != model: source.free()
		var bounds: AABB = AABB()
		var has_bounds: bool = false
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh: MeshInstance3D = node as MeshInstance3D
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			bounds = bounds.merge(box) if has_bounds else box; has_bounds = true
		_report[kind] = {"bones": skeleton.get_bone_count(), "clips": clips, "bounds": str(bounds)}
		model.free()
	var manifest: FileAccess = FileAccess.open(BASE + "animation_manifest.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify(_report, "\t")); manifest.close()
	print("NEW_ENEMY_ANIMATIONS_BAKED ", JSON.stringify(_report))
	quit()
