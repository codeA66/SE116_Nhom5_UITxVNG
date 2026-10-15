class_name HurtboxComponent
extends Area3D
## Vùng nhận sát thương. Nguồn gây sát thương gọi receive_hit() với một DamageInfo.
## Hurtbox quyết định thực sự mất bao nhiêu máu (cố định mỗi đòn hoặc theo kháng), rồi báo HealthComponent.
## Layer của hurtbox quyết định phe nào đánh được nó (player / enemy).

## damage_taken: lượng máu thực sự bị trừ sau khi tính cố định / kháng
signal hurt(info: DamageInfo, damage_taken: int)

## Mọi hurtbox tự vào group này để soft-lock tìm mục tiêu mà không cần biết loại entity
const GROUP := &"hurtbox"

@export var health: HealthComponent
## Thời gian bất tử sau mỗi lần trúng đòn, 0 = không có
@export var invincibility_time: float = 0.0
## > 0: mọi đòn chỉ trừ đúng chừng này máu, bỏ qua sát thương của đòn (player dùng 1)
@export var fixed_damage_per_hit: int = 0
## Hệ số nhận sát thương theo loại: 0 = miễn nhiễm, 0.5 = kháng một nửa, 2 = yếu gấp đôi. Không có = 1
@export var resistances: Dictionary[DamageInfo.Type, float] = {}

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


func receive_hit(info: DamageInfo) -> void:
	if is_invincible() or not is_alive():
		return
	_invincible_timer = invincibility_time
	var damage_taken := _resolve_damage(info)
	if health:
		health.take_damage(damage_taken)
	hurt.emit(info, damage_taken)


func _resolve_damage(info: DamageInfo) -> int:
	if fixed_damage_per_hit > 0:
		return fixed_damage_per_hit
	var multiplier: float = resistances.get(info.type, 1.0)
	return maxi(roundi(info.amount * multiplier), 0)
