extends Node
## Test cổng cần mật khẩu ở Đền Tứ Linh (bản cho người test, chưa thương mại). Chạy headless; save và file mật khẩu
## đều ở thư mục dữ liệu riêng của test. Test không chứa mật khẩu thật: logic dùng mật khẩu thử, cổng Lửa thật chỉ
## kiểm tra có điều kiện mật khẩu, mã băm đúng định dạng và không lộ chữ gốc.
##
## ===== USE CASE =====
## UC1  Chưa thắng boss Gió: bước tới cổng Lửa -> không hiện ô mật khẩu, cổng báo cần đánh boss.
## UC2  Đã thắng boss Gió, chưa nhập mật khẩu: cổng Lửa MỞ ngay (lễ thức / cắt cảnh chạy, người chơi biết đi đâu)
##      nhưng chưa vào được (vách chặn còn, cổng dịch chuyển tắt, bảng ghi "Cần mật khẩu"); bước vào vùng trước cổng
##      -> hiện ô nhập mật khẩu kèm dòng liên hệ, player đứng yên.
## UC3  Gõ sai rồi Enter -> báo sai, vẫn chưa vào được, ô vẫn mở để nhập lại.
## UC4  Esc -> ô đóng, player đi lại được, vẫn chưa vào được; bước ra rồi vào lại -> ô hiện lại.
## UC5  Gõ đúng rồi Enter -> ô đóng, player đi lại được, vào được (vách chặn tắt, cổng dịch chuyển bật); opened không
##      phát thêm (đã phát lúc thắng boss Gió).
## UC6  Nhớ theo máy: nạp lại hub, hoặc chơi save mới (đã thắng boss Gió) -> vào được ngay, không hỏi lại.
## UC7  Cổng Lửa thật trong hub có điều kiện mật khẩu; file scene chỉ chứa mã băm SHA-256, không có chữ gốc.
##
## ===== TEST CASE =====
## TC1 (UC1)  Không cờ zone.wind.cleared, đi bộ thật vào vùng -> prompt ẩn.
## TC2 (UC2)  Đặt cờ lúc đang ở hub -> is_open, opened = 1, chưa vào được (portal tắt, vách chặn bật), bảng ghi mật khẩu;
##            đi bộ vào vùng -> prompt hiện, có chữ liên hệ gmail, controls_enabled = false.
## TC3 (UC3)  Gõ phím thật "sai123" + Enter -> báo sai, chưa vào được, prompt vẫn hiện, ô nhập trống.
## TC4 (UC4)  Esc -> prompt ẩn, điều khiển bật lại, chưa vào được; ra khỏi vùng rồi vào lại -> prompt hiện.
## TC5 (UC5)  Gõ phím thật mật khẩu thử + Enter -> prompt ẩn, điều khiển bật, vào được (portal bật, vách chặn tắt), opened = 1.
## TC6 (UC6)  Nạp lại hub; rồi thay tiến trình mới (chỉ có cờ boss Gió) -> vào được ngay, prompt không hiện.
## TC7 (UC7)  FireGate có PasswordUnlock, mã băm 64 ký tự hex, hub.tscn không chứa chữ gốc mật khẩu thử.

const HUB := "res://levels/temple_center/hub/hub.tscn"
## Mật khẩu thử chỉ dùng trong test (gắn đè lên cổng lúc test), không phải mật khẩu thật
const TEST_PASSWORD := "foxy-test-pass"
const STORE := "user://test_password_gate.cfg"

var _fails: int = 0
var _hub: Node3D
var _p: Player
var _opened: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_run.call_deferred()


func _run() -> void:
	var stand_in := Node.new()
	get_tree().root.add_child(stand_in)
	get_tree().current_scene = stand_in
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	var password_class: Script = load("res://objects/hub/zone_gate/password/password_unlock.gd")
	_check(password_class != null, "Có script PasswordUnlock")
	if password_class == null:
		_finish()
		return
	password_class.set(&"store_path", STORE)
	_tc7_scene_condition()
	_new_progress(false)
	await _load_hub()
	await _tc1_before_boss()
	GameState.set_flag(&"zone.wind.cleared")
	await get_tree().process_frame
	await _tc2_prompt()
	await _tc3_wrong()
	await _tc4_escape()
	await _tc5_correct()
	await _tc6_remember()
	_finish()


func _finish() -> void:
	print("RESULT fails=%d" % _fails)
	get_tree().quit()


