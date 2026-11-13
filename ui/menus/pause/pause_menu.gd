extends CanvasLayer
## Autoload "PauseMenu": Esc khi đang chơi dừng hẳn game (get_tree().paused) và mở menu tạm dừng:
## Tiếp tục / Cài đặt / Sổ hướng dẫn / Về menu chính / Thoát game.
## Là autoload nên nhận Esc SAU mọi thứ trong khu (popup hướng dẫn, hội thoại, màn Tab dùng Esc trước rồi đánh dấu đã xử lý).
## Chỉ mở trong khu chơi (ZoneRoot), khi Player đang được điều khiển và không đang chuyển cảnh.
## Mỗi màn con (danh sách, cài đặt, xác nhận) là một node trong Views; thêm màn = thêm node + một mục trong _views.

signal opened
signal closed

const MAIN_MENU := "res://ui/menus/main/main_menu.tscn"

@export var pause_action: StringName = &"pause"
@export_range(0.05, 1.0, 0.01) var fade_time: float = 0.18
@export_range(0.0, 60.0, 1.0) var slide: float = 14.0

var is_open: bool = false

var _confirm_action: Callable
var _tween: Tween
var _views: Dictionary[StringName, Control] = {}
var _current_view: StringName = &""

@onready var _root: Control = $Root
@onready var _list: Control = $Root/Views/List
@onready var _settings_view: Control = $Root/Views/Settings
@onready var _confirm_view: Control = $Root/Views/Confirm
@onready var _resume: MenuItem = $Root/Views/List/Items/Resume
@onready var _settings: MenuItem = $Root/Views/List/Items/Settings
@onready var _tutorials: MenuItem = $Root/Views/List/Items/Tutorials
@onready var _to_title: MenuItem = $Root/Views/List/Items/ToTitle
@onready var _quit: MenuItem = $Root/Views/List/Items/Quit
@onready var _panel: SettingsPanel = $Root/Views/Settings/Panel
@onready var _settings_back: MenuItem = $Root/Views/Settings/Back
@onready var _question: Label = $Root/Views/Confirm/Box/Question
@onready var _warning: Label = $Root/Views/Confirm/Box/Warning
@onready var _no: MenuItem = $Root/Views/Confirm/Box/Buttons/No
@onready var _yes: MenuItem = $Root/Views/Confirm/Box/Buttons/Yes


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_views = {&"list": _list, &"settings": _settings_view, &"confirm": _confirm_view}
	_root.visible = false
	for view: Control in _views.values():
		view.visible = false
	_resume.pressed.connect(close)
	_settings.pressed.connect(_show_view.bind(&"settings"))
	_tutorials.pressed.connect(_open_tutorials)
	_to_title.pressed.connect(_ask.bind("Về menu chính?", _go_to_title))
	_quit.pressed.connect(_ask.bind("Thoát game?", _quit_game))
	_settings_back.pressed.connect(_show_view.bind(&"list"))
	_no.pressed.connect(_show_view.bind(&"list"))
	_yes.pressed.connect(_on_confirm)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		if event.is_action_pressed(pause_action) and _can_open():
			get_viewport().set_input_as_handled()
			open()
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(pause_action):
		get_viewport().set_input_as_handled()
		_go_back()


func open() -> void:
	if is_open:
		return
	is_open = true
	get_tree().paused = true
	_root.visible = true
	_root.modulate.a = 0.0
	_animate(1.0)
	_show_view(&"list")
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	get_viewport().gui_release_focus()
	get_tree().paused = false
	_animate(0.0)
	closed.emit()


func _can_open() -> bool:
	if not get_tree().current_scene is ZoneRoot or SceneManager.is_busy() or get_tree().paused:
		return false
	var player := get_tree().current_scene.get_node_or_null(^"Player") as Player
	return player != null and player.controls_enabled


## Esc: ở màn con thì về danh sách, ở danh sách thì tiếp tục chơi. Đang chờ phím mới thì chỉ huỷ chờ
func _go_back() -> void:
	if _current_view == &"settings" and _panel.handle_cancel():
		return
	if _current_view == &"list":
		close()
	else:
		_show_view(&"list")


func _show_view(view: StringName) -> void:
	var previous := _current_view
	_current_view = view
	for key: StringName in _views:
		_views[key].visible = key == view
	match view:
		&"list":
			# Quay về từ Cài đặt thì con trỏ đứng lại ở Cài đặt
			(_settings if previous == &"settings" else _resume).grab_focus.call_deferred()
		&"settings":
			_panel.focus_default.call_deferred()
		&"confirm":
			_no.grab_focus.call_deferred()


## Hỏi lại trước khi rời màn chơi: tiến trình chỉ được lưu ở checkpoint
func _ask(question: String, action: Callable) -> void:
	_question.text = question
	_warning.text = "Tiến trình từ checkpoint gần nhất sẽ không được lưu."
	_confirm_action = action
	_show_view(&"confirm")


func _on_confirm() -> void:
	if _confirm_action.is_valid():
		_confirm_action.call()


func _go_to_title() -> void:
	close()
	_root.visible = false
	get_tree().change_scene_to_file(MAIN_MENU)


func _quit_game() -> void:
	get_tree().quit()


func _open_tutorials() -> void:
	var inventory := get_tree().get_first_node_in_group(InventoryMenu.GROUP) as InventoryMenu
	close()
	if inventory:
		inventory.open_to_page_type(TutorialsPage)


func _animate(target: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_root, ^"modulate:a", target, fade_time)
	_tween.tween_property($Root/Views as Control, ^"position:y", 0.0 if target > 0.0 else slide, fade_time).from(slide if target > 0.0 else 0.0)
	if target <= 0.0:
		_tween.chain().tween_callback(_root.hide)
