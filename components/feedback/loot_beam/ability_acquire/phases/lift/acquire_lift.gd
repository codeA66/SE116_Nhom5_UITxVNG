class_name AcquireLift
extends "res://components/feedback/loot_beam/ability_acquire/core/ability_acquire_phase.gd"
## Nâng model và giữ sách làm nguồn nhìn thấy được.
func _phase_enter() -> void:
	duration = context.data.lift_time
	renderer.enter_phase(0)
## Ease mềm ở đầu/cuối để cáo không giật lên như dịch chuyển.
func _phase_update(progress: float) -> void:
	var ease: float = progress*progress*(3.0-2.0*progress)
	context.lift(ease)
	context.face_viewer(elapsed/maxf(context.data.facing_time,context.data.minimum_time))
	renderer.update_book(ease)
	renderer.update_phase(0,progress,elapsed)
	ui.set_grade(context.data.gather_dim*progress*0.5,context.data.gather_desaturation*progress*0.5)
	ui.set_focus(context.visual.global_position+Vector3.UP*context.data.focus_height)
