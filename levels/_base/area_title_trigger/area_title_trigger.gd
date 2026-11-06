class_name AreaTitleTrigger
extends Node
## Gọi chữ giới thiệu khu vực (autoload AreaTitle) cho một nơi. Cắm bằng signal ngay trong scene:
## ZoneRoot.combat_ready -> announce (vào khu, sau khi màn đen rút), TierZone.player_entered -> announce (vào vùng con).
## Nhiều vùng = nhiều node, mỗi node giữ AreaData của mình; không sửa ZoneRoot / TierZone.

@export var area: AreaData
## Lần đầu tới khu có cutscene giới thiệu: đợi cutscene diễn xong mới hiện chữ (đã xem rồi thì hiện ngay)
@export var wait_for_cutscene: CameraCutscene


func _ready() -> void:
	# Khu đang nạp (màn còn đen): vẽ sẵn chữ để lúc hiện không khựng
	AreaTitle.prepare(area)


## Tham số mặc định để nối được cả signal không tham số (combat_ready, player_entered) lẫn có tham số
func announce(_source: Variant = null) -> void:
	if area == null:
		push_warning("%s: chưa gán AreaData" % get_path())
		return
	if _cutscene_pending():
		if not wait_for_cutscene.finished.is_connected(_show):
			wait_for_cutscene.finished.connect(_show, CONNECT_ONE_SHOT)
		return
	_show()


func _cutscene_pending() -> bool:
	return wait_for_cutscene != null and not wait_for_cutscene.persistent_id.is_empty() \
		and not GameState.has_flag(wait_for_cutscene.persistent_id)


func _show() -> void:
	AreaTitle.announce(area)
