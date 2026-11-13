extends Node
## Cửa cần chìa báo "cần chìa khóa" khi bấm tương tác mà chưa có chìa (input và node thật, phòng red_gate_showcase):
## 1. Chưa có chìa, bấm interact: hộp thoại mở đúng câu locked_text, cửa vẫn khóa.
## 2. Đóng hộp thoại, bấm interact lần nữa: hộp thoại mở lại (không kẹt).
## 3. Có chìa, bấm interact: không hộp thoại, cửa bắt đầu mở.
## 4. Câu locked_text rỗng: không hiện hộp thoại (cửa tự đặt câu riêng hoặc tắt).
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/locked_hint_test.tscn (-- --capture để chụp ảnh)

const ROOM: PackedScene = preload("res://tests/levels/red_gate_showcase/red_gate_showcase.tscn")

var _room: Node
var _player: Player
var _failed: int = 0


func _ready() -> void:
	_room = ROOM.instantiate()
	add_child(_room)
	_run.call_deferred()


func _run() -> void:
	await _frames(30)
	_player = _room.get_node("Player") as Player
	var door: RedKeyDoor = _room.get_node("KeyDoor") as RedKeyDoor
	# Mặc định cửa không báo gì (map Gió giữ nguyên); map Lửa đặt câu riêng
	_check(door.locked_text.is_empty() and door.get_node_or_null("DialogBox") == null, "mặc định: không câu, không tạo hộp thoại (map Gió giữ nguyên)")
	door.locked_text = "Cần chìa khóa để mở cửa này."
	var unlock_started: Array[int] = [0]
	door.unlock_started.connect(func() -> void: unlock_started[0] += 1)
	_stand_before(door)
	await _frames(25)
	# 1. Chưa có chìa
	await _press(&"interact")
	await _frames(10)
	var dialog: DialogBox = _find_dialog(door)
	var label: Label = dialog.get_node("Panel/Margin/VBox/Text") as Label
	_check(dialog.is_open and label.text == door.locked_text and not door.is_open, "chưa có chìa: hộp thoại báo \"%s\"" % label.text)
	await _capture("locked_door_hint.png")
	# 2. Đóng rồi bấm lại
	dialog.choose(true)
	await _frames(40)
	_check(not dialog.is_open, "đóng hộp thoại")
	await _press(&"interact")
	await _frames(10)
	_check(dialog.is_open, "bấm lại: hộp thoại mở lại")
	dialog.choose(true)
	await _frames(40)
	# 4. Câu rỗng thì không hiện (làm trước bước có chìa để cửa còn khóa)
	door.locked_text = ""
	await _press(&"interact")
	await _frames(10)
	_check(not dialog.is_open and unlock_started[0] == 0, "locked_text rỗng: không hiện hộp thoại")
	door.locked_text = "Cần chìa khóa để mở cửa này."
	await _frames(20)
	# 3. Có chìa
	GameState.set_flag(door.key_id)
	await _press(&"interact")
	await _frames(10)
	_check(not dialog.is_open and unlock_started[0] == 1, "có chìa: không hộp thoại, cửa bắt đầu mở (%d)" % unlock_started[0])
	print("LOCKED HINT RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


func _find_dialog(door: Node) -> DialogBox:
	for c: Node in door.get_children():
		if c is DialogBox:
			return c as DialogBox
	return null


## Đứng trước mặt cửa (mặt trước +Z cục bộ), trong tầm tương tác
func _stand_before(door: RedKeyDoor) -> void:
	_player.teleport(door.global_transform * Vector3(0, 0.1, 1.3), -door.global_basis.z)


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _capture(file: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/fire_level_3/qa/" + file)


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	print("%s %s" % ["OK  " if ok else "FAIL", what])
