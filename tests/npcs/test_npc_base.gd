extends Node3D
## Test NPC dùng chung (Npc + FSM Idle/Talk/Serve + hộp thoại + service). Bấm phím thật (Input.parse_input_event),
## player thật, tiến trình giả trong bộ nhớ, không ghi save thật.
## Chạy: mở test_npc_base.tscn rồi F6, hoặc headless. Chụp ảnh: chạy có cửa sổ kèm -- --shots=<thư mục>.
##
## ===== USE CASE =====
## UC1  Cáo ở xa: NPC đứng yên, không chạy _physics_process. Vào vùng nhìn: NPC quay dần về phía cáo. Đứng sát: gợi ý "NÓI CHUYỆN".
## UC2  Lần đầu nói chuyện (F): khóa điều khiển, hộp thoại mở, tên NPC, chữ hiện dần; F hiện hết câu; F sang câu;
##      câu có người nói riêng (Foxy) đổi tên; hết đoạn -> bật cờ "đã gặp" -> mở service (hỏi kèm lựa chọn).
## UC3  Lựa chọn: xuống -> "Không", F -> câu đáp đúng lựa chọn; xong -> lời tạm biệt -> về Idle, trả điều khiển, hộp đóng.
## UC4  Lần sau: đoạn "gặp lại" (vì cờ đã bật). Esc giữa chừng -> về Idle ngay, không mở service.
## UC5  Bị đánh lúc đang nói chuyện -> cắt ngang, trả điều khiển.
## UC6  Hai NPC cùng map: nói với A thì B vẫn Idle, B không tạo hộp thoại; nói với B riêng vẫn chạy.
## UC7  Chuột trái sang câu; rê chuột lên lựa chọn = chọn nó.
## UC8  Cực đoan: chữ hiện ngay (tốc độ 0) và rất nhanh, câu rất dài (hộp mọc lên, vẫn trong màn), NPC không lời không service,
##      đoạn thoại 0 câu, hỏi 0 lựa chọn, màn hẹp 640 px, NPC bị xóa giữa lúc nói -> điều khiển vẫn được trả.

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const NPC_SCENE: PackedScene = preload("res://tests/fire/sandbox/npc/sandbox_npc.tscn")
const BASE_NPC_SCENE: PackedScene = preload("res://entities/npcs/_base/npc.tscn")
const MET_FLAG := &"test.sandbox_npc.met"

var _fails: int = 0
var _shots: String = ""
var _player: Player
var _npc_a: Npc
var _npc_b: Npc


func _ready() -> void:
	for save_signal: Signal in [GameState.progress_changed, GameState.progress_committed]:
		if save_signal.is_connected(SaveManager.save_game):
			save_signal.disconnect(SaveManager.save_game)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
	_run.call_deferred()


func _run() -> void:
	var saved := GameState.progress
	GameState.replace_progress(PlayerProgress.new())
	_build_world()
	await _physics(10)
	await _uc1_look_and_prompt()
	await _uc2_first_talk()
	await _uc3_choice_and_farewell()
	await _uc4_repeat_and_cancel()
	await _uc5_damage_interrupt()
	await _uc6_two_npcs()
	await _uc7_mouse()
	await _uc8_extreme()
	GameState.replace_progress(saved)
	print("RESULT fails=%d" % _fails)
	get_tree().quit()


func _build_world() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	floor_body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box.size
	mesh.mesh = box_mesh
	floor_body.add_child(mesh)
	floor_body.position.y = -0.5
	add_child(floor_body)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	_npc_a = NPC_SCENE.instantiate() as Npc
	_npc_a.name = "NpcA"
	_npc_a.position = Vector3(0, 0, 0)
	add_child(_npc_a)
	_npc_b = NPC_SCENE.instantiate() as Npc
	_npc_b.name = "NpcB"
	_npc_b.display_name = "Người thứ hai"
	_npc_b.position = Vector3(20, 0, 0)
	add_child(_npc_b)
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = Vector3(0, 0, -14)
	add_child(_player)


func _box(npc: Npc) -> DialogueBox:
	return npc.get_dialogue_box()


func _state(npc: Npc) -> StringName:
	return npc.state_machine.current_state.name


