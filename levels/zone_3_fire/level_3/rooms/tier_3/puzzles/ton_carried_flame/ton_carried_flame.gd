class_name TonCarriedFlame
extends Node3D
## Mức phơi dùng cùng kết quả lấy mẫu gió với chuyển động của player.

@export var follow_offset: Vector3 = Vector3(0.85, 1.55, 0.25)
@export_range(1.0, 30.0, 0.5) var follow_speed: float = 10.0
@export_range(0.1, 30.0, 0.5) var flutter_frequency: float = 14.0

var _carrier: Player
var _data: TonPuzzleData
var _exposure: float = 0.0
var _is_ember: bool = false
var _sheltered_time: float = 0.0
var _flutter_time: float = 0.0

@onready var _flame: MeshInstance3D = $Flame
@onready var _light: OmniLight3D = $Light
@onready var _light_energy: float = _light.light_energy
@onready var _blue_light: Color = _light.light_color
@onready var _core: StandardMaterial3D = _flame.get_active_material(0) as StandardMaterial3D
@onready var _blue_core: Color = _core.albedo_color
@onready var _feedback: FlameFeedback = $FireFeedback


func _ready() -> void:
	_feedback.setup(null, null, 0.0)
	hide()


func is_carried_by(player: Player) -> bool:
	return _carrier == player


func can_ignite(player: Player) -> bool:
	return is_carried_by(player) and not _is_ember


func kindle(player: Player, data: TonPuzzleData) -> void:
	_carrier = player
	_data = data
	_exposure = 0.0
	_flutter_time = 0.0
	_set_ember(false)
	global_position = player.global_position + follow_offset
	reset_physics_interpolation()
	_flame.scale = Vector3.ONE
	_light.light_energy = _light_energy
	show()
	_feedback.start_quiet()


func clear() -> void:
	_carrier = null
	_exposure = 0.0
	_feedback.extinguish()
	hide()


func advance(delta: float, exposed: bool) -> void:
	if not is_instance_valid(_carrier):
		return
	var limit: float = maxf(_data.exposure_limit, 0.01)
	if _is_ember:
		_sheltered_time = 0.0 if exposed else _sheltered_time + delta
		if _sheltered_time >= _data.ember_rest_time:
			_exposure = 0.0
			_set_ember(false)
	else:
		_exposure = clampf(_exposure + (delta if exposed else -delta * _data.exposure_recovery), 0.0, limit)
		if _exposure >= limit:
			_set_ember(true)
	_flutter_time += delta
	var bob := sin(_flutter_time * 4.0) * 0.12
	var target := _carrier.global_position + follow_offset + Vector3.UP * bob
	global_position = global_position.lerp(target, 1.0 - exp(-follow_speed * delta))
	if _is_ember:
		return
	var ratio := _exposure / maxf(_data.exposure_limit, 0.01)
	var warning := smoothstep(_data.warning_ratio, 1.0, ratio) if _data.warning_ratio < 1.0 else 0.0
	var flutter := sin(_flutter_time * flutter_frequency * TAU) * 0.5 + 0.5
	var intensity := lerpf(1.0, 0.32 + flutter * 0.53, warning)
	_flame.scale = Vector3(0.75 + intensity * 0.25, intensity, 0.75 + intensity * 0.25)
	_light.light_energy = _light_energy * intensity
	_feedback.sputter = warning > 0.0
	_feedback.intensity = intensity


func _set_ember(ember: bool) -> void:
	_is_ember = ember
	_sheltered_time = 0.0
	_core.albedo_color = _data.ember_color if ember else _blue_core
	_light.light_color = _data.ember_color if ember else _blue_light
	_feedback.visible = not ember
	if ember:
		_light.light_energy = _light_energy * _data.ember_intensity
		_flame.scale = Vector3.ONE * pow(_data.ember_intensity, 0.333333)
