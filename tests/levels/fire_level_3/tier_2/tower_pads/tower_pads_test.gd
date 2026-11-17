extends Node
## Test phòng tháp to dần + đĩa dịch chuyển giữa phòng (tier 2 map Lửa), đo bằng va chạm thật:
## 1. Cỡ sàn 6 tầng 16, 16, 20, 20, 24, 28 m (bắn tia xuống: cách mép 1 m (trong tường) có sàn, ngoài mép là vực); tường kín 4 mặt
##    (bắn tia ngang từ tâm phải chạm tường trước mép phòng). Tầng sau cao hơn tầng trước 4 m.
## 2. Đĩa T1..T5: chưa dọn phòng thì ẩn, đứng lên không dịch chuyển; bật cờ dọn phòng thì hiện dần (hạt bay lên, đèn sáng);
##    đang đứng trên đĩa lúc hiện không bị đưa đi; đi bộ ra rồi vào lại đĩa thì tới điểm đáp tầng sau.
## Không ghi save thật. Chạy: godot --path . res://tests/levels/fire_level_3/tier_2/tower_pads/tower_pads_test.tscn [-- --capture]

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/tier_2/tier_2.tscn")
const ROOMS: Array[String] = ["T2T1Forge", "T2T2Anvil", "T2T3Crucible", "T2T4Chain", "T2T5Smelter", "T2T6Summit"]
const SIZES: Array[float] = [16.0, 16.0, 20.0, 20.0, 24.0, 28.0]
## Trận / lồng / tượng trong tháp: tắt khi đo đĩa
const FIGHTS: Array[String] = ["Tier2Fights/TowerT3MotherFight", "Tier2Fights/TowerT4Masks", "Tier2Fights/T2BossFight", "Tier2Mechanics/TowerFloors"]
## Cờ đĩa từng tầng cần (đủ hết thì đĩa mở)
const PAD_FLAGS: Array = [
	[&"level_3.t2_t1_cleared"],
	[&"level_3.t2_t2_cage_spider", &"level_3.t2_t2_cage_caster"],
	[&"level_3.t2_t3_cleared"],
	[&"level_3.t2_t4_cleared"],
	[&"level_3.t2_t5_cage", &"level_3.t2_t5_statue_nw", &"level_3.t2_t5_statue_ne", &"level_3.t2_t5_statue_sw", &"level_3.t2_t5_statue_se"],
]
## Mặt sàn cao hơn gốc phòng
const FLOOR_TOP: float = 0.32
const WORLD_MASK: int = 1