func _uc1_look_and_prompt() -> void:
	_check(_state(_npc_a) == &"Idle" and not _npc_a.is_physics_processing(), "UC1: cáo ở xa -> Idle, không chạy physics")
	_npc_a.visual.rotation.y = 0.0
	_place_player(Vector3(-3.5, 0, 0))
	await _physics(4)
	_check(_npc_a.is_physics_processing(), "UC1: cáo vào vùng nhìn -> bật physics để quay")
	await _physics(60)
	var to_player := _player.global_position - _npc_a.global_position
	var target := atan2(to_player.x, to_player.z)
	var diff := rad_to_deg(absf(angle_difference(_npc_a.visual.rotation.y, target)))
	_check(diff < 5.0, "UC1: NPC quay về phía cáo (lệch %.1f°)" % diff)
	_place_player(Vector3(-1.2, 0, 0))
	await _physics(4)
	var focus := _player.interactor.current
	_check(focus != null and focus.get_parent() == _npc_a and focus.prompt_text == "NÓI CHUYỆN", "UC1: đứng sát -> gợi ý NÓI CHUYỆN")
	_place_player(Vector3(-20, 0, 0))
	await _physics(4)
	_check(not _npc_a.is_physics_processing(), "UC1: cáo đi khỏi -> tắt physics")
	_place_player(Vector3(-1.2, 0, 0))
	await _physics(4)


func _uc2_first_talk() -> void:
	await _press(&"interact")
	var box := _box(_npc_a)
	_check(_state(_npc_a) == &"Talk", "UC2: F -> NPC sang Talk")
	_check(not _player.controls_enabled, "UC2: khóa điều khiển cáo")
	_check(box.is_open() and box.visible, "UC2: hộp thoại mở")
	var name_label := box.get_node("Box/Name") as Label
	var text := box.get_node("Box/Panel/Margin/Content/Text") as Label
	_check(name_label.text == "NGƯỜI GIỮ LỬA", "UC2: tên NPC trên hộp ('%s')" % name_label.text)
	_check(text.visible_characters >= 0 and text.visible_characters < text.get_total_character_count(), "UC2: chữ đang hiện dần (%d/%d)" % [text.visible_characters, text.get_total_character_count()])
	_check(not _npc_a._interactable.enabled, "UC2: tắt gợi ý tương tác khi đang nói")
	await _shot("typing")
	await _press(&"interact")
	_check(text.visible_characters == -1 and text.text.contains("lạc tới đây"), "UC2: F lần 1 -> hiện hết câu 1")
	await _press(&"interact")
	_check(text.text.contains("người giữ lửa"), "UC2: F lần 2 -> sang câu 2")
	await _press(&"interact")
	await _press(&"interact")
	_check(name_label.text == "FOXY", "UC2: câu 3 đổi tên người nói thành FOXY ('%s')" % name_label.text)
	_check(not GameState.has_flag(MET_FLAG), "UC2: chưa hết đoạn thì chưa bật cờ")
	await _press(&"interact")
	await _press(&"interact")
	await _physics(4)
	_check(GameState.has_flag(MET_FLAG), "UC2: hết đoạn -> bật cờ đã gặp")
	_check(_state(_npc_a) == &"Serve", "UC2: hết đoạn -> mở service (%s)" % _state(_npc_a))
	await _settle_typing(box)
	var choices := box.get_node("Box/Panel/Margin/Content/Choices") as VBoxContainer
	_check(choices.visible and _visible_buttons(choices) == 2, "UC2: hiện 2 lựa chọn")
	var focused := get_viewport().gui_get_focus_owner() as Button
	_check(focused != null and focused.text.begins_with("»") and focused.text.contains("Có"), "UC2: con trỏ ở 'Có' có dấu »")
	await _shot("choices")


func _uc3_choice_and_farewell() -> void:
	var box := _box(_npc_a)
	await _press(&"ui_down")
	var focused := get_viewport().gui_get_focus_owner() as Button
	_check(focused != null and focused.text.contains("Không") and focused.text.begins_with("»"), "UC3: xuống -> 'Không'")
	await _press(&"interact")
	var service := _npc_a.get_node("ChoiceService")
	_check(int(service.get(&"last_choice")) == 1, "UC3: service nhận lựa chọn 1")
	await _settle_typing(box)
	var text := box.get_node("Box/Panel/Margin/Content/Text") as Label
	_check(text.text.contains("Tùy ngươi"), "UC3: câu đáp đúng lựa chọn ('%s')" % text.text)
	await _press(&"interact")
	await _physics(4)
	_check(_state(_npc_a) == &"Talk", "UC3: service đóng -> nói lời tạm biệt")
	await _settle_typing(box)
	_check(text.text.contains("Đi cẩn thận"), "UC3: lời tạm biệt đúng")
	await _press(&"interact")
	await _physics(4)
	_check(_state(_npc_a) == &"Idle", "UC3: tạm biệt xong -> Idle")
	_check(_player.controls_enabled, "UC3: trả điều khiển")
	_check(_npc_a._interactable.enabled, "UC3: bật lại gợi ý tương tác")
	await _wait(0.4)
	_check(not box.visible, "UC3: hộp thoại đã đóng hẳn")


