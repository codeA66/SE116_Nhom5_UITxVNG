class_name TutorialTrigger
extends Area3D
## Vùng kích hoạt hướng dẫn 1 lần trong thế giới:
## - Khi Player bước vào vùng, HOẶC sau khi cutscene kết thúc (nếu có wait_for_cutscene).
## - Kiểm tra nếu chưa mở khóa thì mở khóa (hiện popup 1 lần và lưu vào Sổ Hướng Dẫn).
## - Đã mở khóa rồi thì node tự giải phóng (queue_free) để tránh kiểm tra dư thừa.

@export var tutorial: TutorialData
@export var tutorial_id: StringName = &""
## Nếu gán cutscene: chờ cutscene chiếu xong mới kích hoạt popup
@export var wait_for_cutscene: CameraCutscene
## Thời gian chờ sau khi cutscene kết thúc trước khi hiện popup (giây)
@export var delay_after_cutscene: float = 0.5


func _ready() -> void:
	var id := _get_target_id()
	if id.is_empty():
		return
	if GameState.has_tutorial(id):
		queue_free()
		return
	
	if _cutscene_pending():
		monitoring = false
		wait_for_cutscene.finished.connect(_on_cutscene_finished, CONNECT_ONE_SHOT)
		return
	
	body_entered.connect(_on_body_entered)


func _cutscene_pending() -> bool:
	return wait_for_cutscene != null and not wait_for_cutscene.persistent_id.is_empty() \
		and not GameState.has_flag(wait_for_cutscene.persistent_id)


func _on_cutscene_finished() -> void:
	if delay_after_cutscene > 0.0:
		await get_tree().create_timer(delay_after_cutscene).timeout
	_trigger_unlock()


func _on_body_entered(body: Node3D) -> void:
	if not (body is Player or body.is_in_group(&"player")):
		return
	_trigger_unlock()


func _trigger_unlock() -> void:
	if tutorial:
		GameState.unlock_tutorial(tutorial)
	elif not tutorial_id.is_empty():
		GameState.unlock_tutorial(tutorial_id)
	queue_free()


func _get_target_id() -> StringName:
	if tutorial:
		return tutorial.id
	return tutorial_id