func _new_progress(wind_cleared: bool) -> void:
	GameState.replace_progress(PlayerProgress.new())
	for id in [&"hub.intro_seen", &"hub.awaken.fire"]:
		GameState.set_flag(id)
	if wind_cleared:
		GameState.set_flag(&"zone.wind.cleared")


## Nạp hub, gắn mật khẩu thử lên điều kiện mật khẩu của cổng Lửa trước khi vào cây
func _load_hub() -> void:
	if is_instance_valid(_hub):
		_hub.queue_free()
		await get_tree().process_frame
	_hub = (load(HUB) as PackedScene).instantiate() as Node3D
	var condition := _password_condition(_hub)
	if condition:
		condition.call(&"set_password", TEST_PASSWORD)
	get_tree().root.add_child(_hub)
	await _wait(1.0)
	_p = _hub.get_node("Player") as Player
	_p.get_node("HurtboxComponent").set_invincible(9999.0)
	_opened = 0
	_gate().opened.connect(func() -> void: _opened += 1)


func _gate() -> ZoneGate:
	return _hub.get_node("Gates/FireGate") as ZoneGate


func _password_condition(hub: Node) -> Resource:
	var gate := hub.get_node_or_null("Gates/FireGate") as ZoneGate
	if gate == null:
		return null
	for c in gate.conditions:
		if c and (c.get_script() as Script).resource_path.ends_with("password_unlock.gd"):
			return c
	return null


## Vào được thật: cổng báo vào được, vùng dịch chuyển đang nghe, vách chặn tắt
func _enterable() -> bool:
	var gate := _gate()
	if not gate.has_method(&"is_enterable") or not gate.call(&"is_enterable"):
		return false
	var portal_area := gate.get_node("Portal").find_children("*", "Area3D", true, false)[0] as Area3D
	var blocker := gate.get_node("Blocker/CollisionShape3D") as CollisionShape3D
	return portal_area.monitoring and blocker.disabled


func _prompt() -> Node:
	return _hub.find_child("PasswordGate", true, false)


func _prompt_visible() -> bool:
	var gate_node := _prompt()
	return gate_node != null and gate_node.has_method(&"is_prompt_open") and gate_node.call(&"is_prompt_open")


## Đứng trước cổng rồi đi bộ thật về phía cổng tới khi bị chặn
func _walk_to_gate() -> void:
	var gate := _gate()
	var inward := -gate.global_basis.z
	_p.teleport(gate.global_position - inward * 5.0, inward)
	await _wait(0.2)
	var t := 0.0
	while t < 1.5 and _p.controls_enabled:
		_hold_move(inward)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_release_move()
	await _wait(0.2)


func _walk_away() -> void:
	var gate := _gate()
	_p.teleport(gate.global_position + gate.global_basis.z * 8.0, gate.global_basis.z)
	await _wait(0.4)


func _tc1_before_boss() -> void:
	await _walk_to_gate()
	_check(not _prompt_visible() and not _gate().is_open(), "TC1: chưa thắng boss Gió -> không hiện ô mật khẩu, cổng đóng")
	await _walk_away()


