class_name MainMenu
extends Node
## Menu chính: nền là khu trung tâm (camera bay chậm), giao diện chia màn, chuyển màn bằng FSM node
## (StateMachine/Title, Home, Profiles, ConfirmDelete, Settings). Thêm màn mới = thêm MenuScreen + MenuState,
## không sửa các màn cũ. Script này chỉ giữ tham chiếu dùng chung, âm thanh và việc vào game.

enum Sfx { MOVE, CONFIRM, BACK, DELETE }

@export var data: MainMenuData
@export var registry: ZoneRegistry

## Ô đang chờ xác nhận xóa (state hồ sơ đặt, state xác nhận đọc)
var pending_delete_slot: int = 1

var _launching: bool = false
var _sfx: Dictionary[Sfx, AudioStreamPlayer] = {}

@onready var logo: MenuLogo = $UI/Root/Logo
@onready var title_screen: TitleScreen = $UI/Root/TitleScreen
@onready var home_screen: HomeScreen = $UI/Root/HomeScreen
@onready var profiles_screen: ProfilesScreen = $UI/Root/ProfilesScreen
@onready var settings_screen: SettingsScreen = $UI/Root/SettingsScreen
@onready var confirm_screen: ConfirmScreen = $UI/Root/ConfirmScreen
@onready var _state_machine: StateMachine = $StateMachine
@onready var _fade: ColorRect = $UI/Root/Fade
@onready var _music: AudioStreamPlayer = $Audio/Music


func _ready() -> void:
	_sfx = {
		Sfx.MOVE: $Audio/Move,
		Sfx.CONFIRM: $Audio/Confirm,
		Sfx.BACK: $Audio/Back,
		Sfx.DELETE: $Audio/Delete,
	}
	logo.set_text(data.title_text)
	title_screen.setup(data)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	if _music.stream:
		_music.play()
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, ^"color:a", 0.0, data.intro_fade_time)
	logo.play_reveal()


func _unhandled_input(event: InputEvent) -> void:
	if _launching:
		return
	var state := _state_machine.current_state as MenuState
	if state:
		state.handle_input(event)


func play_sfx(kind: Sfx) -> void:
	var player: AudioStreamPlayer = _sfx.get(kind)
	# Chưa có file âm thanh thì bỏ qua (chỗ cắm sẵn trong scene)
	if player and player.stream:
		player.play()


## Vào game với ô hồ sơ đã chọn: có dữ liệu thì chơi tiếp ở checkpoint, trống thì bắt đầu hành trình mới
## (khu trung tâm). Khóa menu ngay để bấm liên tục không gọi chuyển cảnh hai lần.
func start_profile(slot: int) -> void:
	if _launching:
		return
	_launching = true
	play_sfx(Sfx.CONFIRM)
	get_viewport().gui_release_focus()
	SaveManager.select_slot(slot)
	if not SaveManager.load_game():
		GameState.replace_progress(PlayerProgress.new())
	if _music.playing:
		create_tween().tween_property(_music, ^"volume_db", -40.0, data.screen_fade_time * 2.0)
	SceneManager.go_to_last_checkpoint()


func is_launching() -> bool:
	return _launching


func quit_game() -> void:
	_launching = true
	play_sfx(Sfx.BACK)
	var tween := create_tween()
	tween.tween_property(_fade, ^"color:a", 1.0, data.screen_fade_time)
	tween.tween_callback(get_tree().quit)


func _on_focus_changed(_control: Control) -> void:
	if not _launching:
		play_sfx(Sfx.MOVE)
