class_name EnergyComponent
extends Node
## Giữ số ô năng lượng. Không biết ai nạp, ai tiêu: ai cần phản ứng (HUD, âm thanh) thì nghe signal.
## Không chạy mỗi frame.

signal energy_changed(current: int, max_value: int)
## Có lệnh muốn tiêu nhưng không đủ ô: HUD nháy, phát âm báo
signal insufficient(cost: int)

@export var data: EnergyData

var current: int = 0


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	current = get_max()


func get_max() -> int:
	return data.max_energy if data else 0


func can_spend(cost: int) -> bool:
	return cost <= current


## Trừ cost ô nếu đủ; không đủ thì phát insufficient và trả false. cost <= 0 luôn thành công
func spend(cost: int) -> bool:
	if cost <= 0:
		return true
	if not can_spend(cost):
		insufficient.emit(cost)
		return false
	set_current(current - cost)
	return true


## Nạp theo một nhát đánh trúng
func gain_from_hit() -> void:
	if data:
		set_current(current + data.gain_per_hit)


func set_current(value: int) -> void:
	var clamped := clampi(value, 0, get_max())
	if clamped == current:
		return
	current = clamped
	energy_changed.emit(current, get_max())


func notify_insufficient(cost: int) -> void:
	insufficient.emit(cost)
