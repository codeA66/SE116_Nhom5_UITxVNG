class_name PasswordGate
extends Node3D
## Vùng trước cổng khu cần mật khẩu: player bước vào khi cổng đã mở (khu trước đã phá, lễ thức đã chiếu) mà chưa
## nhập mật khẩu thì hiện ô nhập. Đúng -> ghi nhớ, báo cổng tính lại (cổng tự mở). Sai -> báo, xoá ô để nhập lại. Esc -> đóng ô.
## Gắn với đúng một cổng + một điều kiện qua tham chiếu (nhiều cổng cần mật khẩu không lẫn nhau).
## Hiệu năng: chỉ nghe body_entered và nhận phím lúc ô đang mở; không có _process.

## Ô nhập vừa mở / vừa đóng (âm thanh, hiệu ứng nối vào đây)
signal prompt_opened
signal prompt_closed
## Nhập đúng mật khẩu
signal unlocked

@export var gate: ZoneGate
## Chính điều kiện mật khẩu nằm trong gate.conditions
@export var condition: PasswordUnlock
@export var title_text: String = "Nhập mật khẩu để vào khu này"
@export var wrong_text: String = "Sai mật khẩu, thử lại"
@export var contact_text: String = "Liên hệ gmail ledangquangtht@gmail.com để lấy mật khẩu"
## Kích thước vùng kích hoạt (m), hộp đặt giữa đáy tại gốc node
@export var trigger_size: Vector3 = Vector3(4.4, 3.0, 3.0)

var _player: Player
var _open: bool = false

@onready var _trigger: Area3D = $Trigger
@onready var _shape: CollisionShape3D = $Trigger/CollisionShape3D
@onready var _prompt: CanvasLayer = $Prompt
@onready var _title: Label = %Title
@onready var _field: LineEdit = %Input
@onready var _status: Label = %Status
@onready var _contact: Label = %Contact


func _ready() -> void:
	var box := BoxShape3D.new()
	box.size = trigger_size
	_shape.shape = box
	_shape.position.y = trigger_size.y * 0.5
	_title.text = title_text
	_contact.text = contact_text
	_prompt.visible = false
	set_process_input(false)
	if gate == null or condition == null:
		push_error("%s: chưa gán gate / condition" % get_path())
		_trigger.monitoring = false
		return
	_trigger.body_entered.connect(_on_body_entered)
	_field.text_submitted.connect(_on_submitted)


func is_prompt_open() -> bool:
	return _open


func _input(event: InputEvent) -> void:
	# Bắt Esc trước menu tạm dừng (menu nghe _unhandled_input) để Esc chỉ đóng ô mật khẩu
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _on_body_entered(body: Node3D) -> void:
	if _open or not body is Player or not gate.is_open() or gate.is_enterable() or condition.is_met():
		return
	_player = body as Player
	_player.set_controls_enabled(false)
	_open = true
	_status.visible = false
	_field.clear()
	_prompt.visible = true
	_field.grab_focus.call_deferred()
	set_process_input(true)
	prompt_opened.emit()


func _on_submitted(text: String) -> void:
	if condition.try_password(text):
		_close()
		gate.refresh()
		unlocked.emit()
		return
	_status.text = wrong_text
	_status.visible = true
	_field.clear()


func _close() -> void:
	if not _open:
		return
	_open = false
	set_process_input(false)
	_field.release_focus()
	_prompt.visible = false
	if is_instance_valid(_player):
		_player.set_controls_enabled(true)
	prompt_closed.emit()
