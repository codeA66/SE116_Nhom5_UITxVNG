class_name StatModifiers
extends Node
## Chỉ số cộng dồn từ nhiều nguồn (bùa, buff tạm...): mỗi nguồn đặt / gỡ riêng.
## Hai kiểu: hệ số nhân (tốc độ chém...) và số cộng (máu tối đa...). Nhiều nguồn cùng chỉ số: nhân với nhau / cộng lại.
## Ai đọc chỉ số thì gọi get_multiplier() / get_bonus() lúc cần hoặc nghe changed, không có _process.
## Thêm chỉ số mới không cần sửa file này: tên chỉ số là StringName do nơi đọc tự đặt.

## Phát một lần cho mỗi chỉ số đổi giá trị; trong lúc gom (begin_batch) thì để dành tới end_batch
signal changed(stat: StringName)

## stat -> {nguồn -> giá trị}
var _multipliers: Dictionary[StringName, Dictionary] = {}
var _bonuses: Dictionary[StringName, Dictionary] = {}
## Kết quả đã tính sẵn: đọc không phải duyệt nguồn
var _multiplier_totals: Dictionary[StringName, float] = {}
var _bonus_totals: Dictionary[StringName, float] = {}
var _batch_depth: int = 0
var _pending: Dictionary[StringName, bool] = {}


func _ready() -> void:
	set_process(false)
	set_physics_process(false)


func get_multiplier(stat: StringName) -> float:
	return _multiplier_totals.get(stat, 1.0)


func get_bonus(stat: StringName) -> float:
	return _bonus_totals.get(stat, 0.0)


func set_multiplier(stat: StringName, source: StringName, value: float) -> void:
	_set_source(_multipliers, stat, source, value)


func remove_multiplier(stat: StringName, source: StringName) -> void:
	_remove_source(_multipliers, stat, source)


func set_bonus(stat: StringName, source: StringName, value: float) -> void:
	_set_source(_bonuses, stat, source, value)


func remove_bonus(stat: StringName, source: StringName) -> void:
	_remove_source(_bonuses, stat, source)


## Gỡ rồi áp lại nhiều nguồn mà người nghe chỉ thấy kết quả cuối:
## không có khoảnh khắc "chưa có bùa" làm máu bị kẹp xuống rồi mất luôn
func begin_batch() -> void:
	_batch_depth += 1


func end_batch() -> void:
	_batch_depth = maxi(_batch_depth - 1, 0)
	if _batch_depth > 0:
		return
	var stats := _pending.keys()
	_pending.clear()
	for stat: StringName in stats:
		changed.emit(stat)


func _set_source(table: Dictionary[StringName, Dictionary], stat: StringName, source: StringName, value: float) -> void:
	if not table.has(stat):
		table[stat] = {}
	table[stat][source] = value
	_recompute(stat)


func _remove_source(table: Dictionary[StringName, Dictionary], stat: StringName, source: StringName) -> void:
	if not table.has(stat) or not table[stat].has(source):
		return
	table[stat].erase(source)
	_recompute(stat)


func _recompute(stat: StringName) -> void:
	var old_multiplier := get_multiplier(stat)
	var old_bonus := get_bonus(stat)
	var multiplier := 1.0
	for value: float in _multipliers.get(stat, {}).values():
		multiplier *= value
	var bonus := 0.0
	for value: float in _bonuses.get(stat, {}).values():
		bonus += value
	if is_equal_approx(multiplier, 1.0):
		_multiplier_totals.erase(stat)
	else:
		_multiplier_totals[stat] = multiplier
	if is_zero_approx(bonus):
		_bonus_totals.erase(stat)
	else:
		_bonus_totals[stat] = bonus
	if is_equal_approx(old_multiplier, get_multiplier(stat)) and is_equal_approx(old_bonus, get_bonus(stat)):
		return
	if _batch_depth > 0:
		_pending[stat] = true
	else:
		changed.emit(stat)
