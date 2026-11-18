class_name KhamSinkingTile
extends CrumblingFloor
## Giữ FSM sàn sụp dùng chung, thêm vòng đời theo van và trigger khi rời ô.

var trigger_on_exit: bool = false
var _enabled: bool = false
var _players: Array[Player] = []

func _ready() -> void:
	super()
	$Detector.body_exited.connect(_on_body_exited)
	state_machine.state_changed.connect(_on_state_changed)
	set_physics_process(false)


func set_enabled(enabled: bool, safe: bool = false) -> void:
	_enabled = enabled and not safe
	_players.clear()
	if enabled:
		show()
		state_machine.transition_to(&"Solid")
		collision_layer = 1
		$Detector.set_deferred(&"monitoring", not safe)
	else:
		collision_layer = 0
		$Detector.set_deferred(&"monitoring", false)
		set_physics_process(false)
		hide()


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if not _enabled or player == null:
		return
	if trigger_on_exit:
		if not _players.has(player):
			_players.append(player)
	else:
		super(body)


func _on_body_exited(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null or not _players.has(player):
		return
	_players.erase(player)
	if _enabled and trigger_on_exit:
		super._on_body_entered(body)


func _on_state_changed(_from: StringName, to: StringName) -> void:
	set_physics_process(to != &"Solid" and _enabled)
