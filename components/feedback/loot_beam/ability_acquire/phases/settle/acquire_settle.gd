class_name AcquireSettle
extends "res://components/feedback/loot_beam/ability_acquire/core/ability_acquire_phase.gd"
## Đuôi sáng đi xuống cùng cáo, ring và ray đã được ẩn.
func _phase_enter() -> void:
	duration = context.data.settle_time
	renderer.enter_phase(3)
## Hạ nhẹ và chốt đúng transform ở cuối để lặp nhiều lượt không trôi model.
func _phase_update(progress: float) -> void:
	var eased: float = progress*progress*(3.0-2.0*progress)
	context.lift(1.0-eased)
	var land: float = clampf((progress-context.data.landing_start)/maxf(1.0-context.data.landing_start,context.data.minimum_time),0.0,1.0)
	context.ceremony_pose(1.0-eased,elapsed,sin(land*PI))
	renderer.update_phase(3,progress,elapsed)
	ui.set_grade(context.data.gather_dim*(1.0-progress),context.data.gather_desaturation*(1.0-progress))
