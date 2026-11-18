extends Node
## Tuyến bốn phòng dùng ấn riêng để hồ sơ preview không mở sẵn cửa.

signal walkthrough_completed
signal activated

const COMPLETE_FLAG: StringName = &"level_3.t3_walkthrough_completed"
const FINISH_SPAWN: StringName = &"complete"

@export var required_flags: Array[StringName] = []

@onready var _finish: Area3D = $"../Finish/Completion"
@onready var _fall_recovery: Area3D = $"../FallRecovery"


func _ready() -> void:
	_finish.body_entered.connect(_on_finish_entered)
	_fall_recovery.body_entered.connect(_on_fall)
	GameState.progress_changed.connect(_on_progress_changed)
	for label: Node in get_parent().find_children("*", "Label3D", true, false):
		(label as Label3D).modulate.a = 0.0


func is_active() -> bool:
	for flag: StringName in required_flags:
		if not GameState.has_flag(flag):
			return false
	return not required_flags.is_empty()


func _on_progress_changed() -> void:
	if is_active():
		GameState.progress_changed.disconnect(_on_progress_changed)
		activated.emit()


func _on_finish_entered(body: Node3D) -> void:
	if not body is Player or GameState.has_flag(COMPLETE_FLAG) or not is_active():
		return
	GameState.set_flag(COMPLETE_FLAG)
	GameState.set_checkpoint(get_parent().scene_file_path, FINISH_SPAWN)
	walkthrough_completed.emit()


func _on_fall(body: Node3D) -> void:
	var player: Player = body as Player
	if player:
		player.on_lethal_zone_entered()
