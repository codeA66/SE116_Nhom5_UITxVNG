class_name KhamReturnStage
extends Node3D
## Lượt quay về dùng các ô sập độc lập và reset riêng tại seal.

signal failed(player: Player)
signal completed

const DEFAULT_DATA: KhamReturnData = preload("res://levels/zone_3_fire/level_3/rooms/tier_3/puzzles/kham_return_stage/kham_return_data.tres")
const DEFAULT_THERMAL: KhamPuzzleData = preload("res://levels/zone_3_fire/level_3/rooms/tier_3/puzzles/kham_puzzle_data.tres")

@export var data: KhamReturnData = DEFAULT_DATA

var _active: bool = false
var _finished: bool = false
var _floors: Array[StaticBody3D] = []
var _paths: Array[CoolingPath] = []
var _vents: Array[SteamVent] = []
var _valves: Array[KhamReturnValve] = []
var _routes: Array[KhamSinkingRoute] = []
var _traps: Array[ValveSinkTrap] = []
var _route_bodies: Dictionary[StaticBody3D, bool] = {}

@onready var _exit: Area3D = $Exit


func _ready() -> void:
	if data == null:
		data = DEFAULT_DATA
	if data.thermal == null:
		data.thermal = DEFAULT_THERMAL
	for body: Node in $Floors.get_children():
		_floors.append(body as StaticBody3D)
		(body as StaticBody3D).collision_layer = 0
	for child: Node in $Paths.get_children():
		var path: CoolingPath = child as CoolingPath
		_paths.append(path)
		path.configure(data.thermal)
		path.monitoring = false
		path.failed.connect(_on_failed)
	for child: Node in $Vents.get_children():
		var vent: SteamVent = child as SteamVent
		_vents.append(vent)
		vent.configure(data.thermal)
		vent.monitoring = false
		vent.failed.connect(_on_failed)
	for child: Node in $Valves.get_children():
		var valve: KhamReturnValve = child as KhamReturnValve
		_valves.append(valve)
		var duration: float = data.cold_times.get(valve.valve_id, data.default_cold_time)
		valve.configure(data.thermal, duration)
	for child: Node in $SinkingRoutes.get_children():
		var route: KhamSinkingRoute = child as KhamSinkingRoute
		_routes.append(route)
		route.configure(data.sinking)
		for body: StaticBody3D in route.floor_bodies:
			_route_bodies[body] = true
	for child: Node in $Traps.get_children():
		_traps.append(child as ValveSinkTrap)
	_exit.body_entered.connect(_on_exit_entered)
	_exit.monitoring = false
	hide()


func start() -> void:
	if _active:
		return
	_active = true
	show()
	for body: StaticBody3D in _floors:
		if not _route_bodies.has(body):
			body.set_deferred(&"collision_layer", 1)
	for path: CoolingPath in _paths:
		path.set_deferred(&"monitoring", true)
	for vent: SteamVent in _vents:
		vent.set_deferred(&"monitoring", true)
	for valve: KhamReturnValve in _valves:
		valve.set_enabled(true)
	_exit.set_deferred(&"monitoring", true)
	for route: KhamSinkingRoute in _routes:
		route.set_active(true)
	for trap: ValveSinkTrap in _traps:
		trap.set_enabled(true)


func finish() -> void:
	_finished = true
	for trap: ValveSinkTrap in _traps:
		trap.set_enabled(false)
	for path: CoolingPath in _paths:
		path.set_safe()
		path.set_deferred(&"monitoring", false)
	for vent: SteamVent in _vents:
		vent.stop()
	for valve: KhamReturnValve in _valves:
		valve.set_enabled(false)
	_exit.set_deferred(&"monitoring", false)


func _on_failed(player: Player) -> void:
	if _active and not _finished:
		failed.emit(player)


func _on_exit_entered(body: Node3D) -> void:
	if body is Player and _active and not _finished:
		finish()
		completed.emit()
