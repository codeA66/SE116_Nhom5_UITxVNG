class_name TntItemData
extends QuickItemData
## TNT: đặt một khối thuốc nổ ở chỗ nhắm (trong tầm aim_range); khối chỉ nổ khi chạm lửa (TntBlock).
## Dùng không giới hạn, mỗi player chỉ một khối: khối tạo một lần (lưu trong state của QuickItemUser) rồi dùng lại,
## đặt lần nữa là dời khối cũ sang chỗ mới.

## Scene khối thuốc nổ (TntBlock)
@export var block_scene: PackedScene
## Animation đặt xuống (qua Character.play_action, không đổi state của player). Trống = không chạy
@export var animation: StringName = &"Rig_Medium_General/PickUp"
@export_range(0.1, 4.0, 0.05) var anim_speed: float = 1.8


func use(player: Player, state: Dictionary, target: Vector3) -> bool:
	if block_scene == null:
		push_error("TntItemData chưa gán block_scene")
		return false
	var block: TntBlock = get_block(state)
	if block == null:
		block = block_scene.instantiate() as TntBlock
		player.get_parent().add_child(block)
		state[&"block"] = block
	var away := Vector3(target.x - player.global_position.x, 0.0, target.z - player.global_position.z)
	block.place(target, atan2(away.x, away.z) if away.length_squared() > 0.0001 else player.rotation.y, player)
	if not animation.is_empty():
		if away.length_squared() > 0.0001:
			player.face_instantly(away.normalized())
		player.play_action(animation, anim_speed)
	return true


## Khối đã đặt của player (state của QuickItemUser); null nếu chưa đặt lần nào
func get_block(state: Dictionary) -> TntBlock:
	var block: Variant = state.get(&"block")
	return block as TntBlock if is_instance_valid(block) else null


## Dò sàn bỏ qua khối cũ: đặt lại đúng chỗ khối cũ không bị đặt chồng lên nóc khối
func get_probe_exclude(state: Dictionary) -> Array[RID]:
	var block := get_block(state)
	return [block.get_rid()] if block else []
