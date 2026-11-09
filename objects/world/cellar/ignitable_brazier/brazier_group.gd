class_name BrazierGroup
extends Node
## Gom nhiều đuốc (IgnitableBrazier): thắp đủ hết thì phòng bừng sáng (các đèn trong lights tăng dần lên lit_energy),
## lưu cờ persistent_id (ví dụ để Encounter dùng làm required_flag cho quái xuất hiện) và phát activated.
## Có is_active() nên cũng làm nguồn cho StoneGate được.
## Hiệu năng: chỉ nghe signal activated của từng đuốc, không có _process.

signal activated

@export var braziers: Array[IgnitableBrazier] = []
## Đèn phòng bật khi thắp đủ (để năng lượng 0 sẵn trong scene)
@export var lights: Array[Light3D] = []
@export var lit_energy: float = 2.2
@export_range(0.05, 5.0, 0.05) var light_up_time: float = 1.2
## Cờ lưu khi đã thắp đủ. Để trống = không lưu
@export var persistent_id: StringName

var is_complete: bool = false


func _ready() -> void:
	for light: Light3D in lights:
		light.light_energy = 0.0
		light.visible = false
	for b: IgnitableBrazier in braziers:
		b.activated.connect(_refresh)
	# Đuốc đã thắp từ lần chơi trước nạp xong trong _ready của chúng: kiểm tra một lượt sau khi cả cây sẵn sàng
	_refresh.call_deferred()


func is_active() -> bool:
	return is_complete


func lit_count() -> int:
	var n: int = 0
	for b: IgnitableBrazier in braziers:
		if b.is_active():
			n += 1
	return n


func _refresh() -> void:
	if is_complete or braziers.is_empty() or lit_count() < braziers.size():
		return
	is_complete = true
	var tween: Tween = create_tween().set_parallel(true)
	for light: Light3D in lights:
		light.visible = true
		tween.tween_property(light, ^"light_energy", lit_energy, light_up_time)
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	activated.emit()
