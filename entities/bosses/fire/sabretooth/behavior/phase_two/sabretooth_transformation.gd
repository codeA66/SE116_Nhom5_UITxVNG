extends EnemyState
## Giữ trận đang chạy qua cutscene, không phát chết boss khi hết máu phase đầu.

var _actor: FireSabretooth
var _done: bool


func _ready() -> void:
	super()
	_actor = enemy as FireSabretooth
	(_actor.get_node("Phase") as SabretoothPhase).finished.connect(_on_transformed)


func enter(_previous: StringName) -> void:
	_done = false
	_actor.hitbox.cancel()
	_actor.velocity = Vector3.ZERO
	_actor.phase.preview(_actor.target as Player)


func exit() -> void:
	if not _done:
		_actor.phase.cancel_preview()


func physics_update(delta: float) -> void:
	_actor.apply_gravity(delta)
	if _done:
		state_machine.transition_to(&"TigerFireBeam")


func _on_transformed() -> void:
	if state_machine.current_state == self:
		_done = true
