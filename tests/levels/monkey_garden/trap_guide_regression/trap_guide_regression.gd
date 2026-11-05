extends Node
## Kiểm tra hướng dẫn, bia dịch chuyển, nhóm khỉ bổ sung và điều kiện nhận thưởng.
const TEST_MAP: String = "res://levels/zone_1_wind/level_1/rooms/tier_3/tier3_test.tscn"
const MAIN_MAP: String = "res://levels/zone_1_wind/level_1/level_1.tscn"
var _checks: int = 0
var _failures: PackedStringArray = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	# Bài test có mở level chính nhưng không được ghi đè tiến trình đã lưu của người chơi.
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	await _case(TEST_MAP,false)
	await _case(TEST_MAP,true)
	await _case(MAIN_MAP,false)
	await _right_room_and_boss(TEST_MAP)
	await _right_room_and_boss(MAIN_MAP)
	print("TRAP_GUIDE_RESULT ",_checks-_failures.size(),"/",_checks," failures=",_failures)
	get_tree().quit(0 if _failures.is_empty() else 1)

func _case(path: String, missing_links: bool) -> void:
	var world: ZoneRoot = load(path).instantiate() as ZoneRoot
	world.shader_warmup = null
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	var tier: Node3D = world if path==TEST_MAP else world.get_node("Rooms/Tier3")
	var trial: RoomGateTrial = tier.get_node("Rooms/BrokenPavilion/DoorTrial")
	var trap: TrapGardenChallenge = trial.challenge as TrapGardenChallenge
	if missing_links:
		# Mô phỏng đúng dữ liệu null mà editor đã lưu khi phát sinh lỗi.
		trap.moving_seals.assign([null,null,null,null,null])
		trap.guards.append(null)
		trap.hazards.append(null)
	get_tree().root.add_child(world)
	if not world.is_combat_ready(): await world.combat_ready
	await _frames(8)
	var player: Player = world.get_node("Player")
	player.health.damaged.connect(func(_damage: int) -> void: player.health.heal_full())
	var context: String = ("recovered" if missing_links else "saved")+" "+path.get_file()
	_check(trap.moving_seals.size()==5,context+" resolves five movers")
	for mover: ShiftingGardenSeal in trap.moving_seals:
		_check(is_instance_valid(mover) and mover.anchors.size()==3,context+" valid mover and anchors")
	player.teleport(tier.global_position+Vector3(35,0.1,10),Vector3.FORWARD)
	await _frames(8)
	_check(not trap.started,context+" waits for guide")
	var guide: GardenTotemGuide = trial.start_guide
	await _open_guide(player,guide)
	_check(get_tree().paused and guide.is_reading(),context+" reading pauses world")
	await _press_f()
	_check(trap.started and not get_tree().paused and player.controls_enabled,context+" F resumes complete challenge")
	var positions: Array[Vector3] = []
	for seal: GardenSwitch in trap.seals: positions.append(seal.global_position)
	await _frames(75)
	_check(trap.seals[0].global_position==positions[0],context+" no teleport before two seconds")
	await _frames(50)
	for index: int in trap.seals.size():
		_check(trap.seals[index].global_position.distance_to(positions[index])>0.1,context+" teleports seal "+str(index+1))
		_check(trap.seals[index].glow.scale.is_equal_approx(Vector3(0.5,1.0,0.5)) and trap.seals[index].scale==Vector3.ONE,context+" preserves seal height and unscaled physics after teleport "+str(index+1))
	await _open_guide(player,guide)
	var held: Vector3 = trap.seals[0].global_position
	await _frames(30)
	_check(get_tree().paused and trap.seals[0].global_position==held,context+" rereading freezes movers")
	await _press_f()
	_check(not get_tree().paused and trap.started,context+" second close resumes without restarting")
	for seal: GardenSwitch in trap.seals:
		await _activate_seal(player,seal)
		_check(seal.is_active(),context+" F activates "+str(seal.name))
		if seal == trap.seals[2]:
			_check(not trap.completed and not trap.reward.available,context+" first three seals do not clear the five-seal trial")
	await _frames(145)
	_check(trap.completed and trap.reward.available and trap.item.available,context+" rewards land after all five seals")
	_check(not trap.wind_ambush.hazard.running,context+" clear stops wind")
	var stopped: Vector3 = trap.seals[0].global_position
	await _frames(185)
	_check(stopped==trap.seals[0].global_position,context+" cleared seals stay still")
	# Ngừng xử lý trước khi tắt vùng quét, tránh callback vật lý trong lúc dọn bài test.
	world.process_mode = Node.PROCESS_MODE_DISABLED
	for area: Node in world.find_children("*","Area3D",true,false): area.set_deferred("monitoring",false)
	await _frames(3)
	world.queue_free()
	await _frames(3)

