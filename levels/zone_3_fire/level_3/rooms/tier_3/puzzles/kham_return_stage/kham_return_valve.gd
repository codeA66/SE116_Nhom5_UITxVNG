class_name KhamReturnValve
extends Node3D
## Mỗi cụm van tự giữ các nhánh làm nguội và phục hồi ô sàn.

signal activated(player: Player)

@export var paths: Array[CoolingPath] = []
@export var vents: Array[SteamVent] = []
@export var valve_id: StringName

var _duration: float = 0.0

@onready var _valve: InteractValve = $InteractValve


func _ready() -> void:
	_valve.set_enabled(false)
	_valve.activated.connect(_on_valve_opened)


func configure(data: KhamPuzzleData, duration: float) -> void:
	_duration = duration
	_valve.configure(data)


func set_enabled(enabled: bool) -> void:
	_valve.set_enabled(enabled)


func _on_valve_opened(player: Player) -> void:
	for path: CoolingPath in paths:
		path.cool_for(_duration)
	for vent: SteamVent in vents:
		vent.start_cycle()
	activated.emit(player)
