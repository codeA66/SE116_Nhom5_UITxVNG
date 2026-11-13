extends Node
## Đo thời gian thử thách u tối bằng người chơi máy, input thật từ đầu tới cuối (không dịch chuyển giữa chừng):
## bấm bệ → đi Bắc (05) → đánh quái + phá lồng → thắp lò bằng Phun lửa → về Hub → Đông (07, đi theo lối gạch) → trụ Đông
## → cổng xoáy về Hub → Nam (09) → trụ Nam. In thời gian từng chặng và còn lại bao nhiêu giây so với data.duration.
## Người chơi máy không né đòn nên thời gian và máu mất là mức "chơi vụng"; người chơi thật thường nhanh hơn.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/tier_2/dark_trial/dark_trial_route_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")
const SHARDS: ForgeShardSet = preload("res://resources/world/puzzles/forge_shards.tres")
const DATA: DarkTrialData = preload("res://resources/world/puzzles/dark_trial.tres")
const FLAME_BREATH: AbilityData = preload("res://abilities/flame_breath/flame_breath.tres")
const FRONT: Vector3 = Vector3(278, 4.42, 48.6)
## Máu người chơi lúc đo: để cao vì chết sẽ đổi scene (mất bài đo); máu mất được in ra để đánh giá độ khó. 0 = giữ máu thật
@export var player_max_health: int = 999

## Chặng đi bộ: tên, các điểm (y chỉ để đọc, đi theo x z)
const TO_NORTH: Array[Vector3] = [Vector3(281.5, 4, 48), Vector3(281.5, 4, 42), Vector3(278, 4, 40), Vector3(278, 4, 34), Vector3(278, 8, 26), Vector3(278, 8, 18.2)]
## Dây leo chắn cầu phòng 04 (không lưu đã cháy): đốt bằng Phun lửa rồi đi tiếp
const BRIDGE_VINES: NodePath = ^"Tier2Mechanics/Room04Flammables/BridgeVines"
const NORTH_AFTER_VINES: Array[Vector3] = [Vector3(278, 8, 14), Vector3(286, 8, 14), Vector3(300, 8, 14)]
const NORTH_TO_VINES: Array[Vector3] = [Vector3(300, 8, 14), Vector3(286, 8, 14), Vector3(278, 8, 13.4)]
const NORTH_TO_HUB: Array[Vector3] = [Vector3(278, 8, 14), Vector3(278, 8, 26), Vector3(278, 4, 34), Vector3(278, 4, 44), Vector3(284, 4, 52)]
const HUB_TO_EAST: Array[Vector3] = [Vector3(288, 4, 52), Vector3(294, 4, 50), Vector3(326, 4, 50), Vector3(331, 4, 50), Vector3(339, 4, 50),
		Vector3(339, 4, 56), Vector3(345, 4, 56), Vector3(345, 4, 44), Vector3(349, 4, 42)]
const EAST_TO_PORTAL: Array[Vector3] = [Vector3(351.5, 4, 42.6), Vector3(353.6, 4, 42.4)]
const HUB_TO_SOUTH: Array[Vector3] = [Vector3(282, 4, 44), Vector3(278, 4, 52), Vector3(278, 4, 58), Vector3(278, 4, 66), Vector3(278, 0, 74),
		Vector3(278, 0, 82), Vector3(294, 0, 86), Vector3(306, 0, 86), Vector3(310, 0, 88)]

