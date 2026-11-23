class_name TimedHurtBonus
extends Node
## Mỗi player giữ timer riêng vì CharmEffect là Resource dùng chung.

signal activated(duration: float)
signal deactivated

var _stats: StatModifiers
var _health: HealthComponent
var _hurtbox: HurtboxComponent
var _stat: StringName
var _source: StringName
var _bonus: float
var _duration: float
var _active: bool = false
var _status_icon: Texture2D
var _status_color: Color

@onready var _timer: Timer = $Timer


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_timer.timeout.connect(_clear_bonus)
	_hurtbox.hurt.connect(_on_hurt)
	_health.died.connect(_clear_bonus)


func _exit_tree() -> void:
	_clear_bonus()
	if is_instance_valid(_hurtbox) and _hurtbox.hurt.is_connected(_on_hurt):
		_hurtbox.hurt.disconnect(_on_hurt)
	if is_instance_valid(_health) and _health.died.is_connected(_clear_bonus):
		_health.died.disconnect(_clear_bonus)


func configure(player: Node, stat: StringName, source: StringName, bonus: float, duration: float,
		status_icon: Texture2D = null, status_color: Color = Color.WHITE) -> void:
	_stats = player.get_node(^"StatModifiers") as StatModifiers
	_health = player.get_node(^"HealthComponent") as HealthComponent
	_hurtbox = player.get_node(^"HurtboxComponent") as HurtboxComponent
	_stat = stat
	_source = source
	_bonus = maxf(bonus, 0.0)
	_duration = maxf(duration, 0.0)
	_status_icon = status_icon
	_status_color = status_color


func release() -> void:
	# Gỡ khỏi cây ngay để đổi bùa trong cùng frame không giữ hai bộ signal.
	get_parent().remove_child(self)
	queue_free()


func get_time_left() -> float:
	return _timer.time_left if _active and is_instance_valid(_timer) else 0.0


func get_status_icon() -> Texture2D:
	return _status_icon


func get_status_color() -> Color:
	return _status_color


func _on_hurt(_info: DamageInfo, damage_taken: int) -> void:
	if damage_taken <= 0 or _health.is_dead() or _bonus <= 0.0 or _duration <= 0.0:
		return
	_stats.set_bonus(_stat, _source, _bonus)
	_timer.start(_duration)
	_active = true
	activated.emit(_duration)


func _clear_bonus() -> void:
	if is_instance_valid(_timer):
		_timer.stop()
	if is_instance_valid(_stats):
		_stats.remove_bonus(_stat, _source)
	if _active:
		_active = false
		deactivated.emit()
