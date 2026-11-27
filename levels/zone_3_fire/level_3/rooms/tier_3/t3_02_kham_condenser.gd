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
@export var gem_placed_flag: StringName

var _reset_pending: bool = false
var _started: bool = false
var _pressure_released: bool = false
var _valve_b_locked: bool = false
var _complete: bool = false
var _phase_two: bool = false
var _hurtboxes: Dictionary[Player, HurtboxComponent] = {}
var _bridge_bodies: Array[StaticBody3D] = []
var _phase_one_bodies: Array[StaticBody3D] = []
var _routes: Array[KhamSinkingRoute] = []
var _bridge_tween: Tween
var _phase_transition: Tween
var _valve_b_locked_material: StandardMaterial3D

@onready var _valve_a: InteractValve = $Valves/A
@onready var _valve_b: InteractValve = $Valves/B
@onready var _lever: InteractValve = $Valves/Lever
@onready var _handle: Node3D = $Landmarks/Lever.find_child("Handle", true, false)
@onready var _valve_b_meshes: Array[MeshInstance3D] = [
	$Landmarks/DiverterB/Handwheel,
	$Landmarks/DiverterB/Spoke,
	$Landmarks/DiverterB/Mark0,
	$Landmarks/DiverterB/Mark1,
]
@onready var _first: CoolingPath = $Paths/First
@onready var _west: CoolingPath = $Paths/West
@onready var _north: CoolingPath = $Paths/North
@onready var _west_route: KhamSinkingRoute = $SinkingRoutes/West
@onready var _west_vent: SteamVent = $Vents/West
@onready var _bridge: Node3D = $FoldBridge
@onready var _presence: Area3D = $RoomPresence
@onready var _gem: SealGem = $KhamGem
@onready var _return_stage: KhamReturnStage = $ReturnStage


func _ready() -> void:
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
		path.failed.connect(_on_fatal_failure)
		path.set_deferred(&"monitoring", true)
	for valve: InteractValve in [_valve_a, _valve_b, _lever]:
		valve.configure(data)
	for child: Node in $SinkingRoutes.get_children():
		var route: KhamSinkingRoute = child as KhamSinkingRoute
		_routes.append(route)
		route.configure(data.sinking)
		route.set_active(true)
	_valve_a.activated.connect(_on_inlet_opened)
	_valve_b.activated.connect(_on_diverter_opened)
	_lever.set_enabled(false)
	_lever.activated.connect(_on_relief_opened)
	_valve_b_locked_material = StandardMaterial3D.new()
	_valve_b_locked_material.albedo_color = data.valve_locked_color
	_valve_b_locked_material.roughness = 0.85
	_valve_b_locked_material.emission_enabled = false
	_west.heat_changed.connect(_on_west_heat_changed)
	_north.heat_changed.connect(_on_north_heat_changed)
	_west_vent.configure(data)
	_west_vent.failed.connect(_on_fatal_failure)
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
	_gem.configure_pickup(_can_collect_gem, gem_placed_flag)
	_gem.collected.connect(_on_gem_collected)
	var zone: ZoneRoot = get_parent() as ZoneRoot
	if zone:
		zone.player_spawned.connect(_gem.set_carrier)
		_gem.set_carrier(zone.get_node_or_null(^"Player") as Player)
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
	if _complete:
		_gem.set_carrier(player)


