class_name DialogBox
extends CanvasLayer
## Hộp thoại dùng chung (bia đá, NPC...): khung chữ dưới màn hình, khoá điều khiển player khi mở.
## - say(text): thông báo, bấm interact (hoặc ui_accept / chuột) để đóng.
## - ask(text): câu hỏi có 2 nút (yes_text / no_text), chọn bằng trái / phải hoặc chuột, xác nhận bằng interact;
##   phát answered(bool). Đóng xong phát closed.
## Hiệu năng: chỉ nhận input khi đang mở (set_process_unhandled_input), không có _process.

signal answered(accepted: bool)
signal closed

@export var yes_text: String = "ĐỒNG Ý"
@export var no_text: String = "CHƯA"
## Bỏ qua input trong khoảng này sau khi mở: phím interact vừa mở hộp thoại không tự đóng luôn
@export_range(0.0, 1.0, 0.05) var input_delay: float = 0.2
## Trả điều khiển cho player chậm chừng này sau khi đóng: phím interact vừa đóng không bị nhân vật dùng tiếp
## để tương tác lại (mở lại hộp thoại ngay)
@export_range(0.0, 1.0, 0.05) var release_delay: float = 0.15

var is_open: bool = false
var is_question: bool = false

var _player: Player
var _choice: int = 0
var _open_time: float = 0.0

@onready var _panel: Control = $Panel
@onready var _label: Label = $Panel/Margin/VBox/Text
@onready var _buttons: Control = $Panel/Margin/VBox/Buttons
@onready var _yes: Button = $Panel/Margin/VBox/Buttons/Yes
@onready var _no: Button = $Panel/Margin/VBox/Buttons/No
@onready var _hint: Label = $Panel/Margin/VBox/Hint


func _ready() -> void:
	_panel.hide()
	set_process_unhandled_input(false)
	_yes.text = yes_text
	_no.text = no_text
	_yes.pressed.connect(_finish.bind(true))
	_no.pressed.connect(_finish.bind(false))
	_yes.mouse_entered.connect(_select.bind(0))
	_no.mouse_entered.connect(_select.bind(1))


func say(text: String, player: Player = null) -> void:
	_open(text, false, player)


func ask(text: String, player: Player = null) -> void:
	_open(text, true, player)


## Chọn đáp án bằng code (test, phím tắt); đóng hộp thoại như bấm nút
func choose(accepted: bool) -> void:
	if is_open:
		_finish(accepted)


func _open(text: String, question: bool, player: Player) -> void:
	is_open = true
	is_question = question
	_player = player
	_label.text = text
	_buttons.visible = question
	_hint.visible = not question
	_panel.show()
	_open_time = Time.get_ticks_msec() / 1000.0
	if is_instance_valid(_player):
		_player.set_controls_enabled(false)
	_select(0)
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if Time.get_ticks_msec() / 1000.0 - _open_time < input_delay:
		return
	if is_question and (event.is_action_pressed(&"move_left") or event.is_action_pressed(&"ui_left")):
		_select(0)
	elif is_question and (event.is_action_pressed(&"move_right") or event.is_action_pressed(&"ui_right")):
		_select(1)
	elif event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
		_finish(_choice == 0 if is_question else true)
	else:
		return
	get_viewport().set_input_as_handled()


func _select(index: int) -> void:
	_choice = index
	if not is_question:
		return
	(_yes if index == 0 else _no).grab_focus()


func _finish(accepted: bool) -> void:
	if not is_open:
		return
	var question: bool = is_question
	is_open = false
	set_process_unhandled_input(false)
	_panel.hide()
	if is_instance_valid(_player):
		var player: Player = _player
		get_tree().create_timer(release_delay).timeout.connect(func() -> void:
			if is_instance_valid(player) and not is_open:
				player.set_controls_enabled(true))
	_player = null
	if question:
		answered.emit(accepted)
	closed.emit()
