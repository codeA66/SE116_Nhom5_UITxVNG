class_name BeamPuzzleStage
extends Node3D
## Một bộ gương có nguồn, khóa đích và chuyển động nâng/hạ; thêm lượt bằng scene và dữ liệu.

signal activated
signal deactivated
signal completed(stage: BeamPuzzleStage)
signal presence_finished(stage: BeamPuzzleStage, present: bool)

@export var rig: Node3D
@export var mirrors: Array[RotatingFireMirror] = []
@export var emitter: Node3D
@export var beam: FireBeam
@export var receiver: HeatLock
@export var blockers: Array[CollisionShape3D] = []

var reveal_progress: float = 1.0:
	set(value):
		reveal_progress = clampf(value, 0.0, 1.0)
		if is_instance_valid(rig):
			rig.position = _hidden_position.lerp(_raised_position, reveal_progress)

var _data: LiPuzzleData
var _raised_position: Vector3
var _hidden_position: Vector3
var _present: bool = false
var _desired_present: bool = false
var _route_open: bool = false
var _prerequisite_met: bool = true

@onready var _animation: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_animation.animation_finished.connect(_on_animation_finished)


func configure(data: LiPuzzleData, completion_flag: StringName) -> void:
	_data = data
	_raised_position = rig.position
	_hidden_position = _raised_position - Vector3.UP * data.stage_sink_depth
	receiver.configure(data, completion_flag)
	receiver.melted.connect(_on_melted)
	for mirror: RotatingFireMirror in mirrors:
		mirror.orientation_changed.connect(beam.request_trace)
	beam.configure(emitter, data)
	set_present(false, false)


func is_active() -> bool:
	return _route_open


func is_complete() -> bool:
	return receiver.is_active()


func is_present() -> bool:
	return _present


func is_changing() -> bool:
	return _animation.is_playing()


func set_route_open(open: bool) -> void:
	if open == _route_open:
		return
	_route_open = open
	if open:
		activated.emit()
	else:
		deactivated.emit()


func set_prerequisite_met(met: bool) -> void:
	_prerequisite_met = met
	receiver.set_enabled(_present and met and not is_complete())


func stop_puzzle() -> void:
	beam.set_enabled(false)
	receiver.set_enabled(false)
	for mirror: RotatingFireMirror in mirrors:
		mirror.set_locked(true)


func set_present(present: bool, animate: bool) -> void:
	_animation.stop(true)
	_desired_present = present
	_present = false
	stop_puzzle()
	for mirror: RotatingFireMirror in mirrors:
		mirror.set_present(false)
	for blocker: CollisionShape3D in blockers:
		blocker.set_deferred(&"disabled", true)
	rig.visible = true
	if animate:
		_animation.play(&"stage/raise" if present else &"stage/lower", -1.0, 1.0 / maxf(_data.stage_transition_time, 0.01))
		_animation.advance(0.0)
	else:
		reveal_progress = 1.0 if present else 0.0
		_finish_presence()


func _on_animation_finished(_name: StringName) -> void:
	_animation.stop(true)
	reveal_progress = 1.0 if _desired_present else 0.0
	_finish_presence()


func _finish_presence() -> void:
	_present = _desired_present
	rig.visible = _present
	if _present:
		for index: int in range(mirrors.size()):
			var initial: int = _data.initial_steps[index] if index < _data.initial_steps.size() else 0
			mirrors[index].configure(_data, initial)
			mirrors[index].set_present(true)
			mirrors[index].set_locked(is_complete())
		for blocker: CollisionShape3D in blockers:
			blocker.set_deferred(&"disabled", false)
		receiver.set_enabled(_prerequisite_met and not is_complete())
		beam.set_enabled(not is_complete())
	presence_finished.emit(self, _present)


func _on_melted() -> void:
	stop_puzzle()
	completed.emit(self)
