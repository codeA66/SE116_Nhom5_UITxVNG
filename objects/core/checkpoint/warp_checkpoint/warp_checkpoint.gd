class_name WarpCheckpoint
extends Node3D
## Checkpoint không có miếu, gắn với một WarpPortal: chỉ lưu khi cổng thật sự đưa player đi
## (ví dụ bệ đá cổ đã đủ đá → dịch chuyển vào tháp). Chết sau đó thì hồi sinh tại Spawn (trước bệ),
## mọi tiến trình sau lúc dịch chuyển (tầng đã dọn, boss) bị hoàn tác nhờ GameState.restore_checkpoint.
## Hiệu năng: chỉ nghe signal warped, không có _process.

## Tên checkpoint, duy nhất trong khu; cũng là tên điểm xuất hiện khi hồi sinh
@export var checkpoint_id: StringName
## Cổng kích hoạt lưu checkpoint
@export var portal: WarpPortal

@onready var _spawn: SpawnPoint = $Spawn


func _ready() -> void:
	_spawn.spawn_id = checkpoint_id
	set_process(false)
	set_physics_process(false)
	if portal == null or checkpoint_id.is_empty():
		push_warning("WarpCheckpoint '%s': thiếu portal hoặc checkpoint_id" % name)
		return
	portal.warped.connect(_on_portal_warped)


func is_active() -> bool:
	return GameState.get_checkpoint_zone() == _zone_path() and GameState.get_checkpoint_spawn_id() == checkpoint_id


func _on_portal_warped(body: Node3D) -> void:
	if body is Player:
		GameState.set_checkpoint(_zone_path(), checkpoint_id)


func _zone_path() -> String:
	return get_tree().current_scene.scene_file_path
