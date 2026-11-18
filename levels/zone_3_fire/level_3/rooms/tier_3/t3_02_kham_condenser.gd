class_name KhamCondenser
extends Node3D
## Reset lượt Khảm theo phase để giữ phần đã giải khi player quay về.

signal room_reset(replacement: Node3D, player: Player)
signal activated
signal seal_released(seal_id: StringName)
signal phase_two_started

const DEFAULT_DATA: KhamPuzzleData = preload("res://levels/zone_3_fire/level_3/rooms/tier_3/puzzles/kham_puzzle_data.tres")

@export var data: KhamPuzzleData = DEFAULT_DATA
@export_group("Reset")
@export var entrance: Marker3D
@export_group("Chuyển phase")
@export var phase_one_platforms: Array[Node3D] = []

var _reset_pending: bool = false
var _water_bounds: AABB
var _started: bool = false
var _pressure_released: bool = false
var _west_selected: bool = false
var _complete: bool = false
var _phase_two: bool = false
var _hurtboxes: Dictionary[Player, HurtboxComponent] = {}
var _bridge_bodies: Array[StaticBody3D] = []
var _phase_one_bodies: Array[StaticBody3D] = []
var _routes: Array[KhamSinkingRoute] = []
var _bridge_tween: Tween
var _phase_transition: Tween

@onready var _water_volume: CollisionShape3D = $Basin/WaterRecovery/CollisionShape3D
@onready var _valve_a: StrikeValve = $Valves/A
@onready var _valve_b: StrikeValve = $Valves/B
@onready var _valve_c: StrikeValve = $Valves/C
@onready var _first: CoolingPath = $Paths/First
@onready var _west: CoolingPath = $Paths/West
@onready var _north: CoolingPath = $Paths/North
@onready var _west_vent: SteamVent = $Vents/West
@onready var _north_vent: SteamVent = $Vents/North
@onready var _bridge: Node3D = $FoldBridge
@onready var _presence: Area3D = $RoomPresence
@onready var _branch_label: Label3D = $Hints/Branch
@onready var _return_stage: KhamReturnStage = $ReturnStage


func _ready() -> void:
	var box: BoxShape3D = _water_volume.shape as BoxShape3D
	_water_bounds = AABB(-box.size * 0.5, box.size)
	if data == null:
		data = DEFAULT_DATA
	if entrance == null:
		entrance = $Anchors/Start
	if phase_one_platforms.is_empty():
		for platform: Node in $Route.get_children():
			if platform is Node3D and platform.name != &"SealLanding":
				phase_one_platforms.append(platform as Node3D)
		phase_one_platforms.append(_bridge)
	for path: CoolingPath in [_first, _west, _north]:
		path.configure(data)
		path.failed.connect(reset_room)
	for valve: StrikeValve in [_valve_a, _valve_b, _valve_c]:
		valve.configure(data)
	for child: Node in $SinkingRoutes.get_children():
		var route: KhamSinkingRoute = child as KhamSinkingRoute
		_routes.append(route)
		route.configure(data.sinking)
		route.set_active(true)
	_valve_a.struck.connect(_on_inlet_struck)
	_valve_b.struck.connect(_on_diverter_struck)
	_valve_c.struck.connect(_on_relief_struck)
	for vent: SteamVent in [_west_vent, _north_vent]:
		vent.configure(data)
		vent.failed.connect(reset_room)
	for body: Node in _bridge.find_children("*", "StaticBody3D", true, false):
		_bridge_bodies.append(body as StaticBody3D)
	for platform: Node3D in phase_one_platforms:
		if platform is StaticBody3D:
			_phase_one_bodies.append(platform as StaticBody3D)
		for body: Node in platform.find_children("*", "StaticBody3D", true, false):
			_phase_one_bodies.append(body as StaticBody3D)
	_set_bridge_collision(false)
	_bridge.position.y = -maxf(data.bridge_hidden_depth, 0.1)
	_bridge.hide()
	_presence.body_entered.connect(_on_room_entered)
	_presence.body_exited.connect(_on_room_exited)
	$SealTrigger.body_entered.connect(_on_seal_entered)
	_connect_return_stage()
	GameState.progress_replaced.connect(_restore_progress)
	_restore_progress()


