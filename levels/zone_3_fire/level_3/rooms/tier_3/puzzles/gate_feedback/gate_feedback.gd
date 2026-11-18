class_name GateFeedback
extends Node3D
## Cửa nghe nhiệt và trạng thái nguồn; nhịp đỏ dừng khi mở hoặc ra khỏi khung nhìn.

@export var plate: MeshInstance3D

var pulse_intensity: float = 0.0:
	set(value):
		pulse_intensity = value
		_apply_light()

var _data: LiPuzzleData
var _gate: StoneGate
var _lock: HeatLock
var _pulse_locked: bool = false
var _on_screen: bool = true
var _heat: float = 0.0
var _symbol_material: StandardMaterial3D
var _plate_material: StandardMaterial3D

@onready var _glyph: Node3D = $Glyph
@onready var _animation: AnimationPlayer = $AnimationPlayer
@onready var _glow: OmniLight3D = $Glow
@onready var _notifier: VisibleOnScreenNotifier3D = $Notifier


func _ready() -> void:
	_notifier.screen_entered.connect(_set_on_screen.bind(true))
	_notifier.screen_exited.connect(_set_on_screen.bind(false))


func configure(data: LiPuzzleData, gate: StoneGate, heat_source: HeatLock, pulse_locked: bool) -> void:
	_data = data
	_gate = gate
	_lock = heat_source
	_pulse_locked = pulse_locked
	_symbol_material = StandardMaterial3D.new()
	_symbol_material.emission_enabled = true
	for glyph: Node in _glyph.get_children():
		(glyph as MeshInstance3D).material_override = _symbol_material
	_plate_material = plate.get_active_material(0).duplicate() as StandardMaterial3D
	_plate_material.emission_enabled = true
	plate.material_override = _plate_material
	_lock.heat_changed.connect(_on_heat_changed)
	_gate.opened.connect(_refresh)
	_gate.closed.connect(_refresh)
	_heat = _lock.get_heat_ratio()
	_refresh()


func is_pulsing() -> bool:
	return _animation.is_playing()


func _refresh() -> void:
	if _data == null:
		return
	visible = not _gate.is_open and not _lock.is_active()
	if visible and _pulse_locked and _heat <= 0.0 and _on_screen:
		if not _animation.is_playing():
			_animation.play(&"feedback/pulse", -1.0, 1.0 / maxf(_data.gate_pulse_period, 0.01))
	else:
		_animation.stop()
	_apply_light()


func _on_heat_changed(ratio: float) -> void:
	_heat = ratio
	_refresh()


func _set_on_screen(on_screen: bool) -> void:
	_on_screen = on_screen
	_refresh()


func _apply_light() -> void:
	if _data == null or _symbol_material == null:
		return
	var color: Color = _data.cold_color
	var energy: float = 0.0
	if _heat > 0.0:
		color = _data.cold_color.lerp(_data.hot_color, _heat)
		energy = _heat * _data.heat_emission
	elif _pulse_locked:
		color = _data.gate_locked_color
		energy = lerpf(_data.gate_pulse_min_energy, _data.gate_pulse_max_energy, pulse_intensity)
	_symbol_material.albedo_color = color
	_symbol_material.emission = color
	_symbol_material.emission_energy_multiplier = energy
	_plate_material.emission = color
	_plate_material.emission_energy_multiplier = energy * _data.gate_plate_glow_scale if visible else 0.0
	_glow.light_color = color
	_glow.light_energy = energy
