class_name ForgeShardSet
extends Resource
## Bộ mảnh vỡ của một khu: danh sách cờ của từng mảnh. HUD đếm mảnh và bệ công tắc dùng chung dữ liệu này,
## nên thêm/bớt mảnh chỉ cần sửa file .tres.

## Cờ của từng mảnh (trùng key_id của mảnh nằm trên đất)
@export var shard_flags: Array[StringName] = []
## Chữ hiện trên HUD; %d đầu là số đã nhặt, %d sau là tổng
@export var label_format: String = "Mảnh vỡ %d/%d"


func total() -> int:
	return shard_flags.size()


func collected_count() -> int:
	var count: int = 0
	for flag: StringName in shard_flags:
		if GameState.has_flag(flag):
			count += 1
	return count


func label_text() -> String:
	return label_format % [collected_count(), total()]
