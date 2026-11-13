extends Node
## Test thử thách u tối (bản 2 giai đoạn 3, docs/zone_3_fire/tier_2_tower_design.md mục 0):
## 1. Đặt đủ mảnh ở bệ (đi bộ + interact thật) thì bắt đầu: 3 trụ, đồng hồ, khu tối (đèn mặt trời thật sự giảm), vùng tối phòng 07 tạm tắt.
## 2. Trụ: player vào phòng thì lồng sinh đúng loại quái; phá lồng + hạ quái thì hiện lò; thắp lò thì trụ xong.
##    Thắp ngoài thứ tự (Nam, Bắc, Đông). Đủ 3: lưu cờ, sáng lại, đồng hồ ẩn, vùng tối 07 bật lại.
## 3. Tải lại sau khi thắng: không có trụ, không mời bắt đầu.
## 4. Hết giờ (đồng hồ cực ngắn 3 s): dọn trụ và quái, sáng lại, bệ mời "THỬ LẠI"; bấm thì chạy lại. Đồng hồ cực dài 900 s hiện 15:00.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/tier_2/dark_trial/dark_trial_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")
const SHARDS: ForgeShardSet = preload("res://resources/world/puzzles/forge_shards.tres")
var DATA: DarkTrialData = preload("res://resources/world/puzzles/dark_trial.tres")
const FRONT: Vector3 = Vector3(278, 4.42, 48.6)
const START: Vector3 = Vector3(278, 4.42, 54)
## Loại quái mong đợi theo trụ (tên script lớp quái)
const ENEMY_KIND: Dictionary = {&"NorthPillar": "fire_spider", &"EastPillar": "shadow_wolf", &"SouthPillar": "fire_caster"}

var _player: Player
var _level: ZoneRoot
var _failed: int = 0
var _checks: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	get_tree().create_timer(240.0, true, true).timeout.connect(func() -> void:
		print("DARK TRIAL RESULT: TIMEOUT")
		get_tree().quit(2))
	var base_duration: float = DATA.duration
	_fresh_progress()
	for flag: StringName in SHARDS.shard_flags:
		GameState.set_flag(flag)
	await _load_level()
	await _t_start()
	await _t_pillars()
	await _reload()
	_t_after_win()
	# Hết giờ: progress mới, đã ghép công tắc từ trước (vào map lại), đồng hồ 3 s
	_fresh_progress()
	for i: int in SHARDS.total():
		GameState.set_flag(SHARDS.shard_flags[i])
		GameState.set_flag(SHARDS.placed_flags[i])
	GameState.set_flag(SHARDS.switch_flag)
	DATA.duration = 3.0
	await _reload()
	await _t_timeout()
	DATA.duration = 900.0
	await _reload()
	await _t_long()
	DATA.duration = base_duration
	print("DARK TRIAL RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


func _fresh_progress() -> void:
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_flag(&"level_3.boss_defeated")
	# Trận các khu đã thắng: chỉ quái của trụ có mặt
	for flag: StringName in [&"level_3.t2_hub_ambush", &"level_3.t2_timber_caster", &"level_3.t2_slime_hall",
			&"level_3.t2_dark_forge_pack", &"level_3.t2_wisps_cleared", &"level_3.t2_exit_vines"]:
		GameState.set_flag(flag)


func _trial() -> DarkTrial:
	return _level.get_node(^"Tier2Mechanics/DarkTrial") as DarkTrial


func _sun() -> DirectionalLight3D:
	return _level.get_node(^"FireLighting/SunLight") as DirectionalLight3D


func _room07_zone() -> DarkZone:
	return _level.get_node(^"Tier2Mechanics/Room07Blackout/DarkZone") as DarkZone


func _t_start() -> void:
	var trial := _trial()
	var sun_before: float = _sun().light_energy
	_check(not trial.is_running() and trial.get_pillars().is_empty(), "chưa ghép công tắc: thử thách chưa chạy")
	await _walk_and_interact()
	_check(trial.is_running() and trial.get_pillars().size() == 3, "đặt đủ mảnh ở bệ: thử thách bắt đầu, 3 trụ")
	var hud := trial.get_node(^"TrialTimer") as TrialTimer
	_check((hud.get_node(^"Panel") as Control).visible and hud.get_text() in ["2:00", "1:59"], "đồng hồ hiện %s" % hud.get_text())
	_check(not _room07_zone().monitoring, "vùng tối phòng 07 tạm tắt")
	# Trụ và vòng quái sinh quanh nó (bán kính lồng) đứng trên sàn thật, không lơ lửng trên vực
	var space := _level.get_world_3d().direct_space_state
	for pillar: EnergyPillar in trial.get_pillars():
		var solid: bool = true
		var radius: float = pillar.get_cage().spawn_radius
		for off: Vector3 in [Vector3.ZERO, Vector3(radius, 0, 0), Vector3(-radius, 0, 0), Vector3(0, 0, radius), Vector3(0, 0, -radius)]:
			var from: Vector3 = pillar.global_position + off + Vector3(0, 3, 0)
			var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -6, 0))
			query.exclude = [pillar.get_cage().get_rid()]
			var hit := space.intersect_ray(query)
			solid = solid and not hit.is_empty() and absf(float(hit.position.y) - pillar.global_position.y) < 0.2
		_check(solid, "%s: chân trụ và vòng sinh quái %.1f m nằm trên sàn" % [pillar.name, radius])
	await _frames(90)
	_check(_sun().light_energy < sun_before * 0.1, "khu tối thật: nắng %.2f → %.2f" % [sun_before, _sun().light_energy])


