extends Node
## Scene khởi động (main scene): mở menu chính. Menu chọn hồ sơ rồi mới vào khu (SceneManager).

const MAIN_MENU := "res://ui/menus/main/main_menu.tscn"


func _ready() -> void:
	# Đổi scene ngay trong _ready của scene đang tải không an toàn, đợi sang frame sau
	get_tree().change_scene_to_file.call_deferred(MAIN_MENU)
