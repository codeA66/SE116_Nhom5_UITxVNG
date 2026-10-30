extends CameraCutsceneState
## Viền đen trượt vào; camera trượt từ góc của player tới khung hình nhìn mục tiêu.

var _elapsed: float = 0.0
var _from: Transform3D
var _from_fov: float = 0.0


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	_from = cutscene.camera.global_transform
	_from_fov = cutscene.camera.fov


func physics_update(delta: float) -> void:
	var d := cutscene.data
	_elapsed += delta
	cutscene.set_letterbox(_elapsed / maxf(d.letterbox_time, 0.001))
	var t := ease_camera(_elapsed / maxf(d.travel_time, 0.001))
	var shot := cutscene.get_shot_transform(0.0)
	cutscene.camera.global_transform = _from.interpolate_with(shot, t)
	cutscene.camera.fov = lerpf(_from_fov, d.shot_fov, t)
	if _elapsed >= d.travel_time:
		state_machine.transition_to(HOLD)