func _t_pillars() -> void:
	var trial := _trial()
	var sun_dark: float = _sun().light_energy
	var order: Array[StringName] = [&"SouthPillar", &"NorthPillar", &"EastPillar"]
	for i: int in order.size():
		var pillar := trial.get_node(NodePath("Pillars/%s" % order[i])) as EnergyPillar
		await _clear_pillar(pillar)
		_check(pillar.get_brazier() != null and not pillar.is_lit(), "%s: dọn lồng xong thì hiện lò, chưa thắp" % pillar.name)
		pillar.get_brazier().get_node("BurnableComponent").ignite(_player)
		await _frames(5)
		_check(pillar.is_lit() and trial.lit_count() == i + 1, "%s: thắp lò → %d/3 trụ" % [pillar.name, trial.lit_count()])
		if i < order.size() - 1:
			_check(trial.is_running(), "%s: chưa đủ trụ, thử thách còn chạy" % pillar.name)
	_check(not trial.is_running() and GameState.has_flag(DATA.done_flag), "đủ 3 trụ: thắng, lưu cờ %s" % DATA.done_flag)
	_check(not (trial.get_node(^"TrialTimer/Panel") as Control).visible, "thắng: đồng hồ ẩn")
	_check(_room07_zone().monitoring, "thắng: vùng tối phòng 07 bật lại")
	_player.teleport(Vector3(278, 4.42, 54))
	await _frames(90)
	_check(_sun().light_energy > sun_dark + 0.2, "thắng: trời sáng lại (nắng %.2f)" % _sun().light_energy)


## Vào phòng của trụ, chờ lồng sinh quái, phá lồng và hạ quái
func _clear_pillar(pillar: EnergyPillar) -> void:
	var cage := pillar.get_cage()
	_player.teleport(pillar.global_position + Vector3(0, 0.1, 4.0))
	_player.health.max_health = 9999
	_player.health.heal_full()
	var t: int = 0
	while cage.alive_count() == 0 and t < 400:
		await get_tree().physics_frame
		t += 1
	var enemies: Array[Node] = cage.get_node("Enemies").get_children()
	var kind: String = ENEMY_KIND[pillar.name]
	var ok_kind: bool = not enemies.is_empty()
	for e: Node in enemies:
		ok_kind = ok_kind and (e as Node).scene_file_path.contains(kind)
	_check(ok_kind, "%s: player vào phòng thì lồng sinh %s (%d con sau %.1f s)" % [pillar.name, kind, enemies.size(), t / 60.0])
	(cage.get_node("HealthComponent") as HealthComponent).take_damage(99999)
	await _frames(5)
	for e: Node in cage.get_node("Enemies").get_children():
		if e is Enemy:
			(e as Enemy).health.take_damage(99999)
	var w: int = 0
	while pillar.get_brazier() == null and w < 300:
		await get_tree().physics_frame
		w += 1


func _t_after_win() -> void:
	var trial := _trial()
	_check(trial.is_done() and not trial.is_running() and trial.get_pillars().is_empty(), "tải lại sau khi thắng: không trụ, không chạy")
	_check(not (trial.get_node(^"StartInteract") as InteractableComponent).enabled, "tải lại sau khi thắng: bệ không mời bắt đầu")


