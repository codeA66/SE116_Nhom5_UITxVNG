class_name AcquireGather
extends "res://components/feedback/loot_beam/ability_acquire/core/ability_acquire_phase.gd"
## Hạt từ nhiều lớp co về cùng một tâm, không phát rải như ambient.
func _phase_enter() -> void:
	duration = context.data.gather_time
	context.lift(1.0)
	context.face_viewer(1.0)
	renderer.update_book(1.0)
	renderer.enter_phase(1)
## Giữ một nhịp nén cuối pha trước khi chuyển sang bùng.
func _phase_update(progress: float) -> void:
	var moving: float = maxf(duration-context.data.breath_time,context.data.minimum_time)
	var converge: float = clampf(elapsed/moving,0.0,1.0)
	renderer.update_phase(1,converge,minf(elapsed,moving))
	var charge: float = pow(converge,maxf(context.data.charge_power,context.data.minimum_time))
	ui.set_grade(context.data.gather_dim*(1.0-charge),context.data.gather_desaturation*(1.0-charge),context.data.gather_pulse*charge,charge)
	ui.set_focus(context.visual.global_position+Vector3.UP*context.data.focus_height)
