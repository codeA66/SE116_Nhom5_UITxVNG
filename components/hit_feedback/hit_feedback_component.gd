class_name HitFeedbackComponent
extends Node
## Phản hồi khi bị đánh: tia lửa + (máu) + rung màn hình + co dẹt model. Nghe signal của hurtbox, không quét mỗi frame.
## Hurtbox có khiên (GuardedHurtboxComponent) thì đòn bị đỡ cũng có tia kim loại + rung nhẹ, không chảy máu.
## Gắn vào player / quái / boss đều dùng được; khác nhau chỉ ở HitFeedbackData.

## Mạnh hơn mức thường cho đòn mạnh / kết liễu
const STRONG_POWER := 1.5

@export var hurtbox: HurtboxComponent
## Tuỳ chọn: không gán thì bỏ qua hiệu ứng co dẹt
@export var squash_stretch: SquashStretchComponent
@export var data: HitFeedbackData


func _ready() -> void:
	if hurtbox == null or data == null:
		push_error("%s cần hurtbox và data" % get_path())
		return
	hurtbox.hurt.connect(_on_hurt)
	var guarded := hurtbox as GuardedHurtboxComponent
	if guarded:
		guarded.blocked.connect(_on_blocked)


func get_data() -> HitFeedbackData:
	return data


func _on_hurt(info: DamageInfo, _damage_taken: int) -> void:
	var killed := hurtbox.health != null and hurtbox.health.is_dead()
	var strong := killed or info.knockback.length() >= data.strong_knockback
	var power := STRONG_POWER if strong else 1.0
	var origin := hurtbox.global_position + Vector3.UP * data.hit_height
	CombatFx.spawn_hit(origin, _direction(info, data.upward_bias), data.spark_color, data.spark_scale, power)
	if data.bleeds:
		CombatFx.spawn_blood(origin, _direction(info, data.blood_upward_bias), data.blood_color, hurtbox.global_position.y, data.blood_scale * power, killed)
	ScreenShake.add_trauma(data.trauma)
	if squash_stretch:
		squash_stretch.squash(data.squash_impact)


func _on_blocked(info: DamageInfo, _guard: HitGuard) -> void:
	var origin := hurtbox.global_position + Vector3.UP * data.hit_height
	CombatFx.spawn_hit(origin, _direction(info, data.upward_bias), data.blocked_spark_color, data.spark_scale)
	ScreenShake.add_trauma(data.blocked_trauma)


func _direction(info: DamageInfo, upward_bias: float) -> Vector3:
	var direction := info.knockback
	direction.y = 0.0
	return direction.normalized() + Vector3.UP * upward_bias