func _on_room_exited(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null or not _hurtboxes.has(player):
		return
	_hurtboxes[player].remove_hit_interceptor(_intercept_hit.bind(player))
	_hurtboxes.erase(player)


func _intercept_hit(_info: DamageInfo, player: Player) -> bool:
	if _complete:
		return false
	_on_fatal_failure(player)
	return true


func _on_fatal_failure(player: Player) -> void:
	if _reset_pending or not is_instance_valid(player) or player.health.is_dead():
		return
	player.on_lethal_zone_entered()
	if not player.health.is_dead():
		return
	_reset_pending = true


func _on_inlet_opened(_player: Player) -> void:
	if _complete or _phase_two or _reset_pending:
		return
	_first.cool_for(data.first_cold_time)
	if not _started:
		_started = true
		_lever.set_enabled(true)
		_west_vent.start_cycle()


func _on_diverter_opened(_player: Player) -> void:
	if not _started or _complete or _phase_two or _reset_pending or _valve_b_locked:
		return
	if not _pressure_released:
		_west.cool_for(data.west_cold_time)
	else:
		_north.cool_for(data.north_cold_time)
	_set_valve_b_locked(true)


func _on_relief_opened(_player: Player) -> void:
	if not _started or _pressure_released or _complete or _phase_two or _reset_pending:
		return
	_pressure_released = true
	_west_route.set_active(false)
	_west.set_deferred(&"monitoring", false)
	var closing: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	closing.tween_property(_handle, "rotation:z", -_handle.rotation.z, maxf(data.valve_turn_time, 0.01))
	_open_bridge(false)
	_set_valve_b_locked(false)


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


func _can_collect_gem(actor: Node3D) -> bool:
	return actor is Player and not _complete and not _phase_two and not _reset_pending \
		and _pressure_released and _north.heat != CoolingPath.Heat.HOT


func _on_west_heat_changed() -> void:
	if _west.heat == CoolingPath.Heat.HOT and not _pressure_released \
			and not _complete and not _phase_two and not _reset_pending:
		_set_valve_b_locked(false)


func _on_north_heat_changed() -> void:
	if _north.heat == CoolingPath.Heat.HOT and _pressure_released \
			and not _complete and not _phase_two and not _reset_pending:
		_set_valve_b_locked(false)


func _set_valve_b_locked(locked: bool) -> void:
	_valve_b_locked = locked
	_valve_b.set_enabled(not locked)
	var override: Material = _valve_b_locked_material if locked else null
	for mesh: MeshInstance3D in _valve_b_meshes:
		mesh.material_override = override


func _on_gem_collected(_player: Player) -> void:
	_begin_phase_two()


func _begin_phase_two(immediate: bool = false) -> void:
	_phase_two = true
	_stop_phase_one()
	$Landmarks.hide()

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
	GameState.set_flag(data.seal_flag)
	activated.emit()
	seal_released.emit(data.seal_id)


func _connect_return_stage() -> void:
	_return_stage.failed.connect(_on_fatal_failure)
	_return_stage.completed.connect(_finish_puzzle)


func _stop_phase_one() -> void:
	for route: KhamSinkingRoute in _routes:
		route.set_active(false)
	_west_vent.stop()
	_west_vent.set_deferred(&"monitoring", false)
	for path: CoolingPath in [_first, _west, _north]:
		path.set_safe()
		path.set_deferred(&"monitoring", false)
	for valve: InteractValve in [_valve_a, _valve_b, _lever]:
		valve.set_enabled(false)


func _restore_progress() -> void:
	if GameState.has_flag(data.seal_flag):
		if not _complete:
			_complete = true
			_gem.restore_collected()
			_begin_phase_two(true)
	elif _complete:
		for player: Player in _hurtboxes:
			reset_room(player)
			break


func _perform_reset(player: Player, revive: bool = false) -> void:
	if not is_instance_valid(player) or player.health.is_dead() != revive:
		_reset_pending = false
		return
	if _phase_two and not _complete:
		await _reset_return_stage(player, revive)
		return
	var packed_room: PackedScene = load(scene_file_path) as PackedScene
	if packed_room == null or entrance == null:
		push_error("Khảm cần scene nguồn và mốc cửa vào để reset phòng.")
		_cancel_reset(revive)
		return
	var replacement: KhamCondenser = packed_room.instantiate() as KhamCondenser
	replacement.data = data
	replacement.gem_placed_flag = gem_placed_flag
	for route: KhamSinkingRoute in _routes:
		route.set_active(false)
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
	replacement.name = room_name
	replacement.transform = room_transform
	parent.add_child(replacement)
	parent.move_child(replacement, room_index)
	_place_reset_player(player, return_position, return_facing, revive)
	room_reset.emit(replacement, player)
	queue_free()


func _reset_return_stage(player: Player, revive: bool) -> void:
	var previous: KhamReturnStage = _return_stage
	var packed: PackedScene = load(previous.scene_file_path) as PackedScene
	if packed == null:
		push_error("Khảm cần scene nguồn để reset lượt về.")
		_cancel_reset(revive)
		return
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
	_place_reset_player(player, seal.global_position, Vector3.LEFT, revive)
	_gem.set_carrier(player)
	replacement.start()
	_reset_pending = false
	room_reset.emit(self, player)


func _place_reset_player(player: Player, at: Vector3, facing: Vector3, revive: bool) -> void:
	if revive:
		player.revive_locally(at, facing)
	else:
		player.teleport(at, facing)


func _cancel_reset(revive: bool) -> void:
	_reset_pending = false
	if revive:
		GameState.reset_player_health()
		SceneManager.respawn_at_checkpoint()
