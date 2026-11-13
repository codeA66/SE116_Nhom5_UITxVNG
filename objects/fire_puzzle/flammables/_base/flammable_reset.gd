class_name FlammableReset
extends Node
## Dựng lại các vật dễ cháy (không có persistent_id) khi player rời phòng: đốt nhầm cầu treo / đồ chắn lối không làm kẹt
## vĩnh viễn, ra vào lại phòng là thử lại được. Vật có persistent_id (dây leo chắn lối ra) giữ nguyên khi đã cháy.
## Hiệu năng: chỉ nghe signal player_exited của vùng phòng.

## Vùng phòng (TierZone của RoomFocus)
@export var zone: TierZone
## Gốc chứa các vật cần dựng lại (quét con trực tiếp lúc reset)
@export var targets_root: Node


func _ready() -> void:
	if zone == null or targets_root == null:
		push_error("%s: chưa gán zone / targets_root" % get_path())
		return
	zone.player_exited.connect(reset_all)


func reset_all() -> void:
	for child: Node in targets_root.get_children():
		if child is Flammable:
			(child as Flammable).reset()
