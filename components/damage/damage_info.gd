class_name DamageInfo
extends RefCounted
## Một lần gây sát thương. Mọi nguồn (kiếm, bẫy, quái, kỹ năng) đều tạo gói này,
## nên Hurtbox không cần biết sát thương đến từ đâu.

## Loại sát thương. Thêm nguyên tố mới (gió, lửa...) chỉ cần thêm một giá trị ở đây
enum Type { PHYSICAL }

var amount: int
var type: Type
var knockback: Vector3
var source: Node


func _init(p_amount: int = 1, p_type: Type = Type.PHYSICAL, p_knockback: Vector3 = Vector3.ZERO, p_source: Node = null) -> void:
	amount = p_amount
	type = p_type
	knockback = p_knockback
	source = p_source
