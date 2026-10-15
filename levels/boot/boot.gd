extends Node
## Scene khởi động (main scene): có checkpoint đã lưu thì vào đúng chỗ đó, chưa có thì vào khu đầu game
## (SceneManager.START_ZONE).


func _ready() -> void:
	# Đổi scene ngay trong _ready của scene đang tải không an toàn, đợi sang frame sau
	SceneManager.go_to_last_checkpoint.call_deferred()
