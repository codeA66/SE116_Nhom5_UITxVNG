extends Node
## Chuyển tier 1 → tier 2 đi qua scene thật (va chạm, input và SceneManager):
## 1. Đã đeo Bùa Đoạt Tiễn và hạ hổ (đặt cờ): cổng phòng 10 hiện, đi bộ vào -> đấu trường hổ.
## 2. Ở đấu trường, cổng ra đã hiện: đi bộ thật vào cổng -> đổi scene sang levels/zone_3_fire/tier_2/tier_2.tscn.
## 3. Player xuất hiện ở điểm "start" của tier 2 và đứng vững.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/tier_2/split/tier_transition_test.tscn

const LEVEL_PATH: String = "res://levels/zone_3_fire/tier_1/tier_1.tscn"
const TIER_2_PATH: String = "res://levels/zone_3_fire/tier_2/tier_2.tscn"
const BOSS_FLAG: StringName = &"level_3.boss_defeated"
const ARENA_PATH: String = "res://levels/zone_3_fire/tier_1/tiger_arena/tiger_arena.tscn"
const PORTAL_FLAG: StringName = &"level_3.tiger.portal_open"

var _failed: int = 0
var _checks: int = 0


func _ready() -> void:
	_start.call_deferred()


func _start() -> void:
	get_tree().create_timer(120.0, true, true).timeout.connect(func() -> void:
		print("TIER TRANSITION RESULT: TIMEOUT")
		get_tree().quit(2))
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	# Node rỗng làm current_scene để test không bị giải phóng khi SceneManager đổi khu (như test_hub)
	var stand_in := Node.new()
	stand_in.name = "StandIn"
	get_tree().root.add_child(stand_in)
	get_tree().current_scene = stand_in
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_flag(BOSS_FLAG)
	GameState.set_flag(PORTAL_FLAG)
	await _run()
	print("TIER TRANSITION RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


func _run() -> void:
	SceneManager.change_zone(LEVEL_PATH, &"start")
	await _wait_idle()
	var level := get_tree().current_scene
	_check(level != null and level.scene_file_path == LEVEL_PATH, "vào tier 1 (scene %s)" % (level.scene_file_path if level else "null"))
	if level == null:
		return
	if not await _walk_through(level, "Room10TigerPortal/Portal", "cổng phòng 10"):
		return
	var arena := get_tree().current_scene
	_check(arena != null and arena.scene_file_path == ARENA_PATH, "đã vào đấu trường hổ (%s)" % (arena.scene_file_path if arena else "null"))
	if arena == null or not await _walk_through(arena, "ExitReveal/Portal", "cổng ra đấu trường hổ"):
		return
	var tier2 := get_tree().current_scene
	_check(tier2 != null and tier2.scene_file_path == TIER_2_PATH, "đã vào scene tier 2 (%s)" % (tier2.scene_file_path if tier2 else "null"))
	if tier2 == null:
		return
	var start := tier2.get_node_or_null("Start") as Node3D
	var p2 := tier2.get_node_or_null("Player") as Player
	_check(p2 != null and start != null, "tier 2 có player và điểm start")
	if p2 == null or start == null:
		return
	await _frames(60)
	var pos := p2.global_position
	_check(pos.distance_to(start.global_position) < 1.0 and p2.is_on_floor(), "player đứng ở điểm start tier 2 (%s)" % pos.snapped(Vector3.ONE * 0.1))


## Đi bộ thật vào cổng tại portal_path của zone; trả true khi đã đổi khu xong
func _walk_through(zone: Node, portal_path: NodePath, label: String) -> bool:
	var player := zone.get_node_or_null("Player") as Player
	var exit := zone.get_node_or_null(portal_path) as Portal
	_check(player != null and exit != null, "có player và %s" % label)
	if player == null or exit == null:
		return false
	player.health.max_health = 9999
	player.health.heal_full()
	await _frames(20)
	# Đứng cách cổng 2 m về phía trước cổng, rồi bấm đi thẳng vào tâm cổng
	var inward := -exit.global_basis.z
	player.teleport(exit.global_position - inward * 2.0, inward)
	await _frames(20)
	var t := 0.0
	while t < 2.0 and not SceneManager.is_busy():
		_hold_toward(inward)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_release()
	_check(SceneManager.is_busy(), "bước vào %s -> bắt đầu đổi khu (sau %.2f s)" % [label, t])
	await _wait_idle()
	return true


## Giữ phím đi về hướng world_dir (theo trục XZ)
func _hold_toward(world_dir: Vector3) -> void:
	var d := Vector3(world_dir.x, 0.0, world_dir.z).normalized()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cb := cam.global_basis
	var forward := Vector3(-cb.z.x, 0.0, -cb.z.z).normalized()
	var right := Vector3(cb.x.x, 0.0, cb.x.z).normalized()
	_set_axis(&"move_right", &"move_left", d.dot(right))
	_set_axis(&"move_back", &"move_forward", -d.dot(forward))


func _set_axis(positive: StringName, negative: StringName, value: float) -> void:
	if value > 0.05:
		Input.action_press(positive, clampf(value, 0.0, 1.0))
	elif value < -0.05:
		Input.action_press(negative, clampf(-value, 0.0, 1.0))


func _release() -> void:
	for a: StringName in [&"move_right", &"move_left", &"move_forward", &"move_back"]:
		Input.action_release(a)


func _wait_idle() -> void:
	var t := 0.0
	while SceneManager.is_busy() and t < 15.0:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	await _frames(30)


func _frames(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	_checks += 1
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failed += 1