func _tc2_prompt() -> void:
	var label := (_gate().get_node("Label") as Label3D).text
	_check(_gate().is_open() and _opened == 1, "TC2: thắng boss Gió -> cổng mở ngay, chưa cần mật khẩu (opened %d lần)" % _opened)
	_check(not _enterable(), "TC2: chưa nhập mật khẩu -> chưa vào được (portal tắt, vách chặn bật)")
	_check(label.to_lower().contains("mật khẩu"), "TC2: bảng cổng ghi '%s'" % label.replace("
", " / "))
	# Chờ cắt cảnh khu Lửa thức dậy chạy xong (trả điều khiển) rồi mới đi tới cổng
	var t := 0.0
	while t < 12.0 and not _p.controls_enabled:
		await get_tree().process_frame
		t += get_process_delta_time()
	await _walk_to_gate()
	_check(_prompt_visible(), "TC2: bước tới cổng -> hiện ô nhập mật khẩu")
	_check(not _p.controls_enabled, "TC2: lúc nhập mật khẩu player đứng yên")
	var text := _all_text(_prompt())
	_check(text.contains("ledangquangtht@gmail.com"), "TC2: ô có dòng liên hệ gmail để lấy mật khẩu")


func _tc3_wrong() -> void:
	await _type("sai123")
	await _press(KEY_ENTER)
	var gate_node := _prompt()
	_check(not _enterable() and _prompt_visible(), "TC3: sai mật khẩu -> vẫn chưa vào được, ô vẫn mở")
	_check(_all_text(gate_node).to_lower().contains("sai"), "TC3: báo sai mật khẩu")
	_check(_line_edit().text.is_empty(), "TC3: ô nhập được xoá để nhập lại")


func _tc4_escape() -> void:
	await _press(KEY_ESCAPE)
	_check(not _prompt_visible() and _p.controls_enabled and not _enterable(), "TC4: Esc -> ô đóng, đi lại được, vẫn chưa vào được")
	await _walk_away()
	await _walk_to_gate()
	_check(_prompt_visible(), "TC4: ra rồi vào lại -> ô hiện lại")


func _tc5_correct() -> void:
	await _type(TEST_PASSWORD)
	await _press(KEY_ENTER)
	await _wait(0.2)
	_check(not _prompt_visible() and _p.controls_enabled, "TC5: đúng mật khẩu -> ô đóng, đi lại được")
	_check(_enterable(), "TC5: đúng mật khẩu -> vào được (portal bật, vách chặn tắt)")
	_check(_opened == 1, "TC5: opened không phát lại (%d lần)" % _opened)


func _tc6_remember() -> void:
	await _load_hub()
	_check(_enterable(), "TC6: nạp lại hub -> vào được ngay")
	_new_progress(true)
	await _load_hub()
	# Cổng đã vào được nên không đi xuyên qua (sẽ dịch chuyển sang khu Lửa): chỉ đứng trong vùng hỏi mật khẩu
	var password_gate := _prompt() as Node3D
	_p.teleport(password_gate.global_position + _gate().global_basis.z * 1.0, -_gate().global_basis.z)
	await _wait(0.5)
	_check(_enterable() and not _prompt_visible(), "TC6: save mới (đã thắng boss Gió) -> vào được, không hỏi lại")


func _tc7_scene_condition() -> void:
	var hub := (load(HUB) as PackedScene).instantiate()
	var condition := _password_condition(hub)
	_check(condition != null, "TC7: cổng Lửa có điều kiện mật khẩu")
	if condition:
		var hash_text := String(condition.get(&"password_sha256"))
		var hex := RegEx.create_from_string("^[0-9a-f]{64}$")
		_check(hex.search(hash_text) != null, "TC7: mã băm SHA-256 đúng định dạng (%d ký tự)" % hash_text.length())
	hub.free()
	var scene_text := FileAccess.get_file_as_string(HUB)
	_check(not scene_text.contains(TEST_PASSWORD), "TC7: hub.tscn không chứa chữ gốc mật khẩu")


func _line_edit() -> LineEdit:
	return _find_line_edit(_prompt())


func _find_line_edit(n: Node) -> LineEdit:
	for c in n.find_children("*", "LineEdit", true, false):
		return c as LineEdit
	return null


func _all_text(n: Node) -> String:
	var out := ""
	for c in n.find_children("*", "Label", true, false):
		if (c as Label).is_visible_in_tree():
			out += (c as Label).text + "\n"
	return out


## Gõ phím thật từng ký tự vào ô đang có focus
func _type(text: String) -> void:
	for i in text.length():
		var ev := InputEventKey.new()
		ev.pressed = true
		ev.unicode = text.unicode_at(i)
		ev.keycode = OS.find_keycode_from_string(text[i].to_upper())
		Input.parse_input_event(ev)
		await get_tree().process_frame
		var up := ev.duplicate() as InputEventKey
		up.pressed = false
		Input.parse_input_event(up)
	await get_tree().process_frame


func _press(key: Key) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = key
	ev.physical_keycode = key
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1


func _hold_move(dir: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	var forward := Vector3(-cam.global_basis.z.x, 0.0, -cam.global_basis.z.z).normalized()
	var right := Vector3(cam.global_basis.x.x, 0.0, cam.global_basis.x.z).normalized()
	var x := dir.dot(right)
	var y := -dir.dot(forward)
	_release_move()
	if x > 0.0: Input.action_press(&"move_right", x)
	elif x < 0.0: Input.action_press(&"move_left", -x)
	if y > 0.0: Input.action_press(&"move_back", y)
	elif y < 0.0: Input.action_press(&"move_forward", -y)


func _release_move() -> void:
	for a in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		Input.action_release(a)
