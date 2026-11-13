extends Label3D

const HOLD_TIME: float = 1.0
const FADE_TIME: float = 0.25

@export var energy: EnergyComponent

var _fade: Tween


func _ready() -> void:
	energy.insufficient.connect(_show_warning)


func _show_warning(_cost: int) -> void:
	if _fade != null:
		_fade.kill()
	modulate.a = 1.0
	outline_modulate.a = 1.0
	show()
	_fade = create_tween()
	_fade.tween_interval(HOLD_TIME)
	_fade.tween_property(self, ^"modulate:a", 0.0, FADE_TIME)
	_fade.parallel().tween_property(self, ^"outline_modulate:a", 0.0, FADE_TIME)
	_fade.tween_callback(hide)
