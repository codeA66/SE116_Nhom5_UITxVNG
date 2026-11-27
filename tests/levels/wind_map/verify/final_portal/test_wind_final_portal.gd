extends Node3D
## UC1: Ba trận hoàn tất mới có thể mở cổng và cinematic chỉ phát một lượt.
## UC2: Trở lại với tiến trình đã lưu cho phép qua cổng ngay.
## UC3: Cáo bước qua trigger thật và sang đúng điểm vào phòng boss cuối.
## UC4: Vào phòng boss cuối lúc thiếu máu được hồi đầy và lưu đúng máu hiện tại.
##
## TC1: Thiếu một trong ba cờ thì từ chối phát và giữ portal tắt.
## TC2: Đủ cờ thì phát Khỉ, Sói, Gấu, hợp, mở lần lượt. Điểm đứng và điều khiển của cáo được trả.
## TC3: Khi tiến trình đã mở cổng, cập nhật chỉ hiển thị lại cổng.
## TC4: Cáo đi bộ vào cổng qua va chạm thật, phòng đích đặt cáo đúng SpawnPoint.
## TC5: Đi qua cổng với 1 máu, phòng đích hồi tới máu tối đa và đồng bộ GameState.

const SEQUENCE: String = "res://levels/zone_1_wind/level_1/rooms/tier_3/connection/wind_soul_sequence/wind_soul_sequence.tscn"
const ARENA: String = "res://levels/zone_1_wind/final_boss/wind_final_arena.tscn"
const PLAYER: PackedScene = preload("res://entities/player/player.tscn")
const FLAGS: Array[StringName] = [&"level_1.secret_wolf_defeated", &"level_1.enc_bear_miniboss", &"level_1.monkey_king_defeated"]
const OPEN_FLAG: StringName = &"level_1.t3.wind_final_portal_open"
const START: Vector3 = Vector3(0, 0, 4)
var _shots: Array[StringName] = []
var _fails: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveManager.use_storage_dir("user://test_wind_final_portal")
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
	var has_sequence: bool = ResourceLoader.exists(SEQUENCE)
	var has_arena: bool = ResourceLoader.exists(ARENA)
	_check(has_sequence, "có scene cinematic")
	_check(has_arena, "có đấu trường boss cuối")
	if not has_sequence or not has_arena:
		_finish()
		return

	var fixture: Node = get_parent()
	var player: Player = PLAYER.instantiate() as Player
	fixture.add_child(player)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(30, 1, 30)
	floor_shape.shape = floor_box
	floor_body.position.y = -0.5
	floor_body.add_child(floor_shape)
	fixture.add_child(floor_body)
	player.teleport(START, Vector3.FORWARD)

	var sequence: Node3D = load(SEQUENCE).instantiate() as Node3D
	fixture.add_child(sequence)
	sequence.phase_time_scale = 0.16
	sequence.shot_started.connect(_record_shot)
	await _frames(4)
	for missing: StringName in FLAGS:
		GameState.replace_progress(PlayerProgress.new())
		for other: StringName in FLAGS:
			if other != missing:
				GameState.set_flag(other)
		_check(not sequence.try_begin(player) and not sequence.is_portal_open(), "TC1 thiếu " + String(missing))
	GameState.replace_progress(PlayerProgress.new())
	for defeated: StringName in FLAGS:
		GameState.set_flag(defeated)
	_check(sequence.try_begin(player), "TC2 đủ ba cờ thì phát")
	_check(not sequence.try_begin(player) and not player.controls_enabled, "TC2 khóa phát trùng và khóa điều khiển")
	var sequence_deadline: int = Time.get_ticks_msec() + 45000
	while not sequence.is_portal_open() and Time.get_ticks_msec() < sequence_deadline:
		await get_tree().process_frame
	_check(sequence.is_portal_open() and GameState.has_flag(OPEN_FLAG), "TC2 mở cổng và ghi cờ")
	_check(_shots == [&"monkey", &"wolf", &"bear", &"orbit", &"portal"], "TC2 thứ tự năm nhịp %s" % str(_shots))
	_check(player.controls_enabled and player.global_position.distance_to(START) < 0.2, "TC2 trả cáo ở điểm đứng cũ")

	sequence.queue_free()
	await _frames(4)
	var restored: Node3D = load(SEQUENCE).instantiate() as Node3D
	fixture.add_child(restored)
	await _frames(4)
	_check(restored.is_portal_open() and not restored.try_begin(player), "TC3 nạp cờ mở cổng không phát lại")
	var expected: StringName = &"wind_final_entry"
	var deadline: int = Time.get_ticks_msec() + 120000
	var tree: SceneTree = get_tree()
	# Runner sống ngoài current_scene để đo mốc đến sau khi SceneManager dọn phòng cũ.
	reparent(tree.root)
	var crossing: Vector3 = restored.get_portal_position()
	player.health.set_current_health(1)
	_check(player.health.current_health == 1 and GameState.get_player_health() == 1, "TC5 vào cổng khi chỉ còn 1 máu")
	player.teleport(crossing + Vector3(0, 0.05, 3), Vector3.FORWARD)
	await tree.physics_frame
	_check(not SceneManager.is_busy(), "TC4 đứng ngoài cổng chưa chuyển khu")
	var obstructed: bool = false
	for step: int in 18:
		if SceneManager.is_busy():
			break
		var collision: KinematicCollision3D = player.move_and_collide(Vector3.FORWARD * 0.2)
		if collision and absf(collision.get_normal().y) < 0.5:
			obstructed = true
			break
		await tree.physics_frame
	_check(not obstructed, "TC4 cáo đi bộ tới cổng không vướng vật cản")
	while not SceneManager.is_busy() and Time.get_ticks_msec() < deadline:
		await tree.physics_frame
	_check(SceneManager.is_busy(), "TC4 trigger thật bắt đầu đổi khu")
	if SceneManager.is_busy():
		while SceneManager.is_busy() and Time.get_ticks_msec() < deadline:
			await tree.process_frame
		var world: Node = tree.current_scene
		_check(world != null and world.scene_file_path == ARENA, "TC4 vào đúng phòng boss")
		var entry: SpawnPoint = SpawnPoint.find_in(world, expected) if world else null
		var new_player: Player = world.get_node_or_null(^"Player") as Player if world else null
		_check(entry != null and new_player != null and new_player.global_position.distance_to(entry.global_position) < 0.5, "TC4 cáo đến đúng mốc vào phòng")
		_check(new_player != null and new_player.health.current_health == new_player.health.max_health, "TC5 hồi đầy máu khi đến phòng boss")
		_check(new_player != null and GameState.get_player_health() == new_player.health.max_health, "TC5 GameState lưu máu đã hồi")
	_finish()


func _record_shot(shot: StringName) -> void:
	_shots.append(shot)


func _frames(total: int) -> void:
	for frame_index: int in total:
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _finish() -> void:
	print("WIND FINAL RESULT fails=", _fails)
	get_tree().quit(0 if _fails == 0 else 1)
