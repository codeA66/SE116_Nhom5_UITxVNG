class_name AcquireReveal
extends "res://components/feedback/loot_beam/ability_acquire/core/ability_acquire_phase.gd"
## UI tự giữ bảng chờ người đọc, root chỉ nhận close_finished.
func _phase_enter() -> void:
	duration = context.data.panel_time
	auto_finish = false
	context.lift(0.0)
	renderer.clear_visuals()
	ui.show_panel()
## UI có đồng hồ riêng cho reveal và đường bay icon.
func _phase_update(_progress: float) -> void:
	pass
