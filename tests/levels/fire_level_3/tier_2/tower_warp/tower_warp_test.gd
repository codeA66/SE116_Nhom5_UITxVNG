extends Node
## Test bệ dịch chuyển giữa Hub (ShardAltar dùng model warp_altar) + cổng một chiều Hub → T1, bằng đi bộ thật:
## 1. Ổ chưa đặt mảnh thì tối, ổ đã đặt thì sáng; đĩa giữa tối khi chưa đủ đá.
## 2. Chưa đủ đá: đi bộ lên giữa đĩa được (bệ không chặn) nhưng không dịch chuyển.
## 3. Đặt đủ 3 đá (interact thật): đĩa sáng, cột sáng + tia lửa; bước lên tâm bệ → tới T1.
## 4. Tháp một chiều: đứng lên chỗ đáp ở T1 không bị đưa về Hub.
## 5. Bệ đá là checkpoint: dịch chuyển vào tháp thì lưu; chết (restore_checkpoint) thì tiến độ tháp mất, bệ vẫn mở;
##    điểm hồi sinh trước bệ, đứng đó không bị dịch chuyển. Trong tháp không còn miếu (lên tầng bằng đĩa, xem tower_pads_test).
## Không ghi save thật. Chạy: godot --path . res://tests/levels/fire_level_3/tier_2/tower_warp/tower_warp_test.tscn [-- --capture]

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/tier_2/tier_2.tscn")
const ALTAR_PATH: NodePath = ^"Tier2Mechanics/ForgeShards/ShardAltar"
const SHARDS: ForgeShardSet = preload("res://resources/world/puzzles/forge_shards.tres")
const DONE_FLAG: StringName = &"level_3.t2_shard_switch"
const DISC: Vector3 = Vector3(72, 0.1, -4.6)
## Đứng trong tầm tương tác nhưng ngoài vùng dịch chuyển (hộp 1,6 m ở tâm)
const FRONT: Vector3 = Vector3(72, 0.1, -2)
const START: Vector3 = Vector3(72, 0.1, 3.4)
const T1_ARRIVAL: Vector3 = Vector3(194, 4.1, -24.1)
const T1_PORTAL: Vector3 = Vector3(194, 4.1, -24.1)
const HUB_ARRIVAL: Vector3 = Vector3(73.4, 0.1, -1.6)
const ALTAR_CP_ID: StringName = &"level_3.t2_tower_altar"
const T1_FLAG: StringName = &"level_3.t2_t1_cleared"