func _activate_seal(player: Player, seal: GardenSwitch) -> void:
	# Đuổi theo vị trí hiện tại; bia có thể vừa teleport trong lúc người chơi tiến tới.
	for attempt: int in 12:
		if seal.is_active(): return
		var angle: float = attempt * TAU / 8.0
		var approach: Vector3 = Vector3(sin(angle),0,-cos(angle))*1.35
		player.teleport(seal.global_position+approach+Vector3.UP*0.1,Vector3.FORWARD)
		await _frames(6)
		if player.interactor.current == seal.interaction: player.interactor.try_interact()

func _right_room_and_boss(path: String) -> void:
	var world: ZoneRoot = load(path).instantiate() as ZoneRoot
	world.shader_warmup = null
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().root.add_child(world)
	if not world.is_combat_ready(): await world.combat_ready
	await _frames(8)
	var tier: Node3D = world if path==TEST_MAP else world.get_node("Rooms/Tier3")
	var player: Player = world.get_node("Player")
	player.health.damaged.connect(func(_damage: int) -> void: player.health.heal_full())
	var trial: RoomGateTrial = tier.get_node("Rooms/RootGarden/DoorTrial")
	var challenge: RoofGardenChallenge = trial.challenge as RoofGardenChallenge
	_check(challenge.guards.size()==4,"only roof guards exist before entering "+path.get_file())
	player.teleport(tier.global_position+Vector3(55,0.1,-8),Vector3.FORWARD)
	await _frames(12)
	_check(challenge.guards.size()==7 and not challenge.started,"entry spawns three grunts before guide dismissal")
	await _open_guide(player,trial.start_guide)
	_check(get_tree().paused,"short reflection guide still pauses world")
	await _press_f()
	_check(challenge.started,"closing reflection guide starts combat")
	# Totem ở góc xa hơn tầm phát hiện của grunt thường; tiến vào giữa phòng để kiểm tra truy đuổi.
	player.teleport(tier.global_position+Vector3(64,0.1,-8),Vector3.FORWARD)
	await _frames(30)
	var grunts: Array[Enemy] = []
	for guard: Enemy in challenge.guards:
		if not guard is RoofBananaGrunt: grunts.append(guard)
	_check(grunts.size()==3,"three regular ground grunts registered")
	for guard: Enemy in grunts:
		_check(guard.has_target() and guard.can_process(),"spawned grunt pursues player")
	for guard: Enemy in challenge.guards:
		if guard is RoofBananaGrunt: guard.health.take_damage(999)
	await _frames(2)
	_check(not challenge.completed and trial.gates[0].is_locked(),"four roof kills do not unlock room with grunts alive")
	for guard: Enemy in grunts: guard.health.take_damage(999)
	await _frames(150)
	_check(challenge.completed and challenge.reward.available and challenge.item.available,"all seven kills award offering and healing fruit")
	_check(not trial.gates[0].is_locked(),"clearing all seven opens room gate")
	player.teleport(tier.global_position+Vector3(55,0.1,-8),Vector3.FORWARD)
	await _frames(4)
	_check(challenge.guards.size()==7,"re-entering does not duplicate reinforcements")
	var king: GardenKingEncounter = tier.get_node("Rooms/BossRoom/KingEncounter")
	player.teleport(king.global_position+Vector3(0,0.1,3),Vector3.FORWARD)
	await _frames(12)
	_check(king.started and not get_tree().paused and not player.controls_enabled,"boss intro locks controls without pausing animation")
	_check(not king.fighting and not king.guards[1].can_process(),"guards wait during boss introduction")
	await _frames(90)
	_check(king.leader.state_machine.current_state.name==&"Introduction" and king.leader.animation_player().is_playing(),"camera reaches king playing chestbeat introduction")
	for index: int in 600:
		if king.fighting: break
		await _frames(1)
	_check(king.fighting and player.controls_enabled and get_viewport().get_camera_3d().owner==player,"cinematic restores player controls and camera")
	_check(king.guards[0].has_target() and king.guards[1].can_process(),"all guards attack after cinematic")
	world.process_mode = Node.PROCESS_MODE_DISABLED
	for area: Node in world.find_children("*","Area3D",true,false): area.set_deferred("monitoring",false)
	await _frames(3)
	world.queue_free()
	await _frames(3)

func _open_guide(player: Player, guide: GardenTotemGuide) -> void:
	player.teleport(guide.global_position+Vector3(1.7,0.1,0.6),Vector3.FORWARD)
	await _frames(8)
	_check(player.interactor.try_interact(),"F reaches guide")
	await _frames(22)

func _press_f() -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = "interact"; event.pressed = true; Input.parse_input_event(event)
	await _frames(2)
	event.pressed = false; Input.parse_input_event(event)
	await _frames(10)

func _frames(count: int) -> void:
	for index: int in count: await get_tree().physics_frame

func _check(condition: bool, message: String) -> void:
	_checks += 1
	print("PASS " if condition else "FAIL ",message)
	if not condition: _failures.append(message)
