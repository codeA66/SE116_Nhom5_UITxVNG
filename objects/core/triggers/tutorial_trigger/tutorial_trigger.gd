class_name TutorialTrigger
extends Area3D
## Vùng kích hoạt hướng dẫn 1 lần trong thế giới:
## - Khi Player bước vào vùng, HOẶC sau khi cutscene kết thúc (nếu có wait_for_cutscene).
## - Kiểm tra nếu chưa mở khóa thì mở khóa (hiện popup 1 lần và lưu vào Sổ Hướng Dẫn).
## - Đã mở khóa rồi thì node tự giải phóng (queue_free) để tránh kiểm tra dư thừa.

@export var tutorial: TutorialData
## Danh sách nhiều bài hướng dẫn kích hoạt nối tiếp (ví dụ: di chuyển -> lướt)
@export var tutorials: Array[TutorialData] = []
@export var tutorial_id: StringName = &""
## Nếu gán cutscene: chờ cutscene chiếu xong mới kích hoạt popup
@export var wait_for_cutscene: CameraCutscene
## Thời gian chờ sau khi cutscene kết thúc trước khi hiện popup (giây)
@export var delay_after_cutscene: float = 0.5


func _ready() -> void:
	if not _has_pending_tutorials():
		queue_free()
		return
	
	if _cutscene_pending():
		monitoring = false
		wait_for_cutscene.finished.connect(_on_cutscene_finished, CONNECT_ONE_SHOT)
		return
	
	body_entered.connect(_on_body_entered)


func _has_pending_tutorials() -> bool:
	var all_tuts := _get_all_tutorials()
	if all_tuts.is_empty():
		return not tutorial_id.is_empty() and not GameState.has_tutorial(tutorial_id)
	for tut in all_tuts:
		if not GameState.has_tutorial(tut.id):
			return true
	return false


func _get_all_tutorials() -> Array[TutorialData]:
	var list: Array[TutorialData] = tutorials.duplicate()
	if tutorial and not list.has(tutorial):
		list.insert(0, tutorial)
	return list


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
	var all_tuts := _get_all_tutorials()
	if not all_tuts.is_empty():
		for tut in all_tuts:
			GameState.unlock_tutorial(tut)
	elif not tutorial_id.is_empty():
		GameState.unlock_tutorial(tutorial_id)
	queue_free()


func _get_target_id() -> StringName:
	var all_tuts := _get_all_tutorials()
	if not all_tuts.is_empty():
		return all_tuts[0].id
	return tutorial_id