var _player: Player
var _level: ZoneRoot
var _failed: int = 0
var _checks: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	get_tree().create_timer(180.0, true, true).timeout.connect(func() -> void:
		print("TOWER PADS RESULT: TIMEOUT")
		get_tree().quit(2))
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_flag(&"level_3.boss_defeated")
	_level = LEVEL.instantiate()
	_level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	await _frames(30)
	# Đo đĩa, không đánh nhau: tắt các trận trong tháp
	for f: String in FIGHTS:
		_level.get_node(f).process_mode = Node.PROCESS_MODE_DISABLED
	_player.health.max_health = 999
	_player.health.heal_full()
	_t_rooms()
	for n: int in range(1, 6):
		await _t_pad(n)
	print("TOWER PADS RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


func _t_rooms() -> void:
	var prev_y := -INF
	for i: int in ROOMS.size():
		var room := _level.get_node("Rooms/Tier2/" + ROOMS[i]) as Node3D
		var c := room.global_position
		var half := SIZES[i] * 0.5
		var inside_ok := true
		var outside_ok := true
		var walls_ok := true
		for d: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			for side: float in [-1.0, 0.0, 1.0]:
				var along := Vector3(d.z, 0, d.x) * side * (half - 1.5)
				inside_ok = inside_ok and _floor_at(c + d * (half - 1.0) + along, c.y)
				outside_ok = outside_ok and not _floor_at(c + d * (half + 1.0) + along, c.y)
			var from := c + Vector3(0, FLOOR_TOP + 0.6, 0)
			walls_ok = walls_ok and not _ray(from, from + d * (half + 0.5)).is_empty()
		_check(inside_ok and outside_ok, "%s: sàn rộng đúng %d x %d m (trong mép có sàn %s, ngoài mép trống %s)" % [ROOMS[i], SIZES[i], SIZES[i], inside_ok, outside_ok])
		_check(walls_ok, "%s: tường kín 4 mặt" % ROOMS[i])
		if i > 0:
			_check(is_equal_approx(c.y - prev_y, 4.0), "%s: cao hơn tầng trước 4 m (%.2f)" % [ROOMS[i], c.y - prev_y])
		prev_y = c.y


func _t_pad(n: int) -> void:
	var pad := _level.get_node("Tier2Links/TowerExitT%d" % n) as WarpPortal
	var vis := pad.get_node(^"TeleportPadVisual") as TeleportPadVisual
	var arrive := _level.get_node("Tier2Links/TowerArriveT%d" % (n + 1)) as WarpPortal
	var flags: Array = PAD_FLAGS[n - 1]
	_check(not pad.is_active() and not vis.visible, "T%d: chưa dọn phòng, đĩa ẩn" % n)
	var on_pad := pad.global_position + Vector3.UP * 0.1
	_teleport(on_pad)
	await _frames(60)
	_check(_flat(_player.global_position, on_pad) < 0.5, "T%d: đứng lên đĩa đang ẩn không bị dịch chuyển" % n)
	if n == 1:
		await _capture("pad_off.png", pad)
	# Thiếu một cờ (T2, T5 nhiều nguồn) thì đĩa vẫn ẩn
	for i: int in range(flags.size() - 1):
		GameState.set_flag(flags[i])
	if flags.size() > 1:
		await _frames(30)
		_check(not pad.is_active() and not vis.visible, "T%d: mới đủ %d/%d cờ, đĩa vẫn ẩn" % [n, flags.size() - 1, flags.size()])
	GameState.set_flag(flags[-1])
	await _frames(int((vis.appear_time + 0.3) * 60.0))
	var rays := vis.get_node(^"Rays") as GPUParticles3D
	var light := vis.get_node(^"Light") as OmniLight3D
	_check(pad.is_active() and vis.visible and rays.emitting and light.light_energy > 0.1,
		"T%d: dọn phòng xong, đĩa hiện, tia sáng bay, đèn sáng (%.2f)" % [n, light.light_energy])
	_check(_flat(_player.global_position, on_pad) < 0.5, "T%d: đang đứng trên đĩa lúc đĩa hiện không bị đưa đi" % n)
	if n == 1:
		await _capture("pad_on.png", pad)
	# Đi bộ ra khỏi đĩa rồi vào lại
	await _walk_to(pad.global_position + Vector3(0, 0, -3.0), 0.4)
	await _frames(10)
	await _walk_to(pad.global_position, 0.3)
	await _frames(90)
	var target := arrive.get_arrival().global_position
	var d := _flat(_player.global_position, target)
	_check(d < 1.5 and absf(_player.global_position.y - target.y) < 1.0,
		"T%d: đi bộ lên đĩa tới điểm đáp T%d (cách %.2f m, y %.2f)" % [n, n + 1, d, _player.global_position.y])


func _floor_at(p: Vector3, room_y: float) -> bool:
	var hit := _ray(Vector3(p.x, room_y + 3.0, p.z), Vector3(p.x, room_y - 1.0, p.z))
	return not hit.is_empty() and absf((hit.position as Vector3).y - (room_y + FLOOR_TOP)) < 0.2


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK)
	q.exclude = [_player.get_rid()]
	return _player.get_world_3d().direct_space_state.intersect_ray(q)


func _teleport(p: Vector3) -> void:
	_player.teleport(p)
	(_player.get_node("CameraRig") as CameraRig).snap()


func _walk_to(to: Vector3, tolerance: float) -> bool:
	for _i: int in range(300):
		var flat := Vector2(to.x - _player.global_position.x, to.z - _player.global_position.z)
		# Bị đĩa đưa đi xa: thôi bấm đi
		if flat.length() < tolerance or flat.length() > 20.0:
			_release()
			return flat.length() < tolerance
		_press_towards(Vector3(flat.x, 0, flat.y).normalized())
		await get_tree().physics_frame
	_release()
	return false


func _capture(file: String, pad: Node3D) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = pad.global_position + Vector3(4, 4, 5)
	cam.look_at(pad.global_position + Vector3.UP * 0.5)
	cam.make_current()
	for _i: int in range(4):
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://output/teleport_pad")
	get_viewport().get_texture().get_image().save_png("res://output/teleport_pad/" + file)
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
