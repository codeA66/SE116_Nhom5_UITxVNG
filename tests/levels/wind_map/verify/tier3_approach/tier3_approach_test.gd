extends Node3D
## Use case: qua tường đã mở, hạ hai nhóm lính, canh ba đoạn sàn sụp và tới người gác cầu.

const LEVEL_PATH: String = "res://levels/zone_1_wind/level_1/level_1.tscn"
const CONNECTOR: PackedScene = preload("res://levels/zone_1_wind/level_1/rooms/tier_3/connection/tier3_connection.tscn")
const ROOM_27: PackedScene = preload("res://levels/zone_1_wind/level_1/rooms/tier_2/t2_room_27_boss_gate.scn")
const LIGHTING: PackedScene = preload("res://levels/zone_1_wind/map_wind_island/wind_palace_lighting.tscn")
const HERO: PackedScene = preload("res://entities/player/player.tscn")
const FIRST_FIGHT_WON: StringName = &"level_1.t2_approach_arena_lower_cleared"
const ARENA_WON: StringName = &"level_1.t2_approach_arena_cleared"

var _player: Player
var _connector: Node3D
var _level: ZoneRoot
var _failures: int = 0
var _checks: int = 0
var _capture_dir: String


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveManager.use_storage_dir("user://tier3_approach_test")
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_flag(&"level_1.enc_bear_miniboss")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var laser_edges_only: bool = "--laser-edges" in args
	if laser_edges_only:
		GameState.set_flag(FIRST_FIGHT_WON)
		GameState.set_flag(ARENA_WON)
	if args.size() > 1:
		_capture_dir = args[1]
	if "--full" in args:
		var packed: PackedScene = load(LEVEL_PATH) as PackedScene
		_level = packed.instantiate() as ZoneRoot
		_level.shader_warmup = null
		get_tree().root.add_child(_level)
		get_tree().current_scene = _level
		if not _level.is_combat_ready():
			await _level.combat_ready
		_player = _level.get_node("Player") as Player
		_connector = _level.get_node("Tier3Bridge") as Node3D
	else:
		_connector = CONNECTOR.instantiate() as Node3D
		_connector.position = Vector3(-8, 21.62, -375.645)
		var room: Node3D = ROOM_27.instantiate() as Node3D
		room.position = Vector3(-8, 0, -224)
		add_child(room)
		add_child(_connector)
		add_child(LIGHTING.instantiate())
		_player = HERO.instantiate() as Player
		add_child(_player)
		_player.prepare_for_combat()

	var arena: Node3D = _connector.get_node("ApproachRooms/LaserArena") as Node3D
	var walk: Node3D = _connector.get_node("ApproachRooms/CrumblingLaserWalk") as Node3D
	var keeper: Gatekeeper = _connector.get_node("Tier3Gatekeeper") as Gatekeeper
	var victory: StoneGate = arena.get_node("VictoryGate") as StoneGate
	var fight: Encounter = arena.get_node("Fight") as Encounter
	var upper_fight: Encounter = arena.get_node("UpperFight") as Encounter
	var hurtbox: HurtboxComponent = _player.get_node("HurtboxComponent") as HurtboxComponent
	hurtbox.invulnerable = true
	if laser_edges_only:
		await _check_laser_edges(arena, walk, hurtbox)
		await _finish()
		return
	_player.teleport(arena.to_global(Vector3(0, 0.12, 2)), Vector3.FORWARD)
	await _frames(150 if not _capture_dir.is_empty() else 25)
	_check(await _walk_to(arena.to_global(Vector3(0, 0, -3))), "Đi qua mối nối Phòng 27 và đấu trường")
	_check(not victory.is_open, "Cửa ra đóng khi còn quái")
	await _walk_to(fight.global_position)
	await _frames(65)
	_check(fight.is_running() and not upper_fight.is_running(), "Chỉ nhóm đầu kích hoạt khi cáo vào nửa đầu sân")
	await _capture("01_laser_arena")
	_defeat(fight, "Nhóm đầu có đủ ba quái")
	await _frames(100)
	_check(GameState.has_flag(FIRST_FIGHT_WON) and not victory.is_open, "Hạ nhóm đầu, cửa cuối vẫn đóng")
	_check(await _walk_to(upper_fight.global_position, 7.0), "Đi bộ tới nửa sau đấu trường")
	await _frames(65)
	_check(upper_fight.is_running(), "Nhóm thứ hai kích hoạt khi cáo tiến vào")
	await _capture("01b_laser_arena_second_fight")
	_defeat(upper_fight, "Nhóm thứ hai có đủ ba quái")
	await _frames(100)
	_check(victory.is_open and GameState.has_flag(ARENA_WON), "Hạ cả hai nhóm mở cửa và ghi cờ")
	_check(await _walk_to(victory.to_global(Vector3(0, 0, 1.85))), "Tới trục cửa đấu trường")
	_check(await _walk_to(walk.to_global(Vector3(0, 0, -6.5))), "Đi qua cửa tới bệ đầu")
	var first: LaserEmitter = walk.get_node("Hazards/FirstSpanBeam") as LaserEmitter
	var second: LaserEmitter = walk.get_node("Hazards/SecondSpanBeam") as LaserEmitter
	var third: LaserEmitter = walk.get_node("Hazards/ThirdSpanBeam") as LaserEmitter
	var tile: CrumblingFloor = walk.get_node("World/FirstTile01") as CrumblingFloor
	var fell: Array[bool] = [false]
	tile.crumbled.connect(func() -> void: fell[0] = true)
	_check(await _see_phase(first, LaserEmitter.Phase.ON), "Laser ngang sàn có pha bắn")
	await _capture("02_span_laser_on")
	await _walk_to(walk.to_global(Vector3(0, 0, -8.3)))
	await _frames(85)
	_check(fell[0] and _player.global_position.y < walk.global_position.y - 0.15, "Giẫm đủ lâu làm ô rơi và cáo đáp trên dốc đỡ")
	_check(await _walk_to(walk.to_global(Vector3(0, 0, -6.45))), "Đi lên dốc về bệ đầu")
	_check(absf(_player.global_position.y - walk.global_position.y) < 0.15, "Bệ đầu và dốc khớp cao độ")
	_check(await _see_phase(first, LaserEmitter.Phase.ON), "Pha đầu lặp lại")
	_check(await _see_phase(first, LaserEmitter.Phase.OFF), "Qua được lúc tia đầu vừa tắt")
	await _frames(12)
	hurtbox.invulnerable = false
	var health_before: int = _player.health.current_health
	_check(await _walk_to(walk.to_global(Vector3(0, 0, -19.4))), "Đi thường tới vị trí chờ tia thứ hai")
	_check(await _see_phase(second, LaserEmitter.Phase.ON), "Tia thứ hai có pha bắn độc lập")
	_check(await _see_phase(second, LaserEmitter.Phase.OFF), "Có cửa sổ đi đoạn sàn thứ hai")
	_check(await _walk_to(walk.to_global(Vector3(0, 0, -32.4))), "Đi thường tới vị trí chờ tia thứ ba")
	_check(await _see_phase(third, LaserEmitter.Phase.ON), "Tia thứ ba có pha bắn")
	_check(await _see_phase(third, LaserEmitter.Phase.OFF), "Có cửa sổ đi đoạn sàn thứ ba")
	_check(await _walk_to(walk.to_global(Vector3(0, 0, -44.4))), "Đi thường tới bệ ra")
	_check(_player.health.current_health == health_before, "Qua ba tia theo nhịp mà không mất máu")
	var court: Node3D = _connector.get_node("ApproachRooms/KeeperCourt") as Node3D
	_check(await _walk_to(court.to_global(Vector3(2, 0, -4))), "Đi vào sân gặp người gác cầu")
	_check(await _walk_to(keeper.global_position + Vector3(0, 0, 1.3), 7.0), "Đi bộ tới tầm tương tác của NPC")
	await _capture("03_keeper_court")
	var toll: TollService = keeper.get_node("TollService") as TollService
	_check(toll.price == 40 and not keeper.is_passage_open(), "Rào đóng trước khi qua NPC")
	GameState.set_flag(toll.paid_flag)
	await keeper.open_passage(false)
	_check(await _walk_to(_connector.to_global(Vector3(0, 0, -8))), "Tới cầu sau khi mở rào")
	if _level:
		_check(await _walk_to(_connector.to_global(Vector3(0, 0, -29.5)), 7.0), "Đi qua cầu tới mối nối Vườn Khỉ")
		var checkpoint: Checkpoint = _level.get_node("Tier3EntryCheckpoint") as Checkpoint
		_check(await _walk_to(checkpoint.global_position), "Cáo đi đến checkpoint đầu Tier 3")
		_check(checkpoint.is_active() and GameState.get_checkpoint_zone() == LEVEL_PATH, "Checkpoint lưu đúng scene và điểm hồi sinh")
		await _capture("04_tier3_entry")
	hurtbox.invulnerable = true
	await _check_laser_edges(arena, walk, hurtbox)
	await _finish()


