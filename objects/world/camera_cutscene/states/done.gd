extends CameraCutsceneState
## Trả camera và điều khiển cho player. Không chạy lại (vùng kích hoạt tắt).


func enter(_previous: StringName) -> void:
	cutscene.end()
