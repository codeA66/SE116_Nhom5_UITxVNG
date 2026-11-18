class_name StrikeValve
extends HurtboxComponent
## Dùng cùng cơ chế một mục tiêu mỗi đòn của HitboxComponent để tránh xoay van nhiều nấc.

signal struck(player: Player)

@export var wheel: Node3D
@export var one_shot: bool = false
@export var quarter_turn: float = PI * 0.5

var _data: KhamPuzzleData
var _enabled: bool = true
var _used: bool = false
var _turning: bool = false
var _turn: Tween

@onready var _sound: AudioStreamPlayer3D = $TurnSound


func _ready() -> void:
	super()
	remove_from_group(GROUP)
	set_physics_process(false)


func configure(data: KhamPuzzleData) -> void:
	_data = data


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func receive_hit(info: DamageInfo) -> bool:
	if not _enabled or _turning or _data == null or not info.source is Player:
		return false
	if one_shot and _used:
		return false
	_used = true
	_turning = true
	if _sound.stream:
		_sound.play()
	_turn = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	if wheel:
		_turn.tween_property(wheel, "rotation:y", wheel.rotation.y + quarter_turn, maxf(_data.valve_turn_time, 0.01))
	else:
		_turn.tween_interval(maxf(_data.valve_turn_time, 0.01))
	_turn.tween_callback(_finish_turn)
	struck.emit(info.source as Player)
	return true


func _finish_turn() -> void:
	_turning = false