func _uc4_repeat_and_cancel() -> void:
	var service := _npc_a.get_node("ChoiceService")
	service.set(&"last_choice", -2)
	await _press(&"interact")
	var box := _box(_npc_a)
	await _settle_typing(box)
	var text := box.get_node("Box/Panel/Margin/Content/Text") as Label
	_check(text.text.contains("Lại là ngươi"), "UC4: lần sau -> đoạn gặp lại ('%s')" % text.text)
	await _press(&"ui_cancel")
	await _physics(4)
	_check(_state(_npc_a) == &"Idle" and _player.controls_enabled, "UC4: Esc -> Idle, trả điều khiển")
	_check(int(service.get(&"last_choice")) == -2, "UC4: Esc -> không mở service")
	await _wait(0.4)
	_check(not box.visible, "UC4: Esc -> hộp đóng")


func _uc5_damage_interrupt() -> void:
	await _press(&"interact")
	_check(_state(_npc_a) == &"Talk" and not _player.controls_enabled, "UC5: đang nói chuyện")
	_player.health.take_damage(1)
	await _physics(4)
	_check(_state(_npc_a) == &"Idle" and _player.controls_enabled, "UC5: bị đánh -> cắt ngang, trả điều khiển")
	_player.health.heal_full()
	# Chờ hết bất tử sau khi bị đánh để các bước sau không bị ảnh hưởng
	await _wait(1.6)


func _uc6_two_npcs() -> void:
	await _press(&"interact")
	_check(_state(_npc_a) == &"Talk", "UC6: nói với A")
	_check(_state(_npc_b) == &"Idle" and not _npc_b.is_busy() and _npc_b._dialogue_box == null, "UC6: B vẫn Idle, chưa tạo hộp thoại")
	await _press(&"ui_cancel")
	await _physics(4)
	_place_player(Vector3(18.8, 0, 0))
	await _physics(6)
	await _press(&"interact")
	_check(_state(_npc_b) == &"Talk" and _state(_npc_a) == &"Idle", "UC6: nói với B, A vẫn Idle")
	var name_label := _box(_npc_b).get_node("Box/Name") as Label
	_check(name_label.text == "NGƯỜI THỨ HAI", "UC6: hộp của B ghi tên B ('%s')" % name_label.text)
	await _press(&"ui_cancel")
	await _physics(4)
	_check(_player.controls_enabled and _state(_npc_b) == &"Idle", "UC6: thoát B -> trả điều khiển")
	_place_player(Vector3(-1.2, 0, 0))
	await _physics(6)


func _uc7_mouse() -> void:
	await _press(&"interact")
	var box := _box(_npc_a)
	var text := box.get_node("Box/Panel/Margin/Content/Text") as Label
	await _settle_typing(box)
	await _click(Vector2(5, 5))
	await _physics(4)
	_check(_state(_npc_a) == &"Serve", "UC7: chuột trái sang câu -> hết đoạn, mở service")
	await _settle_typing(box)
	var choices := box.get_node("Box/Panel/Margin/Content/Choices") as VBoxContainer
	var second := choices.get_child(1) as Button
	await _hover(second.get_global_rect().get_center())
	var focused := get_viewport().gui_get_focus_owner() as Button
	_check(focused == second and second.text.begins_with("»"), "UC7: rê chuột lên lựa chọn 2 -> chọn nó")
	await _press(&"ui_cancel")
	await _physics(6)
	_check(_state(_npc_a) == &"Idle" and _player.controls_enabled, "UC7: Esc lúc đang chọn -> thoát hẳn (%s)" % _state(_npc_a))
	_check(text != null, "UC7: xong")


