extends SceneTree
## Giữ nguyên nhịp cào gốc, kéo dài động tác thu tay 0.2 -> 0.7 giây để đọc đòn rõ hơn.
const BASE: String = "res://assets/models/enemies/blenderimport/armored_polar_bear/animations/"
const EXTRA: float = 0.5
const ORIGINAL_WINDUP: float = 0.2

func _initialize() -> void:
	_bake.call_deferred()

func _bake() -> void:
	var source: Animation = (load(BASE + "combat_melee.tres") as AnimationLibrary).get_animation(&"Melee_Dualwield_Slash")
	var result: Animation = source.duplicate(true) as Animation
	result.length = source.length + EXTRA
	result.loop_mode = Animation.LOOP_NONE
	for track: int in source.get_track_count():
		var type: Animation.TrackType = source.track_get_type(track)
		if type not in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D, Animation.TYPE_SCALE_3D]: continue
		while result.track_get_key_count(track) > 0: result.track_remove_key(track, 0)
		var count: int = ceili(result.length * 60.0)
		for i: int in count + 1:
			var time: float = minf(float(i) / 60.0, result.length)
			var at: float = time - EXTRA
			if time < ORIGINAL_WINDUP + EXTRA:
				at = ORIGINAL_WINDUP * smoothstep(0.0, ORIGINAL_WINDUP + EXTRA, time)
			if type == Animation.TYPE_ROTATION_3D:
				result.rotation_track_insert_key(track, time, source.rotation_track_interpolate(track, at))
			elif type == Animation.TYPE_POSITION_3D:
				result.position_track_insert_key(track, time, source.position_track_interpolate(track, at))
			else:
				result.scale_track_insert_key(track, time, source.scale_track_interpolate(track, at))
	var library: AnimationLibrary = AnimationLibrary.new()
	library.add_animation(&"Claw_Windup", result)
	var error: Error = ResourceSaver.save(library, BASE + "bear_actions.tres")
	var manifest: String = "res://assets/models/enemies/blenderimport/animation_manifest.json"
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest)) as Dictionary
	for kind: String in report:
		var entry: Dictionary = report[kind] as Dictionary
		entry["bones"] = int(entry["bones"])
	report["armored_polar_bear"]["clips"]["BearActions/Claw_Windup"] = {"length": result.length, "root_distance": 0.0}
	var file: FileAccess = FileAccess.open(manifest, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t", true) + "\n")
	file.close()
	print("BEAR_WINDUP_BAKED length=", result.length, " error=", error)
	quit(0 if error == OK else 1)
