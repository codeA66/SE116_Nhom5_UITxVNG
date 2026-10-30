extends CameraCutsceneState
## Chờ player bước vào vùng kích hoạt.


func on_player_entered(player: Player) -> void:
	cutscene.begin(player)
	state_machine.transition_to(INTRO)