func _uc8_extreme() -> void:
	var box := _box(_npc_a)
	var style := box.style
	var old_speed := style.chars_per_second
	var text := box.get_node("Box/Panel/Margin/Content/Text") as Label
	# Tốc độ 0 = hiện ngay
	style.chars_per_second = 0.0
	await _press(&"interact")
	_check(text.visible_characters == -1 and not box.is_processing(), "UC8: tốc độ 0 -> hiện ngay cả câu")
	await _press(&"ui_cancel")
	await _physics(4)
	# Rất nhanh: vài frame là xong, không treo
	style.chars_per_second = 100000.0
	await _press(&"interact")
	await _physics(3)
	_check(text.visible_characters == -1, "UC8: tốc độ rất lớn -> hiện xong ngay")
	await _press(&"ui_cancel")
	await _physics(4)
	style.chars_per_second = old_speed
	# Câu rất dài: hộp mọc lên, vẫn nằm trong màn
	var long_line := DialogueLine.new()
	long_line.text = "(Chữ tạm) " + "Gió từ đỉnh tháp thổi xuống mang theo tro của những ngọn lửa đã tắt. ".repeat(10)
	_npc_a.begin_session(_player)
	var lines: Array[DialogueLine] = [long_line]
	box.play_lines(lines, "Dài")
	await _settle_typing(box)
	await _wait(0.3)
	var rect := (box.get_node("Box") as Control).get_global_rect()
	var screen := get_viewport().get_visible_rect()
	_check(screen.encloses(rect), "UC8: câu rất dài -> hộp vẫn trong màn (%s trong %s)" % [rect, screen])
	await _shot("long")
	# Màn hẹp: hộp tự thu
	get_window().size = Vector2i(640, 480) if DisplayServer.get_name() != "headless" else get_window().size
	get_viewport().size_changed.emit()
	await _physics(4)
	rect = (box.get_node("Box") as Control).get_global_rect()
	screen = get_viewport().get_visible_rect()
	_check(rect.size.x <= screen.size.x, "UC8: màn hẹp -> hộp không rộng quá màn (%.0f / %.0f)" % [rect.size.x, screen.size.x])
	_npc_a.end_session()
	await _physics(2)
	_check(_player.controls_enabled, "UC8: end_session trả điều khiển")
	# Đoạn 0 câu / hỏi 0 lựa chọn: vẫn trả kết quả, không treo
	var empty: Array[DialogueLine] = []
	var result: int = await _npc_a.say(empty)
	_check(result == DialogueBox.RESULT_DONE, "UC8: đoạn 0 câu -> xong ngay")
	result = await _npc_a.ask("?", PackedStringArray())
	_check(result == DialogueBox.RESULT_CANCELLED, "UC8: hỏi 0 lựa chọn -> coi như thoát")
	# NPC không lời, không service: bấm F không kẹt điều khiển
	var mute := BASE_NPC_SCENE.instantiate() as Npc
	mute.position = Vector3(-30, 0, 10)
	add_child(mute)
	_place_player(Vector3(-28.8, 0, 10))
	await _physics(6)
	await _press(&"interact")
	await _physics(6)
	_check(_state(mute) == &"Idle" and _player.controls_enabled, "UC8: NPC không lời / không service -> không kẹt")
	# NPC bị xóa giữa lúc nói: điều khiển vẫn được trả
	_place_player(Vector3(-1.2, 0, 0))
	await _physics(6)
	await _press(&"interact")
	_check(not _player.controls_enabled, "UC8: đang nói với A")
	_npc_a.queue_free()
	await _physics(3)
	_check(_player.controls_enabled, "UC8: A bị xóa giữa chừng -> trả điều khiển")


func _place_player(at: Vector3) -> void:
	_player.teleport(at)


func _visible_buttons(container: Container) -> int:
	var count := 0
	for child in container.get_children():
		if (child as Control).visible:
			count += 1
	return count


func _settle_typing(box: DialogueBox) -> void:
	for i in 600:
		if not box.is_processing():
			break
		await get_tree().physics_frame
	await _physics(2)


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await _physics(2)


func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		get_viewport().push_input(event)
		await _physics(2)


func _hover(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	var screen_at := get_viewport().get_final_transform() * at
	event.position = screen_at
	event.global_position = screen_at
	get_viewport().push_input(event)
	await _physics(3)


func _shot(name_: String) -> void:
	if _shots.is_empty() or DisplayServer.get_name() == "headless":
		return
	await _wait(0.3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shots.path_join("npc_%s.png" % name_))


func _physics(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
