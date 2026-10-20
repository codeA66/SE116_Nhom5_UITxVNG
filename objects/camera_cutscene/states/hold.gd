extends CameraCutsceneState
## Dừng nhìn mục tiêu: camera trôi ngang chậm quanh mục tiêu và đẩy FOV vào dần.

var _elapsed: float = 0.0


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	cutscene.set_letterbox(1.0)


func physics_update(delta: float) -> void:
	var d := cutscene.data
	_elapsed += delta
	# Trôi đều (không ease) để khung hình luôn "sống"; FOV đẩy vào chậm dần về cuối
	var linear := clampf(_elapsed / maxf(d.hold_time, 0.001), 0.0, 1.0)
	cutscene.camera.global_transform = cutscene.get_shot_transform(d.hold_orbit_degrees * linear)
	cutscene.camera.fov = lerpf(d.shot_fov, d.push_in_fov, 1.0 - (1.0 - linear) * (1.0 - linear))
	if _elapsed >= d.hold_time:
		state_machine.transition_to(OUTRO)
