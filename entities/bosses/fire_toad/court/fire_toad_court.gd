class_name FireToadCourt
extends Node
## Hội Ếch Hoả Vương (kiểu "hội đồng" nhiều boss giống nhau): mở màn cả hội ngồi ngai, con dẫn đầu (lead) xuống đánh
## một mình; nó cúi chào về ngai thì các con còn lại (pair) cùng xuống đánh. Court chỉ điều phối: ai xuống lúc nào,
## skill nào được dùng (không chồng skill độc quyền, không dùng trùng skill cùng lúc), ai cuồng loạn, khi nào thắng.
## Hành vi từng con vẫn nằm trong state của FireToad. Thêm đợt / thêm con = gán thêm vào waves, không sửa code.

signal wave_started(index: int)
signal defeated

## Các đợt xuống sân theo thứ tự; mỗi đợt là danh sách đường dẫn tới FireToad
@export var waves: Array[FireToadWave] = []
## Chờ sau khi sân sẵn sàng rồi con đầu mới xuống (s)
@export_range(0.0, 10.0, 0.1) var intro_delay: float = 1.5
## Chờ giữa lúc đợt trước bị hạ hết và đợt sau xuống (s): đủ để con vừa thua cúi chào về ngai
@export_range(0.0, 10.0, 0.1) var wave_delay: float = 2.6
## Trong cùng đợt, con sau xuống trễ hơn con trước chừng này giây: lệch nhịp, không ra đòn đồng loạt
@export_range(0.0, 5.0, 0.05) var engage_stagger: float = 0.9
## Mỗi lúc chỉ một con trong sân được dùng các skill này (rút ra bệ ngoài, bay lên)
@export var exclusive_skills: Array[StringName] = [&"WebRetreat", &"Hover"]
## Còn một con cuối trong đợt thì nó cuồng loạn
@export var enrage_last_standing: bool = true
## Hạ hết rồi chờ chừng này giây (cả hội về ngai) mới cho cả hội biến mất
@export_range(0.0, 10.0, 0.1) var finale_delay: float = 1.0

var _wave_index: int = -1
var _active: Array[FireToad] = []
var _finished: bool = false


func _ready() -> void:
	for wave in waves:
		for toad in _wave_toads(wave):
			toad.court = self
			toad.defeat_state = &"Bow"
			toad.defeated.connect(_on_toad_defeated.bind(toad))
	_start.call_deferred()


## FireToad hỏi trước khi dùng skill
func allows_skill(toad: FireToad, skill: StringName) -> bool:
	var exclusive := skill in exclusive_skills
	for other in _active:
		if other == toad or not is_instance_valid(other) or other.health.is_dead():
			continue
		var current := other.state_machine.current_state.name
		if current == skill or (exclusive and current in exclusive_skills):
			return false
	return true


func current_wave() -> int:
	return _wave_index


func is_finished() -> bool:
	return _finished


func _start() -> void:
	await ZoneRoot.wait_combat_ready(self)
	await _wait(intro_delay)
	_next_wave()


func _next_wave() -> void:
	_wave_index += 1
	if _wave_index >= waves.size():
		_finish()
		return
	_active = _wave_toads(waves[_wave_index])
	wave_started.emit(_wave_index)
	for i in _active.size():
		if i > 0:
			await _wait(engage_stagger)
		if is_instance_valid(_active[i]):
			_active[i].engage()


func _on_toad_defeated(toad: FireToad) -> void:
	if not toad in _active:
		return
	var alive := _active.filter(func(t: FireToad) -> bool: return is_instance_valid(t) and not t.health.is_dead())
	if alive.is_empty():
		await _wait(wave_delay)
		_next_wave()
	elif alive.size() == 1 and enrage_last_standing:
		(alive[0] as FireToad).enrage()


func _finish() -> void:
	_finished = true
	await _wait(finale_delay)
	for wave in waves:
		for toad in _wave_toads(wave):
			toad.vanish()
	defeated.emit()


func _wave_toads(wave: FireToadWave) -> Array[FireToad]:
	var result: Array[FireToad] = []
	for path in wave.toads:
		var toad := get_node_or_null(path) as FireToad
		if toad:
			result.append(toad)
		else:
			push_warning("%s: không tìm thấy FireToad ở %s" % [get_path(), path])
	return result


func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds, false, true).timeout
