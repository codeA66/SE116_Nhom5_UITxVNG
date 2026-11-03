extends Node
## Chạy scene này để kiểm tra đóng hướng dẫn, bia dịch chuyển và hồi phục tham chiếu bị mất.
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
		trap.moving_seals.assign([null,null,null])
		trap.guards.append(null)
		trap.hazards.append(null)
	get_tree().root.add_child(world)
	if not world.is_combat_ready(): await world.combat_ready
	await _frames(8)
	var player: Player = world.get_node("Player")
	player.health.damaged.connect(func(_damage: int) -> void: player.health.heal_full())
	var context: String = ("recovered" if missing_links else "saved")+" "+path.get_file()
	_check(trap.moving_seals.size()==3,context+" resolves three movers")
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
	await _frames(188)
	for index: int in trap.seals.size():
		_check(trap.seals[index].global_position.distance_to(positions[index])>0.1,context+" teleports seal "+str(index+1))
	await _open_guide(player,guide)
	var held: Vector3 = trap.seals[0].global_position
	await _frames(30)
	_check(get_tree().paused and trap.seals[0].global_position==held,context+" rereading freezes movers")
	await _press_f()
	_check(not get_tree().paused and trap.started,context+" second close resumes without restarting")
	for seal: GardenSwitch in trap.seals:
		player.teleport(seal.global_position+Vector3(0,0.1,1.4),Vector3.FORWARD)
		await _frames(6)
		_check(player.interactor.try_interact() and seal.is_active(),context+" F activates "+str(seal.name))
	await _frames(145)
	_check(trap.completed and trap.reward.available and trap.item.available,context+" rewards land after all three seals")
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