var _player: Player
var _level: ZoneRoot
var _failed: int = 0
var _checks: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	get_tree().create_timer(120.0, true, true).timeout.connect(func() -> void:
		print("TOWER WARP RESULT: TIMEOUT")
		get_tree().quit(2))
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_flag(&"level_3.boss_defeated")
	GameState.set_flag(&"level_3.t2_hub_ambush")
	# Đã đặt mảnh Bắc: ổ Bắc sáng, hai ổ còn lại tối
	GameState.set_flag(SHARDS.shard_flags[0])
	GameState.set_flag(SHARDS.placed_flags[0])
	_level = LEVEL.instantiate()
	_level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	await _frames(30)
	var altar := _level.get_node(ALTAR_PATH) as ShardAltar
	_t_glows(altar)
	await _t_closed()
	await _t_open(altar)
	await _t_return()
	await _t_altar_checkpoint()
	print("TOWER WARP RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


func _lit(altar: ShardAltar, path: NodePath) -> bool:
	return (altar.get_node(path) as GeometryInstance3D).material_override == null


func _t_glows(altar: ShardAltar) -> void:
	var states := [_lit(altar, ^"Model/SocketGlow_1"), _lit(altar, ^"Model/SocketGlow_3"), _lit(altar, ^"Model/SocketGlow_2")]
	_check(states == [true, false, false], "ổ Bắc đã đặt thì sáng, hai ổ chưa đặt tối (%s)" % str(states))
	_check(not _lit(altar, ^"Model/PortalDisc"), "chưa đủ đá: đĩa giữa tối")


func _t_closed() -> void:
	var reached := await _walk_to(START, DISC, 0.6)
	await _frames(40)
	var d := _flat(_player.global_position, DISC)
	_check(reached and d < 1.0, "đi bộ lên giữa đĩa được (cách tâm %.2f m), bệ không chặn" % d)
	_check(absf(_player.global_position.y - DISC.y) < 0.3, "đứng trên đĩa ngang sàn Hub (y %.2f)" % _player.global_position.y)
	await _capture("altar_one_socket.png")


func _t_open(altar: ShardAltar) -> void:
	# Mang 2 mảnh còn lại, đứng trước bệ bấm interact thật để đặt
	GameState.set_flag(SHARDS.shard_flags[1])
	GameState.set_flag(SHARDS.shard_flags[2])
	await _walk_to(START, FRONT, 0.4)
	await _frames(10)
	await _tap(&"interact")
	await _frames(60)
	var fx := altar.get_node(^"CenterFx") as Node3D
	var embers := altar.get_node(^"CenterFx/Embers") as GPUParticles3D
	_check(GameState.has_flag(DONE_FLAG) and _lit(altar, ^"Model/PortalDisc"), "đặt đủ 3 đá: đĩa giữa sáng")
	_check(fx.visible and fx.scale.is_equal_approx(Vector3.ONE) and embers.emitting, "đủ đá: cột sáng mọc lên, tia lửa bay")
	_check(not GameState.has_flag(&"level_3.t2_dark_trial_done") and _level.get_node_or_null(^"Tier2Mechanics/DarkTrial") == null,
		"không còn thử thách u tối trên đường chính")
	await _capture("altar_open.png")
	await _walk_to(START, DISC, 0.6)
	await _frames(90)
	var d := _flat(_player.global_position, T1_ARRIVAL)
	_check(d < 2.0 and absf(_player.global_position.y - T1_ARRIVAL.y) < 1.0,
		"bước lên đĩa: dịch chuyển tới T1 (cách điểm đáp %.2f m, ở %s)" % [d, str(_player.global_position)])


func _t_return() -> void:
	await _walk_to(_player.global_position, T1_PORTAL, 0.4, false)
	await _frames(90)
	var d := _flat(_player.global_position, HUB_ARRIVAL)
	# Một chiều: tháp không có cổng về Hub
	_check(d > 50.0, "đứng lên chỗ đáp T1: không bị đưa về Hub (cách Hub %.0f m)" % d)


func _t_altar_checkpoint() -> void:
	_check(GameState.get_checkpoint_spawn_id() == ALTAR_CP_ID,
		"dịch chuyển vào tháp: bệ đá lưu checkpoint (đang là %s)" % GameState.get_checkpoint_spawn_id())
	var leftovers: Array[String] = []
	for n: String in ["TowerT1Checkpoint", "TowerT2Checkpoint", "TowerT4Checkpoint", "TowerT5Checkpoint", "TowerMidCheckpoint", "TowerT6Checkpoint"]:
		if _level.get_node_or_null(NodePath("Tier2Links/" + n)) != null:
			leftovers.append(n)
	_check(leftovers.is_empty(), "trong tháp không còn miếu checkpoint (còn %s)" % str(leftovers))
	# Leo tháp được một tầng rồi thua: SceneManager gọi restore_checkpoint khi hồi sinh
	GameState.set_flag(T1_FLAG)
	GameState.restore_checkpoint()
	_check(not GameState.has_flag(T1_FLAG), "thua trong tháp: tiến độ tầng đã dọn bị reset")
	_check(GameState.has_flag(DONE_FLAG), "thua trong tháp: bệ đá vẫn đủ đá, vẫn mở")
	var spawn := SpawnPoint.find_in(_level, ALTAR_CP_ID)
	_check(spawn != null, "có điểm hồi sinh %s" % ALTAR_CP_ID)
	if spawn == null:
		return
	_check(_flat(spawn.global_position, DISC) < 4.0, "điểm hồi sinh ngay trước bệ (cách tâm %.2f m)" % _flat(spawn.global_position, DISC))
	_player.teleport(spawn.global_position, spawn.get_facing())
	(_player.get_node("CameraRig") as CameraRig).snap()
	await _frames(90)
	var d := _flat(_player.global_position, spawn.global_position)
	_check(d < 0.5 and absf(_player.global_position.y - DISC.y) < 0.3,
		"hồi sinh trước bệ: đứng vững, không bị dịch chuyển ngay (lệch %.2f m, y %.2f)" % [d, _player.global_position.y])
	await _walk_to(spawn.global_position, DISC, 0.6, false)
	await _frames(90)
	d = _flat(_player.global_position, T1_ARRIVAL)
	_check(d < 2.0, "leo lại: bước lên bệ lần nữa tới T1 (cách điểm đáp %.2f m)" % d)


func _walk_to(from: Vector3, to: Vector3, tolerance: float, teleport: bool = true) -> bool:
	if teleport:
		_player.teleport(from)
		(_player.get_node("CameraRig") as CameraRig).snap()
		await _frames(15)
	var reached := false
	for _i: int in range(300):
		var flat := Vector2(to.x - _player.global_position.x, to.z - _player.global_position.z)
		if flat.length() < tolerance:
			reached = true
			break
		# Bị cổng đưa đi xa (Hub ↔ tháp cách > 100 m): thôi bấm đi
		if flat.length() > 100.0:
			break
		_press_towards(Vector3(flat.x, 0, flat.y).normalized())
		await get_tree().physics_frame
	_release()
	return reached


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


func _capture(file: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = DISC + Vector3(6, 7, 6)
	cam.look_at(DISC)
	cam.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://output/warp_altar")
	get_viewport().get_texture().get_image().save_png("res://output/warp_altar/" + file)
	cam.queue_free()
	(_player.get_node("CameraRig/Camera3D") as Camera3D).make_current()


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


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
