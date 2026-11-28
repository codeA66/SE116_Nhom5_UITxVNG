extends Node
## Tuyến bốn phòng dùng ấn riêng để hồ sơ preview không mở sẵn cửa.

signal walkthrough_completed
signal activated

const COMPLETE_FLAG: StringName = &"level_3.t3_walkthrough_completed"
const ALTAR_SCRIPT = preload("res://levels/zone_3_fire/level_3/rooms/tier_3/tier_3_altar.gd")

@onready var _altar: ALTAR_SCRIPT = $"../Finish/Altar"
@onready var _fall_recovery: Area3D = $"../FallRecovery"
@onready var _wing_collapses: Array[WingCollapseController] = [
	$"../WingCollapses/LyCollapse",
	$"../WingCollapses/KhamCollapse",
	$"../WingCollapses/TonCollapse",
	$"../WingCollapses/ChanCollapse",
]


func _ready() -> void:
	_altar.slot_placed.connect(_on_altar_slot_placed)
	_altar.gem_placed.connect(_check_completion)
	_fall_recovery.body_entered.connect(_on_fall)
	GameState.progress_replaced.connect(_queue_completion_check)
	_queue_completion_check()
	for label: Node in get_parent().find_children("*", "Label3D", true, false):
		(label as Label3D).modulate.a = 0.0


func is_active() -> bool:
	return _altar.is_complete()


func _queue_completion_check() -> void:
	_restore_collapsed_wings()
	_check_completion.call_deferred()


func _on_altar_slot_placed(index: int, actor: Node3D) -> void:
	if index < 0 or index >= _wing_collapses.size():
		return
	var collapse: WingCollapseController = _wing_collapses[index]
	if is_instance_valid(collapse):
		collapse.trigger_collapse(actor as Player)


func _restore_collapsed_wings() -> void:
	for collapse: WingCollapseController in _wing_collapses:
		if is_instance_valid(collapse) and not collapse.placed_flag.is_empty() and GameState.has_flag(collapse.placed_flag):
			collapse.apply_collapsed_immediate()


func _check_completion() -> void:
	if not is_active() or GameState.has_flag(COMPLETE_FLAG):
		return
	GameState.set_flag(COMPLETE_FLAG)
	activated.emit()
	walkthrough_completed.emit()


func _on_fall(body: Node3D) -> void:
	var player: Player = body as Player
	if player:
		player.on_lethal_zone_entered()
