class_name ChieftainPeelBoost
extends BananaPeelResponse
## Tăng tốc theo cùng cấu hình giày của player, không chuyển state hay chạm vào animation.
@export var settings: BananaItemSettings = preload("res://resources/world/monkey_garden/banana_item_settings.tres")
var _remaining: float = 0.0
var _actor: Enemy
var _trail: CPUParticles3D
func _ready() -> void:
	_actor = get_parent() as Enemy
	_trail = BananaItemEffects.particles(true); _trail.position.y = 0.08
	_actor.add_child.call_deferred(_trail)
	set_physics_process(false)
func step_on_peel() -> bool:
	if _actor.is_dead(): return true
	if not _actor.is_on_floor(): return true
	_remaining = maxf(settings.boost_duration,0.0)
	_trail.emitting = _remaining > 0.0
	set_physics_process(_remaining > 0.0)
	return true
func speed_multiplier() -> float:
	return maxf(settings.boost_multiplier,1.0) if _remaining > 0.0 else 1.0
func _physics_process(delta: float) -> void:
	_remaining = maxf(_remaining-delta,0.0)
	if _remaining == 0.0 or _actor.is_dead():
		_remaining = 0.0; _trail.emitting = false; set_physics_process(false)
