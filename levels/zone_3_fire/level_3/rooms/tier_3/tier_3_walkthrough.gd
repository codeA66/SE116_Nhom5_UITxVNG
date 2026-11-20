extends Node
## Tuyến bốn phòng dùng ấn riêng để hồ sơ preview không mở sẵn cửa.

signal walkthrough_completed
signal activated

const COMPLETE_FLAG: StringName = &"level_3.t3_walkthrough_completed"
const FINISH_SPAWN: StringName = &"complete"
const ALTAR_SCRIPT = preload("res://levels/zone_3_fire/level_3/rooms/tier_3/tier_3_altar.gd")

@onready var _altar: ALTAR_SCRIPT = $"../Finish/Altar"
@onready var _fall_recovery: Area3D = $"../FallRecovery"


func _ready() -> void:
	_altar.completed.connect(_on_altar_completed)
	_fall_recovery.body_entered.connect(_on_fall)
	GameState.progress_replaced.connect(_queue_completion_check)
	_queue_completion_check()
	for label: Node in get_parent().find_children("*", "Label3D", true, false):
		(label as Label3D).modulate.a = 0.0


func is_active() -> bool:
	return _altar.is_complete()


func _on_altar_completed(_player: Player) -> void:
	_complete_if_ready()


func _queue_completion_check() -> void:
	_complete_if_ready.call_deferred()


func _complete_if_ready() -> void:
	if GameState.has_flag(COMPLETE_FLAG) or not is_active():
		return
	activated.emit()
	GameState.set_flag(COMPLETE_FLAG)
	GameState.set_checkpoint(get_parent().scene_file_path, FINISH_SPAWN)
	walkthrough_completed.emit()


func _on_fall(body: Node3D) -> void:
	var player: Player = body as Player
	if player:
		player.on_lethal_zone_entered()
