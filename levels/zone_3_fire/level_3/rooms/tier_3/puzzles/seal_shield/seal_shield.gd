class_name SealShield
extends BeamReceiver
## Nung liên tục; sau khi vỡ, thể tích nhận tia biến mất.

@export_range(0.05, 2.0, 0.05) var break_time: float = 0.35
@export var cold_color: Color = Color(0.65, 0.16, 0.06, 0.24)
@export var hot_color: Color = Color(1.0, 0.52, 0.12, 0.82)

var _data: LiPuzzleData
var _heat: float = 0.0
var _material: StandardMaterial3D
var _burst: Tween

@onready var _shell: MeshInstance3D = $Shell
@onready var _shape: CollisionShape3D = $Surface/CollisionShape3D
@onready var _shards: CPUParticles3D = $Shards


func _ready() -> void:
	super._ready()
	_material = _shell.material_override as StandardMaterial3D
	_show_heat(0.0)


func _physics_process(delta: float) -> void:
	_heat += delta
	var duration: float = maxf(_data.melt_time, 0.01)
	_show_heat(minf(_heat / duration, 1.0))
	if _heat < duration:
		return
	set_physics_process(false)
	_shape.set_deferred(&"disabled", true)
	_shards.restart()
	_shards.emitting = true
	_burst = create_tween().set_parallel()
	_burst.tween_property(_shell, "scale", Vector3.ONE * 1.25, break_time)
	_burst.tween_property(_material, "albedo_color:a", 0.0, break_time)
	_burst.tween_property(_material, "emission_energy_multiplier", 0.0, break_time)
	_burst.finished.connect(_finish_burst)


func _configure_feedback(data: LiPuzzleData) -> void:
	_data = data


func _receive(lit: bool) -> void:
	if _burst != null and _burst.is_running():
		return
	set_physics_process(lit)
	if not lit:
		_heat = 0.0
		_show_heat(0.0)


func _restore() -> void:
	if _burst != null:
		_burst.kill()
	_shards.emitting = false
	super._restore()
	_shell.scale = Vector3.ONE
	_shell.visible = not is_active()
	_shape.set_deferred(&"disabled", is_active())


func _show_heat(ratio: float) -> void:
	_material.albedo_color = cold_color.lerp(hot_color, ratio)
	_material.emission = hot_color
	_material.emission_energy_multiplier = ratio * _data.heat_emission if _data else 0.0


func _finish_burst() -> void:
	_shell.hide()
	_complete()
