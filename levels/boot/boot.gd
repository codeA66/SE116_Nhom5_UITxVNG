extends Node
## Scene khởi động (main scene): có checkpoint đã lưu thì vào đúng chỗ đó, chưa có thì vào khu đầu tiên.

@export_file("*.tscn") var first_zone: String


func _ready() -> void:
	# Đổi scene ngay trong _ready của scene đang tải không an toàn, đợi sang frame sau
	_start.call_deferred()


func _start() -> void:
	if GameState.has_checkpoint():
		SceneManager.change_zone(GameState.get_checkpoint_zone(), GameState.get_checkpoint_spawn_id())
	else:
		SceneManager.change_zone(first_zone)
