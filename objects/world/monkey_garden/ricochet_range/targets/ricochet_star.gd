class_name RicochetStar
extends Area3D
signal struck(target: RicochetStar)
@export var travel_speed: float = 1.0
@export var phase_offset: float = 0.0
var collected: bool = false
var _clock: float = 0.0
@onready var _follow: PathFollow3D = get_parent() as PathFollow3D
@onready var _visual: Node3D = $Visual
@onready var _sparks: CPUParticles3D = $Sparkles

func _ready() -> void:
	monitoring = false
	reset_target()
func _physics_process(delta: float) -> void:
	_clock += delta * travel_speed
	_follow.progress_ratio = 0.5 + sin(_clock + phase_offset)*0.5
	_visual.rotation.z += delta*1.5
func hit() -> void:
	if collected: return
	collected = true; _visual.hide(); _sparks.emitting = false
	set_deferred("collision_layer",0)
	struck.emit(self)
func reset_target() -> void:
	collected = false; _clock = 0.0
	_visual.show(); _sparks.emitting = true
	set_deferred("collision_layer",2048)
