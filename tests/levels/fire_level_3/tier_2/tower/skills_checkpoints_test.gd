extends Node
## Test sách → mảnh vỡ (bản 2, docs/zone_3_fire/tier_2_tower_design.md mục 0) và miếu checkpoint của tháp tier 2 map Lửa:
## 1. Ba mảnh vỡ ở ba khu, đúng chỗ bệ đá, giấu tới khi hạ xong trận của khu. Đi bộ tới mảnh, bấm interact thì nhặt được,
##    lưu cờ mảnh; bộ đếm HUD hiện trong tier 2 và tăng 0/3 → 3/3.
## 2. Miếu checkpoint ở Hub, sảnh chân tháp (trong tháp không còn miếu): đứng vững trên điểm hồi sinh; đi bộ chạm miếu thì lưu đúng id, hồi đầy máu.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/tier_2/tower/skills_checkpoints_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/tier_2/tier_2.tscn")
## Mảnh: tên node, cờ trận của khu, cờ mảnh, vị trí mảnh
const SHARDS: Array[Dictionary] = [
	{"name": "NorthShard", "flag": &"level_3.t2_room05_cagespider", "extra_flag": &"level_3.t2_room05_cageslime", "shard": &"level_3.t2_shard_north", "p": Vector3(132, 4.54, -36.6)},
	{"name": "EastShard", "flag": &"level_3.t2_dark_forge_pack", "shard": &"level_3.t2_shard_east", "p": Vector3(142, 0.54, -9.6)},
	{"name": "SouthShard", "flag": &"level_3.t2_wisps_cleared", "shard": &"level_3.t2_shard_south", "p": Vector3(110, -3.46, 41.4)},
]
## Miếu: node, id, điểm bắt đầu đi bộ tới miếu (from) hoặc node chỗ đáp cổng tháp (from_node).
## dz: lệch điểm xuất phát vào phía giữa phòng để không đi vướng cột khung cổng
const CHECKPOINTS: Array[Dictionary] = [
	# Hub: đi từ phía đông vào (phía bắc miếu có cột đèn chắn, đi thẳng từ bắc thì không chạm được vùng lưu)
	{"name": "HubCheckpoint", "id": &"level_3.t2_hub", "from": Vector3(71, 0.1, 9.9)},
	{"name": "FoyerCheckpoint", "id": &"level_3.t2_foyer", "from": Vector3(48.5, 0.1, 1.4)},
]

