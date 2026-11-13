class_name BrazierGroup
extends Node
## Gom nhiều đuốc (IgnitableBrazier): thắp đủ hết thì phòng bừng sáng (các đèn trong lights bật lần lượt như một làn sóng),
## lưu cờ persistent_id (ví dụ để Encounter dùng làm required_flag cho quái xuất hiện) và phát activated.
## Mỗi lần thắp thêm một đuốc (chưa đủ) thì hiện tiến độ "n/tổng" trên đuốc đó và phát progressed.
## Có is_active() nên cũng làm nguồn cho StoneGate được.
## Hiệu năng: chỉ nghe signal activated của từng đuốc, không có _process.

signal activated
signal progressed(lit: int, total: int)

@export var braziers: Array[IgnitableBrazier] = []
## Đèn phòng bật khi thắp đủ (để năng lượng 0 sẵn trong scene)
@export var lights: Array[Light3D] = []
@export var lit_energy: float = 2.2
@export_range(0.05, 5.0, 0.05) var light_up_time: float = 1.2
## Cờ lưu khi đã thắp đủ. Để trống = không lưu
@export var persistent_id: StringName
@export_group("Phản hồi khi thắp đủ")
## Khoảng cách giữa hai đèn bật liên tiếp (giây): làn sóng sáng lan khắp phòng
@export_range(0.0, 1.0, 0.01) var light_stagger: float = 0.15
## Đèn vọt sáng bằng này lần lit_energy rồi dịu về
@export_range(1.0, 4.0, 0.05) var light_overshoot: float = 1.6
@export_range(0.0, 1.0, 0.01) var complete_trauma: float = 0.35
## Slow motion ngắn (thời gian thật, giây); 0 = tắt
@export_range(0.0, 2.0, 0.01) var slow_motion_time: float = 0.25
@export_range(0.05, 1.0, 0.01) var slow_motion_scale: float = 0.35
@export var progress_format: String = "%d/%d"

var is_complete: bool = false


func _ready() -> void:
	for light: Light3D in lights:
		light.light_energy = 0.0
		light.visible = false
	for b: IgnitableBrazier in braziers:
		b.activated.connect(_on_brazier_lit.bind(b))
	# Đuốc đã thắp từ lần chơi trước nạp xong trong _ready của chúng: kiểm tra một lượt sau khi cả cây sẵn sàng (không phản hồi)
	_refresh.call_deferred(false)


func is_active() -> bool:
	return is_complete


func lit_count() -> int:
	var n: int = 0
	for b: IgnitableBrazier in braziers:
		if b.is_active():
			n += 1
	return n


func _on_brazier_lit(brazier: IgnitableBrazier) -> void:
	if is_complete:
		return
	var lit: int = lit_count()
	progressed.emit(lit, braziers.size())
	if lit < braziers.size():
		brazier.show_message(progress_format % [lit, braziers.size()])
	_refresh(true)


func _refresh(celebrate: bool) -> void:
	if is_complete or braziers.is_empty() or lit_count() < braziers.size():
		return
	is_complete = true
	# Nạp lại từ save: sáng dần bình thường, không phản hồi ăn mừng
	var tween: Tween = null if celebrate or lights.is_empty() else create_tween().set_parallel(true)
	for i: int in range(lights.size()):
		var light: Light3D = lights[i]
		light.visible = true
		if tween:
			tween.tween_property(light, ^"light_energy", lit_energy, light_up_time)
			continue
		# Sóng sáng: đèn sau bật trễ hơn, vọt sáng rồi dịu về mức thường
		var step: Tween = create_tween()
		step.tween_interval(light_stagger * i)
		step.tween_property(light, ^"light_energy", lit_energy * light_overshoot, light_up_time * 0.35) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		step.tween_property(light, ^"light_energy", lit_energy, light_up_time * 0.65) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if celebrate:
		if complete_trauma > 0.0:
			ScreenShake.add_trauma(complete_trauma)
		if slow_motion_time > 0.0:
			HitStop.slow_motion(slow_motion_time, slow_motion_scale)
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	activated.emit()
