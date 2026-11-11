extends SceneTree
## Chép clip của file .glb quái ra AnimationLibrary dùng cho AnimationPlayer của quái (root_node = Model):
## đổi đường dẫn track "<Model>/Rig/Skeleton3D:..." thành "Visual/<tên instance>/<Model>/...", đặt lặp cho clip đi / đứng.
## Chạy lại sau mỗi lần dựng lại model. Không truyền tên thì chép tất cả:
##   godot --headless --path . -s res://assets/models/enemies/_tools/extract_enemy_animations.gd -- fire_caster shadow_wolf

## tên -> [glb nguồn, thư viện đích, tiền tố đường dẫn (tên node instance trong scene quái), clip lặp]
const MODELS := {
	"fire_caster": ["res://assets/models/enemies/fire_caster/fire_caster.glb",
		"res://assets/models/enemies/fire_caster/fire_caster_animations.tres",
		"Visual/FireCasterModel/", [&"Idle", &"Walk"]],
	"shadow_wolf": ["res://assets/models/enemies/shadow_wolf/shadow_wolf.glb",
		"res://assets/models/enemies/shadow_wolf/shadow_wolf_animations.tres",
		"Visual/ShadowWolfModel/", [&"Idle", &"Walk", &"Run", &"Stalk"]],
	"lava_slime": ["res://assets/models/enemies/lava_slime/lava_slime.glb",
		"res://assets/models/enemies/lava_slime/lava_slime_animations.tres",
		"Visual/LavaSlimeModel/", [&"Idle", &"Walk"]],
}


func _init() -> void:
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	for key: String in MODELS:
		if wanted.is_empty() or key in wanted:
			_extract(MODELS[key])
	quit()


func _extract(spec: Array) -> void:
	var model: Node = (load(spec[0]) as PackedScene).instantiate()
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var library := AnimationLibrary.new()
	for anim_name: StringName in player.get_animation_list():
		var anim := player.get_animation(anim_name).duplicate(true) as Animation
		for track: int in range(anim.get_track_count()):
			anim.track_set_path(track, NodePath(spec[2] + String(anim.track_get_path(track))))
		anim.loop_mode = Animation.LOOP_LINEAR if anim_name in spec[3] else Animation.LOOP_NONE
		library.add_animation(anim_name, anim)
	var error := ResourceSaver.save(library, spec[1])
	print("EXTRACT %s: %s %s" % [spec[1], "OK" if error == OK else "lỗi %d" % error, library.get_animation_list()])
	model.free()
