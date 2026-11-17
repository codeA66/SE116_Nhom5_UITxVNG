class_name HitFeedbackComponent
extends Node
## Phản hồi khi bị đánh: tia lửa + (máu) + rung màn hình + co dẹt model. Nghe signal của hurtbox, không quét mỗi frame.
## Hurtbox có khiên (GuardedHurtboxComponent) thì đòn bị đỡ cũng có tia kim loại + rung nhẹ, không chảy máu.
## Gắn vào player / quái / boss đều dùng được; khác nhau chỉ ở HitFeedbackData.

## Mạnh hơn mức thường cho đòn mạnh / kết liễu
const STRONG_POWER := 1.5

@export var hurtbox: HurtboxComponent
## Chiếu đòn chém lên mặt capsule vì hitbox chỉ báo hai vùng chồng nhau.
@export var hit_surface: CollisionShape3D
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
	var killed: bool = hurtbox.health != null and hurtbox.health.is_dead()
	var strong: bool = killed or info.knockback.length() >= data.strong_knockback
	var power: float = STRONG_POWER if strong else 1.0
	var style: SlashStyle = info.attack.slash_style if info.attack else null
	if style:
		power *= style.spray_power
	var direction: Vector3 = _attack_direction(info)
	var origin: Vector3 = _hit_origin(info, direction)
	# Nét cắt theo chiều vung của nhát (SlashStyle); không có kiểu thì HitSpark tự chọn ngẫu nhiên như cũ
	var cut_axis: Vector3 = Vector3.ZERO
	var cut_scale: float = 1.0
	if style:
		cut_axis = direction.rotated(Vector3.UP, deg_to_rad(style.cut_angle_degrees))
		cut_scale = style.cut_scale
	CombatFx.spawn_hit(origin, _spray_direction(direction, style, data.upward_bias), data.spark_color, data.spark_scale, power, cut_axis, cut_scale)
	if data.bleeds:
		CombatFx.spawn_blood(
			origin, _spray_direction(direction, style, data.blood_upward_bias), data.blood_color,
			hurtbox.global_position.y, data.blood_scale * power, killed, data.blood_scale,
			data.blood_floor_mask
		)
	ScreenShake.add_trauma(data.trauma)
	if squash_stretch:
		squash_stretch.squash(data.squash_impact)


func _on_blocked(info: DamageInfo, _guard: HitGuard) -> void:
	var direction: Vector3 = _attack_direction(info)
	var origin: Vector3 = _hit_origin(info, direction)
	var style: SlashStyle = info.attack.slash_style if info.attack else null
	CombatFx.spawn_hit(origin, _spray_direction(direction, style, data.upward_bias), data.blocked_spark_color, data.spark_scale)
	ScreenShake.add_trauma(data.blocked_trauma)


## Lấy hướng đòn chứ không lấy knockback: đòn không đẩy vẫn văng đúng hướng. Đòn có SlashStyle thì
## xoay hướng văng và hất thêm theo kiểu của nhát đó
func _attack_direction(info: DamageInfo) -> Vector3:
	if not data.use_hit_contact:
		return info.direction
	if info.has_contact and not info.contact_direction.is_zero_approx():
		return info.contact_direction
	if info.direction.is_zero_approx() and is_instance_valid(info.source) and info.source is Node3D:
		var from_source: Vector3 = hurtbox.global_position - (info.source as Node3D).global_position
		from_source.y = 0.0
		return from_source.normalized()
	return info.direction


func _hit_origin(info: DamageInfo, direction: Vector3) -> Vector3:
	var fallback: Vector3 = hurtbox.global_position + Vector3.UP * data.hit_height
	if not data.use_hit_contact:
		return fallback
	if info.has_contact:
		return info.contact_position
	if hit_surface == null or not hit_surface.shape is CapsuleShape3D:
		return fallback

	var capsule: CapsuleShape3D = hit_surface.shape as CapsuleShape3D
	var inward: Vector3 = hit_surface.global_basis.inverse() * direction
	inward.y = 0.0
	if inward.is_zero_approx():
		return fallback
	var half_height: float = capsule.height * 0.5
	var height: float = clampf(hit_surface.to_local(fallback).y, -half_height, half_height)
	var cap_height: float = maxf(absf(height) - (half_height - capsule.radius), 0.0)
	var radius: float = sqrt(maxf(capsule.radius * capsule.radius - cap_height * cap_height, 0.0))
	return hit_surface.to_global(Vector3.UP * height - inward.normalized() * radius)


func _spray_direction(direction: Vector3, style: SlashStyle, upward_bias: float) -> Vector3:
	if style:
		direction = style.spray_direction(direction)
		upward_bias += style.spray_upward_bias
	return direction + Vector3.UP * upward_bias
