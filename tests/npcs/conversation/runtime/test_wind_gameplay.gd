extends Node
## Chạy Map Gió thật với renderer, dùng input F/Esc, chụp trước/trong/sau và đo chi phí VFX.
## Chạy có cửa sổ: Godot --path <project> res://tests/npcs/conversation/runtime/test_wind_gameplay.tscn

var _fails: int = 0
const OUTPUT := "res://output/wind_conversation/"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for save_signal: Signal in [GameState.progress_changed, GameState.progress_committed]:
		if save_signal.is_connected(SaveManager.save_game):
			save_signal.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
	var level: ZoneRoot = load("res://levels/zone_1_wind/level_1/level_1.tscn").instantiate()
	var baseline := OS.get_cmdline_user_args().has("--baseline")
	if baseline:
		# Đối chứng: bỏ hẳn component hiệu ứng trước khi đưa map vào cây.
		for effect: Node in level.find_children("Conversation*", "", true, false):
			effect.free()
	add_child(level)
	if not level.is_combat_ready():
		await level.combat_ready
	var player := level.get_node("Player") as Player
	for npc_name: String in ["FerryAttendant", "Tier3Gatekeeper"]:
		var npc := level.find_child(npc_name, true, false) as Npc
		if npc == null:
			_check(false, "Missing " + npc_name)
			continue
		player.teleport(npc.global_position + Vector3(0, 0.1, 1.7))
		await get_tree().create_timer(2.0).timeout
		await _shot(npc_name + "_before")
		await _profile(npc_name + " baseline")
		if baseline:
			continue
		await _press(&"interact")
		await get_tree().create_timer(1.6).timeout
		_check(npc.is_busy(), npc_name + " opens with F input")
		npc.get_dialogue_box()._reveal_all()
		await _shot(npc_name + "_during")
		await _profile(npc_name + " cinematic")
		var ambience: Node3D = npc.get_node("ConversationAmbience")
		var before := Time.get_ticks_usec()
		for i in 1000:
			ambience._process(1.0 / 60.0)
		print("VFX_CPU ", npc_name, " mean_us=", float(Time.get_ticks_usec() - before) / 1000.0)
		await _press(&"ui_cancel")
		await get_tree().create_timer(0.6).timeout
		_check(player.controls_enabled and not ambience.is_processing(), npc_name + " restores gameplay and sleeps VFX")
		await _shot(npc_name + "_after")
		if npc_name == "FerryAttendant":
			await _check_ferry_continuation(npc, player)
	print("RUNTIME RESULT fails=", _fails)
	get_tree().quit(_fails)

func _check_ferry_continuation(npc: Npc, player: Player) -> void:
	var fare := npc.get_node("FerryFareService") as FerryFareService
	var currency_id := fare.currency.id
	GameState.add_currency(currency_id, fare.price)
	var balance := GameState.get_currency(currency_id)
	await _press(&"interact")
	var box := npc.get_dialogue_box()
	for i in 12:
		if box._mode != DialogueBox.Mode.LINES:
			break
		await _press(&"interact")
	_check(box._mode == DialogueBox.Mode.CHOICES, "F reaches ferry fare options")
	if box._mode != DialogueBox.Mode.CHOICES:
		await _press(&"ui_cancel")
		return
	if box.is_processing():
		await _press(&"interact")
	await _press(&"interact")
	_check(fare.has_called() and GameState.get_currency(currency_id) == balance - fare.price, "F pays ferry fare once")
	_check(box.is_open() and box._mode == DialogueBox.Mode.LINES, "Payment leaves the dialogue open for F")
	if box.is_processing():
		await _press(&"interact")
	await _press(&"interact")
	_check(box._line_index == 1 and box._text.text.begins_with("Đêm ấy"), "F continues into the lantern story")
	for i in 12:
		if not box.is_open():
			break
		await _press(&"interact")
	_check(GameState.has_flag(&"level_1.story.ferry_lantern"), "Completing the story saves its flag")
	_check(player.controls_enabled and not box.is_open(), "Finishing the story restores controls")
	_check(GameState.get_currency(currency_id) == balance - fare.price, "Continuing the story does not charge again")
	# Chờ tín hiệu đèn gọi thuyền ngay cả khi test lướt nhanh qua chữ.
	await get_tree().create_timer(fare.call_delay + 0.1).timeout
	var ferry := fare._get_ferry()
	_check(ferry != null and ferry.visible, "The paid ferry arrives while the story continues")

func _profile(label: String) -> void:
	var total: float = 0.0
	var draw_calls: float = 0.0
	for i in 20:
		await get_tree().process_frame
		total += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	print("PROFILE ", label, " process_avg_ms=", total / 20.0, " draw_calls=", draw_calls / 20.0)

func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
		await get_tree().process_frame

func _shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(OUTPUT + label + ".png")
	_check(result == OK, "Screenshot " + label)

func _check(passed: bool, label: String) -> void:
	print("PASS " if passed else "FAIL ", label)
	if not passed:
		_fails += 1
