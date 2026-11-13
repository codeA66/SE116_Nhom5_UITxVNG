extends Node
## Test bệ công tắc giữa Hub (bản 2 giai đoạn 2, docs/zone_3_fire/tier_2_tower_design.md mục 0), bằng đi bộ và input thật:
## 1. Không mang mảnh: bấm interact không đặt được gì, công tắc tắt.
## 2. Mang 1 mảnh (Nam, ngoài thứ tự): đặt đúng hốc của nó; HUD "đã đặt 1/3".
## 3. Mang 2 mảnh còn lại: một lần bấm đặt cả hai; đủ 3 thì sáng, lưu cờ công tắc, phát activated đúng 1 lần.
## 4. Bệ chắn đường (va chạm thật): đi thẳng vào bệ không xuyên qua.
## 5. Tải lại map: bệ vẫn sáng, đủ 3 hốc, không bấm lại được.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/tier_2/shard_altar/shard_altar_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")
const ALTAR_PATH: NodePath = ^"Tier2Mechanics/ForgeShards/ShardAltar"
const COUNTER_PATH: NodePath = ^"Tier2Mechanics/ForgeShards/ShardCounter"
const SHARDS: ForgeShardSet = preload("res://resources/world/puzzles/forge_shards.tres")
## Chỗ đứng trước bệ (bệ ở z 46, sâu 3,1 m) và điểm bắt đầu đi bộ
const FRONT: Vector3 = Vector3(278, 4.42, 48.6)
const START: Vector3 = Vector3(278, 4.42, 54)

var _player: Player
var _level: ZoneRoot
var _failed: int = 0
var _checks: int = 0
var _activations: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	get_tree().create_timer(120.0, true, true).timeout.connect(func() -> void:
		print("SHARD ALTAR RESULT: TIMEOUT")
		get_tree().quit(2))
	GameState.replace_progress(PlayerProgress.new())
	# Trận mở màn Hub đã thắng: quái không cắn lúc đo
	GameState.set_flag(&"level_3.boss_defeated")
	GameState.set_flag(&"level_3.t2_hub_ambush")
	await _load_level()
	var altar := _altar()
	altar.activated.connect(func() -> void: _activations += 1)
	await _t_empty(altar)
	await _t_one_out_of_order(altar)
	await _t_rest(altar)
	await _t_blocks()
	await _reload()
	_t_reloaded()
	print("SHARD ALTAR RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


func _altar() -> ShardAltar:
	return _level.get_node(ALTAR_PATH) as ShardAltar


func _sockets_visible(altar: ShardAltar) -> Array[bool]:
	var out: Array[bool] = []
	for socket: Node in altar.get_node(^"Sockets").get_children():
		out.append((socket as Node3D).visible)
	return out


func _t_empty(altar: ShardAltar) -> void:
	await _walk_and_interact()
	_check(SHARDS.placed_count() == 0 and not altar.is_active(), "không mang mảnh: bấm interact không đặt được gì")
	_check(_sockets_visible(altar) == [false, false, false], "không mang mảnh: ba hốc trống")
	# Đóng hộp thoại "cần mảnh" trước lượt sau
	await _frames(30)
	await _tap(&"interact")
	await _frames(30)


func _t_one_out_of_order(altar: ShardAltar) -> void:
	GameState.set_flag(SHARDS.shard_flags[2])
	await _walk_and_interact()
	_check(SHARDS.is_placed(2) and SHARDS.placed_count() == 1 and not altar.is_active(), "mang mảnh Nam: đặt 1 mảnh, công tắc chưa sáng")
	_check(_sockets_visible(altar) == [false, false, true], "mảnh Nam vào đúng hốc của nó (%s)" % str(_sockets_visible(altar)))
	var counter := _level.get_node(COUNTER_PATH) as ForgeShardCounter
	_check(counter.get_text() == "Mảnh vỡ 1/3 · đã đặt 1/3", "HUD: \"%s\"" % counter.get_text())


func _t_rest(altar: ShardAltar) -> void:
	GameState.set_flag(SHARDS.shard_flags[0])
	GameState.set_flag(SHARDS.shard_flags[1])
	await _walk_and_interact()
	_check(SHARDS.placed_count() == 3 and _sockets_visible(altar) == [true, true, true], "mang 2 mảnh còn lại: một lần bấm đặt cả hai")
	_check(altar.is_active() and GameState.has_flag(SHARDS.switch_flag), "đủ 3 mảnh: công tắc sáng, lưu cờ %s" % SHARDS.switch_flag)
	await _frames(60)
	var glow := altar.get_node(^"Glow") as OmniLight3D
	_check(glow.light_energy > 1.0, "đủ 3 mảnh: bệ phát sáng (năng lượng %.2f)" % glow.light_energy)
	await _walk_and_interact()
	_check(_activations == 1, "activated phát đúng 1 lần, bấm lại không phát nữa (%d)" % _activations)


func _t_blocks() -> void:
	await _walk_dir(START, Vector3.FORWARD, 150)
	var z: float = _player.global_position.z
	_check(z > 47.4, "đi thẳng vào bệ bị chặn (z = %.2f, mặt nam bệ ở 47,55)" % z)


func _t_reloaded() -> void:
	var altar := _altar()
	_check(altar.is_active() and _sockets_visible(altar) == [true, true, true], "tải lại map: bệ vẫn sáng, đủ 3 hốc")
	var interactable := altar.get_node(^"InteractableComponent") as InteractableComponent
	_check(not interactable.can_interact(_player), "tải lại map: không tương tác lại được")


func _load_level() -> void:
	_level = LEVEL.instantiate()
	_level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	await _frames(30)


func _reload() -> void:
	_level.queue_free()
	await _frames(5)
	await _load_level()


## Đi bộ thật từ START tới trước bệ rồi bấm interact
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


func _walk_dir(from: Vector3, dir: Vector3, frames: int) -> void:
	_player.teleport(from)
	(_player.get_node("CameraRig") as CameraRig).snap()
	await _frames(15)
	for _i: int in range(frames):
		_press_towards(dir)
		await get_tree().physics_frame
	_release()


## Bấm như phím thật: sự kiện InputEventAction (hộp thoại đọc _unhandled_input) và trạng thái action (player đọc Input)
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
