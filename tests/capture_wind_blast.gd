extends Node
## Chụp skill thổi gió (Wind Blast) bằng camera game trong Level 1, trên nền tối (cỏ) và nền sáng (cao nguyên sách).
## Chạy có cửa sổ: godot --path . --resolution 1280x720 res://tests/capture_wind_blast.tscn
## Ảnh lưu vào SHOT_DIR. APPDATA/LOCALAPPDATA nên trỏ vào .godot/... để không đụng save thật.

const LEVEL_SCENE: PackedScene = preload("res://levels/zone_1_wind/level_1/level_1.tscn")
const WIND_BLAST: AbilityData = preload("res://abilities/wind_blast/wind_blast.tres")
## Mốc chụp tính từ lúc bấm E (s, thời gian thật)
const SHOT_TIMES: Array[float] = [0.06, 0.14, 0.2, 0.28, 0.4, 0.6]

## [tên, vị trí player, hướng thổi]
var spots: Array = [
	["dark", Vector3(0, 0.2, 4), Vector3.LEFT],
	["light", Vector3(33, 12.2, -188), Vector3.FORWARD],
]

var _dir: String


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir.is_empty():
		_dir = ProjectSettings.globalize_path("user://shots")
	DirAccess.make_dir_recursive_absolute(_dir)
	GameState.replace_progress(PlayerProgress.new())
	var level := LEVEL_SCENE.instantiate() as Node3D
	add_child(level)
	await get_tree().physics_frame
	var player := level.get_node("Player") as Player
	player.get_node("HurtboxComponent").set_invincible(1.0e6)
	player.unlock_ability(WIND_BLAST)
	for spot: Array in spots:
		player.teleport(spot[1], spot[2])
		await get_tree().create_timer(1.2).timeout
		Input.action_press(&"skill")
		var start := Time.get_ticks_msec()
		var released := false
		for t in SHOT_TIMES:
			while (Time.get_ticks_msec() - start) / 1000.0 < t:
				await get_tree().process_frame
				if not released and (Time.get_ticks_msec() - start) > 60:
					Input.action_release(&"skill")
					released = true
			await RenderingServer.frame_post_draw
			var path := _dir.path_join("%s_%03d.png" % [spot[0], int(t * 1000)])
			get_viewport().get_texture().get_image().save_png(path)
			print("SHOT ", path)
		await get_tree().create_timer(0.8).timeout
	get_tree().quit()