func _finish() -> void:
	if _level:
		var physics_drain: ScenePhysicsDrain = ScenePhysicsDrain.new()
		await physics_drain.prepare(_level)
		get_tree().current_scene = self
		_level.queue_free()
		physics_drain.clear()
		_level = null
	print("TIER3_APPROACH RESULT checks=%d fails=%d" % [_checks, _failures])
	_player = null
	_connector = null
	for child: Node in get_children():
		child.queue_free()
	Input.set_custom_mouse_cursor(null)
	await _frames(3)
	get_tree().quit(0 if _failures == 0 else 1)


func _check_laser_edges(arena: Node3D, walk: Node3D, hurtbox: HurtboxComponent) -> void:
	# Bám mép phải sát tầm va chạm của thân để phát hiện đường tắt mà test giữa sàn bỏ sót.
	for emitter: LaserEmitter in arena.get_node("Hazards").get_children():
		await _check_edge_crossing(arena, emitter, hurtbox, 8.16)
	for emitter: LaserEmitter in walk.get_node("Hazards").get_children():
		await _check_edge_crossing(walk, emitter, hurtbox, 2.62)
	# Kiểm tra đầu xa phía trái cho hai tượng quay chiều ngược lại.
	for emitter_name: String in ["NorthBeam", "UpperNorthBeam"]:
		var emitter: LaserEmitter = arena.get_node("Hazards/" + emitter_name) as LaserEmitter
		await _check_edge_crossing(arena, emitter, hurtbox, -8.16)


