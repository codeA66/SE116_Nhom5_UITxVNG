class_name WispGroup
extends Node3D
## Nhóm ma trơi của một phòng: dập hết các WispFlame con thì lưu cờ persistent_id và phát cleared.
## Có signal activated + is_active() để làm nguồn (dừng WaveSpawner, mở cổng); rương thưởng hiện theo cờ (FlagReveal).
## Đã có cờ từ trước: tắt sẵn mọi ma trơi.

signal cleared
## Nguồn: dập xong hết
signal activated

@export var persistent_id: StringName

var _remaining: int = 0
var _active: bool = false


func _ready() -> void:
	var wisps: Array[WispFlame] = []
	for child: Node in get_children():
		if child is WispFlame:
			wisps.append(child as WispFlame)
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		_active = true
		for w: WispFlame in wisps:
			w.extinguish()
		return
	_remaining = wisps.size()
	for w: WispFlame in wisps:
		w.extinguished.connect(_on_wisp_extinguished)


func is_active() -> bool:
	return _active


func get_remaining() -> int:
	return _remaining


func _on_wisp_extinguished(_wisp: WispFlame) -> void:
	_remaining -= 1
	if _remaining > 0 or _active:
		return
	_active = true
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	cleared.emit()
	activated.emit()
