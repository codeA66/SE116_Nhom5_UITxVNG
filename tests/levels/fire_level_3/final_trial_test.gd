extends Node
## Thử thách cuối ở Hub (va chạm, input và node thật):
## 1. Sàn Hub là ô thường, trụ xanh ở giữa, cổng phòng boss đóng.
## 2. Chưa mở cổng xuống phòng 13: chạm trụ chỉ hiện "chưa đủ can đảm", khoá điều khiển tới khi đóng hộp thoại.
## 3. Đã mở: chạm trụ hỏi thử thách; chọn CHƯA (phải + interact) thì không có gì.
## 4. Chọn ĐỒNG Ý: sàn rung rồi đổi sang lưới dung nham, cửa Hub bị phong ấn, đồng hồ chạy, lửa phun theo đợt,
##    mỗi ô một ngọn lửa vuông; đủ 4 kiểu (lan dọc, lan ngang, lan 4 phía, so le), nhanh dần; trúng lửa thì mất máu.
## 4b. Hết máu giữa chừng: không chết, về trước trụ đầy máu, sàn / cửa / lửa đặt lại; chạm trụ nhận lại được.
## 5. Hết giờ (đặt duration ngắn): sàn trở lại, cửa mở, lưu cờ, cổng phòng boss mở, đi qua được.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/final_trial_test.tscn (-- --capture để chụp ảnh)

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")

var _player: Player
var _level: Node
var _failed: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
	_level = LEVEL.instantiate()
	(_level as ZoneRoot).player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	_run.call_deferred()