var _player: Player
var _level: ZoneRoot
var _failed: int = 0
var _checks: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	get_tree().create_timer(200.0, true, true).timeout.connect(func() -> void:
		print("SKILLS CHECKPOINTS RESULT: TIMEOUT")
		get_tree().quit(2))
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_flag(&"level_3.boss_defeated")
	_level = LEVEL.instantiate()
	_level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	await _frames(30)
	_player.health.max_health = 9999
	_player.health.heal_full()
	await _t_shards()
	await _t_checkpoints()
	print("SKILLS CHECKPOINTS RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


func _shard_path(shard_name: String) -> NodePath:
	return NodePath("Tier2Mechanics/ForgeShards/%sReveal/%s" % [shard_name, shard_name])


func _t_shards() -> void:
	var counter := _level.get_node(^"Tier2Mechanics/ForgeShards/ShardCounter") as ForgeShardCounter
	var panel := counter.get_node(^"Panel") as Control
	# Người chơi đứng trong tier 2 (Hub) thì bộ đếm hiện
	_player.teleport(Vector3(72, 0.1, -0.6))
	await _frames(30)
	_check(panel.visible and counter.get_text() == "Mảnh vỡ 0/3", "vào tier 2: bộ đếm hiện \"%s\"" % counter.get_text())
	for s: Dictionary in SHARDS:
		_check(_level.get_node_or_null(_shard_path(s.name)) == null, "%s: chưa hạ xong trận của khu thì mảnh chưa có trong cây" % s.name)
	var picked: int = 0
	for s: Dictionary in SHARDS:
		GameState.set_flag(s.flag)
		if s.has("extra_flag"):
			GameState.set_flag(s.extra_flag)
		var shard := _level.get_node_or_null(_shard_path(s.name)) as KeyPickup
		_check(shard != null and shard.key_id == s.shard, "%s: hạ xong trận %s thì mảnh hiện ra, cờ %s" % [s.name, s.flag, s.shard])
		if shard == null:
			continue
		var pos: Vector3 = s.p
		_check(shard.global_position.distance_to(pos) < 0.05, "%s đứng đúng bệ khu của nó (%s)" % [s.name, shard.global_position])
		# Đi bộ thật từ 3 m phía nam vào sát mảnh rồi bấm interact
		await _walk_to(pos + Vector3(0, -0.44, 3.0), pos)
		await _frames(10)
		Input.action_press(&"interact")
		await _frames(3)
		Input.action_release(&"interact")
		await _frames(20)
		picked += 1
		_check(GameState.has_flag(s.shard) and not is_instance_valid(shard), "%s: đi tới bấm interact thì nhặt, lưu cờ %s" % [s.name, s.shard])
		_check(counter.get_text() == "Mảnh vỡ %d/3" % picked, "%s: bộ đếm tăng (\"%s\")" % [s.name, counter.get_text()])
	# Ra khỏi tier 2 (về tier 1) thì bộ đếm ẩn
	_player.teleport(Vector3(-148, 0.1, 1.4))
	await _frames(30)
	_check(not panel.visible, "ra khỏi tier 2: bộ đếm ẩn")


func _t_checkpoints() -> void:
	# Quái phục kích Hub (chưa hạ) vây cắn và chắn đường tới miếu Hub làm sai phép đo: tắt hẳn trận Hub (không kích hoạt,
	# quái đứng yên, dời ra xa; trận đo ở fights_test). Xoá quái thì trận bắt đầu mà không bao giờ xong, rào trận chặn lối vào miếu.
	# Bất tử trước đòn quái phòng khác; phần "bị thương" của test gọi thẳng health.take_damage nên không bị chặn
	var hub := _level.get_node(^"Tier2Fights/T2HubAmbush")
	hub.process_mode = Node.PROCESS_MODE_DISABLED
	# Quái đã thức đuổi theo từ bước nhặt mảnh có thể đang đứng chắn lối vào miếu: dời ra xa khỏi Hub
	for e: Node in hub.get_node(^"Enemies").get_children():
		(e as Node3D).global_position += Vector3(0, 0, 200)
	(_player.get_node(^"HurtboxComponent") as HurtboxComponent).set_invincible(9999.0)
	for c: Dictionary in CHECKPOINTS:
		var cp := _level.get_node("Tier2Links/%s" % c.name) as Checkpoint
		_check(cp != null and not cp.is_active(), "%s: lúc đầu miếu tắt" % c.name)
		var spawn: Node3D = cp.get_node("Spawn")
		_player.teleport(spawn.global_position + Vector3(0, 0.1, 0))
		await _frames(60)
		var p: Vector3 = _player.global_position
		_check(_player.is_on_floor() and absf(p.y - spawn.global_position.y) < 0.3, "%s: điểm hồi sinh đứng vững (y %.2f / %.2f)" % [c.name, p.y, spawn.global_position.y])
		# Đi bộ thật từ chỗ khác vào miếu, bị thương trước để thấy hồi máu
		_player.health.max_health = 40
		_player.health.heal_full()
		_player.health.take_damage(3)
		var hurt := _player.health.current_health
		var from: Vector3 = c.from if c.has("from") else (_level.get_node(c.from_node) as Node3D).global_position + Vector3(0, 0.1, float(c.get("dz", 0.0)))
		await _walk_to(from, cp.global_position)
		await _frames(60)
		_check(GameState.get_checkpoint_spawn_id() == c.id and cp.is_active(), "%s: chạm miếu lưu checkpoint %s (đang là %s)" % [c.name, c.id, GameState.get_checkpoint_spawn_id()])
		_check(_player.health.current_health == _player.health.max_health and hurt < _player.health.max_health, "%s: hồi đầy máu (%d → %d), dừng cách miếu %.2f m" % [c.name, hurt, _player.health.current_health, Vector2(_player.global_position.x - cp.global_position.x, _player.global_position.z - cp.global_position.z).length()])


func _walk_to(from: Vector3, target: Vector3) -> void:
	_player.teleport(from)
	(_player.get_node("CameraRig") as CameraRig).snap()
	await _frames(15)
	for _i: int in range(240):
		var flat := Vector2(target.x - _player.global_position.x, target.z - _player.global_position.z)
		if flat.length() < 0.6:
			break
		_press_towards(Vector3(flat.x, 0, flat.y).normalized())
		await get_tree().physics_frame
	_release()


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
