class_name WolfPack
extends Node
## Điều phối bầy sói: mỗi lúc chỉ một con được vồ (giữ "lượt"), các con khác rình vòng quanh.
## Con vồ xong nhả lượt; con kế tiếp phải chờ thêm turn_gap giây để các cú vồ không dồn dập.
## Sói gán ShadowWolf.pack trỏ tới node này; sói không có bầy thì tự vồ theo hồi chiêu của mình.

signal turn_changed(holder: Node)

## Khoảng nghỉ giữa hai lượt vồ của cả bầy (s)
@export_range(0.0, 5.0, 0.05) var turn_gap: float = 0.6

var holder: Node

var _free_at: int = 0


## Xin lượt vồ; true nếu được (đang giữ lượt thì vẫn true)
func try_claim(wolf: Node) -> bool:
	if holder == wolf:
		return true
	if is_instance_valid(holder) or Time.get_ticks_msec() < _free_at:
		return false
	holder = wolf
	turn_changed.emit(holder)
	return true


func release(wolf: Node) -> void:
	if holder != wolf:
		return
	holder = null
	_free_at = Time.get_ticks_msec() + int(turn_gap * 1000.0)
	turn_changed.emit(null)


func is_busy() -> bool:
	return is_instance_valid(holder)
