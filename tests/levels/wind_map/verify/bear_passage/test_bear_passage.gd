extends Node3D
## Use case: thắng gấu mở đường; người chơi nhìn thấy cú sập và đi qua được.
## Test case: chặn trước trận, giữ va chạm lúc sập, mở sau chạm đất, tải lại, giá trị thời gian biên.

const ROOM: String = "res://levels/zone_1_wind/level_1/rooms/tier_2/t2_room_27_boss_gate.scn"
const FLAG: StringName = &"level_1.enc_bear_miniboss"
var _fails: int = 0
var _checks: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveManager.use_storage_dir("user://bear_passage_tests")
	GameState.progress.flags.erase(FLAG)
	var packed: PackedScene = load(ROOM) as PackedScene
	var room: Node3D = packed.instantiate() as Node3D
	add_child(room)
	var wall: Node3D = room.get_node("BearVictoryPassage") as Node3D
	var stones: Array = wall.get("leaves")
	var dissolve: ShaderMaterial = (stones[0] as MeshInstance3D).material_override as ShaderMaterial
	_check(dissolve != null, "TC0 stones use disintegration shader")
	_check(wall.has_signal(&"impacted"), "collapse exposes impact signal")
	if not wall.has_signal(&"impacted"):
		room.queue_free()
		await get_tree().process_frame
		_done()
		return
	# Bỏ cắt cảnh trong test va chạm để chỉ đo mốc mở cửa.
	wall.set("cinematic", null)
	var probe: CharacterBody3D = CharacterBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.0
	shape.shape = capsule
	probe.add_child(shape)
	probe.collision_layer = 2
	probe.collision_mask = 1
	add_child(probe)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(_blocked(probe, wall), "TC1 real capsule blocked before victory")
	_check(not bool(wall.get("opened")), "TC2 begins closed")
	GameState.set_flag(FLAG)
	await get_tree().physics_frame
	_check(_blocked(probe, wall), "TC3 still blocked during anticipation")
	_check(not bool(wall.get("opened")), "TC4 does not open at victory event")
	await get_tree().create_timer(0.15).timeout
	_check(ScreenShake.trauma > 0.0, "TC4b tremor exists before collapse")
	await Signal(wall, &"impacted")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not _blocked(probe, wall), "TC5 capsule passes after impact")
	await get_tree().create_timer(1.0).timeout
	_check(dissolve != null and float(dissolve.get_shader_parameter("progress")) >= 1.0, "TC0b surface completely disintegrated")
	_check(not wall.is_processing(), "TC6 idle processing disabled")
	var all_hidden: bool = true
	for leaf: Node3D in wall.get("leaves"):
		all_hidden = all_hidden and not leaf.visible
	_check(all_hidden, "TC7 all debris finished")
	room.queue_free()
	await get_tree().process_frame
	room = packed.instantiate() as Node3D
	add_child(room)
	wall = room.get_node("BearVictoryPassage") as Node3D
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(bool(wall.get("opened")), "TC8 reload already open")
	_check(not _blocked(probe, wall), "TC9 reload collision cleared")
	room.queue_free()
	await get_tree().process_frame
	GameState.progress.flags.erase(FLAG)
	room = packed.instantiate() as Node3D
	wall = room.get_node("BearVictoryPassage") as Node3D
	wall.set("cinematic", null)
	wall.set("anticipation", 0.0)
	wall.set("open_duration", 0.0)
	wall.set("debris_hold", 0.0)
	wall.set("debris_fade", 0.0)
	add_child(room)
	GameState.set_flag(FLAG)
	await get_tree().create_timer(0.3).timeout
	_check(bool(wall.get("opened")), "TC10 zero timings complete")
	_check(not wall.is_processing(), "TC11 zero timings stop processing")
	room.queue_free()
	await get_tree().process_frame
	for factor: float in [0.05, 15.0]:
		GameState.progress.flags.erase(FLAG)
		room = packed.instantiate() as Node3D
		room.scale = Vector3.ONE * factor
		wall = room.get_node("BearVictoryPassage") as Node3D
		wall.set("cinematic", null)
		wall.set("anticipation", 0.0)
		wall.set("open_duration", 1000.0)
		wall.set("shake_distance", 0.0)
		add_child(room)
		# Đổi shape trực tiếp vì thu phóng CharacterBody không bảo đảm cập nhật capsule vật lý.
		capsule.radius = 0.3 * factor
		capsule.height = factor
		probe.safe_margin = 0.001 * factor
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check(_blocked(probe, wall), "TC12 scaled wall blocks at " + str(factor))
		GameState.set_flag(FLAG)
		await get_tree().create_timer(0.1).timeout
		_check(not bool(wall.get("opened")), "TC13 long dissolve keeps collision at " + str(factor))
		room.queue_free()
		await get_tree().process_frame
	probe.queue_free()
	await get_tree().process_frame
	_done()


func _blocked(probe: CharacterBody3D, wall: Node3D) -> bool:
	probe.global_position = wall.to_global(Vector3(0.0, 1.0, 2.0))
	var hit: KinematicCollision3D = probe.move_and_collide(wall.global_basis * Vector3(0.0, 0.0, -4.0))
	return hit != null


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_fails += 1
	print("BEAR_PASSAGE ", "PASS " if condition else "FAIL ", label)


func _done() -> void:
	print("BEAR_PASSAGE RESULT checks=", _checks, " fails=", _fails)
	Input.set_custom_mouse_cursor(null)
	get_tree().quit(1 if _fails else 0)