func _exit_tree() -> void:
	for player: Player in _hurtboxes:
		var hurtbox: HurtboxComponent = _hurtboxes[player]
		if is_instance_valid(hurtbox):
			hurtbox.remove_hit_interceptor(_intercept_hit.bind(player))
	_hurtboxes.clear()


func is_active() -> bool:
	return _complete


func is_phase_two() -> bool:
	return _phase_two


func reset_room(player: Player) -> void:
	if _reset_pending or not is_instance_valid(player) or player.health.is_dead():
		return
	_reset_pending = true
	# Đợi hết lượt vật lý trước khi thay scene có Area3D đang phát signal.
	_perform_reset.call_deferred(player)


func _on_room_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null or _hurtboxes.has(player):
		return
	var hurtbox: HurtboxComponent = player.get_node(^"HurtboxComponent") as HurtboxComponent
	_hurtboxes[player] = hurtbox
	hurtbox.add_hit_interceptor(_intercept_hit.bind(player))


func _on_room_exited(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null or not _hurtboxes.has(player):
		return
	_hurtboxes[player].remove_hit_interceptor(_intercept_hit.bind(player))
	_hurtboxes.erase(player)


func _intercept_hit(_info: DamageInfo, player: Player) -> bool:
	if _complete:
		return false
	reset_room(player)
	return true


func _on_inlet_struck(_player: Player) -> void:
	if _complete or _phase_two or _reset_pending:
		return
	_first.cool_for(data.first_cold_time)
	if not _started:
		_started = true
		_west_vent.start_cycle()
		_north_vent.start_continuous()


func _on_diverter_struck(_player: Player) -> void:
	if not _started or _complete or _phase_two or _reset_pending:
		return
	_west_selected = not _west_selected
	if _west_selected:
		_north.set_hot()
		_west.cool_for(data.west_cold_time)
		_branch_label.text = "DÒNG LẠNH → TÂY · VAN XẢ ÁP"
	else:
		_west.set_hot()
		_north.cool_for(data.north_cold_time)
		_branch_label.text = "DÒNG LẠNH → BẮC · PHONG ẤN"


func _on_relief_struck(_player: Player) -> void:
	if not _started or _pressure_released or _complete or _phase_two or _reset_pending:
		return
	_pressure_released = true
	_north_vent.stop()
	_open_bridge(false)


func _open_bridge(immediate: bool) -> void:
	_bridge.show()
	if immediate:
		_bridge.position.y = 0.0
		_finish_bridge()
		return
	_bridge_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_bridge_tween.tween_property(_bridge, "position:y", 0.0, maxf(data.bridge_open_time, 0.01))
	_bridge_tween.tween_callback(_finish_bridge)


func _finish_bridge() -> void:
	if _phase_two:
		return
	_set_bridge_collision(true)


func _set_bridge_collision(enabled: bool) -> void:
	for body: StaticBody3D in _bridge_bodies:
		body.set_deferred(&"collision_layer", 1 if enabled else 0)


func _on_seal_entered(body: Node3D) -> void:
	if not body is Player or _complete or _phase_two or _reset_pending:
		return
	if not _pressure_released or _west_selected or _north.heat == CoolingPath.Heat.HOT:
		return
	_begin_phase_two()


func _begin_phase_two(immediate: bool = false) -> void:
	_phase_two = true
	_stop_phase_one()
	$Landmarks.hide()
	$Hints.hide()
	$StoneInlays.hide()
	if _bridge_tween:
		_bridge_tween.kill()
	# Tắt va chạm trước khi hạ để sàn cũ tránh chặn vật thể của phase sau.
	for body: StaticBody3D in _phase_one_bodies:
		body.set_deferred(&"collision_layer", 0)
	if immediate:
		for platform: Node3D in phase_one_platforms:
			platform.position.y -= maxf(data.phase_one_sink_depth, 0.0)
		_finish_phase_transition()
		return
	_phase_transition = create_tween().set_parallel(true).set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	for platform: Node3D in phase_one_platforms:
		var destination: float = platform.position.y - maxf(data.phase_one_sink_depth, 0.0)
		_phase_transition.tween_property(platform, "position:y", destination, maxf(data.phase_one_sink_time, 0.01))
	_phase_transition.chain().tween_callback(_finish_phase_transition)


func _finish_phase_transition() -> void:
	for platform: Node3D in phase_one_platforms:
		platform.hide()
	_return_stage.start()
	if _complete:
		_return_stage.finish()
	phase_two_started.emit()


func _finish_puzzle() -> void:
	if _complete:
		return
	_complete = true
	_stop_phase_one()
	_branch_label.text = "KHẢM ☵ ĐÃ GIẢI"
	GameState.set_flag(data.seal_flag)
	activated.emit()
	seal_released.emit(data.seal_id)


func _connect_return_stage() -> void:
	_return_stage.failed.connect(reset_room)
	_return_stage.completed.connect(_finish_puzzle)


func _stop_phase_one() -> void:
	for route: KhamSinkingRoute in _routes:
		route.set_active(false)
	_west_vent.stop()
	_north_vent.stop()
	_west_vent.set_deferred(&"monitoring", false)
	_north_vent.set_deferred(&"monitoring", false)
	for path: CoolingPath in [_first, _west, _north]:
		path.set_safe()
		path.set_deferred(&"monitoring", false)
	for valve: StrikeValve in [_valve_a, _valve_b, _valve_c]:
		valve.set_enabled(false)
		valve.set_deferred(&"monitorable", false)


func _restore_progress() -> void:
	if GameState.has_flag(data.seal_flag):
		if not _complete:
			_complete = true
			_begin_phase_two(true)
	elif _complete:
		for player: Player in _hurtboxes:
			reset_room(player)
			break


func _on_water_body_entered(body: Node3D) -> void:
	# Signal có thể đến trễ từ vị trí trước khi teleport, chỉ reset khi body còn trong hồ.
	if body is Player and _water_bounds.has_point(_water_volume.to_local(body.global_position)):
		reset_room(body as Player)


func _perform_reset(player: Player) -> void:
	if not is_instance_valid(player) or player.health.is_dead():
		_reset_pending = false
		return
	if _phase_two and not _complete:
		await _reset_return_stage(player)
		return
	for route: KhamSinkingRoute in _routes:
		route.set_active(false)
	var packed_room: PackedScene = load(scene_file_path) as PackedScene
	if packed_room == null or entrance == null:
		push_error("Khảm cần scene nguồn và mốc cửa vào để reset phòng.")
		_reset_pending = false
		return
	var replacement: KhamCondenser = packed_room.instantiate() as KhamCondenser
	replacement.data = data
	var parent: Node = get_parent()
	var room_index: int = get_index()
	var room_name: StringName = name
	var room_transform: Transform3D = transform
	var return_position: Vector3 = entrance.global_position
	var return_facing: Vector3 = -entrance.global_basis.z
	# Đợi body rời các vùng cũ trên physics server trước khi tạo vùng phát hiện mới.
	player.teleport(return_position, return_facing)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(player):
		replacement.free()
		_reset_pending = false
		return
	parent.remove_child(self)
	player.teleport(return_position, return_facing)
	replacement.name = room_name
	replacement.transform = room_transform
	parent.add_child(replacement)
	parent.move_child(replacement, room_index)
	room_reset.emit(replacement, player)
	queue_free()


func _reset_return_stage(player: Player) -> void:
	var previous: KhamReturnStage = _return_stage
	var packed: PackedScene = load(previous.scene_file_path) as PackedScene
	var replacement: KhamReturnStage = packed.instantiate() as KhamReturnStage
	replacement.data = previous.data
	previous.finish()
	var seal: Marker3D = $Anchors/Seal
	player.teleport(seal.global_position, Vector3.LEFT)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(player):
		replacement.free()
		_reset_pending = false
		return
	var stage_transform: Transform3D = previous.transform
	remove_child(previous)
	previous.queue_free()
	replacement.name = &"ReturnStage"
	replacement.transform = stage_transform
	_return_stage = replacement
	add_child(replacement)
	_connect_return_stage()
	player.teleport(seal.global_position, Vector3.LEFT)
	replacement.start()
	_reset_pending = false
	room_reset.emit(self, player)