func _run() -> void:
	await _frames(30)
	var trial: FinalTrial = _level.get_node("FinalTrial") as FinalTrial
	var dialog: DialogBox = trial.get_node("DialogBox") as DialogBox
	var gate: StoneGate = _level.get_node("BossGate") as StoneGate
	var plain: Node3D = trial.get_node("Floor/Plain")
	var grate: Node3D = trial.get_node("Floor/Grate")
	var altar: Node3D = trial.get_node("Altar")
	# 1. Ban đầu
	_check(plain.get_child_count() == 36 and plain.get_child(0).visible and not grate.get_child(0).visible and not gate.is_open, "Hub: 36 ô sàn thường, cổng phòng boss đóng")
	await _walk_from(Vector3(132, 4.4, 50), Vector3(142, 4, 50))
	_check(_player.global_position.x < 136.0, "cổng phòng boss chặn (x = %.2f)" % _player.global_position.x)
	# 2. Chưa mở khoá
	await _touch_altar(altar)
	_check(dialog.is_open and not dialog.is_question and not _player.controls_enabled, "chưa mở cổng phòng 13: hộp thoại \"chưa đủ can đảm\", khoá điều khiển")
	await _capture("final_trial_locked.png")
	await _frames(20)
	await _press(&"interact")
	await _frames(20)
	_check(not dialog.is_open and _player.controls_enabled and not trial.is_running, "bấm interact: đóng hộp thoại, không bắt đầu")
	# 3. Mở khoá, chọn CHƯA
	GameState.set_flag(&"level_3.hub_south_gate")
	await _touch_altar(altar)
	_check(dialog.is_open and dialog.is_question, "đã mở cổng phòng 13: trụ hỏi thử thách cuối")
	await _capture("final_trial_ask.png")
	await _frames(20)
	await _press(&"move_right")
	await _press(&"interact")
	await _frames(10)
	_check(not dialog.is_open and not trial.is_running, "chọn CHƯA: không bắt đầu")
	# 4. Đồng ý
	trial.duration = 22.0
	await _touch_altar(altar)
	await _frames(20)
	await _press(&"interact")
	await _frames(10)
	_check(trial.is_running and not dialog.is_open, "chọn ĐỒNG Ý: thử thách bắt đầu")
	await _seconds(trial.shake_time + 0.3)
	_check(not plain.get_child(0).visible and grate.get_child(0).visible, "sàn rung rồi đổi sang lưới dung nham")
	var seal: TrialSeal = trial.get_node("Seals/SealWest") as TrialSeal
	_check(seal.is_closed, "cửa Hub bị phong ấn")
	await _walk_from(Vector3(115, 4.4, 54), Vector3(106, 4, 54))
	_check(_player.global_position.x > 112.0, "không ra được cửa tây (x = %.2f)" % _player.global_position.x)
	# 4b. Thất bại: hết máu giữa thử thách → không chết, về trước trụ, mọi thứ đặt lại, nhận lại được
	var player_before: Player = _player
	_player.health.take_damage(99)
	await _seconds(1.6)
	var retry: Vector3 = (trial.get_node("Retry") as Marker3D).global_position
	_check(is_instance_valid(player_before) and player_before == _player and not _player.health.is_dead() and _player.health.current_health == _player.health.max_health, "hết máu giữa thử thách: không chết, hồi đầy máu (không nạp lại khu)")
	_check(_player.global_position.distance_to(retry) < 0.6, "về trước trụ nhận thử thách (cách %.2f m)" % _player.global_position.distance_to(retry))
	await _seconds(trial.shake_time + 0.4)
	_check(not trial.is_running and not trial.is_completed and plain.get_child(0).visible and not grate.get_child(0).visible and not seal.is_closed, "thử thách đặt lại: sàn thường, cửa mở")
	_check(trial.get_flames().all(func(f: GridFlame) -> bool: return f.is_idle()), "lửa tắt hết")
	_check(String(_player.state_machine.current_state.name) != "Dead" and _player.controls_enabled, "điều khiển được bình thường (state %s)" % _player.state_machine.current_state.name)
	await _capture("final_trial_retry.png")
	trial.duration = 45.0
	await _touch_altar(altar)
	_check(dialog.is_open and dialog.is_question, "chạm trụ lần nữa: hỏi lại thử thách")
	await _frames(20)
	await _press(&"interact")
	await _frames(10)
	_check(trial.is_running, "đồng ý lần nữa: thử thách chạy lại")
	await _seconds(trial.shake_time + 0.3)
	# Lửa: mỗi ô một ngọn lửa vuông vừa ô
	var flames: Array[GridFlame] = trial.get_flames()
	_check(flames.size() == 36, "36 ô, mỗi ô một ngọn lửa vuông (%d)" % flames.size())
	# Kiểu lan: bước đầu của mỗi kiểu là đúng hàng / cột / vòng giữa, so le là ô cùng màu bàn cờ
	var v: Array[Array] = trial.build_steps(FinalTrial.Pattern.SPREAD_VERTICAL)
	var h: Array[Array] = trial.build_steps(FinalTrial.Pattern.SPREAD_HORIZONTAL)
	var r: Array[Array] = trial.build_steps(FinalTrial.Pattern.SPREAD_ALL)
	var k: Array[Array] = trial.build_steps(FinalTrial.Pattern.CHECKER)
	var centre: Vector3 = trial.global_position
	var v_ok: bool = v.size() == 3 and v[0].size() == 12 and v[0].all(func(f: GridFlame) -> bool: return absf(f.global_position.z - centre.z) < 4.1)
	var h_ok: bool = h.size() == 3 and h[0].size() == 12 and h[0].all(func(f: GridFlame) -> bool: return absf(f.global_position.x - centre.x) < 4.1)
	var r_ok: bool = r.size() == 3 and r[0].size() == 4 and r[1].size() == 12 and r[2].size() == 20
	var k_ok: bool = k.size() == 2 and k[0].size() == 18 and k[1].size() == 18
	_check(v_ok, "lan dọc: hàng giữa trước, rồi ra 2 bên theo chiều dọc (3 bước)")
	_check(h_ok, "lan ngang: cột giữa trước, rồi ra 2 bên theo chiều ngang (3 bước)")
	_check(r_ok, "lan 4 phía: 4 ô giữa → vòng 12 → vòng 20")
	_check(k_ok, "so le: 18 ô xen kẽ rồi 18 ô còn lại")
	_player.teleport(trial.global_position + Vector3(6, 0.1, 6))
	var hurtbox: HurtboxComponent = _player.get_node("HurtboxComponent") as HurtboxComponent
	# Đứng yên chờ các kiểu lửa chạy: bật bất tử để không chết giữa chừng (chết là nạp lại khu)
	hurtbox.invulnerable = true
	await _seconds(2.5)
	await _capture("final_trial_running.png")
	await _seconds(trial.duration - 5.5)
	hurtbox.invulnerable = false
	var kinds: int = trial.fired_steps.size()
	_check(kinds == 4, "trong thử thách đã chạy đủ 4 kiểu lửa (%s)" % str(trial.fired_steps))
	var early_warn: float = lerpf(trial.warning_time.x, trial.warning_time.y, 0.0)
	var late_warn: float = lerpf(trial.warning_time.x, trial.warning_time.y, 0.9)
	_check(late_warn < early_warn, "nhanh dần: cảnh báo %.2f s lúc đầu → %.2f s về cuối" % [early_warn, late_warn])
	var min_gap: float = minf(trial.step_gap.x, trial.step_gap.y)
	_check(min_gap >= trial.burst_time + 0.4 and trial.warning_time.y >= 1.0, "luôn né được: bước sau bùng khi bước trước đã tắt ≥ %.1f s, cảnh báo tối thiểu %.1f s" % [min_gap - trial.burst_time, trial.warning_time.y])
	# Lửa ở ô đang đứng: phun là mất máu
	_player.health.heal_full()
	var hp0: int = _player.health.current_health
	var mine: GridFlame = null
	for f: GridFlame in flames:
		var d: Vector3 = f.global_position - _player.global_position
		if absf(d.x) < 1.6 and absf(d.z) < 1.6:
			mine = f
	if mine:
		while not mine.is_idle():
			await _frames(2)
		mine.fire(0.3, 0.6)
		await _seconds(0.6)
	_check(mine != null and _player.health.current_health < hp0, "lửa ô đang đứng phun: mất máu (%d → %d)" % [hp0, _player.health.current_health])
	_player.health.heal_full()
	# 5. Hết giờ
	await _seconds(trial.time_left() + trial.shake_time + 0.6)
	_check(trial.is_completed and not trial.is_running and GameState.has_flag(trial.persistent_id), "sống hết giờ: hoàn thành, lưu cờ")
	_check(plain.get_child(0).visible and not grate.get_child(0).visible and not seal.is_closed, "sàn trở lại, cửa mở")
	await _frames(120)
	_check(gate.is_open, "cổng phòng boss mở")
	await _walk_from(Vector3(132, 4.4, 50), Vector3(142, 4, 50))
	_check(_player.global_position.x > 138.0, "đi qua cổng vào phòng boss (x = %.2f)" % _player.global_position.x)
	print("FINAL TRIAL RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


func _touch_altar(altar: Node3D) -> void:
	_player.teleport(altar.global_position + Vector3(2.3, 0.1, 0), Vector3.LEFT)
	await _frames(10)
	await _press(&"interact")
	await _frames(5)


func _press(action: StringName) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	var up: InputEventAction = InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(1)


func _seconds(s: float) -> void:
	await get_tree().create_timer(s, false, true).timeout


func _walk_from(start: Vector3, target: Vector3) -> void:
	_player.teleport(start)
	await _frames(10)
	var t: float = 0.0
	while t < 3.0:
		var flat: Vector2 = Vector2(target.x - _player.global_position.x, target.z - _player.global_position.z)
		if flat.length() < 0.6:
			break
		var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
		var right: Vector3 = Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
		var forward: Vector3 = Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
		var d: Vector3 = Vector3(flat.x, 0.0, flat.y).normalized()
		_axis(&"move_right", &"move_left", d.dot(right))
		_axis(&"move_back", &"move_forward", -d.dot(forward))
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	for a: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		Input.action_release(a)


func _axis(positive: StringName, negative: StringName, value: float) -> void:
	if value > 0.05:
		Input.action_press(positive, clampf(value, 0.0, 1.0))
		Input.action_release(negative)
	elif value < -0.05:
		Input.action_press(negative, clampf(-value, 0.0, 1.0))
		Input.action_release(positive)
	else:
		Input.action_release(positive)
		Input.action_release(negative)


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
