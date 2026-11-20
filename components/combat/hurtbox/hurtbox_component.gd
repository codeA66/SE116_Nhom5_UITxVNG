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

## Bộ chỉnh sát thương dùng chung cho mọi hurtbox (cheat dev): mỗi Callable nhận (hurtbox, info, damage) và trả
## lượng máu mới bị trừ. Mặc định trống nên không tốn gì; tĩnh để cheat không phải tìm từng hurtbox trong màn
static var damage_modifiers: Array[Callable] = []

## Chặn mọi đòn, kể cả đòn xuyên bất tử (chế độ test của player)
var invulnerable: bool = false

var _invincible_timer: float = 0.0
var _hit_interceptors: Array[Callable] = []


func _ready() -> void:
	add_to_group(GROUP)
	# Hurtbox chỉ cần bị phát hiện, không tự quét
	monitoring = false
	monitorable = true


func _physics_process(delta: float) -> void:
	_invincible_timer = maxf(_invincible_timer - delta, 0.0)


func is_invincible() -> bool:
	return _invincible_timer > 0.0


## Thời gian bất tử còn lại (s), 0 nếu không bất tử
func get_invincible_time() -> float:
	return _invincible_timer


## Dùng cho i-frames chủ động (dash, hồi sinh...)
func set_invincible(duration: float) -> void:
	_invincible_timer = maxf(_invincible_timer, duration)


func is_alive() -> bool:
	return health == null or not health.is_dead()


## Trả true từ callback để nhận xử lý đòn hợp lệ trước khi trừ máu và phát hurt.
func add_hit_interceptor(interceptor: Callable) -> void:
	if interceptor.is_valid() and not _hit_interceptors.has(interceptor):
		_hit_interceptors.append(interceptor)


func remove_hit_interceptor(interceptor: Callable) -> void:
	_hit_interceptors.erase(interceptor)


## Trả về true nếu đòn thực sự được tính (không bị bất tử chặn, mục tiêu còn sống)
func receive_hit(info: DamageInfo) -> bool:
	if invulnerable or not is_alive() or (is_invincible() and not info.ignores_invincibility):
		return false
	var damage_taken := _resolve_damage(info)
	for modifier: Callable in damage_modifiers:
		damage_taken = maxi(int(modifier.call(self, info, damage_taken)), 0)
	if damage_taken > 0:
		for interceptor: Callable in _hit_interceptors:
			if interceptor.is_valid() and interceptor.call(info):
				return true
	# Lấy cái dài hơn: đòn xuyên bất tử (tick cháy, bẫy) trúng lúc đang dash không được cắt ngắn bất tử của dash
	_invincible_timer = maxf(_invincible_timer, invincibility_time)
	damage_taken = _apply_damage(damage_taken)
	hurt.emit(info, damage_taken)
	return true


func _apply_damage(amount: int) -> int:
	if health:
		health.take_damage(amount)
	return amount


func _resolve_damage(info: DamageInfo) -> int:
	if fixed_damage_per_hit > 0:
		return fixed_damage_per_hit
	var multiplier: float = resistances.get(info.type, 1.0)
	return maxi(roundi(info.amount * multiplier), 0)
