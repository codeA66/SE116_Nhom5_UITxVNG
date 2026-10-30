extends ZoneRoot
## Phòng thử riêng: dùng bản sao tiến trình, không ghi vào save thật.

var _original_progress: PlayerProgress
var _original_health: int = -1
var _save_connected: bool = false
var _overview: bool = true

func _ready() -> void:
	_original_progress = GameState.progress
	_original_health = GameState.get_player_health()
	_save_connected = GameState.progress_changed.is_connected(SaveManager.save_game)
	if _save_connected:
		GameState.progress_changed.disconnect(SaveManager.save_game)
	SaveManager.set_process_unhandled_input(false)
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_weapon(load("res://resources/combat/weapons/sword.tres"))
	GameState.set_checkpoint(scene_file_path, &"start")
	shader_warmup = null
	super()
	$OverviewCamera.look_at(Vector3(0, 1.3, -1.0))
	$OverviewCamera.current = true
	$Player.health.died.connect(_on_player_died)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()
	elif event.physical_keycode == KEY_TAB:
		_overview = not _overview
		if _overview:
			$OverviewCamera.make_current()
		else:
			$Player/CameraRig/Camera3D.make_current()

func _on_player_died() -> void:
	$UI/Panel/Status.text = "Bạn đã ngã — hồi sinh sẽ đặt lại phòng thử."

func _exit_tree() -> void:
	if _original_progress == null:
		return
	GameState.replace_progress(_original_progress)
	GameState.set_player_health(_original_health)
	if _save_connected and not GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.connect(SaveManager.save_game)
	SaveManager.set_process_unhandled_input(true)
