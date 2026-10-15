class_name ZoneRoot
extends Node3D
## Gốc của một khu (gắn vào node gốc mỗi scene khu). Khi khu tải xong, đặt player vào điểm xuất hiện
## mà SceneManager yêu cầu, hoặc điểm mặc định. Khu không cần tự chứa player.

const PLAYER_SCENE := preload("res://entities/player/player.tscn")

## Dùng khi vào khu không qua cổng hay checkpoint (mở game lần đầu, chạy thử scene bằng F6)
@export var default_spawn_id: StringName = &"start"


func _ready() -> void:
	var spawn := SpawnPoint.find_in(self, SceneManager.consume_pending_spawn_id())
	if spawn == null:
		spawn = SpawnPoint.find_in(self, default_spawn_id)

	var player := get_node_or_null(^"Player") as Player
	if player == null:
		player = PLAYER_SCENE.instantiate() as Player
		add_child(player)

	if spawn:
		player.teleport(spawn.global_position, spawn.get_facing())
	else:
		push_warning("%s: không có SpawnPoint '%s', player giữ vị trí ban đầu" % [name, default_spawn_id])
	SceneManager.notify_zone_ready()
