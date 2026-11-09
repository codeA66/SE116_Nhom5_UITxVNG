class_name AcquireAbsorb
extends AcquireGather
## Pha Hấp thu (phòng học kỹ năng, tham khảo cảnh nhận Howling Wraiths của Hollow Knight): giữ toàn bộ phần của
## Gather (nâng, tạo dáng, camera áp sát, nhân vật sáng dần, hạt co về) và thêm dải năng lượng xoắn từ chỗ sách tan
## cuốn vào ngực, vòng co quanh người, cuối pha quả cầu sáng nuốt nhân vật rồi Burst bùng ra.
## Bật bằng cách đưa "Absorb" vào AbilityAcquireData.phase_order; chuỗi mặc định không đổi.

@onready var _visual: AcquireAbsorbVisual = $Visual


func _phase_enter() -> void:
	super._phase_enter()
	duration = context.data.absorb_time
	if context.data.continuous_energy:
		return
	var chest: Vector3 = context.visual.global_position + Vector3.UP * context.data.focus_height
	var fallback: Vector3 = chest - context.visual.global_basis.z * 1.5
	var accent: Color = context.ability.accent_color if context.ability else Color.WHITE
	_visual.begin(renderer.get_source_point(fallback), chest, accent, context.data)


func _phase_update(progress: float) -> void:
	super._phase_update(progress)
	if not context.data.continuous_energy:
		_visual.update(progress, elapsed)


func exit() -> void:
	super.exit()
	_visual.stop()
