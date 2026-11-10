extends Node3D
## Test tích hợp: NPC thật, FSM thật, input Esc/F, camera, HUD và dữ liệu phòng .scn.

var _fails: int = 0
var _player: Player
var _ferry: Npc
var _gate: Gatekeeper

func _ready() -> void:
	for save_signal: Signal in [GameState.progress_changed, GameState.progress_committed]:
		if save_signal.is_connected(SaveManager.save_game):
			save_signal.disconnect(SaveManager.save_game)
	_run.call_deferred()

func _run() -> void:
	var saved := GameState.progress
	GameState.replace_progress(PlayerProgress.new())
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(50, 1, 50)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	add_child(floor_body)
	_player = load("res://entities/player/player.tscn").instantiate() as Player
	add_child(_player)
	# Lấy đúng instance từ room nhị phân để bắt lỗi override lời chào cũ.
	var room: Node = load("res://levels/zone_1_wind/level_1/rooms/tier_1/room_10_tier2_gate.scn").instantiate()
	_ferry = room.get_node("FerryAttendant") as Npc
	_ferry.get_parent().remove_child(_ferry)
	room.free()
	_ferry.position = Vector3(1.0, 0, 1.0)
	add_child(_ferry)
	_gate = load("res://entities/npcs/gatekeeper/gatekeeper.tscn").instantiate() as Gatekeeper
	(_gate.get_node("TollService") as TollService).paid_flag = &"test.conversation.toll"
	var barrier: TollBarrier = load("res://entities/npcs/gatekeeper/toll_barrier/toll_barrier.tscn").instantiate()
	add_child(barrier)
	_gate.barrier = barrier
	_gate.position = Vector3(-2, 0, 1)
	add_child(_gate)
	await get_tree().create_timer(0.4).timeout
	var camera := get_viewport().get_camera_3d()
	var original_fov := camera.fov
	var original_pos := camera.position
	var hud := _player.get_node("HUD") as CanvasLayer
	_check(_ferry.pick_dialogue(&"greeting").lines.size() == 3, "Room override replaced by three-line ferry story")
	_check(not _ferry.get_node("ConversationAmbience").is_processing(), "Ferry VFX sleeps while idle")
	_ferry.talk_requested.emit(_player)
	await get_tree().create_timer(1.4).timeout
	_check(camera.fov < original_fov and not hud.visible, "Conversation zoom and HUD concealment")
	_check(_ferry.get_node("ConversationAmbience").is_processing(), "Ferry motes active during story")
	await _press(&"ui_cancel")
	await get_tree().create_timer(0.5).timeout
	_check(_player.controls_enabled and hud.visible, "Esc restores controls and HUD")
	_check(is_equal_approx(camera.fov, original_fov) and camera.position.is_equal_approx(original_pos), "Esc restores original camera")
	_check(not _ferry.get_node("ConversationAmbience").is_processing(), "Motes stop after outro")
	_check(not GameState.has_flag(&"level_1.story.ferry_met"), "Cancelled story does not mark as heard")
	_ferry.talk_requested.emit(_player)
	await _finish_lines(_ferry)
	await _finish_lines(_ferry)
	await _press(&"ui_cancel")
	_check(GameState.has_flag(&"level_1.story.ferry_met"), "Completed first fragment is remembered")
	_check(_ferry.pick_dialogue(&"greeting").resource_path.ends_with("lantern.tres"), "Second conversation reveals lantern fragment")
	_gate.talk_requested.emit(_player)
	await get_tree().create_timer(0.2).timeout
	_player.health.take_damage(1)
	await get_tree().create_timer(0.55).timeout
	_check(_player.controls_enabled and hud.visible, "Damage interrupts conversation")
	_check(is_equal_approx(camera.fov, original_fov), "Damage restores camera")
	_check(not _gate.get_node("ConversationAmbience").is_processing(), "Wind stops after damage")
	_player.health.heal_full()
	# Cổng thu tiền vẫn hỏi giá sau hai câu mở đầu.
	GameState.add_currency(&"soul_jade", 100)
	_gate.talk_requested.emit(_player)
	await _finish_lines(_gate)
	await get_tree().process_frame
	_check(_gate.state_machine.current_state.name == &"Serve", "Greeting reaches toll service")
	var box_ui := _gate.get_dialogue_box()
	box_ui._reveal_all()
	box_ui._choose(0)
	await get_tree().process_frame
	_check(GameState.get_currency(&"soul_jade") == 50, "Toll charged exactly once")
	box_ui._reveal_all()
	await _press(&"interact")
	_check(box_ui._text.text.begins_with("Người dưới bến"), "F continues into the gatekeeper story after payment")
	await _press(&"ui_cancel")
	await get_tree().create_timer(3.0).timeout
	_check(_gate.is_passage_open() and not GameState.has_flag(&"level_1.story.gate_knocking"), "Esc opens the paid gate without marking unfinished story")
	_check(_gate.pick_dialogue(&"greeting").resource_path.ends_with("knocking.tres"), "Unread story remains available after payment")
	_gate.talk_requested.emit(_player)
	await _finish_lines(_gate)
	await get_tree().create_timer(0.5).timeout
	_check(GameState.get_currency(&"soul_jade") == 50, "Lore conversation does not charge again")
	_check(_gate.pick_dialogue(&"greeting").resource_path.ends_with("paid.tres"), "Long revelation not repeated")
	# Nhường camera trong lúc outro đang chạy: không tích lũy zoom qua nhiều lượt.
	_ferry.begin_session(_player)
	await get_tree().create_timer(0.1).timeout
	_ferry.end_session()
	_gate.begin_session(_player)
	await get_tree().create_timer(0.1).timeout
	_gate.end_session()
	await get_tree().create_timer(0.5).timeout
	_check(is_equal_approx(camera.fov, original_fov) and hud.visible, "Rapid NPC handoff restores camera and HUD")
	hud.hide()
	_ferry.begin_session(_player)
	_ferry.end_session()
	await get_tree().create_timer(0.5).timeout
	_check(not hud.visible, "Originally hidden HUD stays hidden after conversation")
	hud.show()
	for requested: int in [0, 999]:
		var effect: Node3D = load("res://components/feedback/conversation/gate_wind.gd").new()
		effect.particle_count = requested
		_ferry.add_child(effect)
		_check(effect._mesh.instance_count == clampi(requested, 1, 24), "Particle allocation bounded for count=%d" % requested)
		effect.free()
	# Xóa NPC giữa hội thoại phải khôi phục ngay, không tween trên node đã rời cây.
	_gate.begin_session(_player)
	await get_tree().create_timer(0.15).timeout
	_gate.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_equal_approx(camera.fov, original_fov) and hud.visible and _player.controls_enabled, "Removing active NPC restores gameplay")
	var scene_scope := Node3D.new()
	add_child(scene_scope)
	_ferry.reparent(scene_scope)
	_ferry.begin_session(_player)
	await get_tree().create_timer(0.15).timeout
	scene_scope.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_equal_approx(camera.fov, original_fov) and hud.visible and _player.controls_enabled, "Unloading NPC scene restores gameplay")
	GameState.replace_progress(saved)
	print("CONVERSATION RESULT fails=", _fails)
	get_tree().quit(_fails)

func _finish_lines(npc: Npc) -> void:
	for index in 12:
		var box := npc.get_dialogue_box()
		if box._mode != DialogueBox.Mode.LINES:
			break
		box._reveal_all()
		await _press(&"interact")
		await get_tree().process_frame

func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func _check(passed: bool, message: String) -> void:
	print("PASS " if passed else "FAIL ", message)
	if not passed:
		_fails += 1
