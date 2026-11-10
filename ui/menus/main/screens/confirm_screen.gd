class_name ConfirmScreen
extends MenuScreen
## Hộp xác nhận xóa hồ sơ. Mặc định chọn "Không": bấm nhầm Enter không mất hành trình.

signal confirmed
signal cancelled

## %d = số ô
@export var question_format: String = "Xóa hồ sơ %d?"
@export var warning_text: String = "Hành trình này sẽ mất vĩnh viễn."

@onready var _question: Label = $Box/Question
@onready var _warning: Label = $Box/Warning
@onready var _no: MenuItem = $Box/Buttons/No
@onready var _yes: MenuItem = $Box/Buttons/Yes


func _ready() -> void:
	super._ready()
	_no.pressed.connect(cancelled.emit)
	_yes.pressed.connect(confirmed.emit)
	default_focus = _no
	# Khóa vòng chọn trong hộp: mũi tên không chạy ra các nút phía sau
	for button: Control in [_no, _yes]:
		button.focus_neighbor_top = button.get_path()
		button.focus_neighbor_bottom = button.get_path()
	_no.focus_neighbor_left = _yes.get_path()
	_yes.focus_neighbor_right = _no.get_path()


func setup(slot: int, data: MainMenuData) -> void:
	_question.text = question_format % slot
	_warning.text = warning_text
	_yes.add_theme_color_override(&"font_focus_color", data.danger_color)
	_yes.add_theme_color_override(&"font_hover_color", data.danger_color)
	_yes.accent_color = data.danger_color