func _t_timeout() -> void:
	var trial := _trial()
	var start := trial.get_node(^"StartInteract") as InteractableComponent
	_check(not trial.is_running() and start.enabled and start.prompt_text == DATA.start_prompt, "vào lại map khi đã ghép công tắc: bệ mời \"%s\"" % start.prompt_text)
	var sun_before: float = _sun().light_energy
	await _walk_and_interact()
	_check(trial.is_running(), "bấm bệ: thử thách chạy (đồng hồ 3 s)")
	# Vào phòng 05 cho lồng sinh quái để đo dọn sạch lúc thua
	var north := trial.get_node(^"Pillars/NorthPillar") as EnergyPillar
	_player.teleport(north.global_position + Vector3(0, 0.1, 4.0))
	_player.health.max_health = 9999
	_player.health.heal_full()
	await _frames(int(3.5 * 60.0))
	_check(not trial.is_running() and not GameState.has_flag(DATA.done_flag), "hết 3 s: thua, không lưu cờ thắng")
	await _frames(5)
	_check(_trial().get_node("Pillars").get_child_count() == 0, "thua: dọn hết trụ và quái của trụ")
	_check(start.enabled and start.prompt_text == DATA.retry_prompt, "thua: bệ mời \"%s\"" % start.prompt_text)
	_player.teleport(START)
	await _frames(90)
	_check(_sun().light_energy > sun_before * 0.8, "thua: trời sáng lại (nắng %.2f / %.2f)" % [_sun().light_energy, sun_before])
	await _walk_and_interact()
	_check(trial.is_running() and trial.get_pillars().size() == 3, "bấm THỬ LẠI: chạy lại với 3 trụ mới")
	await _frames(int(3.5 * 60.0))


func _t_long() -> void:
	var trial := _trial()
	await _walk_and_interact()
	await _frames(10)
	var text: String = (trial.get_node(^"TrialTimer") as TrialTimer).get_text()
	_check(trial.is_running() and text in ["15:00", "14:59"], "đồng hồ 900 s hiện %s" % text)
	var warn: bool = (trial.get_node(^"TrialTimer") as TrialTimer).is_warning()
	_check(not warn, "còn nhiều giờ: đồng hồ không đỏ")
	# Hitstop (time_scale 0,05) không làm đồng hồ khựng: 1 s giờ thật vẫn trừ ~1 s
	var before: float = trial.time_left()
	var t0: int = Time.get_ticks_msec()
	Engine.time_scale = 0.05
	while Time.get_ticks_msec() - t0 < 1000:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	var spent: float = before - trial.time_left()
	_check(spent > 0.8 and spent < 1.3, "hitstop không làm đồng hồ khựng: 1 s giờ thật trừ %.2f s" % spent)


func _load_level() -> void:
	_level = LEVEL.instantiate()
	_level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	await _frames(30)


func _reload() -> void:
	_level.queue_free()
	await _frames(5)
	await _load_level()


func _walk_and_interact() -> void:
	_player.teleport(START)
	(_player.get_node("CameraRig") as CameraRig).snap()
	await _frames(15)
	for _i: int in range(240):
		var flat := Vector2(FRONT.x - _player.global_position.x, FRONT.z - _player.global_position.z)
		if flat.length() < 0.4:
			break
		_press_towards(Vector3(flat.x, 0, flat.y).normalized())
		await get_tree().physics_frame
	_release()
	await _frames(10)
	await _tap(&"interact")
	await _frames(30)


func _tap(action: StringName) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await _frames(3)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func _press_towards(world_dir: Vector3) -> void:
	var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
	var forward := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
	var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	_set_axis(&"move_right", &"move_left", world_dir.dot(right))
	_set_axis(&"move_back", &"move_forward", -world_dir.dot(forward))


func _set_axis(positive: StringName, negative: StringName, value: float) -> void:
	if value > 0.05:
		Input.action_press(positive, clampf(value, 0.0, 1.0))
		Input.action_release(negative)
	elif value < -0.05:
		Input.action_press(negative, clampf(-value, 0.0, 1.0))
		Input.action_release(positive)
	else:
		Input.action_release(positive)
		Input.action_release(negative)


func _release() -> void:
	for a: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		Input.action_release(a)


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_failed += 1
