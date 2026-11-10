class_name AcquireBlackout
extends "res://components/feedback/loot_beam/ability_acquire/core/ability_acquire_phase.gd"
## Sau khi cáo đáp đất: màn tối dần thành đen hẳn và giữ đen một lúc rồi mới hiện bảng kỹ năng
## (video Hollow Knight: khoảng 2,5 s màn đen trước bảng). Đen phủ lên cả HUD.
func _phase_enter() -> void:
	duration = context.data.blackout_time
	renderer.clear_visuals()
	context.set_actor_glow(0.0)
	ui.set_black(0.0)
## Chỉ tối dần trong blackout_fade đầu pha, phần còn lại giữ đen
func _phase_update(_progress: float) -> void:
	var fade: float = clampf(elapsed/maxf(context.data.blackout_fade,context.data.minimum_time),0.0,1.0)
	ui.set_black(fade*fade*(3.0-2.0*fade))
