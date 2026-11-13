class_name ForgeShardSet
extends Resource
## Bộ mảnh vỡ của một khu: cờ của từng mảnh (đã nhặt), cờ đã đặt lên bệ, cờ công tắc khi đặt đủ.
## HUD đếm mảnh và bệ công tắc dùng chung dữ liệu này, nên thêm/bớt mảnh chỉ cần sửa file .tres.

## Cờ của từng mảnh (trùng key_id của mảnh nằm trên đất)
@export var shard_flags: Array[StringName] = []
## Cờ đã đặt mảnh lên bệ, cùng thứ tự với shard_flags
@export var placed_flags: Array[StringName] = []
## Cờ công tắc sáng (đặt đủ mảnh)
@export var switch_flag: StringName
## Chữ HUD khi chưa đặt mảnh nào: %d đã nhặt, %d tổng
@export var label_format: String = "Mảnh vỡ %d/%d"
## Chữ HUD khi đã đặt ít nhất một mảnh: đã nhặt, tổng, đã đặt, tổng
@export var placed_label_format: String = "Mảnh vỡ %d/%d · đã đặt %d/%d"


func total() -> int:
	return shard_flags.size()


func collected_count() -> int:
	return _count(shard_flags)


func placed_count() -> int:
	return _count(placed_flags)


func is_placed(index: int) -> bool:
	return index < placed_flags.size() and GameState.has_flag(placed_flags[index])


## Mảnh đang mang theo: đã nhặt mà chưa đặt
func is_carried(index: int) -> bool:
	return GameState.has_flag(shard_flags[index]) and not is_placed(index)


func label_text() -> String:
	var placed: int = placed_count()
	if placed == 0:
		return label_format % [collected_count(), total()]
	return placed_label_format % [collected_count(), total(), placed, total()]


func _count(flags: Array[StringName]) -> int:
	var count: int = 0
	for flag: StringName in flags:
		if GameState.has_flag(flag):
			count += 1
	return count
