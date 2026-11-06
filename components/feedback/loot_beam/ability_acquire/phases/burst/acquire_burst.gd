class_name AcquireBurst
extends "res://components/feedback/loot_beam/ability_acquire/core/ability_acquire_phase.gd"
## Cú bùng dùng lại slot hạt, ray và ring đã dựng trước.
func _phase_enter() -> void:
	duration = context.data.burst_time
	context.lift(1.0)
	context.face_viewer(1.0)
	renderer.update_book(1.0)
	renderer.enter_phase(2)
## Hold hình cục bộ vài mili giây; không để timer HitStop toàn cục rò sau khi hủy.
func _phase_update(_progress: float) -> void:
	var t: float = clampf(maxf(elapsed-context.data.hitstop,0.0)/maxf(duration-context.data.hitstop,context.data.minimum_time),0.0,1.0)
	renderer.update_phase(2,t,elapsed)
	var release: float = (1.0-t)*(1.0-t)
	var strength: float = clampf(context.data.burst_intensity,0.0,context.data.maximum_intensity)
	ui.set_grade(0.0,0.0,context.data.fullscreen_pulse*release*strength,release*strength)
