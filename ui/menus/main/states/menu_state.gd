class_name MenuState
extends State
## Một màn của menu chính trong FSM. MainMenu chuyển input chưa được nút nào nhận (Esc, phím bất kỳ...) vào state
## đang chạy. Tên node state: Title / Home / Profiles / ConfirmDelete / Settings.

const TITLE := &"Title"
const HOME := &"Home"
const PROFILES := &"Profiles"
const CONFIRM_DELETE := &"ConfirmDelete"
const SETTINGS := &"Settings"

var menu: MainMenu


func _ready() -> void:
	menu = owner as MainMenu


## Input chưa được giao diện dùng. Lớp con ghi đè
func handle_input(_event: InputEvent) -> void:
	pass


## Nối signal của màn khi vào state, gỡ khi ra: state không chạy thì không phản ứng
static func link(source: Signal, target: Callable, connect_it: bool) -> void:
	if connect_it and not source.is_connected(target):
		source.connect(target)
	elif not connect_it and source.is_connected(target):
		source.disconnect(target)
