class_name AcquireScatter
extends "res://components/feedback/loot_beam/ability_acquire/core/ability_acquire_phase.gd"
## Ngay sau khi hấp thụ sách: màn lóe trắng, rồi hàng trăm đốm sáng tròn nổ ra từ cáo, chậm dần
## và trôi lơ lửng, lấp lánh khắp màn (giống đoạn 0,45–4,2 s trong video Hollow Knight người dùng gửi).
func _phase_enter() -> void:
	duration = context.data.scatter_time
	context.lift(1.0)
	context.face_viewer(1.0)
	renderer.update_book(1.0)
	renderer.enter_phase(renderer.PHASE_SCATTER)
## Lóe trắng tắt nhanh; nền tối dần về mức của pha tụ
func _phase_update(progress: float) -> void:
	context.lift(1.0)
	context.ceremony_pose(1.0,elapsed)
	renderer.update_phase(renderer.PHASE_SCATTER,progress,elapsed)
	var flash: float = context.data.scatter_flash*(1.0-clampf(elapsed/maxf(context.data.scatter_flash_time,context.data.minimum_time),0.0,1.0))
	ui.set_grade(context.data.gather_dim*clampf(elapsed/maxf(context.data.scatter_flash_time*2.0,context.data.minimum_time),0.0,1.0),context.data.gather_desaturation,flash)
	ui.set_focus(context.visual.global_position+Vector3.UP*context.data.focus_height)
