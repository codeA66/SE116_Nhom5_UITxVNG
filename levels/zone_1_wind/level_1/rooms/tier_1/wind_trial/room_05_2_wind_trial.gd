extends Node3D
## Hai đợt dùng Encounter riêng. Chỉ đợt cuối mới chốt tiến trình và mở cổng.

signal activated

const WIND_ID := &"wind_blast"
const TrialGrille := preload("grille/trial_grille.gd")

@export var cleared_flag: StringName = &"level_1.wind_reflect_trial_cleared"
@export var wave_break: float = 2.0

var current_wave: int = 0

@onready var _trigger: Area3D = $EntryTrigger
@onready var _entry_gate: TrialGrille = $EntryGate
@onready var _exit_gate: TrialGrille = $ExitGate
@onready var _intro: Encounter = $FirstWave
@onready var _final: Encounter = $SecondWave


func _ready() -> void:
	if is_active():
		_trigger.monitoring = false
		_exit_gate.set_open(true, false)
		_intro.queue_free()
		_final.queue_free()
		return
	_intro.cleared.connect(_after_first_wave, CONNECT_ONE_SHOT)
	_final.cleared.connect(_finish, CONNECT_ONE_SHOT)
	_trigger.body_entered.connect(_on_entry)


## StoneGate dùng cờ này để mở ngay khi nạp lại tiến trình đã thắng.
func is_active() -> bool:
	return GameState.has_flag(cleared_flag)


func _on_entry(body: Node3D) -> void:
	if not body is Player or current_wave != 0 or not GameState.has_ability(WIND_ID):
		return
	current_wave = 1
	_trigger.set_deferred(&"monitoring", false)
	_entry_gate.set_open(false)
	# Vào phòng xảy ra trong lúc vật lý phát overlap. Chờ ra khỏi callback rồi mới đưa quái vào cây.
	_intro.start.call_deferred()


func _after_first_wave() -> void:
	var next_wave := create_tween()
	next_wave.tween_interval(maxf(wave_break, 0.0))
	next_wave.tween_callback(_start_final_wave)


func _start_final_wave() -> void:
	current_wave = 2
	_final.start()


func _finish() -> void:
	GameState.set_flag(cleared_flag)
	_entry_gate.set_open(true)
	_exit_gate.set_open(true)
	activated.emit()
