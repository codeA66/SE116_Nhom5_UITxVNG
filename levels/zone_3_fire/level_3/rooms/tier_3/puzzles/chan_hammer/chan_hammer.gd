class_name ChanHammer
extends Node3D
## Nhịp búa chỉ chạy khi có player. Vành sóng và vùng trúng dùng cùng bán kính.

signal struck
signal wave_hit(player: Player)

const MIN_TIME: float = 0.01
const LIFT_RATIO: float = 0.8
const WAVE_BAND: float = 0.13

@export_range(0.1, 30.0, 0.1, "or_greater") var radius: float = 5.0
@export var lift_height: float = 1.9

var _data: ChanPuzzleData
var _player: Player
var _swing: Tween
var _wave_radius: float = 0.0
var _cycle_time: float
var _warning_time: float
var _wave_hit: bool = false
var _rest_height: float

@onready var _head: Node3D = $Head
@onready var _timer: Timer = $Cycle
@onready var _ring: MeshInstance3D = $Ring
@onready var _ring_material: ShaderMaterial = _ring.material_override as ShaderMaterial
@onready var _warning: MeshInstance3D = $Warning
@onready var _impact: AudioStreamPlayer3D = $Impact


func _ready() -> void:
	_rest_height = _head.position.y
	var diameter: Vector3 = Vector3(radius * 2.0, 1.0, radius * 2.0)
	_ring.scale = diameter
	_warning.scale = diameter
	_timer.timeout.connect(_warn)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	var previous: float = _wave_radius
	_wave_radius = minf(1.0 + WAVE_BAND, previous + delta / maxf(_data.wave_time, MIN_TIME))
	_ring_material.set_shader_parameter(&"radius", _wave_radius)
	if not _wave_hit and is_instance_valid(_player):
		var local: Vector3 = to_local(_player.global_position)
		var distance: float = Vector2(local.x, local.z).length() / maxf(radius, MIN_TIME)
		if distance <= 1.0 and distance >= previous - WAVE_BAND and distance <= _wave_radius + WAVE_BAND:
			_wave_hit = true
			wave_hit.emit(_player)
	if _wave_radius >= 1.0 + WAVE_BAND:
		_ring.hide()
		set_physics_process(false)


func start(player: Player, data: ChanPuzzleData, cycle: float = 0.0, warning: float = 0.0, offset: float = 0.0) -> void:
	_player = player
	_data = data
	_cycle_time = cycle if cycle > 0.0 else data.cycle_time
	_warning_time = warning if warning > 0.0 else data.warning_time
	_wait_for_next_warning(offset)


func stop() -> void:
	_player = null
	_timer.stop()
	_impact.stop()
	if _swing:
		_swing.kill()
	_head.position.y = _rest_height
	_ring.hide()
	_warning.hide()
	set_physics_process(false)


func _warn() -> void:
	_warning.show()
	var warning_time: float = maxf(_warning_time, MIN_TIME)
	_swing = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_swing.tween_property(_head, ^"position:y", _rest_height + lift_height, warning_time * LIFT_RATIO)
	_swing.tween_property(_head, ^"position:y", _rest_height, warning_time * (1.0 - LIFT_RATIO)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_swing.tween_callback(_strike)


func _strike() -> void:
	_warning.hide()
	_ring_material.set_shader_parameter(&"radius", 0.0)
	_ring.show()
	_wave_radius = 0.0
	_wave_hit = false
	if _impact.stream:
		_impact.play()
	set_physics_process(true)
	_wait_for_next_warning()
	struck.emit()


func _wait_for_next_warning(offset: float = 0.0) -> void:
	var wave_duration: float = _data.wave_time * (1.0 + WAVE_BAND)
	_timer.start(maxf(_cycle_time - _warning_time, maxf(wave_duration, MIN_TIME)) + offset)