var _player: Player
var _level: ZoneRoot
var _trial: DarkTrial
var _frames_total: int = 0
var _failed: int = 0
var _checks: int = 0
var _hp_start: int = 0
var _last_clock: float = 0.0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	get_tree().create_timer(400.0, true, true).timeout.connect(func() -> void:
		print("ROUTE RESULT: TIMEOUT")
		get_tree().quit(2))
	GameState.replace_progress(PlayerProgress.new())
	for flag: StringName in [&"level_3.boss_defeated", &"level_3.t2_hub_ambush", &"level_3.t2_timber_caster", &"level_3.t2_slime_hall",
			&"level_3.t2_dark_forge_pack", &"level_3.t2_wisps_cleared", &"level_3.t2_exit_vines"]:
		GameState.set_flag(flag)
	for i: int in SHARDS.total():
		GameState.set_flag(SHARDS.shard_flags[i])
	_level = LEVEL.instantiate()
	_level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	await _frames(30)
	_trial = _level.get_node(^"Tier2Mechanics/DarkTrial") as DarkTrial
	_player.unlock_ability(FLAME_BREATH)
	if player_max_health > 0:
		_player.health.max_health = player_max_health
	_player.health.heal_full()
	_hp_start = _player.health.current_health
	# Bấm bệ thật (đứng sẵn trước bệ)
	_player.teleport(FRONT)
	(_player.get_node("CameraRig") as CameraRig).snap()
	await _frames(15)
	await _tap(&"interact")
	await _frames(5)
	_check(_trial.is_running(), "bấm bệ: thử thách chạy, đồng hồ %.0f s" % DATA.duration)
	var ok: bool = await _leg("Hub → dây leo phòng 04", TO_NORTH)
	ok = ok and await _burn(BRIDGE_VINES)
	ok = ok and await _leg("dây leo → trụ Bắc (05)", NORTH_AFTER_VINES)
	ok = ok and await _pillar(&"NorthPillar")
	# Ra khỏi phòng 04 thì dây leo + cầu dựng lại: về Hub phải đốt lần nữa từ phía bắc
	ok = ok and await _leg("trụ Bắc → dây leo (phía bắc)", NORTH_TO_VINES)
	ok = ok and await _burn(BRIDGE_VINES)
	ok = ok and await _leg("dây leo → Hub (dash qua cầu đang cháy)", NORTH_TO_HUB, true)
	ok = ok and await _leg("Hub → trụ Đông (07, lối gạch)", HUB_TO_EAST)
	ok = ok and await _pillar(&"EastPillar")
	ok = ok and await _leg("trụ Đông → cổng xoáy về Hub", EAST_TO_PORTAL)
	if ok:
		var w: int = 0
		# Đi tiếp vào cổng (355, 40) tới khi bị dịch về Hub
		while _player.global_position.x > 300.0 and w < 240:
			var flat := Vector2(355.0 - _player.global_position.x, 40.0 - _player.global_position.z)
			if flat.length() > 0.3:
				_press_towards(Vector3(flat.x, 0, flat.y).normalized())
			else:
				_release()
			await _step()
			w += 1
		_release()
		_check(_player.global_position.x < 300.0, "cổng xoáy đưa về Hub (%.1f s chờ)" % (w / 60.0))
	ok = ok and await _leg("Hub → trụ Nam (09)", HUB_TO_SOUTH)
	ok = ok and await _pillar(&"SouthPillar")
	var used: float = _frames_total / 60.0
	var clock_used: float = DATA.duration - _trial.time_left() if _trial.is_running() else DATA.duration - _last_clock
	# Thời gian thật (khung vật lý) dài hơn đồng hồ thử thách vì hitstop làm chậm thời gian game lúc đánh trúng
	# Khung vật lý headless không khớp giờ thật (máy chậm thì mỗi khung vẽ chạy bù nhiều bước vật lý): số đúng để chỉnh là đồng hồ thử thách
	print("INFO đồng hồ thử thách dùng ~%.1f / %.0f s (đếm khung vật lý %.1f s, chỉ để so); máu %d → %d" % [clock_used, DATA.duration, used, _hp_start, _player.health.current_health])
	_check(ok and GameState.has_flag(DATA.done_flag), "người chơi máy thắng thử thách trước khi đồng hồ %.0f s hết (thời gian thật %.1f s)" % [DATA.duration, used])
	print("ROUTE RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


func _step() -> void:
	await get_tree().physics_frame
	_frames_total += 1


func _leg(label: String, points: Array[Vector3], dash: bool = false) -> bool:
	var start: int = _frames_total
	for p: Vector3 in points:
		var stuck: int = 0
		var last := _player.global_position
		while true:
			var flat := Vector2(p.x - _player.global_position.x, p.z - _player.global_position.z)
			if flat.length() < 0.5:
				break
			_press_towards(Vector3(flat.x, 0, flat.y).normalized())
			# Chặng cần chạy gấp (cầu đang cháy): bấm dash mỗi 0,5 s
			if dash and _frames_total % 30 == 0:
				Input.action_press(&"dash")
			elif dash and _frames_total % 30 == 2:
				Input.action_release(&"dash")
			await _step()
			if _player.health.is_dead() or not _trial.is_running():
				_release()
				_check(false, "%s: dừng ở %s (%s)" % [label, _player.global_position, "chết" if _player.health.is_dead() else "hết giờ"])
				return false
			if _frames_total % 30 == 0:
				stuck = stuck + 1 if _player.global_position.distance_to(last) < 0.3 else 0
				last = _player.global_position
				if stuck >= 4:
					_release()
					_check(false, "%s: kẹt ở %s khi đi tới %s" % [label, _player.global_position, p])
					return false
	_release()
	print("INFO %s: %.1f s (tổng %.1f s, máu %d)" % [label, (_frames_total - start) / 60.0, _frames_total / 60.0, _player.health.current_health])
	return true


## Đánh quái lồng sinh + phá lồng, rồi thắp lò bằng Phun lửa thật
func _pillar(pillar_name: StringName) -> bool:
	var pillar := _trial.get_node(NodePath("Pillars/%s" % pillar_name)) as EnergyPillar
	var cage := pillar.get_cage()
	var start: int = _frames_total
	var frame: int = 0
	while pillar.get_brazier() == null:
		var target: Node3D = _nearest_enemy()
		if target == null and not cage.is_broken:
			target = cage
		if target != null:
			var to := target.global_position - _player.global_position
			to.y = 0.0
			var reach: float = 2.4 if target == cage else 1.8
			if to.length() > reach:
				_press_towards(to.normalized())
			else:
				_release()
				_face(to.normalized())
			if to.length() < reach + 0.8:
				_tap_attack(frame)
			else:
				Input.action_release(&"attack")
		else:
			_release()
			Input.action_release(&"attack")
		await _step()
		frame += 1
		if _player.health.is_dead() or not _trial.is_running():
			_release()
			Input.action_release(&"attack")
			var info: Array[String] = []
			for e: Node in cage.get_node("Enemies").get_children():
				if e is Enemy:
					info.append("%s hp%d" % [(e as Enemy).global_position, (e as Enemy).health.current_health])
			print("INFO %s lúc dừng: lồng vỡ %s, quái còn %d [%s], player %s" % [pillar_name, cage.is_broken, cage.alive_count(), ", ".join(info), _player.global_position])
			_check(false, "%s: %s lúc đánh (đã %.1f s)" % [pillar_name, "chết" if _player.health.is_dead() else "hết giờ", (_frames_total - start) / 60.0])
			return false
	_release()
	Input.action_release(&"attack")
	var fight: float = (_frames_total - start) / 60.0
	# Đồng hồ thử thách (Timer theo thời gian game, chậm lại khi hitstop) khác số khung vật lý đếm ở đây
	var clock_before_light: float = _trial.time_left()
	_last_clock = clock_before_light
	# Thắp: đứng cách lò 1,6 m, quay về lò, bấm Phun lửa; trượt thì thử lại (tối đa 5 lần)
	var brazier := pillar.get_brazier()
	var tries: int = 0
	while not pillar.is_lit() and tries < 5:
		tries += 1
		var to := brazier.global_position - _player.global_position
		to.y = 0.0
		while to.length() > 1.8:
			_press_towards(to.normalized())
			await _step()
			to = brazier.global_position - _player.global_position
			to.y = 0.0
		_release()
		_player.energy.set_current(maxi(_player.energy.current, _player.energy.get_max()))
		await _face(to.normalized())
		Input.action_press(&"skill_fire")
		for _i: int in range(2):
			await _step()
		Input.action_release(&"skill_fire")
		for _i: int in range(50):
			await _step()
	_check(pillar.is_lit(), "%s: Phun lửa thật thắp được lò (%d lần bấm)" % [pillar_name, tries])
	print("INFO %s: đánh + phá lồng %.1f s, thắp %d lần, tổng trụ %.1f s (tổng %.1f s, máu %d); đồng hồ thử thách còn %.1f s lúc bắt đầu thắp" % [
			pillar_name, fight, tries, (_frames_total - start) / 60.0, _frames_total / 60.0, _player.health.current_health, clock_before_light])
	return pillar.is_lit()


func _burn(path: NodePath) -> bool:
	var start: int = _frames_total
	var target := _level.get_node_or_null(path) as Node3D
	var tries: int = 0
	while is_instance_valid(target) and tries < 4 and not (target as Flammable).is_burning:
		tries += 1
		_player.energy.set_current(_player.energy.get_max())
		var to := target.global_position - _player.global_position
		to.y = 0.0
		await _face(to.normalized())
		Input.action_press(&"skill_fire")
		await _step()
		await _step()
		Input.action_release(&"skill_fire")
		for _i: int in range(40):
			await _step()
	# Dây leo cháy rụi là chạy ngay: lửa lan sang cầu treo, chậm thì cầu sập (thiết kế phòng 04, flammables_test)
	var w: int = 0
	while is_instance_valid(target) and not (target as Flammable).is_burned and w < 600:
		await _step()
		w += 1
	var done: bool = not is_instance_valid(target) or (target as Flammable).is_burned
	_check(done, "đốt %s bằng Phun lửa: cháy rụi sau %.1f s (%d lần bấm)" % [path, (_frames_total - start) / 60.0, tries])
	return done


## Quay mặt bằng một nhịp input hướng (player quay theo input)
func _face(dir: Vector3) -> void:
	# Nhập đủ lực (dưới deadzone 0,2 thì không quay); 4 khung chỉ nhích ~0,3 m
	_press_towards(dir)
	for _i: int in range(4):
		await _step()
	_release()
	for _i: int in range(2):
		await _step()


func _tap_attack(frame: int) -> void:
	var phase := frame % 10
	if phase == 0:
		Input.action_press(&"attack")
	elif phase == 2:
		Input.action_release(&"attack")


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for node: Node in get_tree().get_nodes_in_group(HurtboxComponent.GROUP):
		var owner_node := (node as HurtboxComponent).owner as Node3D
		if owner_node == null or owner_node == _player or not owner_node is Enemy:
			continue
		if (owner_node as Enemy).health.is_dead():
			continue
		var d := owner_node.global_position.distance_to(_player.global_position)
		if d < best_d and d < 16.0:
			best_d = d
			best = owner_node
	return best


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
