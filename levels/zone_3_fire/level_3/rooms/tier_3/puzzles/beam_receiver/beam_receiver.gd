class_name BeamReceiver
extends Node3D
## Nối tia với bề mặt va chạm thật của cửa hoặc khiên.

signal activated
signal deactivated
signal completed

const SURFACE_RECEIVER: StringName = &"tier_3_beam_receiver"

@export var surface: CollisionObject3D
@export var requires_continuous_light: bool = false
@export var stay_open_on_completion: bool = false
@export_range(0.0, 5.0, 0.05) var charge_time: float = 0.0
@export var flame_symbols: Array[CSGPolygon3D] = []

var _flag: StringName
var _legacy_flag: StringName
var _active: bool = false
var _enabled: bool = false
var _illuminated: bool = false
var _blocked: bool = false
var _charge_elapsed: float = 0.0
var _charge_level: float = 0.0
var _latched: bool = false
var _gate_lowered: bool = false
var _flame_materials: Array[ShaderMaterial] = []


func _ready() -> void:
	if surface != null:
		surface.set_meta(SURFACE_RECEIVER, self)
	for symbol: CSGPolygon3D in flame_symbols:
		var material: ShaderMaterial = symbol.material as ShaderMaterial
		if material != null:
			_flame_materials.append(material)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if _illuminated:
		_charge_elapsed += delta
		_set_charge_level(minf(_charge_elapsed / charge_time, 1.0))
		if _charge_level >= 1.0 or is_equal_approx(_charge_level, 1.0):
			_latched = true
			_set_charge_level(1.0)
			set_physics_process(false)
			if _gate_lowered:
				record_completion()
	else:
		_set_charge_level(move_toward(_charge_level, 0.0, delta / charge_time))
		if _charge_level <= 0.0:
			set_physics_process(false)


func configure(data: LiPuzzleData, flag: StringName, legacy_flag: StringName = &"") -> void:
	_flag = flag
	_legacy_flag = legacy_flag
	_configure_feedback(data)
	GameState.progress_replaced.connect(_restore)
	_restore()


func is_active() -> bool:
	if _blocked:
		return false
	if requires_continuous_light:
		return _illuminated or _latched or (stay_open_on_completion and _active)
	return _active


func is_completed() -> bool:
	return _active


func set_blocked(blocked: bool) -> void:
	if blocked == _blocked:
		return
	var was_active: bool = is_active()
	_blocked = blocked
	if charge_time > 0.0:
		if blocked:
			_reset_charge()
		for symbol: CSGPolygon3D in flame_symbols:
			symbol.visible = not blocked
	_emit_active_change(was_active)


func record_completion() -> void:
	if not is_active() or _active:
		return
	if charge_time > 0.0 and not _latched:
		_gate_lowered = true
		return
	_complete()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		set_illuminated(false)


func set_illuminated(lit: bool) -> void:
	var receiving: bool = lit and _enabled and not _blocked
	if requires_continuous_light:
		var was_active: bool = is_active()
		_illuminated = receiving
		if charge_time > 0.0 and not _latched:
			if not receiving:
				_charge_elapsed = 0.0
				_gate_lowered = false
			set_physics_process(receiving or _charge_level > 0.0)
		_emit_active_change(was_active)
	else:
		_receive(receiving and not _active)


func _receive(lit: bool) -> void:
	if lit:
		_complete()


func _complete() -> void:
	var was_active: bool = is_active()
	_active = true
	GameState.set_flag(_flag)
	_emit_active_change(was_active)
	completed.emit()


func _configure_feedback(_data: LiPuzzleData) -> void:
	pass


func _restore() -> void:
	var was_active: bool = is_active()
	_active = GameState.has_flag(_flag) or GameState.has_flag(_legacy_flag)
	if charge_time > 0.0:
		_reset_charge()
		if stay_open_on_completion and _active:
			_set_charge_level(1.0)
	else:
		_illuminated = false
	_receive(false)
	_emit_active_change(was_active)


func _emit_active_change(was_active: bool) -> void:
	var active: bool = is_active()
	if active and not was_active:
		activated.emit()
	elif was_active and not active:
		deactivated.emit()


func _reset_charge() -> void:
	_illuminated = false
	_latched = false
	_gate_lowered = false
	_charge_elapsed = 0.0
	_set_charge_level(0.0)
	set_physics_process(false)


func _set_charge_level(level: float) -> void:
	_charge_level = level
	for material: ShaderMaterial in _flame_materials:
		material.set_shader_parameter(&"charge", level)
