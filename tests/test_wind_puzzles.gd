extends Node
## Kiểm va chạm gió, điều kiện AND và cờ lưu của ba câu đố.

const LEVEL: PackedScene = preload("res://levels/zone_1_wind/level_1/level_1.tscn")
const SWITCH: PackedScene = preload("res://objects/wind_turbine_switch/wind_turbine_switch.tscn")
const BLOCK: PackedScene = preload("res://objects/push_block/push_block.tscn")

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	GameState.replace_progress(PlayerProgress.new())
	await _run()
	print("WIND PUZZLES: %d PASS / %d FAIL" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _run() -> void:
	var level: Node3D = LEVEL.instantiate() as Node3D
	add_child(level)
	await get_tree().physics_frame
	var puzzles: Node3D = level.get_node("WindPuzzles") as Node3D
	var c1: WindTurbineSwitch = puzzles.get_node("C1Turbine") as WindTurbineSwitch
	var c1_door: WindDoor = puzzles.get_node("C1Door") as WindDoor
	_check(not c1_door.is_open, "C1 ban đầu đóng")
	await _shot(level, "c1_before", Vector3(36, 12.2, -190))
	_blow(c1)
	await _wait(0.35)
	_check(c1.is_active() and c1_door.is_open, "C1 thổi mở cửa")
	_check(GameState.has_flag(&"level_1.c1_bridge"), "C1 lưu cờ")
	await get_tree().physics_frame
	_check(not _ray_hits(c1_door, Vector3(38, 13.3, -190), Vector3(41, 13.3, -190)), "C1 va chạm cửa đã tắt")
	await _shot(level, "c1_after", Vector3(40, 12.2, -190))
	var cover: BlowableCover = puzzles.get_node("C2Cover") as BlowableCover
	_check(not cover.is_uncovered, "C2 ban đầu che lối")
	_check(_ray_hits(cover, Vector3(25.7, 13, -185.5), Vector3(28.3, 13, -185.5)), "C2 lá chắn có va chạm")
	await _shot(level, "c2_before", Vector3(30, 12.2, -185.5))
	var leaf_receiver: WindReactiveReceiver = cover.get_node("LeafPile/WindReceiver") as WindReactiveReceiver
	leaf_receiver.push(Vector3.LEFT * 10.0)
	await get_tree().physics_frame
	_check(cover.is_uncovered and GameState.has_flag(&"level_1.c2_cover"), "C2 thổi lộ lối và lưu cờ")
	_check(not _ray_hits(cover, Vector3(25.7, 13, -185.5), Vector3(28.3, 13, -185.5)), "C2 va chạm đã tắt")
	await _shot(level, "c2_after", Vector3(27, 12.2, -185.5))
	var left: WindTurbineSwitch = puzzles.get_node("C3TurbineLeft") as WindTurbineSwitch
	var right: WindTurbineSwitch = puzzles.get_node("C3TurbineRight") as WindTurbineSwitch
	var c3_door: WindDoor = puzzles.get_node("C3Door") as WindDoor
	await _shot(level, "c3_before", Vector3(21, 9.2, -225))
	_blow(left)
	await get_tree().physics_frame
	_check(not c3_door.is_open, "C3 một cối không mở cổng")
	GameState.set_flag(&"level_1.enc_final")
	_blow(right)
	await get_tree().physics_frame
	_check(c3_door.is_open and GameState.has_flag(&"level_1.c3_gate"), "C3 hai cối và trận cuối mở cổng")
	await get_tree().physics_frame
	_check(not _ray_hits(c3_door, Vector3(24, 10.3, -229), Vector3(27, 10.3, -229)), "C3 va chạm cửa đã tắt")
	await _shot(level, "c3_after", Vector3(26, 9.2, -229))
	var block: WindPushBlock = BLOCK.instantiate() as WindPushBlock
	add_child(block)
	block.global_position = Vector3(0, 30, 0)
	(block.get_node("WindReceiver") as WindReceiverComponent).push(Vector3.RIGHT * 8.0)
	await _wait(0.3)
	_check(absf(block.global_position.x - 1.0) < 0.05, "bệ đá trượt đúng một ô")
	block.queue_free()
	var slow: WindTurbineSwitch = SWITCH.instantiate() as WindTurbineSwitch
	slow.activation_seconds = 30.0
	add_child(slow)
	_blow(slow)
	await _wait(0.2)
	_check(not slow.is_active(), "ngưỡng 30 giây chưa kích hoạt sớm")
	slow.queue_free()
	level.queue_free()
	await get_tree().physics_frame
	var reloaded: Node3D = LEVEL.instantiate() as Node3D
	add_child(reloaded)
	await get_tree().physics_frame
	var again: Node3D = reloaded.get_node("WindPuzzles") as Node3D
	_check((again.get_node("C1Door") as WindDoor).is_open, "C1 mở sau tải lại")
	_check((again.get_node("C2Cover") as BlowableCover).is_uncovered, "C2 mở sau tải lại")
	_check((again.get_node("C3Door") as WindDoor).is_open, "C3 mở sau tải lại")
	reloaded.queue_free()


func _blow(wind_switch: WindTurbineSwitch) -> void:
	var receiver: WindReactiveReceiver = wind_switch.get_node("Windmill/WindReceiver") as WindReactiveReceiver
	receiver.push(Vector3.FORWARD * 12.0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _ray_hits(body: CollisionObject3D, from_point: Vector3, to_point: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_point, to_point, 257)
	var result: Dictionary = get_viewport().world_3d.direct_space_state.intersect_ray(query)
	return result.get("collider") == body


func _shot(level: Node3D, name: String, player_point: Vector3) -> void:
	var dir: String = OS.get_environment("SHOT_DIR")
	if dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(dir)
	var player: Player = level.get_node("Player") as Player
	player.teleport(player_point)
	await _wait(1.2)
	await RenderingServer.frame_post_draw
	var shot_path: String = dir.path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(shot_path)
	print("SHOT ", shot_path)


func _check(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS ", label)
	else:
		_failed += 1
		push_error("FAIL " + label)
