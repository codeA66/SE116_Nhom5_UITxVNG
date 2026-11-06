class_name ZoneCameraView
extends Node
## Đặt góc camera riêng cho khu khi player xuất hiện. Gắn làm con của ZoneRoot, nghe player_spawned.

@export var view: CameraViewData


func _ready() -> void:
	var root := get_parent() as ZoneRoot
	if root == null:
		push_error("%s: phải là con của ZoneRoot" % get_path())
		return
	root.player_spawned.connect(_on_player_spawned)


func _on_player_spawned(player: Player) -> void:
	for rig in get_tree().get_nodes_in_group(CameraRig.GROUP):
		if player.is_ancestor_of(rig):
			(rig as CameraRig).apply_view(view)
