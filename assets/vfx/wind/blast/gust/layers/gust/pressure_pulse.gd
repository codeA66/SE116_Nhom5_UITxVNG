extends WindGustSoftLayer
## Vệt áp lực hiện dọc cả vùng đẩy ngay lúc bật hitbox; lốc nối theo trong pha tác dụng.

const FLASH_TIME: float = 0.075
const START_PHASE: float = 0.12


func _ready() -> void:
	super._ready()
	var main_line := PackedVector3Array([
		Vector3(0.00, 0.33, 0.00), Vector3(-0.12, 0.38, 0.19),
		Vector3(-0.14, 0.39, 0.42), Vector3(-0.05, 0.35, 0.68),
		Vector3(0.06, 0.30, 0.88), Vector3(0.13, 0.28, 1.00),
	])
	var side_line := PackedVector3Array([
		Vector3(0.04, 0.30, 0.04), Vector3(0.19, 0.25, 0.25),
		Vector3(0.26, 0.23, 0.55), Vector3(0.28, 0.24, 0.81),
		Vector3(0.23, 0.27, 0.98),
	])
	mesh = merge_ribbons([
		build_ribbon(main_line, PackedFloat32Array([0.02, 0.11, 0.16, 0.14, 0.08, 0.0])),
		build_ribbon(side_line, PackedFloat32Array([0.0, 0.05, 0.09, 0.06, 0.0])),
	])
	gust.visual_burst.connect(_on_burst)


func _on_burst(data: WindBlastData, _burst_span: float) -> void:
	var physics_step: float = 1.0 / Engine.physics_ticks_per_second
	var lifetime: float = maxf(physics_step, minf(data.active_time, FLASH_TIME))
	begin_layer(lifetime, Vector3(data.width, data.height, data.reach))


func _update_shape(phase: float) -> void:
	# Hình phải đọc được ngay khung đầu, vì hitbox mở toàn vùng cùng lúc.
	super._update_shape(lerpf(START_PHASE, 1.0, phase))
