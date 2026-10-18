extends Node
## Chụp ảnh Level 1 ở các khu chính bằng camera game, để duyệt ánh sáng / bố cục.
## Chạy có cửa sổ: godot --path . --resolution 1280x720 res://tests/capture_level_1.tscn
## Ảnh lưu vào thư mục trong biến môi trường SHOT_DIR (mặc định user://shots). APPDATA nên trỏ vào .godot/lvl_runtime.

const LEVEL_SCENE: PackedScene = preload("res://levels/zone_1_wind/level_1/level_1.tscn")
## Thời gian chờ camera bám tới và hiệu ứng chạy ổn định trước khi chụp (s)
const SETTLE_TIME := 1.5

## [tên ảnh, vị trí player, cờ cần bật trước (kích hoạt trận)]
var shots: Array = [
	["01_start", Vector3(0, 0.2, 4), []],
	["02_tailwind", Vector3(11, 4.2, -42), []],
	["03_pulse_lane", Vector3(11, 4.2, -64), []],
	["04_updraft_yard", Vector3(15, 4.2, -86), []],
	["05_sword_yard", Vector3(15, 9.2, -126), [&"level_1.sword_pickup"]],
	["06_dock", Vector3(15, 9.2, -175), []],
	["07_book", Vector3(33, 12.2, -188), [&"level_1.wind_book"]],
	["08_far_shore", Vector3(15, 9.2, -222), []],
]


func _ready() -> void:
	var dir := OS.get_environment("SHOT_DIR")
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("user://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	GameState.replace_progress(PlayerProgress.new())
	var level := LEVEL_SCENE.instantiate() as Node3D
	add_child(level)
	await get_tree().physics_frame
	var player := level.get_node("Player") as Player
	player.get_node("HurtboxComponent").set_invincible(1.0e6)
	for shot: Array in shots:
		for flag: StringName in shot[2]:
			GameState.set_flag(flag)
		player.teleport(shot[1])
		await get_tree().create_timer(SETTLE_TIME).timeout
		await RenderingServer.frame_post_draw
		var path := dir.path_join(String(shot[0]) + ".png")
		get_viewport().get_texture().get_image().save_png(path)
		print("SHOT ", path)
	get_tree().quit()
