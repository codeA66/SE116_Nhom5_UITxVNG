extends DevCheat
## Tốc độ chạy: nhân tốc độ chạy tối đa của player (Character.move_speed_scale). Không đổi dash.
## Làm chậm của băng / tơ nhện vẫn có tác dụng vì chúng thay MovementStats, cheat nhân thêm lên trên.


func _init() -> void:
	title = "Tốc độ chạy"
	group = "1. Player"
	kind = Kind.SLIDER
	order = 1
	min_value = 1.0
	max_value = 3.0
	step = 0.25
	default_value = 1.0


func set_value(console: DevConsole, new_value: float) -> void:
	value = new_value
	_apply_to_player(console)


func on_zone_ready(console: DevConsole) -> void:
	_apply_to_player(console)


func _apply_to_player(console: DevConsole) -> void:
	var player := console.find_player()
	if player:
		player.move_speed_scale = value
