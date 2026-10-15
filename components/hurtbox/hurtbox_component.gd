class_name HurtboxComponent
extends Area3D
## Vùng nhận sát thương. Hitbox phát hiện vùng này rồi gọi receive_hit().
## Layer của hurtbox quyết định phe nào đánh được nó (player / enemy).

signal hurt(damage: int, knockback: Vector3)

## Mọi hurtbox tự vào group này để soft-lock tìm mục tiêu mà không cần biết loại entity
const GROUP := &"hurtbox"

@export var health: HealthComponent
## Thời gian bất tử sau mỗi lần trúng đòn, 0 = không có
@export var invincibility_time: float = 0.0

var _invincible_timer: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	# Hurtbox chỉ cần bị phát hiện, không tự quét
	monitoring = false
	monitorable = true


func _physics_process(delta: float) -> void:
	_invincible_timer = maxf(_invincible_timer - delta, 0.0)


func is_invincible() -> bool:
	return _invincible_timer > 0.0


## Dùng cho i-frames chủ động (dash, hồi sinh...)
func set_invincible(duration: float) -> void:
	_invincible_timer = maxf(_invincible_timer, duration)


func is_alive() -> bool:
	return health == null or not health.is_dead()


func receive_hit(damage: int, knockback: Vector3) -> void:
	if is_invincible():
		return
	_invincible_timer = invincibility_time
	if health:
		health.take_damage(damage)
	hurt.emit(damage, knockback)
