extends CameraCutsceneState
## Camera trượt từ khung hình về camera của player (đích cập nhật mỗi frame vì player vẫn đang di chuyển
## trên thuyền), viền đen rút ra. Tới nơi thì trả camera và điều khiển cho player.

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
	var t := ease_camera(_elapsed / maxf(d.return_time, 0.001))
	var target := cutscene.player_camera
	if is_instance_valid(target):
		cutscene.camera.global_transform = _from.interpolate_with(target.global_transform, t)
		cutscene.camera.fov = lerpf(_from_fov, target.fov, t)
	cutscene.set_letterbox(1.0 - clampf((_elapsed - (d.return_time - d.letterbox_time)) / maxf(d.letterbox_time, 0.001), 0.0, 1.0))
	if _elapsed >= d.return_time:
		state_machine.transition_to(DONE)
