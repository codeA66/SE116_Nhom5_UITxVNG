class_name InteractValve
extends InteractableComponent
## Dùng vùng tương tác của người chơi để xoay van và báo cho câu đố.

signal activated(player: Player)

@export_group("Chuyển động")
@export var wheel: Node3D
@export var one_shot: bool = false
@export var quarter_turn: float = PI * 0.5

var _data: KhamPuzzleData
var _used: bool = false
var _turning: bool = false

@onready var _sound: AudioStreamPlayer3D = $TurnSound


func _ready() -> void:
	super()
	availability_check = _can_open
	interacted.connect(_on_interacted)


func configure(data: KhamPuzzleData) -> void:
	_data = data


func set_enabled(active: bool) -> void:
	enabled = active
	set_deferred(&"monitorable", active)


func _can_open(interactor: Node3D) -> bool:
	return interactor is Player and _data != null and not _turning and not (one_shot and _used)


func _on_interacted(interactor: Node3D) -> void:
	_used = true
	_turning = true
	if _sound.stream:
		_sound.play()
	var duration: float = maxf(_data.valve_turn_time, 0.01)
	var turn: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	if wheel:
		turn.tween_property(wheel, "rotation:y", wheel.rotation.y + quarter_turn, duration)
	else:
		turn.tween_interval(duration)
	turn.tween_callback(_finish_turn)
	activated.emit(interactor as Player)


func _finish_turn() -> void:
	_turning = false
