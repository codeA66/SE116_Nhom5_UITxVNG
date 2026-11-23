class_name DamageInfo
extends RefCounted
## Một lần gây sát thương. Mọi nguồn (kiếm, bẫy, quái, kỹ năng) đều tạo gói này,
## nên Hurtbox không cần biết sát thương đến từ đâu.

## Loại sát thương. Thêm nguyên tố mới (gió, lửa...) chỉ cần thêm một giá trị ở đây
enum Type { PHYSICAL, FIRE, WIND }

var amount: int
var type: Type
var knockback: Vector3
var source: Node
## Hướng đòn (ngang, đã chuẩn hóa), tách khỏi knockback: đòn không đẩy vẫn có hướng cho hiệu ứng văng
var direction: Vector3
## So với hướng knockback, thông tin này vẫn có khi đòn chạm nhưng không đẩy.
var has_contact: bool = false
var contact_position: Vector3
var contact_direction: Vector3
## Đòn gây ra cú đánh (null nếu nguồn không phải AttackData: bẫy, sóng...). Hiệu ứng trúng đọc kiểu chém từ đây
var attack: AttackData
## Bỏ qua bất tử của mục tiêu (bẫy môi trường: dash hay vừa bị đánh cũng không đi xuyên được)
var ignores_invincibility: bool = false
## false: đòn không làm mục tiêu khựng (tick cháy...), mục tiêu vẫn nháy và mất máu
var staggers: bool = true


func _init(p_amount: int = 1, p_type: Type = Type.PHYSICAL, p_knockback: Vector3 = Vector3.ZERO, p_source: Node = null) -> void:
	amount = p_amount
	type = p_type
	knockback = p_knockback
	source = p_source
	direction = Vector3(p_knockback.x, 0.0, p_knockback.z).normalized()


func set_contact(world_position: Vector3, incoming_direction: Vector3) -> void:
	has_contact = true
	contact_position = world_position
	contact_direction = incoming_direction.normalized()


func apply_weapon_damage_bonus(origin: Node) -> void:
	if amount <= 0 or not is_instance_valid(source) or not source.has_method(&"get_weapon_damage_bonus"):
		return
	# Chủ đòn xác nhận đúng vũ khí; đòn nguyên tố riêng không tự nhận bonus này.
	amount += maxi(int(source.call(&"get_weapon_damage_bonus", origin, attack)), 0)
