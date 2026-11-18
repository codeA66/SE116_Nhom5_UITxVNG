class_name KhamReturnValve
extends Node3D
## Mỗi cụm van tự giữ các nhánh làm nguội và phục hồi ô sàn.

signal activated(player: Player)

@export var paths: Array[CoolingPath] = []
@export var vents: Array[SteamVent] = []
@export var valve_id: StringName

var _duration: float = 0.0

@onready var _valve: StrikeValve = $StrikeValve


func _ready() -> void:
	_valve.set_enabled(false)
	_valve.struck.connect(_on_struck)
	$Label.text = "VAN " + String(valve_id)


func configure(data: KhamPuzzleData, duration: float) -> void:
	_duration = duration
	_valve.configure(data)


func set_enabled(enabled: bool) -> void:
	_valve.set_enabled(enabled)
	_valve.set_deferred(&"monitorable", enabled)


func _on_struck(player: Player) -> void:
	for path: CoolingPath in paths:
		path.cool_for(_duration)
	for vent: SteamVent in vents:
		vent.start_cycle()
	activated.emit(player)