func _check_edge_crossing(room: Node3D, emitter: LaserEmitter, hurtbox: HurtboxComponent,
		edge_x: float) -> void:
	var beam_z: float = room.to_local(emitter.global_position).z
	var start: Vector3 = room.to_global(Vector3(edge_x, 0.09, beam_z + 1.45))
	var target: Vector3 = room.to_global(Vector3(edge_x, 0.0, beam_z - 1.05))
	var edge: String = "phải" if edge_x > 0.0 else "trái"
	var description: String = "%s chặn đi thường sát mép %s khi tia bật" % [emitter.name, edge]
	_player.teleport(start, Vector3.FORWARD)
	if not await _see_phase(emitter, LaserEmitter.Phase.WARN):
		_check(false, description)
		return
	var hit: Array[bool] = [false]
	var damage_area: Area3D = emitter.get_node("Muzzle/DamageArea") as Area3D
	var on_contact: Callable = func(area: Area3D) -> void:
		if area == hurtbox:
			hit[0] = true
	damage_area.area_entered.connect(on_contact)
	var active: bool = await _see_phase(emitter, LaserEmitter.Phase.ON)
	if active:
		await _walk_to(target, 0.85 * emitter.timing.on_time)
	damage_area.area_entered.disconnect(on_contact)
	var end_z: float = room.to_local(_player.global_position).z
	var crossed: bool = end_z < beam_z - 0.45
	var moved: bool = beam_z + 1.45 - end_z > 0.25
	print("TIER3_APPROACH EDGE ", emitter.name, " ", edge, " on=", emitter.is_active(),
		" contact=", hit[0], " crossed=", crossed, " moved=", moved)
	_check(active and moved and (hit[0] or (emitter.is_active() and not crossed)), description)
	if emitter.name == &"SouthBeam" and edge_x > 0.0:
		await _capture("05_arena_laser_right_edge")


func _defeat(encounter: Encounter, label: String) -> void:
	var enemies: Array[Node] = encounter.get_node("Enemies").get_children()
	_check(enemies.size() == 3, label)
	for enemy: Enemy in enemies:
		enemy.health.take_damage(enemy.health.current_health)


func _walk_to(target: Vector3, timeout: float = 5.0) -> bool:
	var elapsed: float = 0.0
	var reached: bool = false
	while elapsed < timeout:
		var direction: Vector3 = target - _player.global_position
		direction.y = 0.0
		if direction.length() < 0.28:
			reached = true
			break
		var camera_basis: Basis = get_viewport().get_camera_3d().global_basis
		var right: Vector3 = Vector3(camera_basis.x.x, 0.0, camera_basis.x.z).normalized()
		var forward: Vector3 = -Vector3(camera_basis.z.x, 0.0, camera_basis.z.z).normalized()
		direction = direction.normalized()
		_axis(&"move_right", &"move_left", direction.dot(right))
		_axis(&"move_forward", &"move_back", direction.dot(forward))
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	for action: StringName in [&"move_right", &"move_left", &"move_forward", &"move_back"]:
		Input.action_release(action)
	return reached


func _axis(positive: StringName, negative: StringName, amount: float) -> void:
	if amount > 0.03:
		Input.action_release(negative)
		Input.action_press(positive, amount)
	elif amount < -0.03:
		Input.action_release(positive)
		Input.action_press(negative, -amount)
	else:
		Input.action_release(positive)
		Input.action_release(negative)


func _see_phase(emitter: LaserEmitter, phase: LaserEmitter.Phase) -> bool:
	for index: int in 300:
		if emitter.phase == phase:
			return true
		await get_tree().physics_frame
	return false


func _frames(count: int) -> void:
	for index: int in count:
		await get_tree().physics_frame


func _capture(label: String) -> void:
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var result: Error = image.save_png(_capture_dir.path_join(label + ".png"))
	print("TIER3_APPROACH CAPTURE ", label, " ", error_string(result))


func _check(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("TIER3_APPROACH ", "PASS " if ok else "FAIL ", description, " ", _player.global_position)
